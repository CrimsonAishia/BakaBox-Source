import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'parser/cs2_engine_events.dart';
import 'parser/cs2_log_parser.dart';

import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import 'game_launcher_service.dart';
import 'game_path_service.dart';
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
    bool clearErrorMessage = false,
    bool? condebugEnabled,
  }) {
    return ConsoleLogState(
      available: available ?? this.available,
      state: state ?? this.state,
      serverAddress: serverAddress ?? this.serverAddress,
      mapName: mapName ?? this.mapName,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
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

  /// 语义等价（不含 [lastUpdate]，因为它每次都变，参与比较等于永不 dedup）。
  ///
  /// `_updateState` 会用它跳过与当前状态语义相同的 emit，
  /// 避免下游（OBS / 热身 / 挤服守护 / 比分上传）反复处理无变化的事件。
  bool sameStateAs(ConsoleLogState other) {
    return available == other.available &&
        state == other.state &&
        serverAddress == other.serverAddress &&
        mapName == other.mapName &&
        errorMessage == other.errorMessage &&
        condebugEnabled == other.condebugEnabled;
  }
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
  // 最近一次真正 emit 出去的状态，用来做去重比较。
  // 不能用 _currentState 本身：调用方通常已经先 `_currentState = copyWith(...)`
  // 再调 _updateState，导致 prev 和 next 指向同一个对象。
  ConsoleLogState _lastEmittedState = const ConsoleLogState();
  bool _isMonitoring = false;
  bool _isCancelled = false;

  // 日志文件监控
  int _lastFileSize = 0;
  int _lastReadPos = 0;
  String? _logFilePath;

  // 未处理完的字节缓冲（处理"半行"和跨 chunk 的多字节 UTF-8）
  //
  // 500ms 轮询可能读到尚未写完整的行（结尾没有 \n），或一个多字节 UTF-8
  // 字符被切成两半。直接按当前 chunk split('\n') + fromCharCodes 会丢失这一
  // 行的信号（如进服 / 满员），从而触发误重试。这里以字节为单位缓冲，仅在
  // 遇到换行符 0x0A 时才把完整行交给解析器，剩余不完整的尾部留待下次拼接。
  final List<int> _pendingBytes = [];

  // 缓冲上限：防止异常情况下（始终没有换行符）无限增长
  static const int _maxPendingBytes = 1024 * 1024; // 1MB

  // 游戏路径检测缓存（避免重复检测）
  bool _gamePathDetectionAttempted = false;
  String? _cachedGamePath;
  // 并发保护 —— 500ms 轮询期间可能有多个调用者同时进入
  // detectGamePath，用共享 Future 让并发调用等在同一次异步检测上，避免重复
  // 触发耗时的进程扫描。
  Future<String?>? _pathDetectionFuture;

  // 单块读取分片大小，防止一次性读取巨型 diff 导致 OOM
  static const int _readChunkSize = 512 * 1024; // 512 KB

  // 连接目标追踪
  String _targetServer = '';
  bool _isLoopbackFallback = false;
  bool _isInLoopbackMode = false; // 是否处于 loopback 模式（主菜单背景服务器）

  // condebug 状态刷新：
  // - _checkLogFile 里不再硬编码 condebugEnabled=true。
  // - 不再自己额外轮询 isCS2LaunchedWithCondebug()：GameStatusService 已经每
  //   3s 检测一次并维护权威的 isMonitorable，只需在 _onGameStatusChanged
  //   里镜像它即可。同时 startMonitoring 会先读取一次 GameStatusService
  //   的当前值，覆盖启动瞬间还没 emit 事件的空窗期。

  // 事件历史
  final List<ConsoleLogEvent> _events = [];
  static const int _maxEvents = 100;

  // 定时器
  Timer? _monitorTimer;
  // 500ms 轮询存在长尾（例如首次 attach + I/O 慢盘），加锁避免重入并发
  bool _isCheckingLogFile = false;
  // 轮询频率自适应。游戏运行时用高频（500ms）保证连接 / 断开
  // 事件能及时抓到；游戏未运行时降到 2s，纯粹做"日志文件出现"探测，
  // 避免笔记本每天数十万次 wakeup。切换通过 _applyPollInterval 完成。
  Duration _currentPollInterval = const Duration(milliseconds: 500);
  static const Duration _pollActive = Duration(milliseconds: 500);
  static const Duration _pollIdle = Duration(seconds: 2);

  // 把连接监控 completer / cleanup 提到实例上，
  // 让 cancelConnectionMonitor() 能立即完成，不再依赖状态流下一次 emit。
  Completer<ConnectionStatusResult>? _monitorCompleter;
  void Function()? _monitorCleanup;

  // 等待类操作（waitForMainMenu / waitForAvailable /
  // waitForGameFullyLoaded）注册在此，cancelConnectionMonitor 会同步唤醒。
  // 之前它们只在状态流触发时才检查 _isCancelled，会导致取消后仍要等到 maxWait。
  final List<void Function()> _cancelListeners = [];

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
        // 使用共享 Future 避免并发调用重复触发耗时的进程扫描。
        // 500ms 轮询里可能多个 tick 同时到达此处，如果各自都 await
        // detectGamePath()，就会造成多个 wmic/nativeProcess 扫描并行执行。
        _pathDetectionFuture ??= _detectGamePathOnce();
        gamePath = await _pathDetectionFuture;
      }
    } else {
      // 设置中有配置，重置检测缓存（用户可能更新了设置）
      _gamePathDetectionAttempted = false;
      _cachedGamePath = null;
      _pathDetectionFuture = null;
    }

    if (gamePath == null || gamePath.isEmpty) {
      return null;
    }

    // CS2 控制台日志路径: <游戏路径>/game/csgo/console.log
    return '$gamePath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}console.log';
  }

  /// 单次检测游戏路径，检测完成后置位缓存与已尝试标志。
  Future<String?> _detectGamePathOnce() async {
    LogService.d('[ConsoleLog] 设置中未配置游戏路径，尝试自动检测');
    try {
      final path = await _gameLauncher.detectGamePath();
      _cachedGamePath = path;
      return path;
    } catch (e) {
      LogService.w('[ConsoleLog] 自动检测游戏路径失败: $e');
      _cachedGamePath = null;
      return null;
    } finally {
      _gamePathDetectionAttempted = true;
      // 保留 _pathDetectionFuture 引用即可：后续调用会走
      // _gamePathDetectionAttempted 的快速路径，不再触发检测。
    }
  }

  /// 重置游戏路径检测缓存（当用户更新设置时调用）
  ///
  /// 把已经被 [_checkLogFile] 缓存下来的 [_logFilePath] 也
  /// 一并清掉，否则用户在设置里改了游戏路径后，仍然在监控旧路径下的
  /// console.log，直到应用重启才生效。下一次 tick 会重新走
  /// [getLogFilePath] 拿到最新路径。
  void resetGamePathCache() {
    _gamePathDetectionAttempted = false;
    _cachedGamePath = null;
    _pathDetectionFuture = null;
    _logFilePath = null;
    // 换路径了，旧文件的读偏移已经没有意义
    _lastFileSize = 0;
    _lastReadPos = 0;
    _pendingBytes.clear();
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

    // 命令行扫描可能因权限 / 进程枚举失败抛异常。
    // 之前未加保护会让整个 checkAvailability / startMonitoring 因这一处
    // 崩溃而无法进入监控。这里降级为"未启用 condebug"继续走后续判断。
    bool condebugEnabled = false;
    try {
      condebugEnabled = await _gameLauncher.isCS2LaunchedWithCondebug();
    } catch (e) {
      LogService.w('[ConsoleLog] 检测 -condebug 失败: $e');
    }

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
  ///
  /// 返回是否成功进入监控循环。之前失败时静默返回 void，导致
  /// [monitorConnection] 只能坐等 maxTimeout 才知道监控没起来。
  Future<bool> startMonitoring() async {
    if (_isMonitoring) {
      return true;
    }

    // 非桌面平台直接跳过，避免在移动端也起 500ms 轮询。
    if (!isDesktopPlatform) {
      LogService.d('[ConsoleLog] 非桌面平台，跳过监控');
      return false;
    }

    // 启动前先验证路径是否有效，避免因磁盘更换导致后续全部无响应
    final pathValidation = await GamePathService().verifyCurrentPaths();
    if (!pathValidation.isValid) {
      LogService.w('[ConsoleLog] 路径失效，停止监控并等待用户重新配置: ${pathValidation.error}');
      return false;
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

    // 初始化状态。condebug 直接读 GameStatusService 权威值，
    // 而不是自己扫描进程，两个 service 保持一致来源。
    final bootCondebug = _readCondebugFromGameStatus(
      fallback: availability['condebugEnabled'] == true,
    );
    _currentState = ConsoleLogState(
      available: availability['available'] == true,
      state: GameState.mainMenu,
      condebugEnabled: bootCondebug,
      lastUpdate: DateTime.now(),
    );

    // 监听游戏状态变化（游戏退出时重置状态；游戏运行 / condebug 变化时同步）
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
        _pendingBytes.clear();
        LogService.d('[ConsoleLog] 监控从文件位置 $_lastReadPos 开始（只读取新内容）');

        // 分析历史日志，恢复当前状态
        await _analyzeHistoryAndRestoreState(file);
      } else {
        _lastFileSize = 0;
        _lastReadPos = 0;
        _pendingBytes.clear();
      }
    }

    _updateState(_currentState);

    // 起始轮询频率根据当前游戏状态决定。
    _currentPollInterval = _pickPollInterval();
    _startPollingWithCurrentInterval();

    LogService.d(
      '[ConsoleLog] 控制台日志监控已启动 (轮询间隔 ${_currentPollInterval.inMilliseconds}ms)',
    );
    return true;
  }

  /// 根据 GameStatusService 的当前 isRunning 选择轮询间隔。
  Duration _pickPollInterval() {
    try {
      return GameStatusService().isGameRunning ? _pollActive : _pollIdle;
    } catch (_) {
      return _pollActive; // 拿不到就保守用高频
    }
  }

  /// 启动 / 重启 `_monitorTimer` 使用当前 [_currentPollInterval]
  void _startPollingWithCurrentInterval() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_currentPollInterval, (_) {
      _checkLogFile();
    });
  }

  /// 若目标间隔和当前不一致则重启定时器
  void _syncPollInterval() {
    if (!_isMonitoring) return;
    final target = _pickPollInterval();
    if (target == _currentPollInterval) return;
    _currentPollInterval = target;
    _startPollingWithCurrentInterval();
    LogService.d('[ConsoleLog] 轮询间隔切换为 ${target.inMilliseconds}ms');
  }

  /// 从 GameStatusService 读取 condebug 值（避免自己重复扫描进程）
  bool _readCondebugFromGameStatus({required bool fallback}) {
    try {
      return GameStatusService().isMonitorable;
    } catch (_) {
      return fallback;
    }
  }

  /// 游戏状态变化处理
  void _onGameStatusChanged(GameStatusEvent event) {
    // 游戏开 / 关时同步切换轮询频率
    _syncPollInterval();

    if (!event.isRunning) {
      // 游戏退出，重置连接类状态。
      //
      // 不在这里改 `available`。文件是否可读由 [_checkLogFile]
      // 根据文件真实存在情况维护——游戏退出时 console.log 通常仍在磁盘上，
      // 之前把 `available` 置 false 会导致下一次 500ms tick 又被翻回 true，
      // 让下游订阅者看到 false→true 的假抖动。
      LogService.d('[ConsoleLog] 游戏已退出，重置状态');
      _currentState = _currentState.copyWith(
        state: GameState.unknown,
        serverAddress: '',
        mapName: '',
        condebugEnabled: false,
      );
      _targetServer = '';
      _isLoopbackFallback = false;
      _isInLoopbackMode = false;
      _updateState(_currentState);
      return;
    }

    // 游戏运行 / condebug 参数状态由 GameStatusService 权威维护，
    // 这里镜像到 currentState，避免和进程扫描来源不一致造成的假死。
    if (event.isMonitorable != _currentState.condebugEnabled) {
      _currentState = _currentState.copyWith(
        condebugEnabled: event.isMonitorable,
      );
      _updateState(_currentState);
      LogService.d('[ConsoleLog] condebug 状态同步为: ${event.isMonitorable}');
    }
  }

  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _gameStatusSubscription?.cancel();
    _gameStatusSubscription = null;
    _isMonitoring = false;
    _isCheckingLogFile = false;
    _pendingBytes.clear();

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

    _updateState(_currentState);
    LogService.d('[ConsoleLog] 状态已重置');
  }

  /// 取消当前的连接监控（不停止日志监控服务）
  ///
  /// 立即完成正在等待的 [monitorConnection] Completer，
  /// 而不是让调用方被动等到 [maxTimeout] 才拿到 cancelled 结果。
  ///
  /// 同时唤醒所有注册在 [_cancelListeners] 上的等待类操作
  /// （如 [waitForMainMenu] / [waitForAvailable]），避免它们只在下一次
  /// 状态流事件时才注意到 _isCancelled。
  void cancelConnectionMonitor() {
    _isCancelled = true;

    // 先唤醒普通 wait 类操作
    final listeners = List<void Function()>.from(_cancelListeners);
    _cancelListeners.clear();
    for (final cb in listeners) {
      try {
        cb();
      } catch (e) {
        LogService.w('[ConsoleLog] cancel listener 异常: $e');
      }
    }

    // 再处理 monitorConnection
    final cleanup = _monitorCleanup;
    final completer = _monitorCompleter;
    _monitorCleanup = null;
    _monitorCompleter = null;
    cleanup?.call();
    if (completer != null && !completer.isCompleted) {
      completer.complete(ConnectionStatusResult.cancelled());
    }
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

    // 监控启动失败（非桌面平台 / 路径失效）时立即返回失败，
    // 不再让调用方傻等 maxTimeout。
    final ok = await startMonitoring();
    if (!ok) {
      return ConnectionStatusResult.failed('监控服务未启动（游戏路径失效或不可用）');
    }

    // 把"取消上一次 monitorConnection"放在 await
    // 之后。原本放在 await 之前，两个 monitorConnection 若在 startMonitoring
    // 的 await 里交叠，后来者做取消检查时前一个还没把 completer 挂上，
    // 结果两个 completer 都被登记，最先设置的那一个会被后者悄悄覆盖，成为
    // 无法通过 cancelConnectionMonitor 唤醒的"孤儿"。
    //
    // 先把引用抓到本地再 cleanup，避免 cleanup 内的 identical
    // 检查把 _monitorCompleter 置 null 后我们再取到 null。
    final prevCleanup = _monitorCleanup;
    final prevCompleter = _monitorCompleter;
    _monitorCleanup = null;
    _monitorCompleter = null;
    prevCleanup?.call();
    if (prevCompleter != null && !prevCompleter.isCompleted) {
      prevCompleter.complete(ConnectionStatusResult.cancelled());
    }

    final completer = Completer<ConnectionStatusResult>();
    StreamSubscription<ConsoleLogState>? subscription;
    Timer? timeoutTimer;

    // 清理回调
    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
      if (identical(_monitorCompleter, completer)) {
        _monitorCompleter = null;
        _monitorCleanup = null;
      }
    }

    _monitorCompleter = completer;
    _monitorCleanup = cleanup;

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
  /// 返回 true 表示已回到主菜单，false 表示超时（或被取消）
  Future<bool> waitForMainMenu({
    Duration maxWait = const Duration(seconds: 30),
  }) async {
    _isCancelled = false;

    // 如果当前已经是主菜单，直接返回（极速被拒载时经常发生）
    if (_currentState.state == GameState.mainMenu) {
      LogService.d('[ConsoleLog] 检测到当前已经在主菜单，无需等待，直接返回');
      return true;
    }

    LogService.d('[ConsoleLog] 开始等待回到主菜单...');

    // 使用 Completer 等待状态流中的 mainMenu 状态
    final completer = Completer<bool>();
    StreamSubscription<ConsoleLogState>? subscription;
    Timer? timeoutTimer;
    // 注册到全局 cancel 列表，让 cancelConnectionMonitor 能
    // 立即唤醒本 wait，而不是等到 maxWait 才返回。
    late final void Function() onCancel;

    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
      _cancelListeners.remove(onCancel);
    }

    onCancel = () {
      cleanup();
      if (!completer.isCompleted) {
        LogService.d('[ConsoleLog] waitForMainMenu 被取消');
        completer.complete(false);
      }
    };
    _cancelListeners.add(onCancel);

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
        onCancel();
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
  ///
  /// 先把在飞的 monitorConnection / wait 类等待方以 cancelled
  /// 唤醒，再停监控、关流。之前不 cancel 会导致这些 Future 只能等到自己的
  /// maxTimeout 才结束（甚至永远吊着），期间它们回调里对 _stateController
  /// 的操作也会命中 close 后 add 的异常。
  void dispose() {
    cancelConnectionMonitor();
    stopMonitoring();
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }


  /// 更新状态
  ///
  /// `dispose()` 之后仍可能有正在飞的异步任务（例如条件刷新
  /// 或 raf.read）回调回来试图更新状态；此时 [_stateController] 已经 close
  /// 会抛 StateError。在这里守一次，让 dispose 后的迟到调用变成静默 no-op。
  ///
  /// 语义等价的连续状态不再向下游广播。之前每 500ms tick 只要走过
  /// "首次可用"分支就会 emit；解析新行时 [_updateConnectionState] 也总是 emit，
  /// 大量重复事件让 OBS / 热身 / 挤服守护做无谓的 refresh。
  void _updateState(ConsoleLogState newState) {
    _currentState = newState;
    if (_stateController.isClosed) return;
    if (_lastEmittedState.sameStateAs(newState)) return;
    _lastEmittedState = newState;
    _stateController.add(newState);
  }

  /// 检查日志文件变化
  Future<void> _checkLogFile() async {
    // 重入保护：500ms 轮询在慢盘/多字节日志上可能超过一个 tick，
    // 未加锁时会出现两次 read 指针错位。
    if (_isCheckingLogFile) return;
    _isCheckingLogFile = true;
    try {
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
        _pendingBytes.clear();
        return;
      }

      try {
        final stat = await file.stat();

        // 如果之前不可用，现在可用了
        //
        // 不再"文件存在即断言 condebug=true"。
        // 真实的 -condebug 状态由 GameStatusService 权威维护，
        // 通过 _onGameStatusChanged 事件流镜像到 currentState，
        // 这里只更新 available 字段，避免残留旧文件让上层误以为实时监控在工作。
        if (!_currentState.available) {
          _currentState = _currentState.copyWith(
            available: true,
            // 首次激活时同步一次 GameStatusService 的当前值，
            // 覆盖尚未 emit 首个事件的空窗期
            condebugEnabled: _readCondebugFromGameStatus(
              fallback: _currentState.condebugEnabled,
            ),
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
          _pendingBytes.clear();
          // 重置连接追踪状态
          _targetServer = '';
          _isLoopbackFallback = false;
          _isInLoopbackMode = false;
        }

        // 读取新内容
        await _readNewContent(currentSize);
        // 用真实的读进度更新 lastFileSize：若发生短读（分块
        // 读取里可能出现），下次轮询会继续从 _lastReadPos 追读剩余尾部。
        _lastFileSize = _lastReadPos;
      } catch (e) {
        // stat / open 异常必须把 available 同步为 false，
        // 否则会出现"上层判断可读、底层持续报错"的读取状态不一致。
        LogService.e('[ConsoleLog] 检查日志文件失败', e);
        if (_currentState.available) {
          _currentState = _currentState.copyWith(available: false);
          _updateState(_currentState);
        }
      }
    } finally {
      _isCheckingLogFile = false;
    }
  }

  /// 读取新增的日志内容
  ///
  /// 改为分块（512KB）读取，避免监控停顿后一次性 diff 过大
  /// 触发内存峰值 / GC 卡顿。
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

        int remaining = currentSize - _lastReadPos;
        while (remaining > 0) {
          final want = remaining > _readChunkSize ? _readChunkSize : remaining;
          final chunk = await raf.read(want);
          if (chunk.isEmpty) break; // 防御：读到 EOF 之前的意外空返回

          _processBytes(chunk);

          remaining -= chunk.length;
          _lastReadPos += chunk.length;

          if (chunk.length < want) {
            // 短读：文件在被读取过程中被截断或读到当前末尾，安全退出
            break;
          }
        }
      } finally {
        await raf.close();
      }
    } catch (e) {
      // 读取失败时把 available 同步为 false。
      // 之前仅重置读指针后继续保持 available=true，导致上层认为日志"可读"
      // 却始终拿不到内容。condebugEnabled 由 GameStatusService 事件驱动，
      // 这里保持不变即可。
      LogService.e('[ConsoleLog] 读取日志文件失败', e);
      _lastReadPos = 0;
      _pendingBytes.clear();
      if (_currentState.available) {
        _currentState = _currentState.copyWith(
          available: false,
          errorMessage: '日志文件读取失败: $e',
        );
        _updateState(_currentState);
      }
    }
  }

  /// 将新读到的字节追加到缓冲，按换行符切出完整行交给解析器
  ///
  /// - 以字节（而非字符串）为单位查找换行符 0x0A，避免跨 chunk 的多字节
  ///   UTF-8 字符被 [String.fromCharCodes] 错误解码导致整行匹配失败。
  /// - 每个完整行用 [utf8] 解码（allowMalformed，遇到坏字节不抛异常）。
  /// - 最后不完整的一段（无换行符结尾）保留在 [_pendingBytes] 等待下次拼接。
  void _processBytes(List<int> newBytes) {
    if (newBytes.isEmpty) return;

    _pendingBytes.addAll(newBytes);

    int start = 0;
    for (int i = 0; i < _pendingBytes.length; i++) {
      if (_pendingBytes[i] == 0x0A) {
        // [start, i) 为一行（不含换行符），兼容 \r\n（去掉结尾 \r）
        var end = i;
        if (end > start && _pendingBytes[end - 1] == 0x0D) {
          end--;
        }
        final lineBytes = _pendingBytes.sublist(start, end);
        final line = utf8.decode(lineBytes, allowMalformed: true);
        // 单行解析失败必须就地降级，不能让异常冒到
        // [_readNewContent] 的 catch。那里会把 _lastReadPos 归零，下一 tick
        // 又会从头重读、再次撞到同一行、再次抛异常 —— 变成静默的死循环。
        try {
          _parseLine(line);
        } catch (e) {
          LogService.w('[ConsoleLog] 解析行失败，跳过: $e');
        }
        start = i + 1;
      }
    }

    // 移除已处理的完整行，保留不完整的尾部
    if (start > 0) {
      _pendingBytes.removeRange(0, start);
    }

    // 防御：缓冲异常膨胀（始终无换行符）时丢弃，避免内存无限增长
    if (_pendingBytes.length > _maxPendingBytes) {
      LogService.w('[ConsoleLog] 行缓冲超过上限，丢弃未完成内容');
      _pendingBytes.clear();
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
      // 边界：只有游戏带 -condebug 启动（可监控）时，console.log 才是"当前这次
      // 会话"实时写入的。否则文件是上一次运行残留的旧日志，回溯它会把过期的
      // "在服务器中"状态错误地恢复出来。因此不可监控时直接回落到主菜单，等真正
      // 可监控后再依靠实时解析更新状态。
      bool monitorable = false;
      try {
        monitorable = GameStatusService().isMonitorable;
      } catch (_) {}
      if (!monitorable) {
        _currentState = _currentState.copyWith(
          state: GameState.mainMenu,
          serverAddress: '',
          mapName: '',
        );
        LogService.d('[ConsoleLog] 历史: 游戏不可监控，跳过回溯，按主菜单处理');
        return;
      }

      final stat = await file.stat();
      final fileSize = stat.size;

      // 用户可能在打开软件之前就已经进入了服务器：此时"连接服务器"的日志行
      // （Sending connect to / Opened Steam Net Connection / Connected to 'addr'）
      // 是在很久以前进服那一刻写入的。如果只回溯末尾一小段日志，就会找不到
      // 服务器地址，从而被误判为"在主菜单"，导致 OBS / 热身一直显示"等待进入
      // 服务器"。因此这里回溯尽可能多的历史日志来定位地址。
      const maxReadSize = 16 * 1024 * 1024; // 最多回溯 16MB，覆盖长时间在服的会话
      final startPos = fileSize > maxReadSize ? fileSize - maxReadSize : 0;

      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(startPos);

        // 分块（512KB）读取 + 分块 UTF-8 解码，避免 16MB 单缓冲
        // 造成的 GC / OOM 尖峰。同 _readNewContent 的处理思路，也用字节缓冲
        // 保证跨 chunk 的多字节 UTF-8 / 半行不会被错误解析。
        final List<String> lines = [];
        final buffer = <int>[];
        int remaining = fileSize - startPos;
        while (remaining > 0) {
          final want = remaining > _readChunkSize ? _readChunkSize : remaining;
          final chunk = await raf.read(want);
          if (chunk.isEmpty) break;
          remaining -= chunk.length;
          buffer.addAll(chunk);

          // 拆完整行
          int lineStart = 0;
          for (int i = 0; i < buffer.length; i++) {
            if (buffer[i] == 0x0A) {
              var end = i;
              if (end > lineStart && buffer[end - 1] == 0x0D) end--;
              lines.add(
                utf8.decode(
                  buffer.sublist(lineStart, end),
                  allowMalformed: true,
                ),
              );
              lineStart = i + 1;
            }
          }
          if (lineStart > 0) {
            buffer.removeRange(0, lineStart);
          }
        }
        // 处理最后一段没有换行符的尾部
        if (buffer.isNotEmpty) {
          lines.add(utf8.decode(buffer, allowMalformed: true));
        }

        String? lastServerAddress;
        String? lastMapName;
        bool isInGame = false;

        bool isUsableAddress(String? addr) =>
            addr != null && addr.isNotEmpty && !addr.contains('loopback');

        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          // 单行解析失败不能让整个历史回溯崩掉，否则会走到
          // 外层 catch 把整段 history 恢复能力都吃掉。
          CS2EngineEvent? event;
          try {
            event = CS2LogParser.parse(line);
          } catch (e) {
            LogService.w('[ConsoleLog] 历史行解析失败，跳过: $e');
            continue;
          }
          if (event == null) continue;

          if (event is EvMainMenu || event is EvDisconnect) {
            // 回溯到上一次回主菜单 / 断开，即当前在服会话的起始边界。
            // 连接相关日志行都在该边界之后，到这里已经扫描完毕。
            break;
          } else if (event is EvSignonState) {
            if (event.state >= 5) {
              isInGame = true; // In game!
            }
            // "Connected to 'IP:port'" 会带地址，作为兜底来源
            if (isInGame &&
                lastServerAddress == null &&
                isUsableAddress(event.address)) {
              lastServerAddress = event.address;
            }
            // keep looking for the server IP backward
          } else if (event is EvConnectOpened) {
            // 开始连接真实远程服务器的最可靠信号，携带解析后的 IP:port
            if (isInGame &&
                lastServerAddress == null &&
                isUsableAddress(event.address)) {
              lastServerAddress = event.address;
            }
          } else if (event is EvConnectInitiated) {
            if (isInGame &&
                lastServerAddress == null &&
                isUsableAddress(event.target)) {
              lastServerAddress = event.target;
            }
          } else if (event is EvMapLoaded) {
            if (isInGame && lastMapName == null) {
              lastMapName = event.mapName;
            }
          }
        }

        if (isInGame && isUsableAddress(lastServerAddress)) {
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
          mapName: '', // 新连接清空旧地图，避免残留上一个服务器的地图名
          clearErrorMessage: true,
          rawLine: line,
        );
      }
    } else if (event is EvConnectOpened) {
      // 引擎已为真实远程服务器打开底层连接 → 确定进入"连接中"。
      // 这是比 "Sending connect to" 更早、更可靠的信号：超时场景下
      // "Sending connect to" 可能永不出现，仅靠它就能退出 loopback 模式，
      // 使后续的超时/断开信号能被正常处理，避免卡在"连接中"。
      _isLoopbackFallback = false;
      _isInLoopbackMode = false;
      // 地址用解析后的 IP:port（与 "Sending connect to" 同源，均为解析后 IP，
      // 域名仅出现在未被解析的 "Remote Connect (domain)" 行）。该事件早于
      // "Sending connect to" 到达，是"正在连接此地址"的权威信号。
      // 注意：连接中/加载中的地址不参与 location 匹配（下游仅在 inGame 时
      // 才信任 serverAddress），因此不会引入地址比对副作用。
      _targetServer = event.address;
      LogService.d('[ConsoleLog] 解析到底层连接已打开: ${event.address}');
      _updateConnectionState(
        GameState.connecting,
        serverAddress: event.address,
        mapName: '', // 新连接清空旧地图
        clearErrorMessage: true,
        rawLine: line,
      );
    } else if (event is EvSignonState) {
      if (_isInLoopbackMode) return;

      LogService.d('[ConsoleLog] 解析到握手状态: ${event.state} (${event.stateName})');

      if (event.state == 2) {
        // "[Client] CL: Connected to 'addr'" 可能携带地址。若此前的
        // "Sending connect to" 行被漏读（半行/轮询间隙）导致 serverAddress
        // 为空，这里用它兜底，避免后续 signon>=5 因缺地址被误判为"主菜单背景"。
        final addr = event.address;
        if (addr != null && addr.contains('loopback')) {
          // 实为主菜单背景的 loopback 连接
          _targetServer = '';
          _isLoopbackFallback = false;
          _isInLoopbackMode = true;
          return;
        }
        if (addr != null &&
            addr.isNotEmpty &&
            _currentState.serverAddress.isEmpty) {
          _targetServer = addr;
          LogService.d('[ConsoleLog] 用 Connected 行兜底服务器地址: $addr');
          _updateConnectionState(
            GameState.loading,
            serverAddress: addr,
            rawLine: line,
          );
        } else {
          _updateConnectionState(GameState.loading, rawLine: line);
        }
      } else if (event.state >= 5) {
        if (_currentState.serverAddress.isEmpty) {
          LogService.d('[ConsoleLog] 忽略无地址的进入游戏状态（推测为主菜单背景）');
          _updateConnectionState(
            GameState.mainMenu,
            serverAddress: '',
            mapName: '',
            rawLine: line,
          );
          _targetServer = '';
          _isLoopbackFallback = false;
          _isInLoopbackMode = true;
          return;
        }

        _updateConnectionState(
          GameState.inGame,
          serverAddress: _currentState.serverAddress,
          rawLine: line,
        );
        _targetServer = '';
      }
    } else if (event is EvDisconnect) {
      LogService.d(
        '[ConsoleLog] 解析到断开连接: ${event.reason}, 服满: ${event.isServerFull}',
      );

      if (event.isConnectFailure) {
        _isInLoopbackMode = false;
        _targetServer = '';

        String? errMsg;
        if (event.reason.contains('HOSTSTATE_IDLE')) {
          errMsg = '下载地图失败等异常';
        }

        _updateConnectionState(
          GameState.failed,
          serverAddress: _currentState.serverAddress,
          errorMessage: errMsg,
          rawLine: line,
        );
        return;
      }

      if (event.isServerFull) {
        _isInLoopbackMode = false;
        _targetServer = '';
        _updateConnectionState(
          GameState.serverFull,
          serverAddress: _currentState.serverAddress,
          rawLine: line,
        );
        return;
      }

      // 正常断开 (如 LOOPDEACTIVATE, LOOPSHUTDOWN)
      // 若当前已在 loopback 模式（主菜单），则无需处理
      if (_isInLoopbackMode) return;

      // 否则说明是从远程服务器正常断开（如自动切服、地图更换或换图过程中的断开）
      // 退回主菜单状态，等待后续的 connect 指令或重连
      _updateConnectionState(
        GameState.mainMenu,
        serverAddress: '',
        mapName: '', // 断开连接清空地图名
        clearErrorMessage: true,
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
        mapName: '', // 回到主菜单清空地图名
        clearErrorMessage: true,
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
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    _currentState = _currentState.copyWith(
      state: state,
      serverAddress: serverAddress ?? _currentState.serverAddress,
      mapName: mapName ?? _currentState.mapName,
      errorMessage: errorMessage,
      clearErrorMessage: clearErrorMessage,
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
