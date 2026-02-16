import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../api/server_api.dart';
import '../bloc/queue_users/queue_users_bloc.dart';
import '../bloc/queue_users/queue_users_event.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import 'audio_service.dart';
import 'console_log_service.dart';
import 'floating_window_service.dart';
import 'game_launcher_service.dart';
import 'game_status_service.dart';
import 'source_server_service.dart';

/// 操作类型
enum OperationType {
  none,       // 无操作
  launching,  // 启动游戏
  queueing,   // 挤服中
  connecting, // 连接服务器
}

/// 操作状态
enum OperationStatus {
  idle,       // 空闲
  running,    // 运行中
  success,    // 成功
  failed,     // 失败
  paused,     // 已暂停
  serverFull, // 服务器已满
}

/// 线程状态
enum ThreadStatus {
  idle,
  requesting,
  success,
  failed,
}

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

  const QueueConfig({
    this.targetPlayers = 60,
    this.threadCount = 3,
    this.enableAutoRetry = false,
    this.isDonator = false,
  });

  QueueConfig copyWith({
    int? targetPlayers,
    int? threadCount,
    bool? enableAutoRetry,
    bool? isDonator,
  }) {
    return QueueConfig(
      targetPlayers: targetPlayers ?? this.targetPlayers,
      threadCount: threadCount ?? this.threadCount,
      enableAutoRetry: enableAutoRetry ?? this.enableAutoRetry,
      isDonator: isDonator ?? this.isDonator,
    );
  }
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
  });

  OperationState copyWith({
    OperationType? type,
    OperationStatus? status,
    String? message,
    String? serverAddress,
    String? serverName,
    ServerInfo? serverInfo,
    MapData? mapInfo,
    QueueConfig? queueConfig,
    List<ThreadStatus>? threadStatuses,
    bool? isGameRunning,
    String? error,
    bool? needCsgoLegacy,
    bool? needManualLaunch,
  }) {
    return OperationState(
      type: type ?? this.type,
      status: status ?? this.status,
      message: message,
      serverAddress: serverAddress ?? this.serverAddress,
      serverName: serverName ?? this.serverName,
      serverInfo: serverInfo ?? this.serverInfo,
      mapInfo: mapInfo ?? this.mapInfo,
      queueConfig: queueConfig ?? this.queueConfig,
      threadStatuses: threadStatuses ?? this.threadStatuses,
      isGameRunning: isGameRunning ?? this.isGameRunning,
      error: error,
      needCsgoLegacy: needCsgoLegacy ?? this.needCsgoLegacy,
      needManualLaunch: needManualLaunch ?? this.needManualLaunch,
    );
  }
  
  /// 是否正在挤服
  bool get isQueueing => type == OperationType.queueing && status == OperationStatus.running;
  
  /// 是否正在连接
  bool get isConnecting => type == OperationType.connecting || 
      (type == OperationType.queueing && status == OperationStatus.running && message?.contains('连接') == true);
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
  bool _isThreadsRunning = false;        // 防止重复启动线程
  bool _isTriggeredConnection = false;   // 防止重复触发连接
  bool _isFetching = false;              // 防止并发请求
  bool _isQueueWindowOpen = false;       // 挤服窗口是否打开
  final Set<int> _activeThreadIds = {};
  String? _lastMapName;
  int _consecutiveFailures = 0;
  double _backoffMultiplier = 1.0;
  DateTime? _lastSuccessTime;
  
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
  
  /// 设置挤服窗口打开状态
  void setQueueWindowOpen(bool isOpen) {
    if (_isQueueWindowOpen != isOpen) {
      _isQueueWindowOpen = isOpen;
      // 通知监听者状态变化
      _stateController.add(_state);
    }
  }
  
  /// 当前操作类型
  OperationType get currentType => _state.type;

  // ==================== 公开方法 ====================
  
  /// 初始化服务（应用启动时调用）
  void initialize() {
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = _gameStatusService.statusStream.listen(_onGameStatusChanged);
    _updateState(_state.copyWith(isGameRunning: _gameStatusService.isGameRunning));
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
  }) async {
    // 检查游戏路径是否已配置
    final hasGamePath = await _gameLauncher.hasGamePath();
    if (!hasGamePath) {
      _updateState(OperationState(
        type: OperationType.none,
        status: OperationStatus.failed,
        message: '请先在设置中配置游戏路径',
        serverAddress: serverAddress,
        serverName: serverName,
        isGameRunning: false,
      ));
      return false;
    }
    
    // 检查是否为 CSGO 服务器
    final isCsgo = gameType != null && 
        (gameType.toLowerCase().contains('csgo') || gameType.toLowerCase().contains('cs:go'));
    
    if (isCsgo) {
      // CSGO 服务器无法通过 Steam URL 自动启动，需要手动启动
      _updateState(OperationState(
        type: OperationType.none,
        status: OperationStatus.failed,
        message: '此服务器需要手动启动 CSGO',
        serverAddress: serverAddress,
        serverName: serverName,
        isGameRunning: false,
        needManualLaunch: true,
      ));
      return false;
    }
    
    // 检查是否有其他操作正在进行
    if (_state.type != OperationType.none && _state.status == OperationStatus.running) {
      LogService.w('[StatusWindowService] 有其他操作正在进行');
      return false;
    }
    
    _cancelCloseTimer();
    
    // 更新状态
    _updateState(OperationState(
      type: OperationType.launching,
      status: OperationStatus.running,
      message: _Messages.launching,
      serverAddress: serverAddress,
      serverName: serverName,
    ));
    
    // 先检查游戏是否已在运行
    final alreadyRunning = await _gameLauncher.isCS2Running();
    if (alreadyRunning) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.success,
        message: _Messages.gameAlreadyRunning,
        isGameRunning: true,
      ));
      return true;
    }
    
    // 检测 Steam 状态是否卡住（Steam 认为游戏在运行但进程不存在）
    final steamStuck = await _gameLauncher.isSteamStatusStuck();
    if (steamStuck) {
      _updateState(_state.copyWith(
        type: OperationType.none,
        status: OperationStatus.failed,
        message: _Messages.launchSteamStuck,
      ));
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
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: result.error ?? _Messages.launchFailed,
      ));
      await _updateWindow(state: 'failed', message: result.error ?? _Messages.launchFailed, autoDismissSeconds: 3);
      _scheduleClose(seconds: 3);
      return false;
    }
    
    // 游戏已在运行（二次检查）
    if (result.alreadyRunning) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.success,
        message: _Messages.gameAlreadyRunning,
        isGameRunning: true,
      ));
      await _updateWindow(state: 'success', message: _Messages.gameAlreadyRunning, autoDismissSeconds: 3);
      _scheduleClose(seconds: 3);
      return true;
    }
    
    // 等待游戏加载
    final loaded = await _waitForGameLoad();
    
    if (loaded) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型（如果没有后续连接）
        status: OperationStatus.success,
        message: _Messages.launchSuccess,
        isGameRunning: true,
      ));
      await _updateWindow(state: 'success', message: _Messages.launchSuccess, autoDismissSeconds: 5);
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
        );
      }
    } else {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: _Messages.launchTimeout,
      ));
      await _updateWindow(state: 'failed', message: _Messages.launchTimeout, autoDismissSeconds: 3);
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
  }) async {
    // 检查游戏路径是否已配置
    final hasGamePath = await _gameLauncher.hasGamePath();
    if (!hasGamePath) {
      _updateState(OperationState(
        type: OperationType.none,
        status: OperationStatus.failed,
        message: '请先在设置中配置游戏路径',
        serverAddress: serverAddress,
        serverName: serverName,
        isGameRunning: false,
      ));
      return false;
    }
    
    // 检查游戏是否运行
    final gameRunning = await _gameLauncher.isCS2Running();
    
    if (!gameRunning) {
      // 游戏未运行，判断是否为 CSGO 服务器
      final isCsgo = gameType != null && 
          (gameType.toLowerCase().contains('csgo') || gameType.toLowerCase().contains('cs:go'));
      
      if (isCsgo) {
        // CSGO 服务器无法自动启动，直接调用 connectToServer 让它返回错误
        final result = await _gameLauncher.connectToServer(serverAddress, gameType: gameType);
        
        // 处理 CSGO 相关错误
        if (!result.success) {
          _updateState(OperationState(
            type: OperationType.none,
            status: OperationStatus.failed,
            message: result.error,
            serverAddress: serverAddress,
            serverName: serverName,
            isGameRunning: false,
            needCsgoLegacy: result.needCsgoLegacy,
            needManualLaunch: result.needManualLaunch,
          ));
        }
        return result.success;
      }
      
      // CS2 服务器，先启动游戏
      return await launchGame(
        serverAddress: serverAddress,
        serverName: serverName,
        mapName: mapName,
        mapNameCn: mapNameCn,
        mapBackground: mapBackground,
        gameType: gameType,
      );
    }
    
    // 检查是否可监控
    final canMonitor = _gameStatusService.isMonitorable;
    
    if (!canMonitor) {
      // 不可监控时，再次确认游戏是否运行
      final stillRunning = await _gameLauncher.isCS2Running();
      if (!stillRunning) {
        _updateState(OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: '游戏已关闭，请重新启动',
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: false,
        ));
        return false;
      }
      
      // 不可监控，直接发送连接命令
      final result = await _gameLauncher.connectToServer(serverAddress, gameType: gameType);
      
      // 检查是否需要安装 CSGO Legacy 或手动启动
      if (!result.success) {
        _updateState(OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: result.error,
          serverAddress: serverAddress,
          serverName: serverName,
          isGameRunning: true,
          needCsgoLegacy: result.needCsgoLegacy,
          needManualLaunch: result.needManualLaunch,
        ));
        return false;
      }
      
      if (result.success && playSuccessSound) {
        _audioService.playQueueSuccessSound();
      }
      return result.success;
    }
    
    _cancelCloseTimer();
    
    // 更新状态
    _updateState(OperationState(
      type: OperationType.connecting,
      status: OperationStatus.running,
      message: _Messages.connecting,
      serverAddress: serverAddress,
      serverName: serverName,
      isGameRunning: true,
    ));
    
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
    final connectResult = await _gameLauncher.connectToServer(serverAddress, gameType: gameType);
    if (!connectResult.success) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: connectResult.error ?? _Messages.connectFailed,
        needCsgoLegacy: connectResult.needCsgoLegacy,
        needManualLaunch: connectResult.needManualLaunch,
      ));
      await _updateWindow(state: 'failed', message: connectResult.error ?? _Messages.connectFailed, autoDismissSeconds: 3);
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
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.success,
        message: _Messages.connectSuccess,
      ));
      await _updateWindow(state: 'success', message: _Messages.connectSuccess, autoDismissSeconds: 5);
      if (playSuccessSound) {
        _audioService.playQueueSuccessSound();
      }
      _scheduleClose(seconds: 5);
      return true;
    } else if (monitorResult.state == GameState.serverFull) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.serverFull,
        message: _Messages.serverFull,
      ));
      await _updateWindow(state: 'serverFull', message: _Messages.serverFull, autoDismissSeconds: 8);
      _scheduleClose(seconds: 8);  // 失败状态使用8秒倒计时
      return false;
    } else {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: monitorResult.message ?? _Messages.connectFailed,
      ));
      await _updateWindow(state: 'failed', message: monitorResult.message ?? _Messages.connectFailed, autoDismissSeconds: 8);
      _scheduleClose(seconds: 8);  // 失败状态使用8秒倒计时
      return false;
    }
  }

  /// 开始挤服
  Future<bool> startQueue({
    required String serverAddress,
    QueueConfig? config,
    ServerInfo? serverInfo,
    MapData? mapInfo,
  }) async {
    // 检查游戏路径是否已配置
    final hasGamePath = await _gameLauncher.hasGamePath();
    if (!hasGamePath) {
      _updateState(OperationState(
        type: OperationType.none,
        status: OperationStatus.failed,
        message: '请先在设置中配置游戏路径',
        serverAddress: serverAddress,
        isGameRunning: false,
      ));
      return false;
    }
    
    // 检查游戏是否运行
    if (!_gameStatusService.isGameRunning) {
      _updateState(_state.copyWith(error: _Messages.gameNotRunning));
      return false;
    }
    
    // 如果是 CSGO 服务器，额外检查 CSGO 是否安装和运行
    final gameType = serverInfo?.gameType;
    if (gameType != null && (gameType.toLowerCase().contains('csgo') || gameType.toLowerCase().contains('cs:go'))) {
      final isInstalled = await _gameLauncher.isCsgoLegacyInstalled();
      if (!isInstalled) {
        _updateState(OperationState(
          type: OperationType.none,
          status: OperationStatus.failed,
          message: '此服务器需要 CSGO 客户端',
          serverAddress: serverAddress,
          isGameRunning: true,
          needCsgoLegacy: true,
        ));
        return false;
      }
      
      // 注意：这里不需要检查 CSGO 是否运行，因为前面已经检查了 isGameRunning
      // isGameRunning 会检测 csgo.exe 和 cs2.exe
    }
    
    // 检查是否有其他操作
    if (_state.type == OperationType.connecting && _state.status == OperationStatus.running) {
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
    final threadStatuses = List<ThreadStatus>.filled(finalConfig.threadCount, ThreadStatus.idle);
    
    // 更新状态
    _updateState(OperationState(
      type: OperationType.queueing,
      status: OperationStatus.running,
      message: _Messages.queueing,
      serverAddress: serverAddress,
      serverName: serverInfo?.hostName ?? serverAddress,
      serverInfo: serverInfo,
      mapInfo: mapInfo,
      queueConfig: finalConfig,
      threadStatuses: threadStatuses,
      isGameRunning: true,
    ));
    
    // 重置挤服状态
    _isQueueRunning = true;
    _isThreadsRunning = false;
    _isTriggeredConnection = false;
    _isFetching = false;
    _activeThreadIds.clear();
    _consecutiveFailures = 0;
    _backoffMultiplier = 1.0;
    _lastSuccessTime = null;
    
    // 创建窗口
    await _showWindow(
      type: FloatingWindowType.queue,
      serverAddress: serverAddress,
      title: serverInfo?.hostName ?? serverAddress,
      state: 'queueing',
      message: _Messages.queueing,
      mapName: serverInfo?.map,
      mapNameCn: mapInfo?.mapLabel,
      mapBackground: mapInfo?.mapUrl,
      currentPlayers: serverInfo?.players,
      targetPlayers: finalConfig.targetPlayers,
      threadStatuses: threadStatuses.map((s) => s.name).toList(),
    );
    
    // 获取初始服务器信息
    await _fetchServerInfo(serverAddress);
    
    // 开始多线程请求
    if (_isQueueRunning) {
      _scheduleNextFetch(serverAddress);
    }
    
    LogService.d('[StatusWindowService] 挤服已开始: ${finalConfig.threadCount}个线程, 自动重试=${finalConfig.enableAutoRetry}');
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
    
    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());
    
    _updateState(_state.copyWith(
      type: OperationType.none,  // 重置操作类型
      status: OperationStatus.paused,
      message: _Messages.queuePaused,
    ));
    
    _updateWindow(state: 'paused', message: _Messages.queuePaused, autoDismissSeconds: 1);
    _scheduleClose(seconds: 1);
    
    LogService.d('[StatusWindowService] 挤服已暂停');
  }
  
  /// 更新挤服配置
  void updateQueueConfig(QueueConfig config) {
    if (_state.type != OperationType.queueing) return;
    
    _updateState(_state.copyWith(queueConfig: config));
    
    // 更新线程状态数组大小
    if (config.threadCount != _state.threadStatuses.length) {
      final newStatuses = List<ThreadStatus>.filled(config.threadCount, ThreadStatus.idle);
      _updateState(_state.copyWith(threadStatuses: newStatuses));
    }
  }
  
  /// 设置目标人数
  void setTargetPlayers(int targetPlayers) {
    if (_state.type != OperationType.queueing) return;
    _updateState(_state.copyWith(
      queueConfig: _state.queueConfig.copyWith(targetPlayers: targetPlayers),
    ));
  }
  
  /// 设置线程数量
  void setThreadCount(int threadCount) {
    if (_state.type != OperationType.queueing) return;
    final newStatuses = List<ThreadStatus>.filled(threadCount, ThreadStatus.idle);
    _updateState(_state.copyWith(
      queueConfig: _state.queueConfig.copyWith(threadCount: threadCount),
      threadStatuses: newStatuses,
    ));
  }
  
  /// 设置自动重试
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
    
    _updateState(_state.copyWith(
      queueConfig: _state.queueConfig.copyWith(enableAutoRetry: enable),
    ));
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
    
    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());
    
    _updateState(_state.copyWith(
      type: OperationType.none,  // 重置操作类型
      status: OperationStatus.paused,
      message: _Messages.cancelled,
    ));
    
    _updateWindow(state: 'paused', message: _Messages.cancelled, autoDismissSeconds: 2);
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
    
    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());
    
    _updateState(OperationState(
      isGameRunning: _gameStatusService.isGameRunning,
    ));
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
      LogService.d('[StatusWindowService] Floating window closed notification received: $windowId');
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
      
      // 断开 WebSocket 连接
      final usersBloc = QueueUsersBloc.instance;
      usersBloc.add(const QueueUsersLeave());
      usersBloc.add(const QueueUsersDisconnect());
      
      // 取消日志监控
      _consoleLogService.cancelConnectionMonitor();
      
      // 禁用自动重试
      if (_state.queueConfig.enableAutoRetry) {
        _updateState(_state.copyWith(
          queueConfig: _state.queueConfig.copyWith(enableAutoRetry: false),
        ));
      }
      
      // 如果有正在进行的操作，标记为失败并关闭窗口
      if (_state.type != OperationType.none && _state.status == OperationStatus.running) {
        _updateState(_state.copyWith(
          type: OperationType.none,  // 重置操作类型
          status: OperationStatus.failed,
          message: _Messages.gameClosed,
        ));
        _updateWindow(state: 'failed', message: _Messages.gameClosed, autoDismissSeconds: 3);
        _scheduleClose(seconds: 3);
      }
    }
    
    // 游戏启动但不可监控时，禁用自动重试
    if (event.isRunning && !event.isMonitorable && _state.queueConfig.enableAutoRetry) {
      _updateState(_state.copyWith(
        queueConfig: _state.queueConfig.copyWith(enableAutoRetry: false),
      ));
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
          mapName: consoleState.mapName.isNotEmpty ? consoleState.mapName : mapName,
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
      
      final sourceInfo = await SourceServerService.getServerInfo(ip, port, timeout: 5000);
      
      if (sourceInfo != null) {
        final serverInfo = ServerInfo(
          hostName: sourceInfo.name,
          map: sourceInfo.map,
          players: sourceInfo.players,
          maxPlayers: sourceInfo.maxPlayers,
          pingLatency: sourceInfo.ping,
          gameType: sourceInfo.gameType,
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
        
        _updateState(_state.copyWith(
          serverInfo: serverInfo,
          mapInfo: mapInfo,
          serverName: serverInfo.hostName,
          error: null,
        ));
        
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
    
    // 防止重复触发连接
    if (_isTriggeredConnection) return;
    
    final players = _state.serverInfo!.players ?? 0;
    final targetPlayers = _state.queueConfig.targetPlayers;
    
    if (players <= targetPlayers) {
      // 标记已触发连接，防止重复
      _isTriggeredConnection = true;
      _isQueueRunning = false;
      _isThreadsRunning = false;
      _activeThreadIds.clear();
      _connectForQueue(serverAddress);
    }
  }
  
  /// 挤服专用连接
  Future<void> _connectForQueue(String serverAddress) async {
    _updateState(_state.copyWith(
      status: OperationStatus.running,
      message: _Messages.connecting,
    ));
    
    await _updateWindow(state: 'connecting', message: _Messages.connecting);
    
    try {
      // 从状态中获取游戏类型
      final gameType = _state.serverInfo?.gameType;
      final result = await _gameLauncher.connectToServer(serverAddress, gameType: gameType);
      
      if (result.success) {
        final canMonitor = _gameStatusService.isMonitorable;
        
        if (canMonitor) {
          _updateState(_state.copyWith(message: _Messages.loading));
          await _updateWindow(state: 'loading', message: _Messages.loading);
          
          final connectionResult = await _monitorConnection(
            mapName: _state.serverInfo?.map,
            mapNameCn: _state.mapInfo?.mapLabel,
            mapBackground: _state.mapInfo?.mapUrl,
          );
          
          switch (connectionResult.state) {
            case GameState.inGame:
              // 发送挤服成功消息并断开 WebSocket
              final usersBloc = QueueUsersBloc.instance;
              usersBloc.add(const QueueUsersSuccess());
              usersBloc.add(const QueueUsersDisconnect());
              
              _updateState(_state.copyWith(
                type: OperationType.none,  // 重置操作类型
                status: OperationStatus.success,
                message: _Messages.connectSuccess,
              ));
              await _updateWindow(state: 'success', message: _Messages.connectSuccess, autoDismissSeconds: 5);
              _audioService.playQueueSuccessSound();
              _scheduleClose(seconds: 5);
              break;
              
            case GameState.serverFull:
              _handleQueueConnectionFailure(_Messages.serverFull, serverAddress);
              break;
              
            case GameState.failed:
              _handleQueueConnectionFailure(connectionResult.message ?? _Messages.connectFailed, serverAddress);
              break;
              
            default:
              _handleQueueConnectionFailure(connectionResult.message ?? _Messages.connectFailed, serverAddress);
              break;
          }
        } else {
          // 不可监控，发送成功消息并断开 WebSocket
          final usersBloc = QueueUsersBloc.instance;
          usersBloc.add(const QueueUsersSuccess());
          usersBloc.add(const QueueUsersDisconnect());
          
          _updateState(_state.copyWith(
            type: OperationType.none,  // 重置操作类型
            status: OperationStatus.success,
            message: _Messages.commandSent,
          ));
          await _updateWindow(state: 'success', message: _Messages.commandSent, autoDismissSeconds: 5);
          _audioService.playQueueSuccessSound();
          _scheduleClose(seconds: 5);
        }
      } else {
        _handleQueueConnectionFailure(result.error ?? _Messages.connectFailed, serverAddress);
      }
    } catch (e) {
      _handleQueueConnectionFailure(_Messages.networkError, serverAddress);
    }
  }
  
  /// 处理挤服连接失败
  void _handleQueueConnectionFailure(String reason, String serverAddress) {
    LogService.w('[StatusWindowService] 连接失败: $reason');
    
    // 保存当前的自动重试状态（在检查前保存，避免状态被意外修改）
    final enableAutoRetry = _state.queueConfig.enableAutoRetry;
    LogService.d('[StatusWindowService] 当前状态: type=${_state.type}, enableAutoRetry=$enableAutoRetry');
    
    if (enableAutoRetry) {
      LogService.i('[StatusWindowService] 自动重试已启用，准备重新挤服...');
      
      // 自动重试 - 直接显示重试消息，不发送终态避免触发浮窗倒计时
      final retryMessage = reason.contains('服务器已满') 
          ? _Messages.queueRetryServerFull
          : reason.contains('超时')
              ? _Messages.queueRetryTimeout
              : _Messages.queueRetryFailed;
      
      // 保持 queueing 类型和 enableAutoRetry 状态
      _updateState(_state.copyWith(
        type: OperationType.queueing,  // 保持挤服类型
        status: OperationStatus.running,
        message: retryMessage,
        queueConfig: _state.queueConfig.copyWith(enableAutoRetry: true),  // 确保保持自动重试状态
      ));
      // 发送 queueing 状态而不是终态，避免触发浮窗倒计时关闭
      _updateWindow(state: 'queueing', message: retryMessage);
      
      // 根据失败原因调整延迟时间
      final retryDelay = reason.contains('服务器已满') 
          ? const Duration(milliseconds: 500)
          : reason.contains('超时')
              ? const Duration(seconds: 1)
              : const Duration(milliseconds: 500);
      
      // 延迟后重新开始挤服
      Future.delayed(retryDelay, () {
        // 再次检查状态，确保仍然需要重试
        if (_state.type == OperationType.queueing && _state.queueConfig.enableAutoRetry) {
          // 重置状态标志
          _isTriggeredConnection = false;
          _isThreadsRunning = false;
          _isQueueRunning = true;
          
          _updateState(_state.copyWith(message: _Messages.queueing));
          _updateWindow(state: 'queueing', message: _Messages.queueing);
          _scheduleNextFetch(serverAddress);
          
          LogService.i('[StatusWindowService] 自动重试：重新开始挤服');
        } else {
          LogService.w('[StatusWindowService] 自动重试取消：type=${_state.type}, enableAutoRetry=${_state.queueConfig.enableAutoRetry}');
        }
      });
    } else {
      // 非自动重试模式，显示终态并关闭窗口
      String windowState;
      if (reason.contains('服务器已满')) {
        windowState = 'serverFull';
      } else {
        windowState = 'failed';
      }
      
      // 断开 WebSocket 连接
      final usersBloc = QueueUsersBloc.instance;
      usersBloc.add(const QueueUsersLeave());
      usersBloc.add(const QueueUsersDisconnect());
      
      LogService.i('[StatusWindowService] 自动重试未启用，关闭窗口');
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: reason.contains('服务器已满') ? OperationStatus.serverFull : OperationStatus.failed,
        message: reason,
      ));
      _updateWindow(state: windowState, message: reason, autoDismissSeconds: 3);
      _scheduleClose(seconds: 3);
    }
  }

  /// 调度下次获取
  void _scheduleNextFetch(String serverAddress) {
    if (!_isQueueRunning) return;
    
    // 防止重复启动线程
    if (_isThreadsRunning) return;
    
    _isThreadsRunning = true;
    _activeThreadIds.clear();
    
    for (int i = 0; i < _state.queueConfig.threadCount; i++) {
      final threadIndex = i;
      final threadId = DateTime.now().millisecondsSinceEpoch + i;
      _activeThreadIds.add(threadId);
      final delay = i * 500;
      
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
          _startThreadWorkLoop(threadIndex, threadId, serverAddress);
        }
      });
    }
  }
  
  /// 线程工作循环
  Future<void> _startThreadWorkLoop(int threadIndex, int threadId, String serverAddress) async {
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
      return;
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
      LogService.d('[StatusWindowService] Window created: $_windowId');
    } catch (e) {
      LogService.e('[StatusWindowService] Create window error', e);
    }
  }
  
  /// 更新窗口
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
    
    // 使用地图信息
    final effectiveMapNameCn = mapNameCn ?? _state.mapInfo?.mapLabel;
    final effectiveMapBackground = mapBackground ?? _state.mapInfo?.mapUrl;
    
    final success = await _windowService.sendStateUpdate(
      _windowId!,
      state: state ?? _getWindowState(),
      message: message ?? _state.message ?? '',
      currentPlayers: currentPlayers ?? _state.serverInfo?.players,
      targetPlayers: targetPlayers ?? _state.queueConfig.targetPlayers,
      threadStatuses: threadStatuses ?? _state.threadStatuses.map((s) => s.name).toList(),
      mapName: mapName ?? _state.serverInfo?.map,
      mapNameCn: effectiveMapNameCn,
      mapBackground: effectiveMapBackground,
      autoDismissSeconds: autoDismissSeconds,
    );
    
    // 如果发送失败（窗口可能已关闭），清理windowId
    if (!success && !_windowService.isWindowActive(_windowId!)) {
      LogService.w('[StatusWindowService] Window $_windowId no longer active, clearing reference');
      _windowId = null;
    }
  }
  
  /// 获取窗口状态字符串
  String _getWindowState() {
    switch (_state.status) {
      case OperationStatus.success:
        return 'success';
      case OperationStatus.failed:
        return 'failed';
      case OperationStatus.serverFull:
        return 'serverFull';
      case OperationStatus.paused:
        return 'paused';
      case OperationStatus.running:
        switch (_state.type) {
          case OperationType.launching:
            return 'launching';
          case OperationType.queueing:
            return 'queueing';
          case OperationType.connecting:
            return 'connecting';
          default:
            return 'idle';
        }
      default:
        return 'idle';
    }
  }
  
  /// 延迟关闭窗口
  /// 作为备份机制，比浮窗自己的倒计时多2秒
  void _scheduleClose({int seconds = 3}) {
    _cancelCloseTimer();
    // 增加2秒作为备份，让浮窗自己的倒计时先尝试关闭
    final backupSeconds = seconds + 2;
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
    
    // 断开 WebSocket 连接
    final usersBloc = QueueUsersBloc.instance;
    usersBloc.add(const QueueUsersLeave());
    usersBloc.add(const QueueUsersDisconnect());
    
    _gameStatusSubscription?.cancel();
    _cancelCloseTimer();
    await closeWindow();
    _stateController.close();
  }
}
