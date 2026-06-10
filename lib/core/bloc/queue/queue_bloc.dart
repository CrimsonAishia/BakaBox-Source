import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/server_api.dart';
import '../../utils/log_service.dart';
import '../../utils/storage_utils.dart';
import '../../models/server_models.dart';
import '../../services/game_status_service.dart';
import '../../services/source_server_service.dart';
import '../../services/status_window_service.dart';
import '../queue_users/queue_users_bloc.dart';
import '../queue_users/queue_users_event.dart';
import 'queue_event.dart';
import 'queue_state.dart';

// 配置存储键
const String _keyQueueTargetPlayers = 'queue_target_players';
const String _keyQueueThreadCount = 'queue_thread_count';
const String _keyQueueIsDonator = 'queue_is_donator';
const String _keyQueueMultiThreadEnabled = 'queue_multi_thread_enabled';
const String _keyQueueRequestInterval = 'queue_request_interval';

/// 挤服Bloc
///
/// 管理挤服页面的 UI 状态，实际业务逻辑由 StatusWindowService 处理。
class QueueBloc extends Bloc<QueueEvent, QueueBlocState> {
  final StatusWindowService _statusService = StatusWindowService();
  final GameStatusService _gameStatusService = GameStatusService();
  final ServerApi _serverApi = ServerApi();
  StreamSubscription<OperationState>? _stateSubscription;
  Timer? _regularUpdateTimer;

  QueueBloc() : super(const QueueBlocState()) {
    on<QueueInitialize>(_onInitialize);
    on<QueueStart>(_onStart);
    on<QueuePause>(_onPause);
    on<QueueSetTargetPlayers>(_onSetTargetPlayers);
    on<QueueSetThreadCount>(_onSetThreadCount);
    on<QueueSetMultiThreadEnabled>(_onSetMultiThreadEnabled);
    on<QueueSetRequestInterval>(_onSetRequestInterval);
    on<QueueSetAutoRetry>(_onSetAutoRetry);
    on<QueueSetDonator>(_onSetDonator);
    on<QueueLaunchGame>(_onLaunchGame);
    on<QueueRefreshServerInfo>(_onRefreshServerInfo);
    on<QueueStateUpdated>(_onStateUpdated);
    on<QueueDispose>(_onDispose);
  }

  /// 初始化
  Future<void> _onInitialize(
    QueueInitialize event,
    Emitter<QueueBlocState> emit,
  ) async {
    LogService.d('[QueueBloc] 初始化: ${event.serverAddress}');

    // 加载保存的配置
    final savedConfig = await _loadSavedConfig();

    // 监听服务状态变化
    _stateSubscription?.cancel();
    _stateSubscription = _statusService.stateStream.listen((serviceState) {
      add(QueueStateUpdated(serviceState));
    });

    // 从当前服务状态初始化
    final currentState = _statusService.state;

    // 使用传入的初始数据（如果有），否则后续异步获取
    final initialServerInfo = event.initialServerInfo;
    final initialMapInfo = event.initialMapInfo;

    // 调整目标人数不超过允许的最大值
    var config = savedConfig;
    if (initialServerInfo != null) {
      final maxTarget = (initialServerInfo.maxPlayers ?? 64) - 1;
      if (maxTarget > 0 && config.targetPlayers > maxTarget) {
        config = config.copyWith(targetPlayers: maxTarget);
      }
    }

    // 多线程开关只对自定义服务器生效；非自定义服务器始终走多线程模式
    // 避免用户在自定义服务器关了多线程后，影响其他服务器的挤服速度
    if (!event.isCustomServer && !config.multiThreadEnabled) {
      config = config.copyWith(multiThreadEnabled: true);
    }

    emit(
      state.copyWith(
        isInitialized: true,
        serverAddress: event.serverAddress,
        serverName: event.serverName,
        isCustomServer: event.isCustomServer,
        isGameRunning: currentState.isGameRunning,
        config: config,
        serverInfo: initialServerInfo,
        mapInfo: initialMapInfo,
      ),
    );

    // 异步刷新服务器信息（获取最新数据）
    // 使用 add 事件而不是直接调用，避免 emit 失效问题
    add(QueueRefreshServerInfo());

    // 启动定时更新（非挤服状态下每5秒更新一次）
    _startRegularUpdate(event.serverAddress);
  }

  /// 加载保存的配置
  Future<QueueConfig> _loadSavedConfig() async {
    try {
      final targetPlayers = StorageUtils.getInt(_keyQueueTargetPlayers) ?? 60;
      final threadCount = StorageUtils.getInt(_keyQueueThreadCount) ?? 3;
      final isDonator = StorageUtils.getBool(
        _keyQueueIsDonator,
        defaultValue: false,
      );
      final multiThreadEnabled = StorageUtils.getBool(
        _keyQueueMultiThreadEnabled,
        defaultValue: true,
      );
      final requestIntervalSeconds =
          (StorageUtils.getInt(_keyQueueRequestInterval) ?? 1).clamp(1, 6);
      return QueueConfig(
        targetPlayers: targetPlayers,
        threadCount: threadCount,
        enableAutoRetry: false, // 自动重试不保存，每次默认关闭
        isDonator: isDonator,
        multiThreadEnabled: multiThreadEnabled,
        requestIntervalSeconds: requestIntervalSeconds,
      );
    } catch (e) {
      LogService.e('[QueueBloc] 加载配置失败', e);
      return const QueueConfig();
    }
  }

  /// 保存配置
  Future<void> _saveConfig(QueueConfig config) async {
    try {
      await StorageUtils.setInt(_keyQueueTargetPlayers, config.targetPlayers);
      await StorageUtils.setInt(_keyQueueThreadCount, config.threadCount);
      await StorageUtils.setBool(_keyQueueIsDonator, config.isDonator);
      await StorageUtils.setBool(
        _keyQueueMultiThreadEnabled,
        config.multiThreadEnabled,
      );
      await StorageUtils.setInt(
        _keyQueueRequestInterval,
        config.requestIntervalSeconds,
      );
    } catch (e) {
      LogService.e('[QueueBloc] 保存配置失败', e);
    }
  }

  /// 启动定时更新
  void _startRegularUpdate(String serverAddress) {
    _stopRegularUpdate();
    _regularUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // 只在非挤服状态下更新
      if (state.status != QueueStatus.running &&
          state.status != QueueStatus.connecting) {
        add(QueueRefreshServerInfo());
      }
    });
  }

  /// 停止定时更新
  void _stopRegularUpdate() {
    _regularUpdateTimer?.cancel();
    _regularUpdateTimer = null;
  }

  /// 获取服务器信息
  Future<void> _fetchServerInfo(
    String serverAddress,
    Emitter<QueueBlocState> emit,
  ) async {
    try {
      final parts = serverAddress.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final sourceInfo = await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: 5000,
      );

      if (sourceInfo != null) {
        final serverInfo = ServerInfo(
          hostName: sourceInfo.name,
          map: sourceInfo.map,
          players: sourceInfo.players,
          maxPlayers: sourceInfo.maxPlayers,
          pingLatency: sourceInfo.ping,
          gameType: sourceInfo.gameType,
          appId: sourceInfo.appId,
        );

        // 获取地图信息
        MapData? mapInfo;
        try {
          mapInfo = await _serverApi.getMapInfo(sourceInfo.map);
        } catch (e) {
          LogService.d('[QueueBloc] 获取地图信息失败: $e');
        }

        // 调整目标人数不超过允许的最大值
        var config = state.config;
        final maxTarget = sourceInfo.maxPlayers - 1;
        if (maxTarget > 0 && config.targetPlayers > maxTarget) {
          config = config.copyWith(targetPlayers: maxTarget);
        }

        emit(
          state.copyWith(
            serverInfo: serverInfo,
            mapInfo: mapInfo,
            config: config,
          ),
        );
      }
    } catch (e) {
      LogService.e('[QueueBloc] 获取服务器信息失败', e);
    }
  }

  /// 开始挤服
  Future<void> _onStart(QueueStart event, Emitter<QueueBlocState> emit) async {
    LogService.d('[QueueBloc] 开始挤服');

    emit(state.copyWith(isCheckingGame: true));

    final success = await _statusService.startQueue(
      serverAddress: state.serverAddress ?? '',
      serverName: state.serverName,
      config: state.config,
      serverInfo: state.serverInfo,
      mapInfo: state.mapInfo,
      force: event.force,
    );

    emit(state.copyWith(isCheckingGame: false));

    if (!success) {
      // 挤服未能真正开始（游戏未运行 / 正在连接中等守卫拦截），
      // 但此前 _startQueue 已经连上 WebSocket 并发了 join（人已进竞技场）。
      // 这里必须主动断开，否则会一直卡在挤服竞技场里，关窗口也退不出来。
      final usersBloc = QueueUsersBloc.instance;
      usersBloc.add(const QueueUsersLeave());
      usersBloc.add(const QueueUsersDisconnect());

      emit(state.copyWith(error: '游戏未运行，请先启动游戏'));
    }
  }

  /// 暂停挤服
  void _onPause(QueuePause event, Emitter<QueueBlocState> emit) {
    LogService.d('[QueueBloc] 暂停挤服');
    _statusService.pauseQueue();
  }

  /// 设置目标人数
  Future<void> _onSetTargetPlayers(
    QueueSetTargetPlayers event,
    Emitter<QueueBlocState> emit,
  ) async {
    _statusService.setTargetPlayers(event.targetPlayers);
    final newConfig = state.config.copyWith(targetPlayers: event.targetPlayers);
    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);
  }

  /// 设置线程数量
  Future<void> _onSetThreadCount(
    QueueSetThreadCount event,
    Emitter<QueueBlocState> emit,
  ) async {
    _statusService.setThreadCount(event.threadCount);
    final newConfig = state.config.copyWith(threadCount: event.threadCount);
    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);
  }

  /// 设置是否启用多线程
  Future<void> _onSetMultiThreadEnabled(
    QueueSetMultiThreadEnabled event,
    Emitter<QueueBlocState> emit,
  ) async {
    _statusService.setMultiThreadEnabled(event.enabled);
    final newConfig = state.config.copyWith(multiThreadEnabled: event.enabled);
    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);
  }

  /// 设置单线程模式下的请求间隔
  Future<void> _onSetRequestInterval(
    QueueSetRequestInterval event,
    Emitter<QueueBlocState> emit,
  ) async {
    final clamped = event.seconds.clamp(1, 6);
    _statusService.setRequestIntervalSeconds(clamped);
    final newConfig = state.config.copyWith(requestIntervalSeconds: clamped);
    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);
  }

  /// 设置自动重试
  Future<void> _onSetAutoRetry(
    QueueSetAutoRetry event,
    Emitter<QueueBlocState> emit,
  ) async {
    if (event.enable) {
      // 启用自动重试前，先刷新并检查游戏状态
      await _gameStatusService.refreshStatus();
      if (!_gameStatusService.isMonitorable) {
        emit(state.copyWith(error: '请使用 BakaBox 启动游戏'));
        return;
      }
    }

    // 如果正在挤服，同步到 StatusWindowService
    if (state.status == QueueStatus.running ||
        state.status == QueueStatus.connecting) {
      final success = await _statusService.setAutoRetry(event.enable);
      if (!success) {
        emit(state.copyWith(error: '请使用 BakaBox 启动游戏'));
        return;
      }
    }

    // 更新本地配置
    emit(
      state.copyWith(
        config: state.config.copyWith(enableAutoRetry: event.enable),
      ),
    );
  }

  /// 设置是否捐助者
  Future<void> _onSetDonator(
    QueueSetDonator event,
    Emitter<QueueBlocState> emit,
  ) async {
    // 正在挤服或连接时不允许修改
    if (state.status == QueueStatus.running ||
        state.status == QueueStatus.connecting) {
      emit(state.copyWith(error: '挤服中无法修改捐助者设置'));
      return;
    }

    final maxPlayers = state.serverInfo?.maxPlayers ?? 64;

    // 切换捐助者状态时，调整目标人数
    int newTargetPlayers;
    if (event.isDonator) {
      // 开启捐助者：保持当前设置，但不超过 maxPlayers - 1
      newTargetPlayers = state.config.targetPlayers.clamp(1, maxPlayers - 1);
    } else {
      // 关闭捐助者：如果当前超过59，则设为59
      final maxNonDonator = 59;
      newTargetPlayers = state.config.targetPlayers > maxNonDonator
          ? maxNonDonator
          : state.config.targetPlayers;
    }

    // 更新配置
    final newConfig = state.config.copyWith(
      isDonator: event.isDonator,
      targetPlayers: newTargetPlayers,
    );

    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);
  }

  /// 启动游戏
  Future<void> _onLaunchGame(
    QueueLaunchGame event,
    Emitter<QueueBlocState> emit,
  ) async {
    if (state.isLaunchingGame || state.isGameRunning) return;

    LogService.d('[QueueBloc] 启动游戏');

    emit(
      state.copyWith(
        isLaunchingGame: true,
        launchMessage: '正在启动游戏...',
        needManualLaunch: false, // 重置状态
      ),
    );

    final success = await _statusService.launchGame(
      serverAddress: null, // 挤服页面启动游戏不自动连接
      serverName: state.serverInfo?.hostName,
      mapName: state.serverInfo?.map,
      mapNameCn: state.mapInfo?.mapLabel,
      mapBackground: state.mapInfo?.mapUrl,
      gameType: state.serverInfo?.gameType,
      appId: state.serverInfo?.appId,
    );

    // 只在这里设置一次 needManualLaunch
    // isGameRunning 以 StatusWindowService 的真实状态为准（基于进程检测），
    // 不直接用 success（success 可能只代表命令已下发）。
    emit(
      state.copyWith(
        isLaunchingGame: false,
        launchMessage: success ? '启动成功' : null,
        isGameRunning: _statusService.state.isGameRunning,
        error: success ? null : '游戏启动失败',
        needManualLaunch: _statusService.state.needManualLaunch,
      ),
    );
  }

  /// 刷新服务器信息
  Future<void> _onRefreshServerInfo(
    QueueRefreshServerInfo event,
    Emitter<QueueBlocState> emit,
  ) async {
    if (state.serverAddress == null) return;
    await _fetchServerInfo(state.serverAddress!, emit);
  }

  /// 服务状态更新
  void _onStateUpdated(QueueStateUpdated event, Emitter<QueueBlocState> emit) {
    final serviceState = event.state;

    // 如果正在启动游戏，忽略服务状态更新（避免干扰 _onLaunchGame）
    if (state.isLaunchingGame) {
      return;
    }

    // 映射服务状态到 Bloc 状态
    QueueStatus status;
    QueueConnectionState connectionState;

    switch (serviceState.status) {
      case OperationStatus.running:
        if (serviceState.type == OperationType.queueing) {
          status = QueueStatus.running;
          connectionState = QueueConnectionState.idle;
        } else if (serviceState.type == OperationType.connecting) {
          status = QueueStatus.connecting;
          connectionState = QueueConnectionState.connecting;
        } else if (serviceState.type == OperationType.launching) {
          // 其他地方正在启动游戏，保持当前状态但更新游戏运行状态
          status = state.status;
          connectionState = state.connectionState;
        } else {
          status = QueueStatus.idle;
          connectionState = QueueConnectionState.idle;
        }
        break;
      case OperationStatus.success:
        status = QueueStatus.success;
        connectionState = QueueConnectionState.connected;
        break;
      case OperationStatus.failed:
        status = QueueStatus.paused;
        connectionState = QueueConnectionState.failed;
        break;
      case OperationStatus.serverFull:
        status = QueueStatus.paused;
        connectionState = QueueConnectionState.serverFull;
        break;
      case OperationStatus.paused:
        status = QueueStatus.paused;
        connectionState = QueueConnectionState.idle;
        break;
      default:
        status = QueueStatus.idle;
        connectionState = QueueConnectionState.idle;
    }

    // 映射线程状态
    final threadStatuses = serviceState.threadStatuses.map((t) {
      switch (t) {
        case ThreadStatus.idle:
          return QueueThreadStatus.idle;
        case ThreadStatus.requesting:
          return QueueThreadStatus.requesting;
        case ThreadStatus.success:
          return QueueThreadStatus.success;
        case ThreadStatus.failed:
          return QueueThreadStatus.failed;
      }
    }).toList();

    // 保留用户设置的目标人数、线程数量、多线程开关、请求间隔
    // 自动重试：仅在挤服进行中时以服务状态为准（服务可能因游戏不可监控而自动关闭）。
    // 空闲时服务端的 enableAutoRetry 仍为 false，若此时同步会覆盖用户刚开启的设置，
    // 导致开关回弹，因此空闲时保留本地配置。
    final isQueueActive =
        status == QueueStatus.running || status == QueueStatus.connecting;
    final updatedConfig = isQueueActive
        ? state.config.copyWith(
            enableAutoRetry: serviceState.queueConfig.enableAutoRetry,
          )
        : state.config;

    emit(
      state.copyWith(
        status: status,
        serverInfo: serviceState.serverInfo,
        mapInfo: serviceState.mapInfo,
        threadStatuses: threadStatuses,
        connectionState: connectionState,
        connectionMessage: serviceState.message,
        isGameRunning: serviceState.isGameRunning,
        config: updatedConfig,
        error: serviceState.error,
        // 保持当前的 needManualLaunch 状态，不被 StatusWindowService 覆盖
        // needManualLaunch 只由 _onLaunchGame 控制
      ),
    );
  }

  /// 销毁
  Future<void> _onDispose(
    QueueDispose event,
    Emitter<QueueBlocState> emit,
  ) async {
    LogService.d('[QueueBloc] 销毁');
    _stopRegularUpdate();
    _stateSubscription?.cancel();
    // 注意：不调用 _statusService 的任何方法，让服务继续运行
  }

  @override
  Future<void> close() {
    _stopRegularUpdate();
    _stateSubscription?.cancel();
    return super.close();
  }
}
