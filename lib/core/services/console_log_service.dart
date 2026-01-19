import 'dart:async';
import 'dart:io';

import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import 'game_launcher_service.dart';
import 'game_status_service.dart';

/// 游戏状态枚举 - 覆盖 CS2 完整生命周期
///
/// 状态流转图：
/// ```
/// [游戏未运行]
///     │
///     ▼ (启动游戏)
/// [gameStarting] ──► [mainMenu] ◄──────────────────┐
///                        │                          │
///                        ▼ (连接服务器)              │
///                   [connecting]                    │
///                        │                          │
///           ┌───────────┼───────────┐              │
///           ▼           ▼           ▼              │
///     [serverFull] [failed]   [loading]            │
///           │           │           │              │
///           └───────────┴───────────┤              │
///                                   ▼              │
///                              [inGame] ──────────►│
///                                   │   (断开连接)  │
///                                   ▼              │
///                            [pauseMenu] ─────────►│
/// ```
enum GameState {
  /// 未知状态（初始状态，监控未启动）
  unknown,

  /// 游戏正在启动中（检测到游戏进程，但还未完全加载）
  gameStarting,

  /// 游戏已启动，在主菜单
  mainMenu,

  /// 正在连接服务器（发送连接请求）
  connecting,

  /// 正在加载地图
  loading,

  /// 已进入游戏（在服务器中）
  inGame,

  /// 在暂停菜单中（ESC菜单）
  pauseMenu,

  /// 连接失败
  failed,

  /// 服务器满员
  serverFull,

  /// 重试连接中
  retrying,
}

/// 控制台日志状态
class ConsoleLogState {
  final bool available;
  final GameState state;
  final String stateText;
  final String serverAddress;
  final String mapName;
  final DateTime lastUpdate;
  final String? errorMessage;
  final bool condebugEnabled;

  const ConsoleLogState({
    this.available = false,
    this.state = GameState.unknown,
    this.stateText = '未启动',
    this.serverAddress = '',
    this.mapName = '',
    DateTime? lastUpdate,
    this.errorMessage,
    this.condebugEnabled = false,
  }) : lastUpdate = lastUpdate ?? const _DefaultDateTime();

  ConsoleLogState copyWith({
    bool? available,
    GameState? state,
    String? stateText,
    String? serverAddress,
    String? mapName,
    DateTime? lastUpdate,
    String? errorMessage,
    bool? condebugEnabled,
  }) {
    return ConsoleLogState(
      available: available ?? this.available,
      state: state ?? this.state,
      stateText: stateText ?? this.stateText,
      serverAddress: serverAddress ?? this.serverAddress,
      mapName: mapName ?? this.mapName,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      errorMessage: errorMessage,
      condebugEnabled: condebugEnabled ?? this.condebugEnabled,
    );
  }

  /// 便捷方法：是否在服务器中
  bool get isInServer => state == GameState.inGame || state == GameState.pauseMenu;

  /// 便捷方法：是否在主菜单
  bool get isInMainMenu => state == GameState.mainMenu;

  /// 便捷方法：是否正在连接
  bool get isConnecting =>
      state == GameState.connecting ||
      state == GameState.loading;

  /// 便捷方法：连接是否失败
  bool get isConnectionFailed =>
      state == GameState.failed || state == GameState.serverFull;
}

/// 默认日期时间（用于const构造函数）
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}

/// 控制台日志事件
class ConsoleLogEvent {
  final DateTime timestamp;
  final String type;
  final GameState state;
  final String message;
  final String details;

  ConsoleLogEvent({
    DateTime? timestamp,
    required this.type,
    required this.state,
    required this.message,
    required this.details,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 连接状态结果
class ConnectionStatusResult {
  final bool success;
  final GameState state;
  final String? message;

  const ConnectionStatusResult({
    required this.success,
    required this.state,
    this.message,
  });

  factory ConnectionStatusResult.connected() {
    return const ConnectionStatusResult(
      success: true,
      state: GameState.inGame,
      message: '已成功进入游戏',
    );
  }

  factory ConnectionStatusResult.failed(String message) {
    return ConnectionStatusResult(
      success: false,
      state: GameState.failed,
      message: message,
    );
  }

  factory ConnectionStatusResult.serverFull() {
    return const ConnectionStatusResult(
      success: false,
      state: GameState.serverFull,
      message: '服务器已满',
    );
  }

  factory ConnectionStatusResult.timeout() {
    return const ConnectionStatusResult(
      success: false,
      state: GameState.failed,
      message: '连接超时',
    );
  }

  factory ConnectionStatusResult.cancelled() {
    return const ConnectionStatusResult(
      success: false,
      state: GameState.mainMenu,
      message: '已取消',
    );
  }
}

/// 控制台日志监控服务 - 桌面端专属功能
/// 
/// 提供以下功能：
/// - console.log 文件监控
/// - 连接成功/失败检测
/// - 服务器满员检测
/// - 地图加载状态检测
class ConsoleLogService {
  final GameLauncherService _gameLauncher = GameLauncherService();
  
  // 状态管理
  ConsoleLogState _currentState = const ConsoleLogState();
  bool _isMonitoring = false;
  bool _isCancelled = false;
  
  // 日志文件监控
  int _lastFileSize = 0;
  int _lastReadPos = 0;
  String? _logFilePath;
  
  // 游戏路径检测缓存（避免重复检测）
  bool _gamePathDetectionAttempted = false;
  String? _cachedGamePath;
  
  // 连接目标追踪
  String _targetServer = '';
  bool _isLoopbackFallback = false;
  bool _connectTimedOut = false;
  bool _connectionPhaseFailed = false;
  bool _isInLoopbackMode = false;  // 是否处于 loopback 模式（主菜单背景服务器）
  
  // 事件历史
  final List<ConsoleLogEvent> _events = [];
  static const int _maxEvents = 100;
  
  // 定时器
  Timer? _monitorTimer;
  Timer? _checkTimer;
  
  // 游戏状态监听
  StreamSubscription<GameStatusEvent>? _gameStatusSubscription;
  
  // 状态流控制器
  final _stateController = StreamController<ConsoleLogState>.broadcast();
  
  /// 状态流
  Stream<ConsoleLogState> get stateStream => _stateController.stream;
  
  /// 当前状态
  ConsoleLogState get currentState => _currentState;
  
  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;
  
  /// 事件历史
  List<ConsoleLogEvent> get events => List.unmodifiable(_events);

  // ==================== 正则表达式 ====================
  
  // 连接相关
  final _regexConnecting = RegExp(r'\[Client\]\s+Sending connect to\s+(\S+)');
  final _regexConnected = RegExp(r"\[Client\].*Connected to\s+'?([^']+)'?");
  final _regexDisconnect = RegExp(r'[Dd]isconnect(ing|ed)?(\s+from server)?');
  final _regexRetrying = RegExp(r'[Rr]etrying|[Rr]econnecting');
  final _regexConnectFailed = RegExp(r'[Cc]onnection failed|[Ff]ailed to connect|[Uu]nable to connect');
  
  // 连接阶段断开检测（关键：在连接过程中被断开）
  final _regexDisconnectionDuringConnection = RegExp(r'Disconnection during connection phase');
  
  // 连接超时断开检测（在连接阶段因超时被断开）
  final _regexDisconnectedTimedout = RegExp(r'Disconnected from server:\s*NETWORK_DISCONNECT_TIMEDOUT');
  
  // 断开原因检测
  final _regexDisconnectLoopShutdown = RegExp(r'NETWORK_DISCONNECT_LOOPSHUTDOWN');
  
  // 用户主动断开连接检测
  final _regexUserDisconnect = RegExp(r'NETWORK_DISCONNECT_DISCONNECT_BY_USER');
  
  // 回到主菜单检测（从游戏或暂停菜单）
  final _regexBackToMainMenu = RegExp(
    r'ChangeGameUIState:.*(?:PAUSEMENU|INGAME)\s*->\s*CSGO_GAME_UI_STATE_MAINMENU'
  );
  
  // 进入游戏界面检测（从加载界面）
  final _regexLoadingToIngame = RegExp(
    r'ChangeGameUIState:.*LOADINGSCREEN\s*->\s*CSGO_GAME_UI_STATE_INGAME'
  );
  
  // 从主菜单直接进入游戏界面检测（异常情况，通常是连接失败后的错误状态）
  final _regexMainMenuToIngame = RegExp(
    r'ChangeGameUIState:.*MAINMENU\s*->\s*CSGO_GAME_UI_STATE_INGAME'
  );
  
  // 地图加载相关
  final _regexLoadingMap = RegExp(r'\[Client\]\s+Map:\s+"([^"]+)"');
  final _regexMapLoaded = RegExp(r'ChangeGameUIState:.*CSGO_GAME_UI_STATE_LOADINGSCREEN');
  
  // 服务器状态
  final _regexServerFull = RegExp(r'[Ss]erver is full|[Nn]o free slots|SERVERFULL|REJECT_SERVERFULL');
  
  // 玩家进入游戏 - 使用更可靠的标志
  // 注意：不再使用 ChangeGameUIState LOADINGSCREEN -> INGAME，因为它可能在 SERVERFULL 之前触发
  // 只使用以下更可靠的标志：
  // 1. [Prediction] Added prediction for player - 预测系统添加玩家
  // 2. 已连接。$ - 中文"已连接"消息（行尾）
  // 3. ClientPutInServer create - 创建玩家控制器（需要配合非 loopback 检查）
  final _regexSpawning = RegExp(
    r'\[Prediction\]\s+Added prediction for player|已连接。$|ClientPutInServer\s+create'
  );
  
  // 连接超时检测
  final _regexConnectTimeout = RegExp(r'CONNECT_REQUEST_TIMEDOUT|[Tt]imed out attempting to connect');
  
  // Loopback 连接检测
  final _regexLoopbackConnect = RegExp(r'[Cc]onnected.*loopback|loopback:\d+');
  
  // 远程连接请求检测
  final _regexRemoteConnect = RegExp(r'Remote Connect \(([^)]+)\)');
  
  // 主菜单状态检测
  final _regexMainMenu = RegExp(r'ChangeGameUIState:.*CSGO_GAME_UI_STATE_MAINMENU');

  /// 单例模式
  static final ConsoleLogService _instance = ConsoleLogService._internal();
  factory ConsoleLogService() => _instance;
  ConsoleLogService._internal();

  /// 检查是否为桌面平台
  bool get isDesktopPlatform => PlatformUtils.isDesktopPlatform;

  /// 获取控制台日志文件路径
  /// 优先从设置获取，没有设置则自动检测（带缓存，避免重复检测）
  Future<String?> getLogFilePath() async {
    // 优先从设置获取游戏路径
    String? gamePath = await _gameLauncher.getGamePath();
    
    // 如果设置中没有，使用缓存或尝试自动检测
    if (gamePath == null || gamePath.isEmpty) {
      // 如果已经尝试过检测，直接使用缓存结果
      if (_gamePathDetectionAttempted) {
        gamePath = _cachedGamePath;
      } else {
        // 首次检测，记录日志并缓存结果
        LogService.d('[ConsoleLog] 设置中未配置游戏路径，尝试自动检测');
        gamePath = await _gameLauncher.detectGamePath();
        _gamePathDetectionAttempted = true;
        _cachedGamePath = gamePath;
      }
    } else {
      // 设置中有配置，重置检测缓存（用户可能更新了设置）
      _gamePathDetectionAttempted = false;
      _cachedGamePath = null;
    }
    
    if (gamePath == null || gamePath.isEmpty) {
      return null;
    }
    
    // CS2 控制台日志路径: <游戏路径>/game/csgo/console.log
    return '$gamePath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}console.log';
  }
  
  /// 重置游戏路径检测缓存（当用户更新设置时调用）
  void resetGamePathCache() {
    _gamePathDetectionAttempted = false;
    _cachedGamePath = null;
    LogService.d('[ConsoleLog] 游戏路径缓存已重置');
  }

  /// 清空 console.log 文件（启动游戏前调用）
  Future<bool> clearConsoleLog() async {
    final logPath = await getLogFilePath();
    if (logPath == null) {
      LogService.w('[ConsoleLog] 无法获取日志路径');
      return false;
    }
    
    final file = File(logPath);
    if (await file.exists()) {
      try {
        await file.delete();
        LogService.d('[ConsoleLog] 已清空 console.log');
      } catch (e) {
        LogService.w('[ConsoleLog] 删除 console.log 失败: $e');
        return false;
      }
    }
    
    return true;
  }


  /// 检查控制台日志监控是否可用
  /// 
  /// 返回：
  /// - available: 日志文件是否存在且可读
  /// - condebugEnabled: 游戏是否带 -condebug 启动（通过命令行参数检测）
  Future<Map<String, dynamic>> checkAvailability() async {
    if (!isDesktopPlatform) {
      return {
        'success': true,
        'available': false,
        'condebugEnabled': false,
        'reason': '仅支持桌面平台',
      };
    }

    // 检测游戏是否带 -condebug 启动
    final condebugEnabled = await _gameLauncher.isCS2LaunchedWithCondebug();
    
    final logPath = await getLogFilePath();
    if (logPath == null) {
      LogService.d('[ConsoleLog] 游戏路径未配置');
      return {
        'success': true,
        'available': false,
        'condebugEnabled': condebugEnabled,
        'reason': '游戏路径未配置',
      };
    }

    final file = File(logPath);
    final fileExists = await file.exists();
    
    if (!fileExists) {
      LogService.d('[ConsoleLog] 日志文件不存在: $logPath');
      return {
        'success': true,
        'available': false,
        'condebugEnabled': condebugEnabled,
        'reason': '日志文件不存在',
        'path': logPath,
      };
    }

    try {
      final stat = await file.stat();
      final hasContent = stat.size > 0;
      final gameRunning = await _gameLauncher.isCS2Running();
      final timeSinceModified = DateTime.now().difference(stat.modified);

      LogService.d('[ConsoleLog] 检查结果: path=$logPath, size=${stat.size}, '
          'available=$hasContent, condebugEnabled=$condebugEnabled, '
          'gameRunning=$gameRunning, timeSinceModified=${timeSinceModified.inSeconds}s');

      return {
        'success': true,
        'available': hasContent,
        'path': logPath,
        'size': stat.size,
        'lastModified': stat.modified,
        'isRecent': timeSinceModified.inSeconds < 60,
        'gameRunning': gameRunning,
        'condebugEnabled': condebugEnabled,
      };
    } catch (e) {
      LogService.d('[ConsoleLog] 无法访问日志文件: $e');
      return {
        'success': true,
        'available': false,
        'condebugEnabled': condebugEnabled,
        'reason': '无法访问日志文件',
      };
    }
  }

  /// 等待控制台日志可用（游戏启动后需要一点时间创建 console.log）
  Future<bool> waitForAvailable({Duration maxWait = const Duration(seconds: 15)}) async {
    _isCancelled = false;
    final startTime = DateTime.now();
    const checkInterval = Duration(milliseconds: 500);
    
    LogService.d('[ConsoleLog] 等待日志文件可用，最大等待时间: ${maxWait.inSeconds}s');
    
    while (DateTime.now().difference(startTime) < maxWait) {
      if (_isCancelled) {
        LogService.d('[ConsoleLog] 等待被取消');
        return false;
      }
      
      final result = await checkAvailability();
      LogService.d('[ConsoleLog] 检查结果: available=${result['available']}, condebugEnabled=${result['condebugEnabled']}');
      
      // 只要文件存在且有内容就认为可用
      if (result['available'] == true) {
        LogService.d('[ConsoleLog] 日志文件可用');
        return true;
      }
      
      await Future.delayed(checkInterval);
    }
    
    LogService.d('[ConsoleLog] 等待超时，日志文件不可用');
    return false;
  }

  /// 检测游戏是否完全启动到主菜单
  /// 通过检查 console.log 中是否包含 "ChangeGameUIState:.*CSGO_GAME_UI_STATE_MAINMENU"
  /// 
  /// 注意：启动游戏前会清空 console.log，所以只要找到主菜单状态就说明游戏已加载完成
  Future<bool> isGameFullyLoaded() async {
    final logPath = await getLogFilePath();
    if (logPath == null) return false;

    final file = File(logPath);
    if (!await file.exists()) return false;

    try {
      final content = await file.readAsString();
      return _regexMainMenu.hasMatch(content);
    } catch (e) {
      LogService.e('[ConsoleLog] 检查游戏加载状态失败', e);
      return false;
    }
  }

  /// 等待游戏完全加载到主菜单
  /// 
  /// [maxWait] 最大等待时间
  /// [onProgress] 进度回调，用于更新UI
  Future<bool> waitForGameFullyLoaded({
    Duration maxWait = const Duration(seconds: 90),
    Future<void> Function(String message)? onProgress,
  }) async {
    _isCancelled = false;
    final startTime = DateTime.now();
    const checkInterval = Duration(seconds: 1);
    
    LogService.d('[ConsoleLog] 等待游戏加载到主菜单，最大等待时间: ${maxWait.inSeconds}s');
    
    int checkCount = 0;
    while (DateTime.now().difference(startTime) < maxWait) {
      if (_isCancelled) {
        LogService.d('[ConsoleLog] 等待被取消');
        return false;
      }
      
      checkCount++;
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      
      // 更新进度
      if (onProgress != null) {
        if (elapsed < 10) {
          await onProgress('游戏启动中...');
        } else if (elapsed < 30) {
          await onProgress('等待游戏加载...');
        } else if (elapsed < 60) {
          await onProgress('游戏加载中，请稍候...');
        } else {
          await onProgress('加载时间较长，继续等待...');
        }
      }
      
      // 检查是否已加载到主菜单
      final fullyLoaded = await isGameFullyLoaded();
      if (fullyLoaded) {
        LogService.d('[ConsoleLog] 游戏已加载到主菜单，耗时: ${elapsed}s');
        return true;
      }
      
      // 每10次检查输出一次日志
      if (checkCount % 10 == 0) {
        LogService.d('[ConsoleLog] 等待游戏加载... 已等待 ${elapsed}s');
      }
      
      await Future.delayed(checkInterval);
    }
    
    LogService.d('[ConsoleLog] 等待游戏加载超时');
    return false;
  }

  /// 开始监控控制台日志
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      return;
    }

    final availability = await checkAvailability();
    if (availability['available'] != true) {
      LogService.d('[ConsoleLog] 控制台日志文件暂不可用，将持续检测');
    }

    _logFilePath = await getLogFilePath();
    _isMonitoring = true;
    _isCancelled = false;

    // 重置连接追踪状态
    _targetServer = '';
    _isLoopbackFallback = false;
    _connectTimedOut = false;
    _connectionPhaseFailed = false;
    _isInLoopbackMode = false;

    // 初始化状态
    _currentState = ConsoleLogState(
      available: availability['available'] == true,
      state: GameState.mainMenu,
      stateText: '监控中',
      condebugEnabled: availability['condebugEnabled'] == true,
      lastUpdate: DateTime.now(),
    );

    // 监听游戏状态变化（游戏退出时重置状态）
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = GameStatusService().statusStream.listen(_onGameStatusChanged);

    // 获取当前文件大小，只读取新内容
    if (_logFilePath != null) {
      final file = File(_logFilePath!);
      if (await file.exists()) {
        final stat = await file.stat();
        _lastFileSize = stat.size;
        _lastReadPos = stat.size;
        LogService.d('[ConsoleLog] 监控从文件位置 $_lastReadPos 开始（只读取新内容）');
        
        // 分析历史日志，恢复当前状态
        await _analyzeHistoryAndRestoreState(file);
      } else {
        _lastFileSize = 0;
        _lastReadPos = 0;
      }
    }

    _updateState(_currentState);

    // 启动监控循环
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkLogFile();
    });

    LogService.d('[ConsoleLog] 控制台日志监控已启动');
    return;
  }

  /// 游戏状态变化处理
  void _onGameStatusChanged(GameStatusEvent event) {
    if (!event.isRunning) {
      // 游戏退出，重置状态
      LogService.d('[ConsoleLog] 游戏已退出，重置状态');
      _currentState = _currentState.copyWith(
        state: GameState.unknown,
        stateText: '游戏未运行',
        serverAddress: '',
        mapName: '',
        available: false,
      );
      _targetServer = '';
      _isLoopbackFallback = false;
      _connectTimedOut = false;
      _connectionPhaseFailed = false;
      _isInLoopbackMode = false;
      _lastFileSize = 0;
      _lastReadPos = 0;
      _updateState(_currentState);
    }
  }

  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _checkTimer?.cancel();
    _checkTimer = null;
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = null;
    _isMonitoring = false;

    _currentState = _currentState.copyWith(stateText: '已停止');
    _updateState(_currentState);

    LogService.d('[ConsoleLog] 控制台日志监控已停止');
    return;
  }

  /// 重置状态（用于开始新的挤服）
  void resetState() {
    _currentState = ConsoleLogState(
      available: _currentState.available,
      state: GameState.mainMenu,
      stateText: '等待连接',
      condebugEnabled: _currentState.condebugEnabled,
      lastUpdate: DateTime.now(),
    );

    // 重置连接追踪状态
    _targetServer = '';
    _isLoopbackFallback = false;
    _connectTimedOut = false;
    _connectionPhaseFailed = false;
    _isInLoopbackMode = false;

    _updateState(_currentState);
    LogService.d('[ConsoleLog] 状态已重置');
  }

  /// 取消当前的连接监控（不停止日志监控服务）
  void cancelConnectionMonitor() {
    _isCancelled = true;
    _checkTimer?.cancel();
    _checkTimer = null;
  }


  /// 监控连接状态
  /// 
  /// [maxTimeout] 最大超时时间
  /// [onStateChange] 状态变化回调
  /// 
  /// 注意：此方法不会停止监控，监控会持续运行以供其他服务使用
  Future<ConnectionStatusResult> monitorConnection({
    Duration maxTimeout = const Duration(seconds: 60),
    void Function(ConsoleLogState)? onStateChange,
  }) async {
    _isCancelled = false;
    
    await startMonitoring();
    
    final completer = Completer<ConnectionStatusResult>();
    int checkCount = 0;
    final maxChecks = maxTimeout.inMilliseconds ~/ 500;
    
    _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isCancelled) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(ConnectionStatusResult.cancelled());
        }
        return;
      }
      
      checkCount++;
      
      // 回调状态变化
      onStateChange?.call(_currentState);
      
      // 检查终态
      switch (_currentState.state) {
        case GameState.inGame:
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(ConnectionStatusResult.connected());
          }
          return;
          
        case GameState.failed:
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(ConnectionStatusResult.failed(
              _currentState.stateText,
            ));
          }
          return;
          
        case GameState.serverFull:
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(ConnectionStatusResult.serverFull());
          }
          return;
          
        default:
          break;
      }
      
      // 超时检查
      if (checkCount >= maxChecks) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(ConnectionStatusResult.timeout());
        }
      }
    });
    
    return completer.future;
  }

  /// 检查是否已连接（进入游戏）
  bool isConnected() {
    return _currentState.state == GameState.inGame;
  }

  /// 检查是否正在加载
  bool isLoading() {
    return _currentState.state == GameState.loading;
  }

  /// 检查连接是否失败
  bool isConnectionFailed() {
    return _currentState.state == GameState.failed || _isLoopbackFallback;
  }

  /// 检查服务器是否满员
  bool isServerFull() {
    return _currentState.state == GameState.serverFull;
  }

  /// 获取事件历史
  List<ConsoleLogEvent> getEvents({int? limit}) {
    if (limit != null && limit > 0 && _events.length > limit) {
      return _events.sublist(_events.length - limit);
    }
    return List.unmodifiable(_events);
  }

  /// 清空事件历史
  void clearEvents() {
    _events.clear();
    LogService.d('[ConsoleLog] 事件历史已清空');
  }

  /// 清理资源
  void dispose() {
    stopMonitoring();
    _stateController.close();
  }

  // ==================== 私有方法 ====================

  /// 更新状态
  void _updateState(ConsoleLogState newState) {
    _currentState = newState;
    _stateController.add(_currentState);
  }

  /// 检查日志文件变化
  Future<void> _checkLogFile() async {
    if (_logFilePath == null) {
      _logFilePath = await getLogFilePath();
      if (_logFilePath == null) return;
    }

    final file = File(_logFilePath!);
    
    if (!await file.exists()) {
      if (_currentState.available) {
        _currentState = _currentState.copyWith(
          available: false,
          condebugEnabled: false,
        );
        _updateState(_currentState);
      }
      // 文件不存在时重置读取位置
      _lastFileSize = 0;
      _lastReadPos = 0;
      return;
    }

    try {
      final stat = await file.stat();
      
      // 如果之前不可用，现在可用了
      if (!_currentState.available) {
        _currentState = _currentState.copyWith(
          available: true,
          condebugEnabled: true,
        );
        _updateState(_currentState);
        LogService.d('[ConsoleLog] 检测到控制台日志文件，监控已激活');
      }

      final currentSize = stat.size;
      
      // 文件大小没变化
      if (currentSize == _lastFileSize) return;
      
      // 文件被截断（可能是游戏重启）
      if (currentSize < _lastFileSize) {
        LogService.d('[ConsoleLog] 检测到日志文件被截断（游戏可能重启），重置读取位置');
        _lastReadPos = 0;
        _lastFileSize = 0;
        // 重置连接追踪状态
        _targetServer = '';
        _isLoopbackFallback = false;
        _connectTimedOut = false;
        _connectionPhaseFailed = false;
        _isInLoopbackMode = false;
      }
      
      // 读取新内容
      await _readNewContent(currentSize);
      _lastFileSize = currentSize;
    } catch (e) {
      LogService.e('[ConsoleLog] 检查日志文件失败', e);
    }
  }

  /// 读取新增的日志内容
  Future<void> _readNewContent(int currentSize) async {
    if (_logFilePath == null) return;
    
    final file = File(_logFilePath!);
    
    try {
      final raf = await file.open(mode: FileMode.read);
      
      try {
        // 定位到上次读取位置
        if (_lastReadPos > 0) {
          await raf.setPosition(_lastReadPos);
        }
        
        // 读取新内容
        final newContent = await raf.read(currentSize - _lastReadPos);
        final lines = String.fromCharCodes(newContent).split('\n');
        
        for (final line in lines) {
          _parseLine(line);
        }
        
        _lastReadPos = currentSize;
      } finally {
        await raf.close();
      }
    } catch (e) {
      LogService.e('[ConsoleLog] 读取日志文件失败', e);
      _lastReadPos = 0;
    }
  }

  /// 分析历史日志，恢复当前游戏状态
  /// 
  /// 通过读取日志文件的最后一部分内容，分析用户当前的游戏状态：
  /// - 是否在服务器中
  /// - 当前连接的服务器地址
  /// - 当前地图名称
  /// - 是否在主菜单
  Future<void> _analyzeHistoryAndRestoreState(File file) async {
    try {
      final stat = await file.stat();
      final fileSize = stat.size;
      
      // 读取最后 100KB 的内容（足够分析最近的状态）
      const maxReadSize = 100 * 1024;
      final startPos = fileSize > maxReadSize ? fileSize - maxReadSize : 0;
      
      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(startPos);
        final content = await raf.read(fileSize - startPos);
        final lines = String.fromCharCodes(content).split('\n');
        
        // 用于检测远程连接的正则
        final regexHostActivate = RegExp(r'\[HostStateManager\] Host activate: Remote Connect \(([^)]+)\)');
        final regexMapPhysics = RegExp(r'\[Client\] Created physics for (\S+)');
        
        // 第一遍：从后往前扫描，找到最近的关键状态标志
        // 需要找到：断开连接、回到主菜单、loopback、远程连接、进入游戏
        String? lastServerAddress;
        String? lastMapName;
        int? disconnectIndex;      // 断开连接的位置
        int? loopbackIndex;        // loopback 的位置
        int? remoteConnectIndex;   // 远程连接的位置
        int? spawningIndex;        // 进入游戏的位置
        
        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          // 检测用户断开连接
          if (disconnectIndex == null && _regexUserDisconnect.hasMatch(line)) {
            disconnectIndex = i;
            LogService.d('[ConsoleLog] 历史分析: 检测到用户断开连接 @$i');
          }
          
          // 检测回到主菜单
          if (disconnectIndex == null && _regexBackToMainMenu.hasMatch(line)) {
            disconnectIndex = i;
            LogService.d('[ConsoleLog] 历史分析: 检测到回到主菜单 @$i');
          }
          
          // 检测 loopback 连接
          if (loopbackIndex == null && _regexLoopbackConnect.hasMatch(line)) {
            loopbackIndex = i;
            LogService.d('[ConsoleLog] 历史分析: 检测到 loopback @$i');
          }
          
          // 检测远程连接
          if (remoteConnectIndex == null) {
            final hostMatch = regexHostActivate.firstMatch(line);
            if (hostMatch != null) {
              remoteConnectIndex = i;
              lastServerAddress = hostMatch.group(1);
              LogService.d('[ConsoleLog] 历史分析: 检测到远程连接 @$i: $lastServerAddress');
            }
          }
          
          // 检测玩家进入游戏
          if (spawningIndex == null && _regexSpawning.hasMatch(line)) {
            spawningIndex = i;
            LogService.d('[ConsoleLog] 历史分析: 检测到进入游戏 @$i');
          }
          
          // 检测地图名称
          if (lastMapName == null) {
            final mapMatch = regexMapPhysics.firstMatch(line);
            if (mapMatch != null) {
              final mapName = mapMatch.group(1);
              if (mapName != null && mapName != '<empty>') {
                lastMapName = mapName;
                LogService.d('[ConsoleLog] 历史分析: 检测到地图 @$i: $lastMapName');
              }
            }
          }
          
          // 如果找到了断开连接，可以提前退出
          if (disconnectIndex != null) break;
          
          // 如果找到了所有关键信息，可以提前退出
          if (remoteConnectIndex != null && spawningIndex != null && lastMapName != null) {
            break;
          }
        }
        
        // 第二遍：根据位置关系判断当前状态
        // 规则：
        // 1. 如果有断开连接，且在 loopback/spawning 之后 → 主菜单
        // 2. 如果有 loopback，且在远程连接之后（或没有远程连接）→ 主菜单（loopback 模式）
        // 3. 如果有 spawning，且在远程连接之后，且没有断开 → 在游戏中
        // 4. 其他情况 → 主菜单
        
        bool isInGame = false;
        
        if (disconnectIndex != null) {
          // 有断开连接记录，用户在主菜单
          LogService.d('[ConsoleLog] 历史分析: 检测到断开，用户在主菜单');
        } else if (loopbackIndex != null) {
          // 有 loopback 连接
          if (remoteConnectIndex == null || loopbackIndex > remoteConnectIndex) {
            // loopback 在远程连接之后，或者没有远程连接 → 主菜单
            _isInLoopbackMode = true;
            LogService.d('[ConsoleLog] 历史分析: loopback 在远程连接之后，用户在主菜单');
          } else if (spawningIndex != null && spawningIndex > remoteConnectIndex && spawningIndex > loopbackIndex) {
            // spawning 在远程连接和 loopback 之后 → 在游戏中
            isInGame = true;
            LogService.d('[ConsoleLog] 历史分析: spawning 在远程连接之后，用户在游戏中');
          }
        } else if (spawningIndex != null && remoteConnectIndex != null && spawningIndex > remoteConnectIndex) {
          // 有 spawning 且在远程连接之后，没有 loopback → 在游戏中
          isInGame = true;
          LogService.d('[ConsoleLog] 历史分析: 用户在游戏中');
        } else {
          // 其他情况，默认主菜单
          LogService.d('[ConsoleLog] 历史分析: 无法确定状态，默认主菜单');
        }
        
        // 根据分析结果更新状态
        if (isInGame && lastServerAddress != null) {
          _currentState = _currentState.copyWith(
            state: GameState.inGame,
            stateText: '已在服务器中',
            serverAddress: lastServerAddress,
            mapName: lastMapName ?? '',
          );
          _isInLoopbackMode = false;
          LogService.d('[ConsoleLog] 历史: 用户当前在服务器中: $lastServerAddress, 地图: $lastMapName');
        } else {
          _currentState = _currentState.copyWith(
            state: GameState.mainMenu,
            stateText: '主菜单',
            serverAddress: '',
            mapName: '',
          );
          LogService.d('[ConsoleLog] 历史: 用户当前在主菜单, loopbackMode=$_isInLoopbackMode');
        }
        
      } finally {
        await raf.close();
      }
    } catch (e) {
      LogService.e('[ConsoleLog] 分析历史日志失败', e);
    }
  }


  /// 解析单行日志
  /// 
  /// 日志事件流程（按时间顺序）：
  /// 
  /// 【连接服务器】
  /// 1. Remote Connect (domain:port) - 开始连接请求
  /// 2. Sending connect to IP:port - 发送连接
  /// 3. Connected to 'IP:port' - 连接建立
  /// 4. ChangeGameUIState: MAINMENU -> LOADINGSCREEN - 进入加载界面
  /// 5. ChangeGameUIState: LOADINGSCREEN -> INGAME - 进入游戏界面
  /// 6. [Prediction] Added prediction for player slot X (PlayerName) - 成功进入游戏
  /// 
  /// 【断开连接】
  /// 1. ChangeGameUIState: INGAME -> PAUSEMENU - 打开暂停菜单
  /// 2. [Client] CL: disconnect - 断开命令
  /// 3. NETWORK_DISCONNECT_DISCONNECT_BY_USER - 用户主动断开
  /// 4. ChangeGameUIState: PAUSEMENU -> MAINMENU - 回到主菜单
  void _parseLine(String line) {
    line = line.trim();
    if (line.isEmpty) return;

    // 检测远程连接请求（记录目标服务器）
    final remoteMatch = _regexRemoteConnect.firstMatch(line);
    if (remoteMatch != null) {
      _targetServer = remoteMatch.group(1) ?? '';
      _isLoopbackFallback = false;
      _connectTimedOut = false;
      _connectionPhaseFailed = false;
      _isInLoopbackMode = false;  // 新的远程连接，退出 loopback 模式
      LogService.d('[ConsoleLog] 检测到远程连接请求，目标服务器: $_targetServer');
      return;
    }

    // 检测连接阶段断开（在连接过程中被服务器断开）
    // 例如：Disconnection during connection phase. Sign-on state: 5 (SIGNONSTATE_SPAWN). Disconnect reason: NETWORK_DISCONNECT_LOOPSHUTDOWN
    // 例如：Disconnection during connection phase. Sign-on state: 2 (SIGNONSTATE_CONNECTED). Disconnect reason: NETWORK_DISCONNECT_TIMEDOUT
    // 例如：Disconnection during connection phase. Sign-on state: 2 (SIGNONSTATE_CONNECTED). Disconnect reason: NETWORK_DISCONNECT_LOOP_LEVELLOAD_ACTIVATE
    // 例如：Disconnection during connection phase. Sign-on state: 2 (SIGNONSTATE_CONNECTED). Disconnect reason: NETWORK_DISCONNECT_REQUEST_HOSTSTATE_IDLE
    if (_regexDisconnectionDuringConnection.hasMatch(line)) {
      _connectionPhaseFailed = true;
      
      // 检查具体的断开原因
      if (line.contains('NETWORK_DISCONNECT_TIMEDOUT')) {
        LogService.d('[ConsoleLog] 检测到连接阶段断开 (TIMEDOUT)');
        _connectTimedOut = true;
        if (_targetServer.isNotEmpty || _currentState.serverAddress.isNotEmpty) {
          _updateConnectionState(
            GameState.failed,
            '连接超时',
            serverAddress: _targetServer.isNotEmpty ? _targetServer : _currentState.serverAddress,
            rawLine: line,
          );
        }
      } else if (line.contains('NETWORK_DISCONNECT_LOOP_LEVELLOAD_ACTIVATE') ||
                 line.contains('NETWORK_DISCONNECT_REQUEST_HOSTSTATE_IDLE')) {
        // 这些是用户重新发起连接请求导致的断开，标记失败但不更新状态文本
        // 因为后续会有新的连接请求
        LogService.d('[ConsoleLog] 检测到连接阶段断开 (重新连接): $line');
      } else if (_regexDisconnectLoopShutdown.hasMatch(line)) {
        LogService.d('[ConsoleLog] 检测到连接阶段断开 (LOOPSHUTDOWN)');
      } else {
        LogService.d('[ConsoleLog] 检测到连接阶段断开: $line');
      }
      return;
    }
    
    // 检测 "Disconnected from server: NETWORK_DISCONNECT_TIMEDOUT"
    // 这是连接超时的另一个标志，通常在 "Disconnection during connection phase" 之后出现
    if (_regexDisconnectedTimedout.hasMatch(line)) {
      _connectTimedOut = true;
      _connectionPhaseFailed = true;
      LogService.d('[ConsoleLog] 检测到服务器断开 (TIMEDOUT)');
      // 如果还没有标记为失败，现在标记
      if (_currentState.state != GameState.failed && _currentState.state != GameState.mainMenu) {
        _updateConnectionState(
          GameState.failed,
          '连接超时',
          serverAddress: _targetServer.isNotEmpty ? _targetServer : _currentState.serverAddress,
          rawLine: line,
        );
      }
      return;
    }

    // 检测连接超时
    if (_regexConnectTimeout.hasMatch(line)) {
      _connectTimedOut = true;
      LogService.d('[ConsoleLog] 检测到连接超时');
      // 只要有目标服务器且检测到超时，就直接标记为失败
      // 不再等待 loopback 连接，因为超时本身就是终态
      if (_targetServer.isNotEmpty) {
        _updateConnectionState(
          GameState.failed,
          '连接超时',
          serverAddress: _targetServer,
          rawLine: line,
        );
        // 重置目标服务器，避免后续 loopback 检测再次触发失败
        _targetServer = '';
      }
      return;
    }

    // 检测 loopback 连接（本地服务器回退或主菜单背景服务器）
    if (_regexLoopbackConnect.hasMatch(line)) {
      // 标记进入 loopback 模式
      _isInLoopbackMode = true;
      LogService.d('[ConsoleLog] 检测到 loopback 连接，进入 loopback 模式');
      
      // 如果之前有远程连接请求且（超时或连接阶段失败），说明是回退到本地服务器
      if (_targetServer.isNotEmpty && (_connectTimedOut || _connectionPhaseFailed)) {
        _isLoopbackFallback = true;
        final reason = _connectTimedOut ? '连接超时，回退到本地' : '连接失败，回退到本地';
        LogService.d('[ConsoleLog] 检测到回退到本地服务器，目标服务器: $_targetServer, 原因: $reason');
        _updateConnectionState(
          GameState.failed,
          reason,
          serverAddress: _targetServer,
          rawLine: line,
        );
      } else if (_currentState.state == GameState.connecting || _currentState.state == GameState.loading) {
        // 如果当前正在连接或加载中，但出现了 loopback，说明连接失败了
        _isLoopbackFallback = true;
        LogService.d('[ConsoleLog] 检测到连接过程中出现 loopback，连接失败');
        _updateConnectionState(
          GameState.failed,
          '连接失败',
          serverAddress: _currentState.serverAddress,
          rawLine: line,
        );
      }
      return;
    }

    // 检查玩家进入游戏（最高优先级）
    if (_regexSpawning.hasMatch(line)) {
      // 检查是否是 loopback 回退的情况（连接远程服务器失败后回退）
      if (_isLoopbackFallback) {
        LogService.d('[ConsoleLog] 忽略 loopback 回退后的连接状态');
        return;
      }
      
      // 检查是否处于 loopback 模式（主菜单背景服务器或断开连接后的本地服务器）
      // 在 loopback 模式下，所有的 Prediction/ClientPutInServer/已连接 消息都应该被忽略
      if (_isInLoopbackMode) {
        LogService.d('[ConsoleLog] 忽略 loopback 模式下的连接消息');
        return;
      }
      
      // 如果没有目标服务器且当前状态是主菜单，说明是游戏启动时的 loopback 连接
      if (_targetServer.isEmpty && _currentState.state == GameState.mainMenu) {
        LogService.d('[ConsoleLog] 忽略主菜单状态下无目标服务器的连接消息');
        return;
      }
      
      _updateConnectionState(
        GameState.inGame,
        '已进入游戏',
        rawLine: line,
      );
      // 重置追踪状态（但不重置 _isInLoopbackMode，因为可能还在服务器中）
      _targetServer = '';
      _connectTimedOut = false;
      _connectionPhaseFailed = false;
      return;
    }

    // 检查开始连接
    final connectingMatch = _regexConnecting.firstMatch(line);
    if (connectingMatch != null) {
      _updateConnectionState(
        GameState.connecting,
        '正在连接',
        serverAddress: connectingMatch.group(1),
        rawLine: line,
      );
      return;
    }

    // 检查地图信息
    final mapMatch = _regexLoadingMap.firstMatch(line);
    if (mapMatch != null) {
      final currentState = _currentState.state;
      if ((currentState == GameState.connecting || 
           currentState == GameState.loading) &&
          !_isLoopbackFallback) {
        _updateConnectionState(
          GameState.loading,
          '正在加载地图',
          mapName: mapMatch.group(1),
          rawLine: line,
        );
      }
      return;
    }

    // 检查进入加载界面
    if (_regexMapLoaded.hasMatch(line)) {
      final currentState = _currentState.state;
      if (currentState != GameState.inGame && !_isLoopbackFallback) {
        _updateConnectionState(
          GameState.loading,
          '正在加载',
          rawLine: line,
        );
      }
      return;
    }

    // 检查已连接（但可能还在加载）
    final connectedMatch = _regexConnected.firstMatch(line);
    if (connectedMatch != null) {
      final connectedTo = connectedMatch.group(1) ?? '';
      
      // 检查是否连接到 loopback
      if (connectedTo.toLowerCase().contains('loopback')) {
        if (_targetServer.isNotEmpty && _connectTimedOut) {
          _isLoopbackFallback = true;
          LogService.d('[ConsoleLog] 检测到连接到 loopback，目标服务器连接失败: $_targetServer');
          return;
        }
      }
      
      final currentState = _currentState.state;
      if (currentState != GameState.inGame && !_isLoopbackFallback) {
        _updateConnectionState(
          GameState.loading,
          '已连接，加载中',
          serverAddress: connectedTo,
          rawLine: line,
        );
      }
      return;
    }

    // 检查服务器满员
    if (_regexServerFull.hasMatch(line)) {
      _updateConnectionState(
        GameState.serverFull,
        '服务器已满',
        rawLine: line,
      );
      return;
    }

    // 检查用户主动断开连接（优先级高于普通断开检测）
    if (_regexUserDisconnect.hasMatch(line)) {
      LogService.d('[ConsoleLog] 检测到用户主动断开连接');
      _updateConnectionState(
        GameState.mainMenu,
        '已断开连接',
        rawLine: line,
      );
      // 重置连接追踪状态
      _targetServer = '';
      _isLoopbackFallback = false;
      _connectTimedOut = false;
      _connectionPhaseFailed = false;
      // 断开连接后会进入 loopback 模式（主菜单背景服务器）
      _isInLoopbackMode = true;
      return;
    }

    // 检查回到主菜单（从游戏或暂停菜单）
    if (_regexBackToMainMenu.hasMatch(line)) {
      final currentState = _currentState.state;
      if (currentState == GameState.inGame) {
        LogService.d('[ConsoleLog] 检测到回到主菜单');
        _updateConnectionState(
          GameState.mainMenu,
          '已断开连接',
          rawLine: line,
        );
        // 重置连接追踪状态
        _targetServer = '';
        _isLoopbackFallback = false;
        _connectTimedOut = false;
        _connectionPhaseFailed = false;
        // 回到主菜单后会进入 loopback 模式
        _isInLoopbackMode = true;
      }
      return;
    }
    
    // 检查进入游戏界面（从加载界面）- 作为备用的连接成功标志
    if (_regexLoadingToIngame.hasMatch(line)) {
      // 如果连接阶段已经失败（超时或其他原因），忽略这个状态变化
      // 游戏在连接超时后会错误地触发 MAINMENU -> INGAME 状态变化
      if (_connectionPhaseFailed || _connectTimedOut) {
        LogService.d('[ConsoleLog] 忽略连接失败后的 LOADINGSCREEN -> INGAME 状态变化');
        return;
      }
      
      final currentState = _currentState.state;
      // 只有在加载状态且不是 loopback 回退时才更新
      if (currentState == GameState.loading && !_isLoopbackFallback) {
        LogService.d('[ConsoleLog] 检测到 LOADINGSCREEN -> INGAME，等待 Prediction 确认');
        // 不直接设置为 inGame，等待 Prediction 消息确认
      }
      return;
    }
    
    // 检查从主菜单直接进入游戏界面（异常情况）
    // 这通常发生在连接超时后，游戏错误地触发了这个状态变化
    if (_regexMainMenuToIngame.hasMatch(line)) {
      if (_connectionPhaseFailed || _connectTimedOut) {
        LogService.d('[ConsoleLog] 忽略连接失败后的 MAINMENU -> INGAME 状态变化（异常状态）');
        return;
      }
      // 正常情况下不应该从主菜单直接进入游戏，记录警告
      LogService.w('[ConsoleLog] 检测到异常状态变化: MAINMENU -> INGAME');
      return;
    }

    // 检查连接失败
    if (_regexConnectFailed.hasMatch(line)) {
      // 排除一些正常的断开情况
      if (!line.contains('LOOPSHUTDOWN') && 
          !line.contains('SERVERFULL') && 
          !line.contains('LOOPDEACTIVATE')) {
        final currentState = _currentState.state;
        if (currentState == GameState.connecting) {
          _updateConnectionState(
            GameState.failed,
            '连接失败',
            rawLine: line,
          );
        }
      }
      return;
    }

    // 检查重试连接
    if (_regexRetrying.hasMatch(line)) {
      _updateConnectionState(
        GameState.retrying,
        '重试连接中',
        rawLine: line,
      );
      return;
    }

    // 检查断开连接（通用检测，排除内部状态切换）
    if (_regexDisconnect.hasMatch(line)) {
      // 排除内部状态切换
      if (!line.contains('LOOPSHUTDOWN') && 
          !line.contains('LOOPDEACTIVATE') &&
          !line.contains('DISCONNECT_BY_USER')) {  // 已在上面处理
        final currentState = _currentState.state;
        if (currentState == GameState.inGame) {
          _updateConnectionState(
            GameState.mainMenu,
            '已断开连接',
            rawLine: line,
          );
        }
      }
      return;
    }
  }

  /// 更新连接状态
  void _updateConnectionState(
    GameState state,
    String stateText, {
    String? serverAddress,
    String? mapName,
    String? rawLine,
  }) {
    _currentState = _currentState.copyWith(
      state: state,
      stateText: stateText,
      serverAddress: serverAddress ?? _currentState.serverAddress,
      mapName: mapName ?? _currentState.mapName,
      lastUpdate: DateTime.now(),
    );
    
    _updateState(_currentState);
    
    // 添加事件
    final event = ConsoleLogEvent(
      type: state.name,
      state: state,
      message: rawLine ?? '',
      details: stateText,
    );
    
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
    
    LogService.d('[ConsoleLog] 状态更新: $state - $stateText');
  }

  /// 获取状态显示文本
  String getStateText(ConsoleLogState state) {
    switch (state.state) {
      case GameState.connecting:
        return '正在连接${state.serverAddress.isNotEmpty ? " (${state.serverAddress})" : ""}';
      case GameState.loading:
        return '正在加载${state.mapName.isNotEmpty ? " ${state.mapName}" : "地图"}';
      case GameState.inGame:
        return '已进入游戏';
      case GameState.pauseMenu:
        return '暂停菜单';
      case GameState.mainMenu:
        return '主菜单';
      case GameState.failed:
        return '连接失败';
      case GameState.serverFull:
        return '服务器已满';
      case GameState.retrying:
        return '重试连接中';
      case GameState.unknown:
        return state.stateText.isNotEmpty ? state.stateText : '未知';
      case GameState.gameStarting:
        return '游戏启动中';
    }
  }
}
