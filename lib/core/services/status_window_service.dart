import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../api/server_api.dart';
import '../bloc/queue_users/queue_users_bloc.dart';
import '../bloc/queue_users/queue_users_event.dart';
import '../bloc/warmup_users/warmup_users_bloc.dart';
import '../bloc/warmup_users/warmup_users_event.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/server_item_utils.dart';
import 'audio_service.dart';
import 'console_log_service.dart';
import 'floating_window_service.dart';
import 'game_launcher_service.dart';
import 'game_status_service.dart';
import 'queue_guard_service.dart';
import 'server_address_mapping_service.dart';
import 'source_server_service.dart';

/// 操作类型
enum OperationType {
  none, // 无操作
  launching, // 启动游戏
  queueing, // 挤服中
  warming, // 暖服中
  connecting, // 连接服务器
}

/// 操作状态
enum OperationStatus {
  idle, // 空闲
  running, // 运行中
  success, // 成功
  failed, // 失败
  paused, // 已暂停
  serverFull, // 服务器已满
}

/// 线程状态
enum ThreadStatus { idle, requesting, success, failed }

// ==================== 消息常量（统一管理所有消息）====================

class _Messages {
  // 启动游戏
  static const launching = '正在启动游戏...';
  static const gameAlreadyRunning = '游戏已在运行';
  static const launchSuccess = '游戏启动成功';
  static const launchFailed = '启动失败';
  static const launchTimeout = '游戏加载超时';
  static const launchSteamStuck = 'Steam 状态异常，请在 Steam 中停止游戏或重启 Steam';

  // 连接服务器
  static const connecting = '正在连接服务器...';
  static const loading = '正在进入游戏...';
  static const connectSuccess = '成功进入游戏！';
  static const connectFailed = '连接失败';
  static const serverFull = '服务器已满';
  static const commandSent = '加入命令已发送';
  static const networkError = '连接异常，请检查网络';

  // 挤服
  static const queueing = '挤服中...';
  static const queuePaused = '已停止挤服';
  static const queueRetryServerFull = '服务器已满，继续挤服...';
  static const queueRetryTimeout = '连接超时，继续挤服...';
  static const queueRetryFailed = '连接失败，继续挤服...';
  static const queueNetworkUnstable = '网络不稳定，暂停挤服';

  // 通用
  static const cancelled = '已取消';
  static const gameClosed = '游戏已关闭';
  static const gameNotRunning = '游戏未运行，请先启动游戏';

  static String loadingMap(String mapName) => '正在加载地图 $mapName';
}

/// 挤服配置
class QueueConfig {
  final int targetPlayers;
  final int threadCount;
  final bool enableAutoRetry;
  final bool isDonator;

  /// 是否启用多线程（仅自定义服务器可关闭）
  ///
  /// - true：使用 [threadCount] 个线程并发请求（默认行为）
  /// - false：单线程模式，按 [requestIntervalSeconds] 间隔轮询
  final bool multiThreadEnabled;

  /// 单线程模式下的请求间隔（秒，1-6）
  final int requestIntervalSeconds;

  const QueueConfig({
    this.targetPlayers = 60,
    this.threadCount = 3,
    this.enableAutoRetry = false,
    this.isDonator = false,
    this.multiThreadEnabled = true,
    this.requestIntervalSeconds = 1,
  });

  QueueConfig copyWith({
    int? targetPlayers,
    int? threadCount,
    bool? enableAutoRetry,
    bool? isDonator,
    bool? multiThreadEnabled,
    int? requestIntervalSeconds,
  }) {
    return QueueConfig(
      targetPlayers: targetPlayers ?? this.targetPlayers,
      threadCount: threadCount ?? this.threadCount,
      enableAutoRetry: enableAutoRetry ?? this.enableAutoRetry,
      isDonator: isDonator ?? this.isDonator,
      multiThreadEnabled: multiThreadEnabled ?? this.multiThreadEnabled,
      requestIntervalSeconds:
          requestIntervalSeconds ?? this.requestIntervalSeconds,
    );
  }

  /// 实际生效的线程数（多线程关闭时强制为 1）
  int get effectiveThreadCount => multiThreadEnabled ? threadCount : 1;
}

/// 操作状态数据
class OperationState {
  final OperationType type;
  final OperationStatus status;
  final String? message;

  // 服务器信息
  final String? serverAddress;
  final String? serverName;
  final ServerInfo? serverInfo;
  final MapData? mapInfo;

  // 挤服专用
  final QueueConfig queueConfig;
  final List<ThreadStatus> threadStatuses;

  // 游戏状态
  final bool isGameRunning;

  // 错误信息
  final String? error;
  final bool needCsgoLegacy; // 是否需要安装 CSGO Legacy
  final bool needManualLaunch; // 是否需要手动启动 CSGO

  // 暖服专用
  final int warmupTargetPlayers;

  const OperationState({
    this.type = OperationType.none,
    this.status = OperationStatus.idle,
    this.message,
    this.serverAddress,
    this.serverName,
    this.serverInfo,
    this.mapInfo,
    this.queueConfig = const QueueConfig(),
    this.threadStatuses = const [],
    this.isGameRunning = false,
    this.error,
    this.needCsgoLegacy = false,
    this.needManualLaunch = false,
    this.warmupTargetPlayers = 0,
  });

  OperationState copyWith({
    OperationType? type,
    OperationStatus? status,
    String? message,
    String? serverAddress,
    String? serverName,
    ServerInfo? serverInfo,
    MapData? mapInfo,
    bool clearMapInfo = false,
    QueueConfig? queueConfig,
    List<ThreadStatus>? threadStatuses,
    bool? isGameRunning,
    String? error,
    bool? needCsgoLegacy,
    bool? needManualLaunch,
    int? warmupTargetPlayers,
  }) {
    return OperationState(
      type: type ?? this.type,
      status: status ?? this.status,
      message: message,
      serverAddress: serverAddress ?? this.serverAddress,
      serverName: serverName ?? this.serverName,
      serverInfo: serverInfo ?? this.serverInfo,
      mapInfo: clearMapInfo ? null : (mapInfo ?? this.mapInfo),
      queueConfig: queueConfig ?? this.queueConfig,
      threadStatuses: threadStatuses ?? this.threadStatuses,
      isGameRunning: isGameRunning ?? this.isGameRunning,
      error: error,
      needCsgoLegacy: needCsgoLegacy ?? this.needCsgoLegacy,
      needManualLaunch: needManualLaunch ?? this.needManualLaunch,
      warmupTargetPlayers: warmupTargetPlayers ?? this.warmupTargetPlayers,
    );
  }

  /// 是否正在挤服
  bool get isQueueing =>
      type == OperationType.queueing && status == OperationStatus.running;

  /// 是否正在暖服
  bool get isWarming =>
      type == OperationType.warming && status == OperationStatus.running;

  /// 是否正在连接
  bool get isConnecting =>
      type == OperationType.connecting ||
      (type == OperationType.queueing &&
          status == OperationStatus.running &&
          message?.contains('连接') == true);
}

/// 状态窗口操作服务（单例）
///
/// 统一管理启动游戏、挤服、连接服务器的完整逻辑。
/// 独立于页面生命周期，页面关闭不影响操作继续执行。
class StatusWindowService {
  static final StatusWindowService _instance = StatusWindowService._internal();
  factory StatusWindowService() => _instance;
  StatusWindowService._internal();

  // 依赖服务
  final ServerApi _serverApi = ServerApi();
  final GameLauncherService _gameLauncher = GameLauncherService();
  final ConsoleLogService _consoleLogService = ConsoleLogService();
  final GameStatusService _gameStatusService = GameStatusService();
  final AudioService _audioService = AudioService();
  final FloatingWindowService _windowService = FloatingWindowService();

  // 状态
  OperationState _state = const OperationState();
  final _stateController = StreamController<OperationState>.broadcast();

  // 窗口
  String? _windowId;
  Timer? _closeTimer;

  // 挤服控制
  bool _isQueueRunning = false;
  bool _isThreadsRunning = false; // 防止重复启动线程
  bool _isTriggeredConnection = false; // 防止重复触发连接
  bool _isFetching = false; // 防止并发请求
  bool _isQueueWindowOpen = false; // 挤服窗口是否打开
  bool _isWarmupWindowOpen = false; // 暖服窗口是否打开
  bool _warmupFloatingWindowEnabled = true; // 暖服原生悬浮窗是否启用
  DateTime? _windowCreatedAt; // 窗口创建时间，用于跳过初始化期间的 IPC 推送
  final Set<int> _activeThreadIds = {};
  String? _lastMapName;
  int _consecutiveFailures = 0;
  double _backoffMultiplier = 1.0;
  DateTime? _lastSuccessTime;

  // 挤服守护进程相关
  bool _outcomeFinalized = false; // 结局闸门：本周期是否已敲定终态
  bool _isObservingConnect = false; // 观察期独占标志
  StreamSubscription<QueueGuardEvent>? _queueGuardSub;

  // 游戏状态订阅
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;

  /// 状态流
  Stream<OperationState> get stateStream => _stateController.stream;

  /// 当前状态
  OperationState get state => _state;

  /// 是否有活跃窗口
  bool get isShowing => _windowId != null;

  /// 挤服窗口是否打开
  bool get isQueueWindowOpen => _isQueueWindowOpen;

  /// 暖服窗口是否打开
  bool get isWarmupWindowOpen => _isWarmupWindowOpen;

  /// 设置挤服窗口打开状态
  void setQueueWindowOpen(bool isOpen) {
    if (_isQueueWindowOpen != isOpen) {
      _isQueueWindowOpen = isOpen;
      // 通知监听者状态变化
      _stateController.add(_state);
    }
  }

  /// 设置暖服窗口打开状态
  void setWarmupWindowOpen(bool isOpen) {
    if (_isWarmupWindowOpen != isOpen) {
      _isWarmupWindowOpen = isOpen;
      // 通知监听者状态变化
      _stateController.add(_state);
    }
  }

  /// 暖服原生悬浮窗是否启用
  bool get isWarmupFloatingWindowEnabled => _warmupFloatingWindowEnabled;

  /// 实时开关暖服原生悬浮窗
  ///
  /// 暖服进行中用户在面板里切换"浮动窗口显示"时调用：
  /// - 关闭：立即关闭已有悬浮窗
  /// - 开启：立即创建并同步当前状态
  void setWarmupFloatingWindowEnabled(bool enabled) {
    _warmupFloatingWindowEnabled = enabled;

    if (_state.type != OperationType.warming) return;

    if (!enabled) {
      // 立即关闭悬浮窗
      _cancelCloseTimer();
      closeWindow();
      return;
    }

    // 重新创建悬浮窗并同步当前状态
    _showWindow(
      type: FloatingWindowType.warmup,
      serverAddress: _state.serverAddress,
      title: _state.serverName ?? _state.serverAddress ?? '',
      state: 'warming',
      message: _state.message ?? '暖服中...',
      mapName: _state.serverInfo?.map,
      mapNameCn: _state.mapInfo?.mapLabel,
      mapBackground: _state.mapInfo?.mapUrl,
      currentPlayers: _state.serverInfo?.players,
      targetPlayers: _state.warmupTargetPlayers,
    );
  }

  /// 当前操作类型
  OperationType get currentType => _state.type;

  // ==================== 公开方法 ====================

  /// 初始化服务（应用启动时调用）
  void initialize() {
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = _gameStatusService.statusStream.listen(
      _onGameStatusChanged,
    );
    _updateState(
      _state.copyWith(isGameRunning: _gameStatusService.isGameRunning),
    );
    LogService.i('[StatusWindowService] 服务已初始化');
  }

  /// 启动游戏
  Future<bool> launchGame({
    String? serverAddress,
    String? serverName,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    String? gameType,
    int? appId,
  }) async {
    // 检查游戏路径是否已配置
    final hasGamePath = await _gameLauncher.hasGamePath();
    if (!hasGamePath) {
      _updateState(
        OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: '请先在设置中配置游戏路径',
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: false,
        ),
      );
      return false;
    }

    // 解析目标游戏客户端
    final client = ServerItemUtils.resolveGameClient(
      appId: appId,
      gameType: gameType,
    );

    // CSGO Legacy 无法通过 Steam URL 自动启动，需要手动启动
    if (client == GameClient.csgoLegacy) {
      _updateState(
        OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: '此服务器需要手动启动 CSGO',
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: false,
          needManualLaunch: true,
        ),
      );
      return false;
    }

    // 独立版 CSGO / CS:Source：无法走 CS2 的 -condebug 监控流程。
    // steam://run/<appId>//+connect 会同时拉起游戏并连接，因此直接交给
    // launchAndConnect 处理（避免与 connectToServer 互相递归）。
    if (client != GameClient.cs2) {
      final result = await _gameLauncher.launchAndConnect(
        serverAddress ?? '',
        gameType: gameType,
        appId: appId,
      );
      // 注意：result.success 仅代表"Steam 启动/连接命令已成功下发"，
      // 并不代表游戏进程已经起来。isGameRunning 必须以真实进程检测为准，
      // 否则点一下连接就会被误判为"游戏运行中"。
      final actuallyRunning = await _gameLauncher.isCS2Running();
      _updateState(
        OperationState(
          type: OperationType.none,
          status: result.success
              ? OperationStatus.success
              : OperationStatus.failed,
          message: result.success
              ? ((serverAddress != null && serverAddress.isNotEmpty)
                    ? _Messages.connecting
                    : _Messages.launchSuccess)
              : result.error,
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: actuallyRunning,
          needCsgoLegacy: result.needCsgoLegacy,
          needManualLaunch: result.needManualLaunch,
        ),
      );
      if (result.success &&
          serverAddress != null &&
          serverAddress.isNotEmpty) {
        _audioService.playQueueSuccessSound();
      }
      return result.success;
    }

    // 检查是否有其他操作正在进行
    if (_state.type != OperationType.none &&
        _state.status == OperationStatus.running) {
      LogService.w('[StatusWindowService] 有其他操作正在进行');
      return false;
    }

    _cancelCloseTimer();

    // 更新状态
    _updateState(
      OperationState(
        type: OperationType.launching,
        status: OperationStatus.running,
        message: _Messages.launching,
        serverAddress: serverAddress,
        serverName: serverName,
      ),
    );

    // 先检查游戏是否已在运行
    final alreadyRunning = await _gameLauncher.isCS2Running();
    if (alreadyRunning) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.success,
          message: _Messages.gameAlreadyRunning,
          isGameRunning: true,
        ),
      );
      return true;
    }

    // 检测 Steam 状态是否卡住（Steam 认为游戏在运行但进程不存在）
    final steamStuck = await _gameLauncher.isSteamStatusStuck();
    if (steamStuck) {
      _updateState(
        _state.copyWith(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: _Messages.launchSteamStuck,
        ),
      );
      return false;
    }

    // 先创建窗口，再启动游戏
    // 启动游戏时不显示地图背景
    await _showWindow(
      type: FloatingWindowType.launch,
      title: serverName ?? '启动游戏',
      state: 'launching',
      message: _Messages.launching,
      // 启动游戏时不传递地图信息，不显示地图背景
    );

    // 执行启动
    final result = await _gameLauncher.launchCS2();

    if (!result.success) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.failed,
          message: result.error ?? _Messages.launchFailed,
        ),
      );
      await _updateWindow(
        state: 'failed',
        message: result.error ?? _Messages.launchFailed,
        autoDismissSeconds: 3,
      );
      _scheduleClose(seconds: 3);
      return false;
    }

    // 游戏已在运行（二次检查）
    if (result.alreadyRunning) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.success,
          message: _Messages.gameAlreadyRunning,
          isGameRunning: true,
        ),
      );
      await _updateWindow(
        state: 'success',
        message: _Messages.gameAlreadyRunning,
        autoDismissSeconds: 3,
      );
      _scheduleClose(seconds: 3);
      return true;
    }

    // 等待游戏加载
    final loaded = await _waitForGameLoad();

    if (loaded) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型（如果没有后续连接）
          status: OperationStatus.success,
          message: _Messages.launchSuccess,
          isGameRunning: true,
        ),
      );
      await _updateWindow(
        state: 'success',
        message: _Messages.launchSuccess,
        autoDismissSeconds: 5,
      );
      _scheduleClose(seconds: 5);

      // 如果有服务器地址，继续连接
      if (serverAddress != null && serverAddress.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        await connectToServer(
          serverAddress: serverAddress,
          serverName: serverName,
          mapName: mapName,
          mapNameCn: mapNameCn,
          mapBackground: mapBackground,
          gameType: gameType,
          appId: appId,
        );
      }
    } else {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.failed,
          message: _Messages.launchTimeout,
        ),
      );
      await _updateWindow(
        state: 'failed',
        message: _Messages.launchTimeout,
        autoDismissSeconds: 3,
      );
      _scheduleClose(seconds: 3);
    }

    return loaded;
  }

  /// 连接服务器
  Future<bool> connectToServer({
    required String serverAddress,
    String? serverName,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    bool playSuccessSound = true,
    String? gameType,
    int? appId,
  }) async {
    // 检查游戏路径是否已配置
    final hasGamePath = await _gameLauncher.hasGamePath();
    if (!hasGamePath) {
      _updateState(
        OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: '请先在设置中配置游戏路径',
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: false,
        ),
      );
      return false;
    }

    // 解析目标游戏客户端
    final client = ServerItemUtils.resolveGameClient(
      appId: appId,
      gameType: gameType,
    );

    // CS:Source：只发连接指令，不监控、不判断游戏是否启动。
    // 直接把 steam://run/240//+connect 指令交给 Steam 处理即可。
    if (client.isConnectOnly) {
      return await _connectOnly(
        serverAddress: serverAddress,
        serverName: serverName,
        gameType: gameType,
        appId: appId,
        playSuccessSound: playSuccessSound,
      );
    }

    // 检查游戏是否运行
    final gameRunning = await _gameLauncher.isCS2Running();

    if (!gameRunning) {
      if (client == GameClient.csgoLegacy) {
        // CSGO Legacy 无法自动启动，直接调用 connectToServer 让它返回错误
        final result = await _gameLauncher.connectToServer(
          serverAddress,
          gameType: gameType,
          appId: appId,
        );

        // 处理 CSGO 相关错误
        if (!result.success) {
          _updateState(
            OperationState(
              type: OperationType.none,
              status: OperationStatus.failed,
              message: result.error,
              serverAddress: serverAddress,
              serverName: serverName,
              isGameRunning: false,
              needCsgoLegacy: result.needCsgoLegacy,
              needManualLaunch: result.needManualLaunch,
            ),
          );
        }
        return result.success;
      }

      // CS2 / 独立版 CSGO / CS:Source，先启动游戏（launchGame 内部会按客户端分流）
      return await launchGame(
        serverAddress: serverAddress,
        serverName: serverName,
        mapName: mapName,
        mapNameCn: mapNameCn,
        mapBackground: mapBackground,
        gameType: gameType,
        appId: appId,
      );
    }

    // 检查是否可监控
    // 注意：连接状态监控依赖 CS2 的 -condebug console.log，
    // 仅 CS2 支持；独立版 CSGO 与 CS:Source 一律走"不可监控"的直发连接路径
    final canMonitor =
        client == GameClient.cs2 && _gameStatusService.isMonitorable;

    if (!canMonitor) {
      // 不可监控时，再次确认游戏是否运行
      final stillRunning = await _gameLauncher.isCS2Running();
      if (!stillRunning) {
        _updateState(
          OperationState(
            type: OperationType.none,
            status: OperationStatus.failed,
            message: '游戏已关闭，请重新启动',
            serverAddress: serverAddress,
            serverName: serverName,
            isGameRunning: false,
          ),
        );
        return false;
      }

      // 不可监控，直接发送连接命令
      final result = await _gameLauncher.connectToServer(
        serverAddress,
        gameType: gameType,
        appId: appId,
      );

      // 检查是否需要安装 CSGO Legacy 或手动启动
      if (!result.success) {
        _updateState(
          OperationState(
            type: OperationType.none,
            status: OperationStatus.failed,
            message: result.error,
            serverAddress: serverAddress,
            serverName: serverName,
            isGameRunning: true,
            needCsgoLegacy: result.needCsgoLegacy,
            needManualLaunch: result.needManualLaunch,
          ),
        );
        return false;
      }

      if (result.success && playSuccessSound) {
        _audioService.playQueueSuccessSound();
      }
      return result.success;
    }

    _cancelCloseTimer();

    // 更新状态
    _updateState(
      OperationState(
        type: OperationType.connecting,
        status: OperationStatus.running,
        message: _Messages.connecting,
        serverAddress: serverAddress,
        serverName: serverName,
        isGameRunning: true,
      ),
    );

    // 先创建窗口，再发送连接命令
    await _showWindow(
      type: FloatingWindowType.connect,
      serverAddress: serverAddress,
      title: serverName ?? serverAddress,
      state: 'connecting',
      message: _Messages.connecting,
      mapName: mapName,
      mapNameCn: mapNameCn,
      mapBackground: mapBackground,
    );

    // 发送连接命令
    final connectResult = await _gameLauncher.connectToServer(
      serverAddress,
      gameType: gameType,
      appId: appId,
    );
    if (!connectResult.success) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.failed,
          message: connectResult.error ?? _Messages.connectFailed,
          needCsgoLegacy: connectResult.needCsgoLegacy,
          needManualLaunch: connectResult.needManualLaunch,
        ),
      );
      await _updateWindow(
        state: 'failed',
        message: connectResult.error ?? _Messages.connectFailed,
        autoDismissSeconds: 3,
      );
      _scheduleClose(seconds: 3);
      return false;
    }

    // 监控连接状态
    final monitorResult = await _monitorConnection(
      mapName: mapName,
      mapNameCn: mapNameCn,
      mapBackground: mapBackground,
    );

    if (monitorResult.success) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.success,
          message: _Messages.connectSuccess,
        ),
      );
      await _updateWindow(
        state: 'success',
        message: _Messages.connectSuccess,
        autoDismissSeconds: 5,
      );
      if (playSuccessSound) {
        _audioService.playQueueSuccessSound();
      }
      _scheduleClose(seconds: 5);
      return true;
    } else if (monitorResult.state == GameState.serverFull) {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.serverFull,
          message: _Messages.serverFull,
        ),
      );
      await _updateWindow(
        state: 'serverFull',
        message: _Messages.serverFull,
        autoDismissSeconds: 8,
      );
      _scheduleClose(seconds: 8); // 失败状态使用8秒倒计时
      return false;
    } else {
      _updateState(
        _state.copyWith(
          type: OperationType.none, // 重置操作类型
          status: OperationStatus.failed,
          message: monitorResult.message ?? _Messages.connectFailed,
        ),
      );
      await _updateWindow(
        state: 'failed',
        message: monitorResult.message ?? _Messages.connectFailed,
        autoDismissSeconds: 8,
      );
      _scheduleClose(seconds: 8); // 失败状态使用8秒倒计时
      return false;
    }
  }

  /// CS:Source 专用连接：只发连接指令，不监控、不判断游戏是否启动。
  ///
  /// CS:Source 不在监控范围内，连接它的服务器只需把
  /// `steam://run/240//+connect <addr>` 指令交给 Steam，由 Steam 负责
  /// 拉起游戏并连接。这里既不检测进程，也不设置 isGameRunning，
  /// 避免"点一下连接就被误判为游戏已启动"。
  Future<bool> _connectOnly({
    required String serverAddress,
    String? serverName,
    String? gameType,
    int? appId,
    bool playSuccessSound = true,
  }) async {
    final result = await _gameLauncher.connectToServer(
      serverAddress,
      gameType: gameType,
      appId: appId,
    );

    if (!result.success) {
      _updateState(
        OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: result.error ?? _Messages.connectFailed,
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: false,
        ),
      );
      return false;
    }

    _updateState(
      OperationState(
        type: OperationType.none,
        status: OperationStatus.success,
        message: _Messages.commandSent,
        serverAddress: serverAddress,
        serverName: serverName,
        // CS:Source 不监控运行状态，这里保持 false。
        isGameRunning: false,
      ),
    );

    if (playSuccessSound) {
      _audioService.playQueueSuccessSound();
    }
    return true;
  }

  /// 开始挤服
  Future<bool> startQueue({
    required String serverAddress,
    String? serverName,
    QueueConfig? config,
    ServerInfo? serverInfo,
    MapData? mapInfo,
  }) async {
    // 检查游戏路径是否已配置
    final hasGamePath = await _gameLauncher.hasGamePath();
    if (!hasGamePath) {
      _updateState(
        OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: '请先在设置中配置游戏路径',
          serverAddress: serverAddress,
          isGameRunning: false,
        ),
      );
      return false;
    }

    // 解析目标客户端（先解析，便于对 CS:Source 做特殊处理）
    final gameType = serverInfo?.gameType;
    final client = ServerItemUtils.resolveGameClient(
      appId: serverInfo?.appId,
      gameType: gameType,
    );

    // 检查游戏是否运行
    // CS:Source 不要求游戏在运行（只发连接指令的乐观挤服），跳过该检查。
    if (!client.isConnectOnly && !_gameStatusService.isGameRunning) {
      _updateState(_state.copyWith(error: _Messages.gameNotRunning));
      return false;
    }

    // 如果是 CSGO Legacy 服务器，额外检查 CSGO Legacy 是否安装
    if (client == GameClient.csgoLegacy) {
      final isInstalled = await _gameLauncher.isCsgoLegacyInstalled();
      if (!isInstalled) {
        _updateState(
          OperationState(
            type: OperationType.none,
            status: OperationStatus.failed,
            message: '此服务器需要 CSGO 客户端',
            serverAddress: serverAddress,
            isGameRunning: true,
            needCsgoLegacy: true,
          ),
        );
        return false;
      }

      // 注意：这里不需要检查 CSGO 是否运行，因为前面已经检查了 isGameRunning
      // isGameRunning 会检测 csgo.exe 和 cs2.exe
    }

    // 检查是否有其他操作
    if (_state.type == OperationType.connecting &&
        _state.status == OperationStatus.running) {
      LogService.w('[StatusWindowService] 正在连接中，无法开始挤服');
      return false;
    }

    _cancelCloseTimer();

    final queueConfig = config ?? const QueueConfig();

    // 验证自动重试条件：先刷新游戏状态，再判断是否可监控
    var finalConfig = queueConfig;
    if (queueConfig.enableAutoRetry) {
      await _gameStatusService.refreshStatus();
      if (!_gameStatusService.isMonitorable) {
        finalConfig = queueConfig.copyWith(enableAutoRetry: false);
        LogService.w('[StatusWindowService] 游戏不可监控，已禁用自动重试（请使用 BakaBox 启动游戏）');
      }
    }

    // 初始化线程状态
    final threadStatuses = List<ThreadStatus>.filled(
      finalConfig.effectiveThreadCount,
      ThreadStatus.idle,
    );

    // 更新状态
    _updateState(
      OperationState(
        type: OperationType.queueing,
        status: OperationStatus.running,
        message: _Messages.queueing,
        serverAddress: serverAddress,
        serverName: serverName ?? serverInfo?.hostName ?? serverAddress,
        serverInfo: serverInfo,
        mapInfo: mapInfo,
        queueConfig: finalConfig,
        threadStatuses: threadStatuses,
        isGameRunning: true,
      ),
    );

    // 重置挤服状态
    _isQueueRunning = true;
    _isThreadsRunning = false;
    _isTriggeredConnection = false;
    _isFetching = false;
    _activeThreadIds.clear();
    _consecutiveFailures = 0;
    _backoffMultiplier = 1.0;
    _lastSuccessTime = null;
    _outcomeFinalized = false;
    _isObservingConnect = false; // 防御：上一周期若被异常打断，避免观察期标志残留

    // 设置守护进程目标地址（同步，DNS 已在应用启动时完成）
    QueueGuardService().setTarget(serverAddress);

    // 创建窗口
    await _showWindow(
      type: FloatingWindowType.queue,
      serverAddress: serverAddress,
      title: serverName ?? serverInfo?.hostName ?? serverAddress,
      state: 'queueing',
      message: _Messages.queueing,
      mapName: serverInfo?.map,
      mapNameCn: mapInfo?.mapLabel,
      mapBackground: mapInfo?.mapUrl,
      currentPlayers: serverInfo?.players,
      targetPlayers: finalConfig.targetPlayers,
      threadStatuses: threadStatuses.map((s) => s.name).toList(),
    );

    // 挂载守护进程（内部检查 isMonitorable / 映射就绪情况）
    await _attachQueueGuard(serverAddress);

    // 入口快照检查：若已被守护判定为终态，跳过后续刷信息
    if (_outcomeFinalized) {
      LogService.i('[StatusWindowService] startQueue 入口快照已敲定终态，跳过刷信息');
      return true;
    }

    // 获取初始服务器信息
    await _fetchServerInfo(serverAddress);

    // 开始多线程请求
    if (_isQueueRunning && !_outcomeFinalized) {
      _scheduleNextFetch(serverAddress);
    }

    LogService.d(
      '[StatusWindowService] 挤服已开始: ${finalConfig.effectiveThreadCount}个线程(多线程=${finalConfig.multiThreadEnabled}, 间隔=${finalConfig.requestIntervalSeconds}s), 自动重试=${finalConfig.enableAutoRetry}',
    );
    return true;
  }

  /// 暂停挤服
  void pauseQueue() {
    if (_state.type != OperationType.queueing) return;

    _isQueueRunning = false;
    _isThreadsRunning = false;
    _isTriggeredConnection = false;
    _isFetching = false;
    _activeThreadIds.clear();

    // 重置退避状态
    _consecutiveFailures = 0;
    _backoffMultiplier = 1.0;
    _lastSuccessTime = null;

    // 卸载守护进程
    _detachQueueGuard();

    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());

    _updateState(
      _state.copyWith(
        type: OperationType.none, // 重置操作类型
        status: OperationStatus.paused,
        message: _Messages.queuePaused,
      ),
    );

    _updateWindow(
      state: 'paused',
      message: _Messages.queuePaused,
      autoDismissSeconds: 1,
    );
    _scheduleClose(seconds: 0);

    LogService.d('[StatusWindowService] 挤服已暂停');
  }

  /// 开始暖服
  Future<bool> startWarmup({
    required String serverAddress,
    String? serverName,
    ServerInfo? serverInfo,
    MapData? mapInfo,
    required int targetPlayers,
    bool showFloatingWindow = true,
  }) async {
    // 检查是否有其他操作正在进行
    if (_state.type != OperationType.none &&
        _state.type != OperationType.warming) {
      LogService.w('[StatusWindowService] 有其他操作正在进行，无法暖服');
      return false;
    }

    _warmupFloatingWindowEnabled = showFloatingWindow;

    _updateState(
      _state.copyWith(
        type: OperationType.warming,
        status: OperationStatus.running,
        serverAddress: serverAddress,
        serverName: serverName ?? serverInfo?.hostName ?? serverAddress,
        serverInfo: serverInfo,
        mapInfo: mapInfo,
        message: '暖服中...',
        warmupTargetPlayers: targetPlayers,
      ),
    );

    // 创建原生悬浮窗（仅在启用浮窗显示时）
    if (showFloatingWindow) {
      await _showWindow(
        type: FloatingWindowType.warmup,
        serverAddress: serverAddress,
        title: serverName ?? serverInfo?.hostName ?? serverAddress,
        state: 'warming',
        message: '暖服中...',
        mapName: serverInfo?.map,
        mapNameCn: mapInfo?.mapLabel,
        mapBackground: mapInfo?.mapUrl,
        currentPlayers: serverInfo?.players,
        targetPlayers: _state.warmupTargetPlayers,
      );
    }

    LogService.d('[StatusWindowService] 暖服已开始: $serverAddress');
    return true;
  }

  /// 供 WarmupBloc 更新状态并同步给原生悬浮窗
  void updateWarmupState({
    int? currentPlayers,
    int? targetPlayers,
    String? message,
    OperationStatus? status,
    MapData? mapInfo,
    bool clearMapInfo = false,
    String? mapName,
    int? maxPlayers,
  }) {
    if (_state.type != OperationType.warming) return;

    ServerInfo? updatedServerInfo = _state.serverInfo;
    // 只要人数、地图或最大人数任一发生变化，就重建 serverInfo
    if (currentPlayers != null || mapName != null || maxPlayers != null) {
      updatedServerInfo = ServerInfo(
        protocol: _state.serverInfo?.protocol,
        hostName: _state.serverInfo?.hostName ?? _state.serverName,
        // 关键修复：地图换图后使用最新的 mapName，避免悬浮窗显示旧地图
        map: mapName ?? _state.serverInfo?.map ?? '',
        modDir: _state.serverInfo?.modDir,
        modDesc: _state.serverInfo?.modDesc,
        appId: _state.serverInfo?.appId,
        players: currentPlayers ?? _state.serverInfo?.players,
        maxPlayers: maxPlayers ?? _state.serverInfo?.maxPlayers ?? 0,
        bots: _state.serverInfo?.bots,
        dedicated: _state.serverInfo?.dedicated,
        os: _state.serverInfo?.os,
        password: _state.serverInfo?.password,
        secure: _state.serverInfo?.secure,
        version: _state.serverInfo?.version,
        extraDataFlags: _state.serverInfo?.extraDataFlags,
        gamePort: _state.serverInfo?.gamePort,
        steamId: _state.serverInfo?.steamId,
        gameTags: _state.serverInfo?.gameTags,
        gameId: _state.serverInfo?.gameId,
        ip: _state.serverInfo?.ip ?? _state.serverAddress,
        pingLatency: _state.serverInfo?.pingLatency,
        pingStatus: _state.serverInfo?.pingStatus,
        gameType: _state.serverInfo?.gameType,
      );
    }

    _updateState(
      _state.copyWith(
        serverInfo: updatedServerInfo,
        warmupTargetPlayers: targetPlayers ?? _state.warmupTargetPlayers,
        message: message ?? _state.message,
        status: status ?? _state.status,
        mapInfo: mapInfo,
        clearMapInfo: clearMapInfo,
      ),
    );

    // 如果浮窗被禁用，则不向原生悬浮窗推送更新
    if (!_warmupFloatingWindowEnabled) return;

    // 地图信息或服务器信息发生变化，主动触发一次悬浮窗更新（含人数）
    // 换图后若新地图信息拉取失败（clearMapInfo），推送空字符串清掉旧译名/背景，
    // 避免悬浮窗出现"新地图英文名 + 旧地图译名/背景"的错配。
    _updateWindow(
      currentPlayers: currentPlayers ?? updatedServerInfo?.players,
      targetPlayers: targetPlayers ?? _state.warmupTargetPlayers,
      mapName: updatedServerInfo?.map,
      mapNameCn: clearMapInfo
          ? ''
          : (mapInfo?.mapLabel ?? _state.mapInfo?.mapLabel),
      mapBackground: clearMapInfo
          ? ''
          : (mapInfo?.mapUrl ?? _state.mapInfo?.mapUrl),
    );
  }

  /// 暂停/停止暖服
  void pauseWarmup() {
    if (_state.type != OperationType.warming) return;

    // 断开暖服 WebSocket 连接
    final usersBloc = WarmupUsersBloc.instance;
    usersBloc.add(const WarmupUsersLeave());
    usersBloc.add(const WarmupUsersDisconnect());

    _updateState(
      _state.copyWith(
        type: OperationType.none, // 重置操作类型
        status: OperationStatus.paused,
        message: '已停止暖服',
      ),
    );

    _updateWindow(
      state: 'paused',
      message: '已停止暖服',
      autoDismissSeconds: 1,
    );
    _scheduleClose(seconds: 0);

    LogService.d('[StatusWindowService] 暖服已停止');
  }

  /// 更新挤服配置
  void updateQueueConfig(QueueConfig config) {
    if (_state.type != OperationType.queueing) return;

    _updateState(_state.copyWith(queueConfig: config));

    // 更新线程状态数组大小（按生效线程数）
    if (config.effectiveThreadCount != _state.threadStatuses.length) {
      final newStatuses = List<ThreadStatus>.filled(
        config.effectiveThreadCount,
        ThreadStatus.idle,
      );
      _updateState(_state.copyWith(threadStatuses: newStatuses));
    }
  }

  /// 设置目标人数
  void setTargetPlayers(int targetPlayers) {
    if (_state.type != OperationType.queueing) return;
    _updateState(
      _state.copyWith(
        queueConfig: _state.queueConfig.copyWith(targetPlayers: targetPlayers),
      ),
    );
  }

  /// 设置线程数量
  void setThreadCount(int threadCount) {
    if (_state.type != OperationType.queueing) return;
    final newConfig = _state.queueConfig.copyWith(threadCount: threadCount);
    final newStatuses = List<ThreadStatus>.filled(
      newConfig.effectiveThreadCount,
      ThreadStatus.idle,
    );
    _updateState(
      _state.copyWith(queueConfig: newConfig, threadStatuses: newStatuses),
    );
  }

  /// 设置是否启用多线程（仅自定义服务器场景）
  ///
  /// 切换会同步重置线程状态数组：
  /// - 关闭：变为 1 个槽位
  /// - 开启：恢复为 [QueueConfig.threadCount] 个槽位
  void setMultiThreadEnabled(bool enabled) {
    if (_state.type != OperationType.queueing) return;
    final newConfig =
        _state.queueConfig.copyWith(multiThreadEnabled: enabled);
    final newStatuses = List<ThreadStatus>.filled(
      newConfig.effectiveThreadCount,
      ThreadStatus.idle,
    );
    _updateState(
      _state.copyWith(queueConfig: newConfig, threadStatuses: newStatuses),
    );
  }

  /// 设置单线程模式下的请求间隔（秒，1-6）
  void setRequestIntervalSeconds(int seconds) {
    if (_state.type != OperationType.queueing) return;
    final clamped = seconds.clamp(1, 6);
    _updateState(
      _state.copyWith(
        queueConfig: _state.queueConfig.copyWith(
          requestIntervalSeconds: clamped,
        ),
      ),
    );
  }

  /// 设置自动重试
  ///
  /// 自动重试强依赖 console.log 监控（-condebug），因此：
  /// - 启用前必须确认 isMonitorable
  /// - isMonitorable 为真 → 守护进程已在 startQueue 时挂载（无需补挂）
  Future<bool> setAutoRetry(bool enable) async {
    if (_state.type != OperationType.queueing) return false;

    if (enable) {
      // 先刷新游戏状态，再判断是否可监控
      await _gameStatusService.refreshStatus();
      if (!_gameStatusService.isMonitorable) {
        LogService.w('[StatusWindowService] 自动重试启用失败：请使用 BakaBox 启动游戏');
        return false;
      }
    }

    _updateState(
      _state.copyWith(
        queueConfig: _state.queueConfig.copyWith(enableAutoRetry: enable),
      ),
    );
    return true;
  }

  /// 取消当前操作
  void cancel() {
    _isQueueRunning = false;
    _isThreadsRunning = false;
    _isTriggeredConnection = false;
    _isFetching = false;
    _activeThreadIds.clear();
    _consoleLogService.cancelConnectionMonitor();

    // 卸载守护进程
    _detachQueueGuard();

    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());

    final warmupUsersBloc = WarmupUsersBloc.instance;
    warmupUsersBloc.add(const WarmupUsersLeave());
    warmupUsersBloc.add(const WarmupUsersDisconnect());

    _updateState(
      _state.copyWith(
        type: OperationType.none, // 重置操作类型
        status: OperationStatus.paused,
        message: _Messages.cancelled,
      ),
    );

    _updateWindow(
      state: 'paused',
      message: _Messages.cancelled,
      autoDismissSeconds: 2,
    );
    _scheduleClose(seconds: 2);
  }

  /// 重置状态
  void reset() {
    _isQueueRunning = false;
    _isThreadsRunning = false;
    _isTriggeredConnection = false;
    _isFetching = false;
    _activeThreadIds.clear();
    _consecutiveFailures = 0;
    _backoffMultiplier = 1.0;
    _lastSuccessTime = null;
    _outcomeFinalized = false;
    _isObservingConnect = false;

    // 卸载守护进程
    _detachQueueGuard();

    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());

    final warmupUsersBloc = WarmupUsersBloc.instance;
    warmupUsersBloc.add(const WarmupUsersLeave());
    warmupUsersBloc.add(const WarmupUsersDisconnect());

    _updateState(
      OperationState(isGameRunning: _gameStatusService.isGameRunning),
    );
  }

  /// 关闭窗口
  Future<void> closeWindow() async {
    _cancelCloseTimer();
    if (_windowId != null) {
      await _windowService.closeWindow(_windowId!);
      _windowId = null;
    }
  }

  /// 处理浮动窗口关闭事件（由主窗口调用）
  void onFloatingWindowClosed(String windowId) {
    if (_windowId == windowId) {
      LogService.d(
        '[StatusWindowService] Floating window closed notification received: $windowId',
      );
      _windowId = null;
      _cancelCloseTimer();
    }
  }

  /// 刷新服务器信息（挤服页面用）
  Future<void> refreshServerInfo() async {
    if (_state.serverAddress == null) return;
    await _fetchServerInfo(_state.serverAddress!);
  }

  // ==================== 私有方法 ====================

  /// 更新状态
  void _updateState(OperationState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  /// 结局闸门：本周期内仅允许一次终态
  ///
  /// 仅包裹"真正终结"的路径（成功 / 不重试的失败终态）。
  /// 自动重试的失败不锁，让下一轮可以继续判定。
  bool _finalizeOnce(void Function() action) {
    if (_outcomeFinalized) return false;
    _outcomeFinalized = true;
    action();
    return true;
  }

  /// 挂载守护进程订阅 + 启动心跳
  ///
  /// - 不可监控（无 -condebug）→ 跳过守护，挤服走"乐观模式"
  /// - 映射服务未就绪 → await load 兜底，失败则跳过守护
  Future<void> _attachQueueGuard(String serverAddress) async {
    _queueGuardSub?.cancel();
    _queueGuardSub = null;

    // 降级 1：游戏不可监控
    if (!_gameStatusService.isMonitorable) {
      LogService.i('[StatusWindowService] 游戏不可监控，跳过守护进程（乐观模式）');
      return;
    }

    // 降级 2：地址映射未就绪
    if (!ServerAddressMappingService().isLoaded) {
      try {
        await ServerAddressMappingService().load().timeout(
          const Duration(seconds: 3),
        );
      } catch (e) {
        LogService.w('[StatusWindowService] 映射服务未就绪且加载失败，跳过守护进程: $e');
        return;
      }
    }

    // 入口快照
    final initial = QueueGuardService().location;
    LogService.d('[StatusWindowService] 挂载守护进程，初始 location=$initial');
    switch (initial) {
      case GuardLocation.inTargetServer:
      case GuardLocation.inUnknownServer:
        LogService.i('[StatusWindowService] 启动时已在游戏中 ($initial)，立即 finalize');
        _finalizeOnce(_handleAlreadyInGame);
        return;
      case GuardLocation.inOtherServer:
        // 入口快照：用户已在其他服，挤服正常继续刷信息（文案保持"挤服中..."，无需切换）
        break;
      case GuardLocation.notInGame:
        break;
    }

    _queueGuardSub = QueueGuardService().events.listen(_onGuardEvent);
    QueueGuardService().startHeartbeat();
  }

  /// 卸载守护进程订阅 + 停止心跳
  void _detachQueueGuard() {
    _queueGuardSub?.cancel();
    _queueGuardSub = null;
    QueueGuardService().stopHeartbeat();
    QueueGuardService().clearTarget();
  }

  /// 守护进程事件回调（全局守护）
  ///
  /// 观察期内（[_isObservingConnect]=true）由 [_observeConnection] 独占处理，
  /// 此处直接 return 避免切服中间态被全局误处理。
  void _onGuardEvent(QueueGuardEvent event) {
    // 用 _state.type 而不是 _isQueueRunning：
    // _isQueueRunning 在 connect 期间为 false（用来停刷信息线程），
    // 但挤服整体仍处于活跃状态，守护回调需要继续工作
    if (_state.type != OperationType.queueing) return;
    if (_isObservingConnect) return;
    if (_outcomeFinalized) return;

    switch (event.location) {
      case GuardLocation.inTargetServer:
        LogService.i('[StatusWindowService] [QueueGuard] 进入目标服，挤服成功');
        _finalizeOnce(_handleAlreadyInGame);
        break;

      case GuardLocation.inUnknownServer:
        LogService.i(
          '[StatusWindowService] [QueueGuard] 检测到在游戏中（地址未知），保守 finalize',
        );
        _finalizeOnce(_handleAlreadyInGame);
        break;

      case GuardLocation.inOtherServer:
        // 用户在其他服，挤服继续运行（不切换文案，保持"挤服中..."）
        break;

      case GuardLocation.notInGame:
        // 主菜单或未在游戏：挤服正常继续，无需特殊处理
        break;
    }
  }

  /// 游戏状态变化处理
  void _onGameStatusChanged(GameStatusEvent event) {
    _updateState(_state.copyWith(isGameRunning: event.isRunning));

    // 游戏关闭时，停止所有操作
    if (!event.isRunning) {
      LogService.d('[StatusWindowService] 游戏已关闭，停止所有操作');

      // 停止挤服
      _isQueueRunning = false;
      _isThreadsRunning = false;
      _isTriggeredConnection = false;
      _isFetching = false;
      _activeThreadIds.clear();

      // 卸载守护进程
      _detachQueueGuard();

      // 断开 WebSocket 连接
      final usersBloc = QueueUsersBloc.instance;
      usersBloc.add(const QueueUsersLeave());
      usersBloc.add(const QueueUsersDisconnect());

      // 取消日志监控
      _consoleLogService.cancelConnectionMonitor();

      // 禁用自动重试
      if (_state.queueConfig.enableAutoRetry) {
        _updateState(
          _state.copyWith(
            queueConfig: _state.queueConfig.copyWith(enableAutoRetry: false),
          ),
        );
      }

      // 如果有正在进行的操作，标记为失败并关闭窗口
      if (_state.type != OperationType.none &&
          _state.status == OperationStatus.running) {
        _updateState(
          _state.copyWith(
            type: OperationType.none, // 重置操作类型
            status: OperationStatus.failed,
            message: _Messages.gameClosed,
          ),
        );
        _updateWindow(
          state: 'failed',
          message: _Messages.gameClosed,
          autoDismissSeconds: 3,
        );
        _scheduleClose(seconds: 3);
      }
    }

    // 游戏启动但不可监控时，禁用自动重试
    if (event.isRunning &&
        !event.isMonitorable &&
        _state.queueConfig.enableAutoRetry) {
      _updateState(
        _state.copyWith(
          queueConfig: _state.queueConfig.copyWith(enableAutoRetry: false),
        ),
      );
      LogService.i('[StatusWindowService] 游戏不可监控，已禁用自动重试');
    }
  }

  /// 等待游戏加载
  Future<bool> _waitForGameLoad() async {
    return await _consoleLogService.waitForGameFullyLoaded(
      maxWait: const Duration(seconds: 90),
      onProgress: (message) async {
        _updateState(_state.copyWith(message: message));
        await _updateWindow(state: 'launching', message: message);
      },
    );
  }

  /// 监控连接状态
  Future<ConnectionStatusResult> _monitorConnection({
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
  }) async {
    _consoleLogService.resetState();

    return await _consoleLogService.monitorConnection(
      maxTimeout: const Duration(seconds: 60),
      onStateChange: (consoleState) async {
        String windowState;
        String message;

        switch (consoleState.state) {
          case GameState.connecting:
            windowState = 'connecting';
            message = _Messages.connecting;
            break;
          case GameState.loading:
            windowState = 'loading';
            message = consoleState.mapName.isNotEmpty
                ? _Messages.loadingMap(consoleState.mapName)
                : _Messages.loading;
            break;
          case GameState.inGame:
            windowState = 'success';
            message = _Messages.connectSuccess;
            break;
          case GameState.serverFull:
            windowState = 'serverFull';
            message = _Messages.serverFull;
            break;
          case GameState.failed:
            windowState = 'failed';
            message = _Messages.connectFailed;
            break;
          default:
            windowState = 'connecting';
            message = _Messages.connecting;
        }

        _updateState(_state.copyWith(message: message));
        await _updateWindow(
          state: windowState,
          message: message,
          mapName: consoleState.mapName.isNotEmpty
              ? consoleState.mapName
              : mapName,
          mapNameCn: mapNameCn,
          mapBackground: mapBackground,
        );
      },
    );
  }

  /// 获取服务器信息
  Future<void> _fetchServerInfo(String serverAddress) async {
    // 防止并发请求
    if (_isFetching) return;

    try {
      _isFetching = true;

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
        MapData? mapInfo = _state.mapInfo;

        if (sourceInfo.map != _lastMapName) {
          // 地图变化时，重新获取地图信息
          try {
            mapInfo = await _serverApi.getMapInfo(sourceInfo.map);
          } catch (e) {
            LogService.d('[StatusWindowService] 获取地图信息失败: $e');
          }

          _lastMapName = sourceInfo.map;
        }

        _consecutiveFailures = 0;
        _backoffMultiplier = 1.0;
        _lastSuccessTime = DateTime.now();

        _updateState(
          _state.copyWith(
            serverInfo: serverInfo,
            mapInfo: mapInfo,
            serverName: serverInfo.hostName,
            error: null,
          ),
        );

        // 更新窗口
        if (_windowId != null && _state.type == OperationType.queueing) {
          await _updateWindow(
            currentPlayers: serverInfo.players,
            mapName: serverInfo.map,
            mapNameCn: mapInfo?.mapLabel,
            mapBackground: mapInfo?.mapUrl,
          );
        }

        // 检查挤服条件
        _checkQueueCondition(serverAddress);
      }
    } catch (e) {
      LogService.e('[StatusWindowService] 获取服务器信息失败', e);
      _consecutiveFailures++;
      _backoffMultiplier = min(_backoffMultiplier * 1.5, 5.0);

      // 连续失败10次，暂停挤服
      if (_consecutiveFailures >= 10 && _isQueueRunning) {
        LogService.w('[StatusWindowService] ${_Messages.queueNetworkUnstable}');
        pauseQueue();
      }
    } finally {
      _isFetching = false;
    }
  }

  /// 检查挤服条件
  void _checkQueueCondition(String serverAddress) {
    if (!_isQueueRunning || _state.serverInfo == null) return;
    if (_outcomeFinalized) return;

    // 防止重复触发连接（多线程并发触发原子锁的快速路径，
    // _connectForQueue 入口还会再次加锁兜底）
    if (_isTriggeredConnection) return;

    // 【守护进程检查】优先用守护进程的判定（覆盖 console + GSI 双信号）
    final loc = QueueGuardService().location;
    if (loc == GuardLocation.inTargetServer ||
        loc == GuardLocation.inUnknownServer) {
      LogService.i('[StatusWindowService] 挤服条件检查：守护进程判定已在游戏中 ($loc)，跳过连接');
      _finalizeOnce(_handleAlreadyInGame);
      return;
    }

    final players = _state.serverInfo!.players ?? 0;
    final targetPlayers = _state.queueConfig.targetPlayers;

    if (players <= targetPlayers) {
      _connectForQueue(serverAddress);
    }
  }

  /// 挤服专用连接（重构版）
  ///
  /// 入口先用 [_isTriggeredConnection] 原子锁防止多线程并发触发，
  /// 再做 location 入口快照 → 进入观察期独占 → 发 connect → 用
  /// [_observeConnection] 等结局。
  Future<void> _connectForQueue(String serverAddress) async {
    // 多线程并发触发的原子锁（设计 3.3.6）
    if (_isTriggeredConnection) return;
    _isTriggeredConnection = true;

    if (_outcomeFinalized) return;

    // 入口快照检查
    final entryLocation = QueueGuardService().location;
    switch (entryLocation) {
      case GuardLocation.inTargetServer:
      case GuardLocation.inUnknownServer:
        LogService.i(
          '[StatusWindowService] _connectForQueue 入口快照: $entryLocation → finalize',
        );
        _finalizeOnce(_handleAlreadyInGame);
        return;
      case GuardLocation.inOtherServer:
      case GuardLocation.notInGame:
        // 继续发 connect（CS2 引擎会自动断开当前连接）
        break;
    }

    // 进入观察期独占
    _isObservingConnect = true;
    try {
      // 立刻清空刷信息线程，避免重复触发
      _activeThreadIds.clear();
      _isThreadsRunning = false;
      _isQueueRunning = false;

      _updateState(
        _state.copyWith(
          status: OperationStatus.running,
          message: _Messages.connecting,
        ),
      );
      await _updateWindow(state: 'connecting', message: _Messages.connecting);

      // 【最终防御】发送 connect 命令前再次确认 location
      // 入口快照与此处之间有 await（_updateWindow），微任务窗口里用户
      // 可能已经进入游戏。这里宁可错失一次 connect 也不在游戏中重连。
      final preConnectLocation = QueueGuardService().location;
      if (preConnectLocation == GuardLocation.inTargetServer ||
          preConnectLocation == GuardLocation.inUnknownServer) {
        LogService.i(
          '[StatusWindowService] 发送 connect 前最终防御: $preConnectLocation → 取消命令并 finalize',
        );
        _finalizeOnce(_handleAlreadyInGame);
        return;
      }

      final gameType = _state.serverInfo?.gameType;
      final result = await _gameLauncher.connectToServer(
        serverAddress,
        gameType: gameType,
        appId: _state.serverInfo?.appId,
      );

      if (!result.success) {
        _handleConnectionOutcome(
          ConnectionOutcome.refused,
          serverAddress,
          result.error,
        );
        return;
      }

      // 不可监控：乐观模式，直接 finalize success（设计 3.3.6）
      if (!_gameStatusService.isMonitorable) {
        // 不可监控时发送成功消息
        final usersBloc = QueueUsersBloc.instance;
        usersBloc.add(const QueueUsersSuccess());
        usersBloc.add(const QueueUsersDisconnect());

        _finalizeOnce(() {
          _isQueueRunning = false;
          _isThreadsRunning = false;
          _activeThreadIds.clear();
          _updateState(
            _state.copyWith(
              type: OperationType.none,
              status: OperationStatus.success,
              message: _Messages.commandSent,
            ),
          );
          _updateWindow(
            state: 'success',
            message: _Messages.commandSent,
            autoDismissSeconds: 5,
          );
          _audioService.playQueueSuccessSound();
          _scheduleClose(seconds: 5);
        });
        return;
      }

      // 可监控：进入观察期，等待守护进程或 console 给出结局
      _updateState(_state.copyWith(message: _Messages.loading));
      await _updateWindow(state: 'loading', message: _Messages.loading);

      final outcome = await _observeConnection(serverAddress, entryLocation);
      _handleConnectionOutcome(outcome, serverAddress, null);
    } catch (e) {
      LogService.e('[StatusWindowService] _connectForQueue 异常', e);
      _handleConnectionOutcome(
        ConnectionOutcome.refused,
        serverAddress,
        _Messages.networkError,
      );
    } finally {
      _isObservingConnect = false;
      // 注意：_isTriggeredConnection 不在这里复位
      // 由 startQueue / _waitForMainMenuAndRetry 复位（保证一次挤服周期内只触发一次）
    }
  }

  /// 观察连接结局
  ///
  /// 同时监听 console.log（明确失败信号）和守护进程（位置变化），
  /// 用 `seenLeftOldServer` 排除"还在原服"误判。
  ///
  /// 切服特殊处理：当 [startLocation] 为 [GuardLocation.inOtherServer] 时，
  /// 引擎会先 disconnect 旧服再 connect 新服。第一次的 `GameState.failed`
  /// 实际上是"按用户意图断开旧服"的副作用，不是真失败，应吞掉并视为
  /// `seenLeftOldServer = true`。后续若再次出现 failed 才是真失败。
  Future<ConnectionOutcome> _observeConnection(
    String serverAddress,
    GuardLocation startLocation,
  ) async {
    final completer = Completer<ConnectionOutcome>();
    StreamSubscription<ConsoleLogState>? consoleSub;
    StreamSubscription<QueueGuardEvent>? guardSub;
    Timer? primaryTimer;
    Timer? extendedTimer;
    bool seenLeftOldServer = false;
    // 切服场景：旧服的引擎 disconnect 不算失败，仅吞一次
    bool consumedSwitchDisconnect =
        startLocation != GuardLocation.inOtherServer;

    void resolve(ConnectionOutcome outcome) {
      if (completer.isCompleted) return;
      consoleSub?.cancel();
      guardSub?.cancel();
      primaryTimer?.cancel();
      extendedTimer?.cancel();
      completer.complete(outcome);
    }

    void onSignal() {
      if (completer.isCompleted) return;
      final loc = QueueGuardService().location;

      // 切服中的过渡态：从其他服 → notInGame（短暂主菜单）→ 目标服
      // 必须等到 inTargetServer 才算成功，inOtherServer 不算
      if (loc == GuardLocation.inTargetServer) {
        resolve(ConnectionOutcome.success);
        return;
      }

      if (loc == GuardLocation.inUnknownServer) {
        // 保守：仅在已离开旧服后才接受 unknown 为成功
        // 避免命令刚发出、还在原服时 GSI 信号被误判
        if (seenLeftOldServer || startLocation == GuardLocation.notInGame) {
          resolve(ConnectionOutcome.success);
        }
        return;
      }

      if (loc == GuardLocation.notInGame) {
        seenLeftOldServer = true; // 标记已离开旧服，进入主菜单（连接中）
      }

      // inOtherServer：仍在原其他服 → 继续等待
    }

    // 监听 console 的状态变化
    //  - 进度态（connecting / loading）→ 更新浮窗 UI
    //  - serverFull / failed → 失败信号
    //  - 其他 → 走 onSignal 重新评估 location
    consoleSub = _consoleLogService.stateStream.listen((s) {
      if (completer.isCompleted) return;

      switch (s.state) {
        case GameState.connecting:
          _updateState(_state.copyWith(message: _Messages.connecting));
          _updateWindow(state: 'connecting', message: _Messages.connecting);
          onSignal();
          return;

        case GameState.loading:
          final msg = s.mapName.isNotEmpty
              ? _Messages.loadingMap(s.mapName)
              : _Messages.loading;
          _updateState(_state.copyWith(message: msg));
          _updateWindow(state: 'loading', message: msg);
          onSignal();
          return;

        case GameState.serverFull:
          // 服务器满始终是真失败（切服中间态不会触发 serverFull）
          resolve(ConnectionOutcome.serverFull);
          return;

        case GameState.failed:
          // 切服场景：吞掉首次 failed（旧服的引擎 disconnect）
          if (!consumedSwitchDisconnect) {
            consumedSwitchDisconnect = true;
            seenLeftOldServer = true;
            LogService.d('[StatusWindowService] [Observe] 吞掉切服过渡的 disconnect');
            return;
          }
          resolve(ConnectionOutcome.refused);
          return;

        default:
          onSignal();
          return;
      }
    });

    guardSub = QueueGuardService().events.listen((_) => onSignal());

    // 启动后立即检查一次（处理"已经在目标服"或"已经在其他服"的初始态）
    onSignal();
    if (completer.isCompleted) return completer.future;

    // 主超时 30 秒
    primaryTimer = Timer(const Duration(seconds: 30), () {
      if (completer.isCompleted) return;
      LogService.w('[StatusWindowService] 观察主超时（30s），延长 30s');
      extendedTimer = Timer(const Duration(seconds: 30), () {
        // 延长结束仍无结果 → 当作 refused 触发重试
        resolve(ConnectionOutcome.refused);
      });
    });

    return completer.future;
  }

  /// 统一处理连接结局
  void _handleConnectionOutcome(
    ConnectionOutcome outcome,
    String serverAddress,
    String? errorHint,
  ) {
    switch (outcome) {
      case ConnectionOutcome.success:
        // QueueUsersSuccess / Disconnect 由 _handleAlreadyInGame 内部统一发送，
        // 避免与该路径重复触发
        _finalizeOnce(_handleAlreadyInGame);
        break;

      case ConnectionOutcome.serverFull:
        _maybeRetry(_Messages.serverFull, serverAddress);
        break;

      case ConnectionOutcome.refused:
        _maybeRetry(errorHint ?? _Messages.connectFailed, serverAddress);
        break;

      case ConnectionOutcome.pending:
        // pending 在 _observeConnection 内部已转化为 refused/success，
        // 兜底当作 refused 处理
        _maybeRetry(_Messages.connectFailed, serverAddress);
        break;
    }
  }

  /// 失败后的重试入口（重试前再问一次守护进程）
  void _maybeRetry(String reason, String serverAddress) {
    final loc = QueueGuardService().location;
    if (loc == GuardLocation.inTargetServer ||
        loc == GuardLocation.inUnknownServer) {
      LogService.i('[StatusWindowService] _maybeRetry 时守护进程已判定在游戏中 → finalize');
      _finalizeOnce(_handleAlreadyInGame);
      return;
    }
    _handleQueueConnectionFailure(reason, serverAddress);
  }

  /// 处理挤服连接失败
  void _handleQueueConnectionFailure(String reason, String serverAddress) {
    LogService.w('[StatusWindowService] 连接失败: $reason');

    if (_outcomeFinalized) {
      LogService.d(
        '[StatusWindowService] _handleQueueConnectionFailure: 已 finalize，忽略',
      );
      return;
    }

    // 保存当前的自动重试状态（在检查前保存，避免状态被意外修改）
    final enableAutoRetry = _state.queueConfig.enableAutoRetry;
    LogService.d(
      '[StatusWindowService] 当前状态: type=${_state.type}, enableAutoRetry=$enableAutoRetry',
    );

    if (enableAutoRetry) {
      LogService.i('[StatusWindowService] 自动重试已启用，准备重新挤服...');

      // 自动重试 - 直接显示重试消息，不发送终态避免触发浮窗倒计时
      final retryMessage = reason.contains('服务器已满')
          ? _Messages.queueRetryServerFull
          : reason.contains('超时')
          ? _Messages.queueRetryTimeout
          : _Messages.queueRetryFailed;

      // 保持 queueing 类型和 enableAutoRetry 状态
      _updateState(
        _state.copyWith(
          type: OperationType.queueing, // 保持挤服类型
          status: OperationStatus.running,
          message: retryMessage,
          queueConfig: _state.queueConfig.copyWith(
            enableAutoRetry: true,
          ), // 确保保持自动重试状态
        ),
      );
      // 发送 queueing 状态而不是终态，避免触发浮窗倒计时关闭
      _updateWindow(state: 'queueing', message: retryMessage);

      // 等待游戏回到主菜单后再重试（不锁闸门，让重试继续）
      _waitForMainMenuAndRetry(serverAddress);
    } else {
      // 非自动重试模式：终态路径，锁闸门
      _finalizeOnce(() {
        String windowState;
        if (reason.contains('服务器已满')) {
          windowState = 'serverFull';
        } else {
          windowState = 'failed';
        }

        // 卸载守护进程
        _detachQueueGuard();

        // 断开 WebSocket 连接
        final usersBloc = QueueUsersBloc.instance;
        usersBloc.add(const QueueUsersLeave());
        usersBloc.add(const QueueUsersDisconnect());

        LogService.i('[StatusWindowService] 自动重试未启用，关闭窗口');
        _updateState(
          _state.copyWith(
            type: OperationType.none, // 重置操作类型
            status: reason.contains('服务器已满')
                ? OperationStatus.serverFull
                : OperationStatus.failed,
            message: reason,
          ),
        );
        _updateWindow(
          state: windowState,
          message: reason,
          autoDismissSeconds: 3,
        );
        _scheduleClose(seconds: 3);
      });
    }
  }

  /// 等待引擎冷却后重试
  Future<void> _waitForMainMenuAndRetry(String serverAddress) async {
    // 检查状态是否仍然需要重试
    if (_state.type != OperationType.queueing ||
        !_state.queueConfig.enableAutoRetry) {
      LogService.w(
        '[StatusWindowService] 重试已取消：type=${_state.type}, enableAutoRetry=${_state.queueConfig.enableAutoRetry}',
      );
      return;
    }

    if (_outcomeFinalized) {
      LogService.d('[StatusWindowService] 重试取消：已 finalize');
      return;
    }

    // 【守护进程检查】重试前先用守护进程的判定（覆盖 console + GSI）
    final guardLoc = QueueGuardService().location;
    if (guardLoc == GuardLocation.inTargetServer ||
        guardLoc == GuardLocation.inUnknownServer) {
      LogService.i('[StatusWindowService] 自动重试取消：守护进程判定已在游戏中 ($guardLoc)');
      _finalizeOnce(_handleAlreadyInGame);
      return;
    }

    // 【防御性检查】如果游戏正在加载中（loading），说明连接可能正在进行
    // 等待加载完成而不是直接重试
    final currentGameState = _consoleLogService.currentState;
    if (currentGameState.state == GameState.loading ||
        currentGameState.state == GameState.connecting) {
      LogService.i(
        '[StatusWindowService] 自动重试延迟：游戏正在连接/加载中 (${currentGameState.state})，等待结果...',
      );
      // 等待游戏状态变为 inGame 或回到主菜单，最多等30秒
      final settled = await _waitForGameStateSettled(
        maxWait: const Duration(seconds: 30),
      );
      if (settled == GameState.inGame) {
        // 不能仅凭 GameState.inGame 就 finalize success，
        // 用户可能进入的是其他服（C 服）而不是目标服。改用守护进程的
        // location 判定，仅 inTargetServer / inUnknownServer 才算成功；
        // inOtherServer 时切换到"在其他服等待"文案并继续重试流程。
        final settledLoc = QueueGuardService().location;
        if (settledLoc == GuardLocation.inTargetServer ||
            settledLoc == GuardLocation.inUnknownServer) {
          LogService.i('[StatusWindowService] 自动重试取消：等待期间进入目标服 ($settledLoc)');
          _finalizeOnce(_handleAlreadyInGame);
          return;
        }
        if (settledLoc == GuardLocation.inOtherServer) {
          LogService.i('[StatusWindowService] 等待期间用户进入其他服，继续重试流程');
          // 不切换文案，保持原有的重试中文案
          // fall through，继续重试
        }
      }
      // 如果回到主菜单或超时，继续重试流程
    }

    // 再次检查状态（等待期间可能被用户暂停）
    if (_state.type != OperationType.queueing ||
        !_state.queueConfig.enableAutoRetry ||
        _outcomeFinalized) {
      LogService.w('[StatusWindowService] 等待期间重试已被取消');
      return;
    }

    // 重置状态标志（让下一轮可以触发 connect）
    _isTriggeredConnection = false;
    _isThreadsRunning = false;
    _isQueueRunning = true;

    _updateState(_state.copyWith(message: _Messages.queueing));
    _updateWindow(state: 'queueing', message: _Messages.queueing);

    // 等待游戏确认回到主菜单（真正的主菜单检测，而不是固定1秒）
    final isMainMenu = await _consoleLogService.waitForMainMenu(
      maxWait: const Duration(seconds: 10),
    );

    if (!_isQueueRunning || _outcomeFinalized) return;

    // 【守护进程检查】waitForMainMenu 返回后再次确认
    final locAfterWait = QueueGuardService().location;
    if (locAfterWait == GuardLocation.inTargetServer ||
        locAfterWait == GuardLocation.inUnknownServer) {
      LogService.i('[StatusWindowService] 自动重试取消：等待主菜单期间守护进程判定在游戏中');
      _finalizeOnce(_handleAlreadyInGame);
      return;
    }

    if (!isMainMenu) {
      // 没有检测到主菜单，但也不在游戏中，使用保守的冷却时间
      LogService.i('[StatusWindowService] 未检测到主菜单状态，使用保守冷却 (2秒)...');
      await Future.delayed(const Duration(seconds: 2));

      if (!_isQueueRunning || _outcomeFinalized) return;

      // 最终防御：冷却后再检查一次
      final finalLoc = QueueGuardService().location;
      if (finalLoc == GuardLocation.inTargetServer ||
          finalLoc == GuardLocation.inUnknownServer) {
        LogService.i('[StatusWindowService] 自动重试取消：冷却期间守护进程判定在游戏中');
        _finalizeOnce(_handleAlreadyInGame);
        return;
      }
    }

    _scheduleNextFetch(serverAddress);

    LogService.i('[StatusWindowService] 自动重试：确认游戏在主菜单，开始重新挤服');
  }

  /// 处理"游戏已在服务器中"的情况（自动重试发现用户已经进入游戏）
  ///
  /// 应通过 [_finalizeOnce] 调用，幂等且只执行一次。
  void _handleAlreadyInGame() {
    // 卸载守护进程
    _detachQueueGuard();

    // 发送挤服成功消息并断开 WebSocket
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersSuccess());
    usersBloc.add(const QueueUsersDisconnect());

    _isQueueRunning = false;
    _isThreadsRunning = false;
    _activeThreadIds.clear();

    _updateState(
      _state.copyWith(
        type: OperationType.none,
        status: OperationStatus.success,
        message: _Messages.connectSuccess,
      ),
    );
    _updateWindow(
      state: 'success',
      message: _Messages.connectSuccess,
      autoDismissSeconds: 5,
    );
    _audioService.playQueueSuccessSound();
    _scheduleClose(seconds: 5);
  }

  Future<void> _updateWindow({
    String? state,
    String? message,
    int? currentPlayers,
    int? targetPlayers,
    List<String>? threadStatuses,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    int? autoDismissSeconds,
  }) async {
    if (_windowId == null) return;

    // 暖服浮窗刚创建时子进程还在初始化 IPC handler，跳过推送。
    // 初始状态已通过 config.extra 传递给子窗口，不需要立即再推一次。
    // 仅对暖服类型生效（挤服的 _updateWindow 调用时机不会触发此问题）。
    if (_state.type == OperationType.warming &&
        _windowCreatedAt != null &&
        DateTime.now().difference(_windowCreatedAt!) <
            const Duration(seconds: 3)) {
      return;
    }

    final stateObj = this.state;
    final finalTargetPlayers = targetPlayers ??
        (stateObj.type == OperationType.queueing
            ? stateObj.queueConfig.targetPlayers
            : stateObj.type == OperationType.warming
                ? stateObj.warmupTargetPlayers
                : null);

    final success = await _windowService.sendStateUpdate(
      _windowId!,
      state: state ??
          (stateObj.type == OperationType.queueing
              ? 'queueing'
              : stateObj.type == OperationType.warming
                  ? 'warming'
                  : 'connecting'),
      message: message ?? stateObj.message,
      currentPlayers: currentPlayers ?? stateObj.serverInfo?.players,
      targetPlayers: finalTargetPlayers,
      threadStatuses:
          threadStatuses ?? stateObj.threadStatuses.map((s) => s.name).toList(),
      mapName: mapName ?? stateObj.serverInfo?.map,
      mapNameCn: mapNameCn ?? stateObj.mapInfo?.mapLabel,
      mapBackground: mapBackground ?? stateObj.mapInfo?.mapUrl,
      autoDismissSeconds: autoDismissSeconds,
    );

    // 如果发送失败且窗口已不在活跃列表中，清理 _windowId
    // 这样后续的 _showWindow 调用能正确创建新窗口
    if (!success && _windowId != null && !_windowService.isWindowActive(_windowId!)) {
      LogService.d('[StatusWindowService] Window $_windowId is no longer active, clearing reference');
      _windowId = null;
    }
  }

  /// 等待游戏状态稳定（变为 inGame 或 mainMenu）
  ///
  /// 返回最终稳定的状态，超时返回 null
  Future<GameState?> _waitForGameStateSettled({
    Duration maxWait = const Duration(seconds: 30),
  }) async {
    final completer = Completer<GameState?>();
    StreamSubscription<ConsoleLogState>? subscription;
    Timer? timeoutTimer;

    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
    }

    timeoutTimer = Timer(maxWait, () {
      cleanup();
      if (!completer.isCompleted) {
        LogService.w('[StatusWindowService] 等待游戏状态稳定超时');
        completer.complete(null);
      }
    });

    subscription = _consoleLogService.stateStream.listen((state) {
      if (state.state == GameState.inGame) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(GameState.inGame);
        }
      } else if (state.state == GameState.mainMenu) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(GameState.mainMenu);
        }
      } else if (state.state == GameState.serverFull ||
          state.state == GameState.failed) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(state.state);
        }
      }
    });

    // 立即检查当前状态
    final current = _consoleLogService.currentState.state;
    if (current == GameState.inGame ||
        current == GameState.mainMenu ||
        current == GameState.serverFull ||
        current == GameState.failed) {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(current);
      }
    }

    return completer.future;
  }

  /// 调度下次获取
  void _scheduleNextFetch(String serverAddress) {
    if (!_isQueueRunning) return;

    // 防止重复启动线程
    if (_isThreadsRunning) return;

    _isThreadsRunning = true;
    _activeThreadIds.clear();

    final effectiveThreadCount = _state.queueConfig.effectiveThreadCount;
    // 单线程模式下不需要错峰启动；多线程模式保留 500ms 错峰
    final isSingleThread = !_state.queueConfig.multiThreadEnabled;

    for (int i = 0; i < effectiveThreadCount; i++) {
      final threadIndex = i;
      final threadId = DateTime.now().millisecondsSinceEpoch + i;
      _activeThreadIds.add(threadId);
      final delay = isSingleThread ? 0 : i * 500;

      Future.delayed(Duration(milliseconds: delay), () {
        if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
          _startThreadWorkLoop(threadIndex, threadId, serverAddress);
        }
      });
    }
  }

  /// 线程工作循环
  Future<void> _startThreadWorkLoop(
    int threadIndex,
    int threadId,
    String serverAddress,
  ) async {
    if (!_isQueueRunning || !_activeThreadIds.contains(threadId)) return;

    try {
      _updateThreadStatus(threadIndex, ThreadStatus.requesting);

      await _fetchServerInfo(serverAddress);

      _updateThreadStatus(threadIndex, ThreadStatus.success);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_state.threadStatuses.length > threadIndex &&
            _state.threadStatuses[threadIndex] == ThreadStatus.success) {
          _updateThreadStatus(threadIndex, ThreadStatus.idle);
        }
      });
    } catch (e) {
      _updateThreadStatus(threadIndex, ThreadStatus.failed);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_state.threadStatuses.length > threadIndex &&
            _state.threadStatuses[threadIndex] == ThreadStatus.failed) {
          _updateThreadStatus(threadIndex, ThreadStatus.idle);
        }
      });
    }

    final nextInterval = _calculateNextInterval(threadIndex);

    if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
      Future.delayed(Duration(milliseconds: nextInterval), () {
        if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
          _startThreadWorkLoop(threadIndex, threadId, serverAddress);
        }
      });
    }
  }

  /// 更新线程状态
  void _updateThreadStatus(int index, ThreadStatus status) {
    if (index >= 0 && index < _state.threadStatuses.length) {
      final newStatuses = List<ThreadStatus>.from(_state.threadStatuses);
      newStatuses[index] = status;
      _updateState(_state.copyWith(threadStatuses: newStatuses));

      // 更新窗口
      if (_windowId != null) {
        _updateWindow(threadStatuses: newStatuses.map((s) => s.name).toList());
      }
    }
  }

  /// 计算下次请求间隔
  int _calculateNextInterval(int threadIndex) {
    // 单线程模式：使用用户设置的固定秒数（1-6 秒），并 clamp
    if (!_state.queueConfig.multiThreadEnabled) {
      final seconds = _state.queueConfig.requestIntervalSeconds.clamp(1, 6);
      return seconds * 1000;
    }

    int baseInterval = max(600, 350);

    if (_consecutiveFailures > 15) {
      baseInterval = min((baseInterval * 1.6).toInt(), 1200);
    } else if (_consecutiveFailures > 10) {
      baseInterval = min((baseInterval * 1.3).toInt(), 1000);
    } else if (_consecutiveFailures > 5) {
      baseInterval = min((baseInterval * 1.1).toInt(), 800);
    }

    final threadOffset = threadIndex * 150;
    baseInterval = max(baseInterval - threadOffset, 350);

    if (_lastSuccessTime != null &&
        DateTime.now().difference(_lastSuccessTime!).inMilliseconds < 10000) {
      baseInterval = max((baseInterval * 0.8).toInt(), 350);
    }

    return max(min(baseInterval, 1200), 350);
  }

  // ==================== 窗口管理 ====================

  /// 显示窗口
  Future<void> _showWindow({
    required FloatingWindowType type,
    String? serverAddress,
    required String title,
    required String state,
    required String message,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    int? currentPlayers,
    int? targetPlayers,
    List<String>? threadStatuses,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }

    _cancelCloseTimer();

    // 如果窗口已存在且活跃，更新状态即可
    if (_windowId != null && _windowService.isWindowActive(_windowId!)) {
      await _updateWindow(
        state: state,
        message: message,
        currentPlayers: currentPlayers,
        targetPlayers: targetPlayers,
        threadStatuses: threadStatuses,
        mapName: mapName,
        mapNameCn: mapNameCn,
        mapBackground: mapBackground,
      );

      // sendStateUpdate 在 CHANNEL_UNREGISTERED 时会把窗口从 _activeWindows 移除，
      // 但不会清理 _windowId。这里重新检查：如果窗口已不活跃，置空 _windowId 并继续创建新窗口。
      if (_windowId != null && _windowService.isWindowActive(_windowId!)) {
        return;
      }
      // 窗口已失效，继续往下创建新窗口
    }

    // 窗口不存在或已关闭，清理并创建新窗口
    _windowId = null;

    try {
      _windowId = await _windowService.openWindow(
        FloatingWindowConfig(
          type: type,
          serverAddress: serverAddress,
          title: title,
          extra: {
            'state': state,
            'message': message,
            'currentPlayers': currentPlayers,
            'targetPlayers': targetPlayers,
            'threadStatuses': threadStatuses,
            'mapName': mapName,
            'mapNameCn': mapNameCn,
            'mapBackground': mapBackground,
          },
        ),
      );
      _windowCreatedAt = DateTime.now();
      LogService.d('[StatusWindowService] Window created: $_windowId');
    } catch (e) {
      LogService.e('[StatusWindowService] Create window error', e);
    }
  }

  /// 延迟关闭窗口
  /// 作为备份机制，比浮窗自己的倒计时多2秒
  void _scheduleClose({int seconds = 3}) {
    _cancelCloseTimer();
    // 增加1秒作为备份，让浮窗自己的倒计时先尝试关闭
    final backupSeconds = seconds + 1;
    _closeTimer = Timer(Duration(seconds: backupSeconds), () async {
      await closeWindow();
      reset();
    });
  }

  /// 取消关闭定时器
  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  /// 销毁服务
  Future<void> dispose() async {
    _isQueueRunning = false;
    _activeThreadIds.clear();

    // 卸载守护进程
    _detachQueueGuard();

    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());

    final warmupUsersBloc = WarmupUsersBloc.instance;
    warmupUsersBloc.add(const WarmupUsersLeave());
    warmupUsersBloc.add(const WarmupUsersDisconnect());

    _gameStatusSubscription?.cancel();
    _cancelCloseTimer();
    await closeWindow();
    _stateController.close();
  }
}
