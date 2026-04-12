import 'dart:async';
import 'dart:io';

import 'parser/cs2_engine_events.dart';
import 'parser/cs2_log_parser.dart';

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
  final String serverAddress;
  final String mapName;
  final DateTime lastUpdate;
  final String? errorMessage;
  final bool condebugEnabled;

  const ConsoleLogState({
    this.available = false,
    this.state = GameState.unknown,
    this.serverAddress = '',
    this.mapName = '',
    DateTime? lastUpdate,
    this.errorMessage,
    this.condebugEnabled = false,
  }) : lastUpdate = lastUpdate ?? const _DefaultDateTime();

  ConsoleLogState copyWith({
    bool? available,
    GameState? state,
    String? serverAddress,
    String? mapName,
    DateTime? lastUpdate,
    String? errorMessage,
    bool? condebugEnabled,
  }) {
    return ConsoleLogState(
      available: available ?? this.available,
      state: state ?? this.state,
      serverAddress: serverAddress ?? this.serverAddress,
      mapName: mapName ?? this.mapName,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      errorMessage: errorMessage,
      condebugEnabled: condebugEnabled ?? this.condebugEnabled,
    );
  }

  /// 便捷方法：是否在服务器中
  bool get isInServer =>
      state == GameState.inGame || state == GameState.pauseMenu;

  /// 便捷方法：是否在主菜单
  bool get isInMainMenu => state == GameState.mainMenu;

  /// 便捷方法：是否正在连接
  bool get isConnecting =>
      state == GameState.connecting || state == GameState.loading;

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
  bool _isInLoopbackMode = false; // 是否处于 loopback 模式（主菜单背景服务器）

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

      LogService.d(
        '[ConsoleLog] 检查结果: path=$logPath, size=${stat.size}, '
        'available=$hasContent, condebugEnabled=$condebugEnabled, '
        'gameRunning=$gameRunning, timeSinceModified=${timeSinceModified.inSeconds}s',
      );

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
  Future<bool> waitForAvailable({
    Duration maxWait = const Duration(seconds: 15),
  }) async {
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
      LogService.d(
        '[ConsoleLog] 检查结果: available=${result['available']}, condebugEnabled=${result['condebugEnabled']}',
      );

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
      return content.contains('CSGO_GAME_UI_STATE_MAINMENU');
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
    _isInLoopbackMode = false;
    _isInLoopbackMode = false;

    // 初始化状态
    _currentState = ConsoleLogState(
      available: availability['available'] == true,
      state: GameState.mainMenu,
      condebugEnabled: availability['condebugEnabled'] == true,
      lastUpdate: DateTime.now(),
    );

    // 监听游戏状态变化（游戏退出时重置状态）
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = GameStatusService().statusStream.listen(
      _onGameStatusChanged,
    );

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
        serverAddress: '',
        mapName: '',
        available: false,
      );
      _targetServer = '';
      _isLoopbackFallback = false;
      _isInLoopbackMode = false;
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

    _updateState(_currentState);

    LogService.d('[ConsoleLog] 控制台日志监控已停止');
    return;
  }

  /// 重置状态（用于开始新的挤服）
  void resetState() {
    _currentState = ConsoleLogState(
      available: _currentState.available,
      state: GameState.mainMenu,
      condebugEnabled: _currentState.condebugEnabled,
      lastUpdate: DateTime.now(),
    );

    // 重置连接追踪状态
    _targetServer = '';
    _isLoopbackFallback = false;
    _isInLoopbackMode = false;
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
    StreamSubscription<ConsoleLogState>? subscription;
    Timer? timeoutTimer;
    
    // 清理回调
    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
    }

    // 设置最大超时
    timeoutTimer = Timer(maxTimeout, () {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(ConnectionStatusResult.timeout());
      }
    });

    // 处理状态变化的逻辑
    void checkState(ConsoleLogState state) {
      if (_isCancelled) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(ConnectionStatusResult.cancelled());
        }
        return;
      }

      // 回调状态变化
      onStateChange?.call(state);

      // 检查终态
      switch (state.state) {
        case GameState.inGame:
          cleanup();
          if (!completer.isCompleted) {
            completer.complete(ConnectionStatusResult.connected());
          }
          break;

        case GameState.failed:
          cleanup();
          if (!completer.isCompleted) {
            completer.complete(ConnectionStatusResult.failed('连接失败'));
          }
          break;

        case GameState.serverFull:
          cleanup();
          if (!completer.isCompleted) {
            completer.complete(ConnectionStatusResult.serverFull());
          }
          break;

        default:
          break;
      }
    }

    // 先检查一次当前状态
    checkState(_currentState);

    // 如果还没有得出结果，则开始监听状态流变化
    if (!completer.isCompleted) {
      // 订阅状态流，使用 broadcast 避免重复监听
      subscription = stateStream.listen((state) {
        checkState(state);
      });
      
      // 我们不需要使用 _checkTimer 了，但保留对 _isCancelled 的依赖以便外部能够中止。
      // 为保持向下兼容（如果其他函数在某处读取），这里设置一个空Timer
      _checkTimer?.cancel();
      _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
         if (_isCancelled || completer.isCompleted) {
            timer.cancel();
            cleanup();
         }
      });
    }

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

  /// 等待游戏回到主菜单
  ///
  /// 用于挤服连接失败后，等待游戏确认已回到主菜单再进行重试
  /// [maxWait] 最大等待时间，默认30秒
  ///
  /// 返回 true 表示已回到主菜单，false 表示超时
  Future<bool> waitForMainMenu({
    Duration maxWait = const Duration(seconds: 30),
  }) async {
    _isCancelled = false;

    // 如果当前已经是主菜单，直接返回（极速被拒载时经常发生）
    if (_currentState.state == GameState.mainMenu) {
      LogService.d('[ConsoleLog] 检测到当前已经在主菜单，无需等待，直接返回');
      return true;
    }

    final startTime = DateTime.now();
    LogService.d('[ConsoleLog] 开始等待回到主菜单...');

    // 使用 Completer 等待状态流中的 mainMenu 状态
    final completer = Completer<bool>();
    StreamSubscription<ConsoleLogState>? subscription;
    Timer? timeoutTimer;

    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
    }

    // 超时处理
    timeoutTimer = Timer(maxWait, () {
      cleanup();
      if (!completer.isCompleted) {
        LogService.w('[ConsoleLog] 等待回到主菜单超时');
        completer.complete(false);
      }
    });

    // 监听状态流，等待 mainMenu 状态
    subscription = stateStream.listen((state) {
      if (_isCancelled) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        return;
      }

      // 检查是否到达最大等待时间
      if (DateTime.now().difference(startTime) > maxWait) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        return;
      }

      // 检查状态是否变为 mainMenu
      if (state.state == GameState.mainMenu) {
        cleanup();
        LogService.d('[ConsoleLog] 已确认游戏返回主菜单');
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    return completer.future;
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
        _isInLoopbackMode = false;
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

      const maxReadSize = 100 * 1024;
      final startPos = fileSize > maxReadSize ? fileSize - maxReadSize : 0;

      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(startPos);
        final content = await raf.read(fileSize - startPos);
        final lines = String.fromCharCodes(content).split('\n');

        String? lastServerAddress;
        String? lastMapName;
        bool isInGame = false;

        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final event = CS2LogParser.parse(line);
          if (event == null) continue;

          if (event is EvMainMenu || event is EvDisconnect) {
            break; // Menu/Disconnected -> Not in game
          } else if (event is EvSignonState && event.state >= 5) {
            isInGame = true; // In game!
            // keep looking for the server IP backward
          } else if (event is EvConnectInitiated) {
            if (isInGame && lastServerAddress == null) {
               lastServerAddress = event.target;
            }
          } else if (event is EvMapLoaded) {
            if (isInGame && lastMapName == null) {
               lastMapName = event.mapName;
            }
          }
        }

        if (isInGame && lastServerAddress != null && !lastServerAddress.contains('loopback')) {
          _currentState = _currentState.copyWith(
            state: GameState.inGame,
            serverAddress: lastServerAddress,
            mapName: lastMapName ?? '',
          );
          _isInLoopbackMode = false;
          LogService.d('[ConsoleLog] 历史: 用户当前在服务器中: $lastServerAddress');
        } else {
          _currentState = _currentState.copyWith(
            state: GameState.mainMenu,
            serverAddress: '',
            mapName: '',
          );
          LogService.d('[ConsoleLog] 历史: 用户当前在主菜单');
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
    if (line.isEmpty) return;

    final event = CS2LogParser.parse(line);
    if (event == null) return;

    if (event is EvConnectInitiated) {
      final newServer = event.target;
      _targetServer = newServer;
      _isLoopbackFallback = false;
      _isInLoopbackMode = newServer.contains('loopback');
      LogService.d('[ConsoleLog] 解析到开始连接: $_targetServer');
      
      if (!_isInLoopbackMode) {
        _updateConnectionState(
          GameState.connecting,
          serverAddress: newServer,
          rawLine: line,
        );
      }
    } else if (event is EvSignonState) {
      if (_isInLoopbackMode) return;
      
      LogService.d('[ConsoleLog] 解析到握手状态: ${event.state} (${event.stateName})');
      
      if (event.state == 2) {
        _updateConnectionState(
          GameState.loading,
          rawLine: line,
        );
      } else if (event.state >= 5) {
        _updateConnectionState(
          GameState.inGame,
          serverAddress: _currentState.serverAddress,
          rawLine: line,
        );
        _targetServer = '';
      }
    } else if (event is EvDisconnect) {
      if (_isInLoopbackMode) return;
      LogService.d('[ConsoleLog] 解析到断开连接: ${event.reason}, 服满: ${event.isServerFull}');
      


      final state = event.isServerFull ? GameState.serverFull : GameState.failed;
      
      _updateConnectionState(
        state,
        serverAddress: '',
        rawLine: line,
      );
    } else if (event is EvMapLoaded) {
      if (_isInLoopbackMode) return;
      _updateConnectionState(
        GameState.loading,
        mapName: event.mapName,
        rawLine: line,
      );
    } else if (event is EvMainMenu) {
      LogService.d('[ConsoleLog] 解析到主菜单');
      _updateConnectionState(
        GameState.mainMenu,
        serverAddress: '',
        rawLine: line,
      );
      _targetServer = '';
      _isLoopbackFallback = false;
      _isInLoopbackMode = true;
    }
  }

  /// 更新连接状态
  void _updateConnectionState(
    GameState state, {
    String? serverAddress,
    String? mapName,
    String? rawLine,
  }) {
    _currentState = _currentState.copyWith(
      state: state,
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
      details: state.name,
    );

    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }

    LogService.d('[ConsoleLog] 状态更新: $state');
  }

  /// 获取状态显示文本（用于调试或日志）
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
        return '未知';
      case GameState.gameStarting:
        return '游戏启动中';
    }
  }
}
