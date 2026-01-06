import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../api/server_api.dart';
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

/// 挤服配置
class QueueConfig {
  final int targetPlayers;
  final int threadCount;
  final bool enableAutoRetry;

  const QueueConfig({
    this.targetPlayers = 60,
    this.threadCount = 3,
    this.enableAutoRetry = false,
  });

  QueueConfig copyWith({
    int? targetPlayers,
    int? threadCount,
    bool? enableAutoRetry,
  }) {
    return QueueConfig(
      targetPlayers: targetPlayers ?? this.targetPlayers,
      threadCount: threadCount ?? this.threadCount,
      enableAutoRetry: enableAutoRetry ?? this.enableAutoRetry,
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
  }) async {
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
      message: '正在启动游戏...',
      serverAddress: serverAddress,
      serverName: serverName,
    ));
    
    // 先检查游戏是否已在运行
    final alreadyRunning = await _gameLauncher.isCS2Running();
    if (alreadyRunning) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.success,
        message: '游戏已在运行',
        isGameRunning: true,
      ));
      return true;
    }
    
    // 先创建窗口，再启动游戏
    // 启动游戏时不显示地图背景
    await _showWindow(
      type: FloatingWindowType.launch,
      title: serverName ?? '启动游戏',
      state: 'launching',
      message: '正在启动游戏...',
      // 启动游戏时不传递地图信息，不显示地图背景
    );
    
    // 执行启动
    final result = await _gameLauncher.launchCS2();
    
    if (!result.success) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: result.error ?? '启动失败',
      ));
      await _updateWindow(state: 'failed', message: result.error ?? '启动失败');
      _scheduleClose(seconds: 3);
      return false;
    }
    
    // 游戏已在运行（二次检查）
    if (result.alreadyRunning) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.success,
        message: '游戏已在运行',
        isGameRunning: true,
      ));
      await _updateWindow(state: 'success', message: '游戏已在运行');
      _scheduleClose(seconds: 3);
      return true;
    }
    
    // 等待游戏加载
    final loaded = await _waitForGameLoad();
    
    if (loaded) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型（如果没有后续连接）
        status: OperationStatus.success,
        message: '游戏启动成功',
        isGameRunning: true,
      ));
      await _updateWindow(state: 'success', message: '游戏启动成功');
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
        );
      }
    } else {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: '游戏加载超时',
      ));
      await _updateWindow(state: 'failed', message: '游戏加载超时');
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
  }) async {
    // 检查游戏是否运行
    final gameRunning = await _gameLauncher.isCS2Running();
    
    if (!gameRunning) {
      // 游戏未运行，先启动
      return await launchGame(
        serverAddress: serverAddress,
        serverName: serverName,
        mapName: mapName,
        mapNameCn: mapNameCn,
        mapBackground: mapBackground,
      );
    }
    
    // 检查是否可监控
    final canMonitor = _gameStatusService.isMonitorable;
    
    if (!canMonitor) {
      // 不可监控，直接发送连接命令
      final result = await _gameLauncher.connectToServer(serverAddress);
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
      message: '正在连接服务器...',
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
      message: '正在连接服务器...',
      mapName: mapName,
      mapNameCn: mapNameCn,
      mapBackground: mapBackground,
    );
    
    // 发送连接命令
    final connectResult = await _gameLauncher.connectToServer(serverAddress);
    if (!connectResult.success) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: connectResult.error ?? '连接失败',
      ));
      await _updateWindow(state: 'failed', message: connectResult.error ?? '连接失败');
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
        message: '成功进入游戏！',
      ));
      await _updateWindow(state: 'success', message: '成功进入游戏！');
      if (playSuccessSound) {
        _audioService.playQueueSuccessSound();
      }
      _scheduleClose(seconds: 5);
      return true;
    } else if (monitorResult.state == GameState.serverFull) {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.serverFull,
        message: '服务器已满',
      ));
      await _updateWindow(state: 'serverFull', message: '服务器已满');
      _scheduleClose(seconds: 3);
      return false;
    } else {
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: OperationStatus.failed,
        message: monitorResult.message ?? '连接失败',
      ));
      await _updateWindow(state: 'failed', message: monitorResult.message ?? '连接失败');
      _scheduleClose(seconds: 3);
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
    // 检查游戏是否运行
    if (!_gameStatusService.isGameRunning) {
      _updateState(_state.copyWith(error: '游戏未运行，请先启动游戏'));
      return false;
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
      message: '挤服中...',
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
      message: '挤服中...',
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
    
    _updateState(_state.copyWith(
      type: OperationType.none,  // 重置操作类型
      status: OperationStatus.paused,
      message: '已停止挤服',
    ));
    
    _updateWindow(state: 'paused', message: '已停止挤服');
    _scheduleClose(seconds: 3);
    
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
    
    _updateState(_state.copyWith(
      type: OperationType.none,  // 重置操作类型
      status: OperationStatus.paused,
      message: '已取消',
    ));
    
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
      LogService.w('[StatusWindowService] 游戏已关闭，停止所有操作');
      
      // 停止挤服
      _isQueueRunning = false;
      _isThreadsRunning = false;
      _isTriggeredConnection = false;
      _isFetching = false;
      _activeThreadIds.clear();
      
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
          message: '游戏已关闭',
        ));
        _updateWindow(state: 'failed', message: '游戏已关闭');
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
        switch (consoleState.state) {
          case GameState.connecting:
            windowState = 'connecting';
            break;
          case GameState.loading:
            windowState = 'loading';
            break;
          case GameState.inGame:
            windowState = 'success';
            break;
          case GameState.serverFull:
            windowState = 'serverFull';
            break;
          case GameState.failed:
            windowState = 'failed';
            break;
          default:
            windowState = 'connecting';
        }
        
        _updateState(_state.copyWith(message: consoleState.stateText));
        await _updateWindow(
          state: windowState,
          message: consoleState.stateText,
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
        LogService.w('[StatusWindowService] 网络不稳定，暂停挤服');
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
      message: '正在连接服务器...',
    ));
    
    await _updateWindow(state: 'connecting', message: '正在连接服务器...');
    
    try {
      final result = await _gameLauncher.connectToServer(serverAddress);
      
      if (result.success) {
        final canMonitor = _gameStatusService.isMonitorable;
        
        if (canMonitor) {
          _updateState(_state.copyWith(message: '正在进入游戏...'));
          await _updateWindow(state: 'loading', message: '正在进入游戏...');
          
          final connectionResult = await _monitorConnection(
            mapName: _state.serverInfo?.map,
            mapNameCn: _state.mapInfo?.mapLabel,
            mapBackground: _state.mapInfo?.mapUrl,
          );
          
          switch (connectionResult.state) {
            case GameState.inGame:
              _updateState(_state.copyWith(
                type: OperationType.none,  // 重置操作类型
                status: OperationStatus.success,
                message: '成功进入游戏！',
              ));
              await _updateWindow(state: 'success', message: '成功进入游戏！');
              _audioService.playQueueSuccessSound();
              _scheduleClose(seconds: 5);
              break;
              
            case GameState.serverFull:
              _handleQueueConnectionFailure('服务器已满', serverAddress);
              break;
              
            case GameState.failed:
              _handleQueueConnectionFailure(connectionResult.message ?? '连接失败', serverAddress);
              break;
              
            default:
              _handleQueueConnectionFailure(connectionResult.message ?? '连接超时', serverAddress);
              break;
          }
        } else {
          // 不可监控
          _updateState(_state.copyWith(
            type: OperationType.none,  // 重置操作类型
            status: OperationStatus.success,
            message: '加入命令已发送',
          ));
          await _updateWindow(state: 'success', message: '加入命令已发送');
          _audioService.playQueueSuccessSound();
          _scheduleClose(seconds: 5);
        }
      } else {
        _handleQueueConnectionFailure(result.error ?? '连接失败', serverAddress);
      }
    } catch (e) {
      _handleQueueConnectionFailure('连接异常: $e', serverAddress);
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
          ? '服务器已满，继续挤服...'
          : reason.contains('超时')
              ? '连接超时，继续挤服...'
              : '连接失败，继续挤服...';
      
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
          
          _updateState(_state.copyWith(message: '挤服中...'));
          _updateWindow(state: 'queueing', message: '挤服中...');
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
      
      LogService.i('[StatusWindowService] 自动重试未启用，关闭窗口');
      _updateState(_state.copyWith(
        type: OperationType.none,  // 重置操作类型
        status: reason.contains('服务器已满') ? OperationStatus.serverFull : OperationStatus.failed,
        message: reason,
      ));
      _updateWindow(state: windowState, message: reason);
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
    
    // 如果窗口已存在，更新状态
    if (_windowId != null) {
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
  }) async {
    if (_windowId == null) return;
    
    // 使用地图信息
    final effectiveMapNameCn = mapNameCn ?? _state.mapInfo?.mapLabel;
    final effectiveMapBackground = mapBackground ?? _state.mapInfo?.mapUrl;
    
    await _windowService.sendStateUpdate(
      _windowId!,
      state: state ?? _getWindowState(),
      message: message ?? _state.message ?? '',
      currentPlayers: currentPlayers ?? _state.serverInfo?.players,
      targetPlayers: targetPlayers ?? _state.queueConfig.targetPlayers,
      threadStatuses: threadStatuses ?? _state.threadStatuses.map((s) => s.name).toList(),
      mapName: mapName ?? _state.serverInfo?.map,
      mapNameCn: effectiveMapNameCn,
      mapBackground: effectiveMapBackground,
    );
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
    _gameStatusSubscription?.cancel();
    _cancelCloseTimer();
    await closeWindow();
    _stateController.close();
  }
}
