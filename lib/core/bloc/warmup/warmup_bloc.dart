import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/server_api.dart';
import '../../utils/log_service.dart';
import '../../utils/storage_utils.dart';
import '../../models/server_models.dart';
import '../../services/source_server_service.dart';
import '../../services/status_window_service.dart';
import '../../services/audio_service.dart';
import '../warmup_users/warmup_users_bloc.dart';
import '../warmup_users/warmup_users_event.dart';
import '../warmup_users/warmup_users_state.dart';
import 'warmup_event.dart';
import 'warmup_state.dart';

// 配置存储键
const String _keyWarmupTargetPlayers = 'warmup_target_players';
const String _keyWarmupShowFloatingWindow = 'warmup_show_floating_window';

/// 暖服 Bloc
///
/// 管理暖服页面的 UI 状态和业务逻辑。
/// 核心功能：
/// - 监控服务器人数 + 暖服WS人数 + 挤服人数
/// - 达到目标后启动60秒倒计时
/// - 倒计时结束自动启动游戏加入服务器
class WarmupBloc extends Bloc<WarmupEvent, WarmupBlocState> {
  // 单例模式
  static WarmupBloc? _instance;

  /// 获取单例实例
  static WarmupBloc get instance {
    _instance ??= WarmupBloc._internal();
    return _instance!;
  }

  final StatusWindowService _statusService = StatusWindowService();
  final AudioService _audioService = AudioService();
  final ServerApi _serverApi = ServerApi();
  StreamSubscription<OperationState>? _stateSubscription;
  StreamSubscription<WarmupUsersState>? _usersSubscription;
  Timer? _regularUpdateTimer;
  Timer? _countdownTimer;

  WarmupBloc._internal() : super(const WarmupBlocState()) {
    on<WarmupInitialize>(_onInitialize);
    on<WarmupStart>(_onStart);
    on<WarmupPause>(_onPause);
    on<WarmupSetTargetPlayers>(_onSetTargetPlayers);
    on<WarmupSetShowFloatingWindow>(_onSetShowFloatingWindow);
    on<WarmupCountdownTick>(_onCountdownTick);
    on<WarmupCountdownCancel>(_onCountdownCancel);
    on<WarmupLaunchGame>(_onLaunchGame);
    on<WarmupRefreshServerInfo>(_onRefreshServerInfo);
    on<WarmupUsersCountUpdated>(_onUsersCountUpdated);
    on<WarmupStateUpdated>(_onStateUpdated);
    on<WarmupTriggerCountdown>(_onTriggerCountdown);
    on<WarmupDispose>(_onDispose);
  }

  /// 初始化
  Future<void> _onInitialize(
    WarmupInitialize event,
    Emitter<WarmupBlocState> emit,
  ) async {
    LogService.d('[WarmupBloc] 初始化: ${event.serverAddress}');

    // 加载保存的配置
    final savedConfig = await _loadSavedConfig();

    // 如果已经初始化过，且是同一个服务器，保留已有状态
    if (state.isInitialized && state.serverAddress == event.serverAddress && state.status != WarmupStatus.idle) {
      LogService.d('[WarmupBloc] 继续已有的暖服任务');
      return;
    }

    // 监听服务状态变化
    _stateSubscription?.cancel();
    _stopRegularUpdate();
    _countdownTimer?.cancel();

    _stateSubscription = _statusService.stateStream.listen((serviceState) {
      add(WarmupStateUpdated(serviceState));
    });

    // 监听暖服 WS 用户数变化（关键：之前缺失此订阅导致 warmupUsersCount 永远为 0，
    // 进而无法触发达标倒计时）
    _usersSubscription?.cancel();
    final usersBloc = WarmupUsersBloc.instance;
    // 立即同步一次当前用户数
    add(WarmupUsersCountUpdated(usersBloc.state.users.length));
    _usersSubscription = usersBloc.stream.listen((usersState) {
      if (!isClosed) {
        add(WarmupUsersCountUpdated(usersState.users.length));
      }
    });

    // 从当前服务状态初始化
    final currentState = _statusService.state;

    WarmupStatus initialStatus = WarmupStatus.idle;
    if (currentState.type == OperationType.warming &&
        currentState.serverAddress == event.serverAddress &&
        currentState.status == OperationStatus.running) {
      initialStatus = WarmupStatus.warming;
    }

    final initialServerInfo = event.initialServerInfo;

    // 调整目标人数不超过 最大人数×0.6。
    // 只有在已知服务器最大人数时才 clamp，避免在信息未拉取到时把用户保存的值压到 1。
    var config = savedConfig;
    final maxPlayers = initialServerInfo?.maxPlayers ?? 0;
    if (maxPlayers > 0) {
      final maxTarget = _calcMaxTarget(maxPlayers);
      if (config.targetPlayers > maxTarget) {
        config = config.copyWith(targetPlayers: maxTarget);
      }
    }

    emit(
      state.copyWith(
        isInitialized: true,
        serverAddress: event.serverAddress,
        serverName: event.serverName,
        isCustomServer: event.isCustomServer,
        isGameRunning: currentState.isGameRunning,
        status: initialStatus,
        config: config,
        serverInfo: initialServerInfo,
        mapInfo: event.initialMapInfo,
        queueUsersCount: event.queueCount,
      ),
    );

    // 异步刷新服务器信息
    add(const WarmupRefreshServerInfo());

    // 启动定时更新
    _startRegularUpdate(event.serverAddress);
  }

  /// 计算暖服目标人数允许的最大值（与 WarmupBlocState.maxTargetPlayers 规则保持一致）
  ///
  /// - 64 人服务器：固定上限 40 人
  /// - 其它服务器：服务器最大人数 × 0.6
  static int _calcMaxTarget(int maxPlayers) {
    if (maxPlayers <= 0) return 1;
    if (maxPlayers == 64) return 40;
    final limit = (maxPlayers * 0.6).floor();
    return limit < 1 ? 1 : limit;
  }

  /// 加载保存的配置
  Future<WarmupConfig> _loadSavedConfig() async {    try {
      final targetPlayers = StorageUtils.getInt(_keyWarmupTargetPlayers) ?? 20;
      final showFloatingWindow = StorageUtils.getBool(
        _keyWarmupShowFloatingWindow,
        defaultValue: true,
      );
      return WarmupConfig(
        // 不在这里 clamp，因为 maxPlayers 还未知。
        // 实际 clamp 在 _onInitialize（已知 maxPlayers 时）和 _fetchServerInfo 中进行。
        targetPlayers: targetPlayers < 1 ? 1 : targetPlayers,
        showFloatingWindow: showFloatingWindow,
      );
    } catch (e) {
      LogService.e('[WarmupBloc] 加载配置失败', e);
      return const WarmupConfig();
    }
  }

  /// 保存配置
  Future<void> _saveConfig(WarmupConfig config) async {
    try {
      await StorageUtils.setInt(_keyWarmupTargetPlayers, config.targetPlayers);
      await StorageUtils.setBool(
        _keyWarmupShowFloatingWindow,
        config.showFloatingWindow,
      );
    } catch (e) {
      LogService.e('[WarmupBloc] 保存配置失败', e);
    }
  }

  /// 启动定时更新
  void _startRegularUpdate(String serverAddress) {
    _stopRegularUpdate();
    _regularUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // 暖服中也需要更新（用于人数比对）
      add(const WarmupRefreshServerInfo());
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
    Emitter<WarmupBlocState> emit,
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
          LogService.d('[WarmupBloc] 获取地图信息失败: $e');
        }

        if (!isClosed) {
          // 如果服务器最大人数已知，确保目标人数不超过允许上限
          var config = state.config;
          final maxPlayers = serverInfo.maxPlayers ?? 0;
          if (maxPlayers > 0) {
            final maxTarget = _calcMaxTarget(maxPlayers);
            if (config.targetPlayers > maxTarget) {
              config = config.copyWith(targetPlayers: maxTarget);
            }
          }

          // 检测是否换图：换图后若新地图信息拉取失败（mapInfo == null），
          // 必须清除旧地图的译名/背景，避免悬浮窗出现"新地图英文名 + 旧地图译名/背景"的错配。
          final oldMap = state.serverInfo?.map;
          final newMap = serverInfo.map;
          final mapChanged = oldMap != null && oldMap != newMap;
          final shouldClearStaleMapInfo = mapChanged && mapInfo == null;

          emit(
            state.copyWith(
              serverInfo: serverInfo,
              mapInfo: mapInfo,
              clearMapInfo: shouldClearStaleMapInfo,
              config: config,
            ),
          );

          // 如果在暖服中，同步数据到原生的悬浮窗
          // 注意：currentPlayers 传"有效总人数 = 服务器人数 + 暖服人数 + 挤服人数"
          // 同时传 mapName/maxPlayers，确保换图后悬浮窗地图信息动态更新
          if (state.status != WarmupStatus.idle) {
            _statusService.updateWarmupState(
              currentPlayers: (serverInfo.players ?? 0) +
                  state.warmupUsersCount +
                  state.queueUsersCount,
              targetPlayers: state.effectiveTargetPlayers,
              mapInfo: mapInfo,
              clearMapInfo: shouldClearStaleMapInfo,
              mapName: serverInfo.map,
              maxPlayers: serverInfo.maxPlayers,
            );
          }

          // 人数变化后检查是否达到目标
          if (state.status == WarmupStatus.warming) {
            _checkTargetReached();
          }
        }
      }
    } catch (e) {
      LogService.e('[WarmupBloc] 获取服务器信息失败', e);
    }
  }

  /// 开始暖服
  Future<void> _onStart(WarmupStart event, Emitter<WarmupBlocState> emit) async {
    LogService.d('[WarmupBloc] 开始暖服');

    // 检查互斥：是否有挤服正在进行
    final globalState = _statusService.state;
    if (globalState.type == OperationType.queueing &&
        globalState.status == OperationStatus.running) {
      emit(state.copyWith(error: '正在挤服中，无法暖服'));
      return;
    }

    // 更新全局状态为暖服中
    _statusService.startWarmup(
      serverAddress: state.serverAddress ?? '',
      serverName: state.serverName,
      serverInfo: state.serverInfo,
      mapInfo: state.mapInfo,
      targetPlayers: state.effectiveTargetPlayers,
      showFloatingWindow: state.config.showFloatingWindow,
    );

    emit(state.copyWith(
      status: WarmupStatus.warming,
      needManualLaunch: false,
      error: null,
    ));

    // 开始后立即检查一次是否已达标（例如服务器本身人数已够）
    _checkTargetReached();
  }

  /// 暂停/停止暖服
  void _onPause(WarmupPause event, Emitter<WarmupBlocState> emit) {
    LogService.d('[WarmupBloc] 停止暖服');
    _stopCountdown();
    _statusService.pauseWarmup();
    emit(state.copyWith(
      status: WarmupStatus.idle,
      countdownSeconds: 60,
    ));
  }

  /// 设置目标人数
  Future<void> _onSetTargetPlayers(
    WarmupSetTargetPlayers event,
    Emitter<WarmupBlocState> emit,
  ) async {
    final clamped = event.targetPlayers.clamp(1, state.maxTargetPlayers);
    final newConfig = state.config.copyWith(targetPlayers: clamped);
    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);
  }

  /// 设置是否显示浮动窗口
  Future<void> _onSetShowFloatingWindow(
    WarmupSetShowFloatingWindow event,
    Emitter<WarmupBlocState> emit,
  ) async {
    final newConfig = state.config.copyWith(
      showFloatingWindow: event.showFloatingWindow,
    );
    emit(state.copyWith(config: newConfig));
    await _saveConfig(newConfig);

    // 暖服进行中实时切换浮窗显示
    if (state.status != WarmupStatus.idle) {
      _statusService.setWarmupFloatingWindowEnabled(event.showFloatingWindow);
    }
  }

  /// 倒计时 tick
  void _onCountdownTick(
    WarmupCountdownTick event,
    Emitter<WarmupBlocState> emit,
  ) {
    if (state.status != WarmupStatus.countdown) return;

    final remaining = state.countdownSeconds - 1;
    if (remaining <= 0) {
      // 倒计时结束，启动游戏
      _stopCountdown();
      add(const WarmupLaunchGame());
      return;
    }

    _statusService.updateWarmupState(message: '倒计时 $remaining 秒');
    emit(state.copyWith(countdownSeconds: remaining));
  }

  /// 取消倒计时
  void _onCountdownCancel(
    WarmupCountdownCancel event,
    Emitter<WarmupBlocState> emit,
  ) {
    LogService.d('[WarmupBloc] 取消倒计时，停止暖服');
    _stopCountdown();
    _audioService.stop();
    _statusService.pauseWarmup();

    // 停止暖服回到空闲状态
    emit(state.copyWith(
      status: WarmupStatus.idle,
      countdownSeconds: 60,
    ));
  }

  /// 启动游戏加入服务器
  Future<void> _onLaunchGame(
    WarmupLaunchGame event,
    Emitter<WarmupBlocState> emit,
  ) async {
    LogService.d('[WarmupBloc] 启动游戏加入服务器');

    _stopCountdown();
    _audioService.stop();

    // 无论点击哪个按钮（取消或立即加入），都必须停止暖服的后台通讯
    final usersBloc = WarmupUsersBloc.instance;
    usersBloc.add(const WarmupUsersLeave());
    usersBloc.add(const WarmupUsersDisconnect());

    emit(state.copyWith(
      status: WarmupStatus.launching,
      isLaunchingGame: true,
    ));

    // 连接服务器（会自动判断是否需要先启动游戏）
    final success = await _statusService.connectToServer(
      serverAddress: state.serverAddress ?? '',
      serverName: state.serverName,
      mapName: state.serverInfo?.map,
      mapNameCn: state.mapInfo?.mapLabel,
      mapBackground: state.mapInfo?.mapUrl,
      gameType: state.serverInfo?.gameType,
      appId: state.serverInfo?.appId,
    );

    if (success) {
      emit(state.copyWith(
        status: WarmupStatus.success,
        isLaunchingGame: false,
      ));
    } else {
      final currentState = _statusService.state;
      emit(state.copyWith(
        status: WarmupStatus.warming,
        isLaunchingGame: false,
        error: currentState.message ?? '连接失败',
        needManualLaunch: currentState.needManualLaunch,
        countdownSeconds: 60,
      ));
    }
  }

  /// 刷新服务器信息
  Future<void> _onRefreshServerInfo(
    WarmupRefreshServerInfo event,
    Emitter<WarmupBlocState> emit,
  ) async {
    if (state.serverAddress == null) return;
    await _fetchServerInfo(state.serverAddress!, emit);
  }

  /// 更新暖服 WS 用户数
  void _onUsersCountUpdated(
    WarmupUsersCountUpdated event,
    Emitter<WarmupBlocState> emit,
  ) {
    if (state.warmupUsersCount == event.warmupUsersCount) {
      // 数量未变，仍检查一次达标（防御）
      _checkTargetReached();
      return;
    }

    emit(state.copyWith(warmupUsersCount: event.warmupUsersCount));

    // 实时同步有效总人数到悬浮窗
    if (state.status != WarmupStatus.idle) {
      _statusService.updateWarmupState(
        currentPlayers: (state.serverInfo?.players ?? 0) +
            event.warmupUsersCount +
            state.queueUsersCount,
        targetPlayers: state.effectiveTargetPlayers,
      );
    }

    _checkTargetReached();
  }

  /// 服务状态更新
  void _onStateUpdated(
    WarmupStateUpdated event,
    Emitter<WarmupBlocState> emit,
  ) {
    final serviceState = event.state;

    // 如果正在启动游戏，忽略服务状态更新
    if (state.isLaunchingGame) return;

    // countdown / launching 是 Bloc 内部驱动的瞬时状态，服务状态流的中间态
    // 不应把它们覆盖掉，否则会出现"倒计时弹窗被意外关闭、但原生悬浮窗还在"的问题。
    if (state.status == WarmupStatus.countdown ||
        state.status == WarmupStatus.launching) {
      emit(state.copyWith(isGameRunning: serviceState.isGameRunning));
      return;
    }

    WarmupStatus status = state.status;
    if (serviceState.type == OperationType.warming &&
        serviceState.serverAddress == state.serverAddress) {
      if (serviceState.status == OperationStatus.running) {
        if (status == WarmupStatus.idle ||
            status == WarmupStatus.success ||
            status == WarmupStatus.paused) {
          status = WarmupStatus.warming;
        }
      } else if (serviceState.status == OperationStatus.success) {
        status = WarmupStatus.success;
      } else if (serviceState.status == OperationStatus.paused) {
        // 服务显式暂停（如点击悬浮卡片的"停止"）
        status = WarmupStatus.idle;
      }
    } else {
      // 服务已不再处于本服务器的暖服状态，回到空闲
      if (status == WarmupStatus.warming) {
        status = WarmupStatus.idle;
      }
    }

    emit(state.copyWith(
      isGameRunning: serviceState.isGameRunning,
      status: status,
    ));
  }

  /// 检查是否达到目标人数 → 启动倒计时
  void _checkTargetReached() {
    if (state.status != WarmupStatus.warming) return;

    if (state.hasReachedTarget) {
      LogService.d('[WarmupBloc] 达到目标人数，启动倒计时');
      add(const WarmupTriggerCountdown());
    }
  }

  /// 触发倒计时 (内部事件)
  void _onTriggerCountdown(
    WarmupTriggerCountdown event,
    Emitter<WarmupBlocState> emit,
  ) {
    if (state.status != WarmupStatus.warming) return;

    emit(state.copyWith(
      status: WarmupStatus.countdown,
      countdownSeconds: 60,
      // 清除上一轮启动失败遗留的标志，避免 needManualLaunch 粘滞导致
      // 全局监听器（listenWhen 中 `if (current.needManualLaunch) return false`）
      // 永久失效，使后续达标无法再弹出倒计时。
      needManualLaunch: false,
      error: null,
    ));
    
    _startCountdown();
    // 播放倒计时音效
    _audioService.playWarmupCountdownSound();
  }

  /// 启动倒计时
  void _startCountdown() {
    _stopCountdown();
    
    // 初始化倒计时为 60 秒
    _statusService.updateWarmupState(message: '倒计时 60 秒');
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const WarmupCountdownTick());
    });
  }

  /// 停止倒计时
  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// 销毁
  ///
  /// 暖服窗口关闭时会触发本事件。但暖服是一个后台任务（单例 Bloc），
  /// 关闭窗口后仍需继续监控人数以触发达标倒计时（全局弹窗）。
  /// 因此只有在暖服已结束（idle/success）时才真正释放定时器和订阅，
  /// 否则保持后台运行。
  Future<void> _onDispose(
    WarmupDispose event,
    Emitter<WarmupBlocState> emit,
  ) async {
    final isActive = state.status == WarmupStatus.warming ||
        state.status == WarmupStatus.countdown ||
        state.status == WarmupStatus.launching;

    if (isActive) {
      LogService.d('[WarmupBloc] 窗口关闭，但暖服仍在后台运行，保持监控');
      return;
    }

    LogService.d('[WarmupBloc] 销毁');
    _stopRegularUpdate();
    _stopCountdown();
    _stateSubscription?.cancel();
    _usersSubscription?.cancel();
  }

  @override
  Future<void> close() {
    _stopRegularUpdate();
    _stopCountdown();
    _stateSubscription?.cancel();
    _usersSubscription?.cancel();
    return super.close();
  }
}
