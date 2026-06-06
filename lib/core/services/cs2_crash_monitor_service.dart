import 'dart:async';
import 'dart:io';

import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import 'crash_inspector/crash_inspector.dart';
import 'game_path_service.dart';
import 'game_status_service.dart';

/// 检测到的新崩溃事件.
class Cs2CrashDetectedEvent {
  final CrashSummary summary;
  final DateTime detectedAt;

  const Cs2CrashDetectedEvent({
    required this.summary,
    required this.detectedAt,
  });
}

/// CS2 崩溃 (.mdmp) 监控服务 (单例, 仅桌面端有效).
///
/// 工作机制:
/// 1. 监听 [GameStatusService] 的状态流, 在游戏从运行 -> 退出时触发一次扫描.
/// 2. 扫描 `<游戏路径>/game/bin/win64/*.mdmp`, 与"游戏启动时"的快照对比,
///    新增的文件视为本次会话的崩溃.
/// 3. 解析 .mdmp -> [CrashSummary] 后通过 [crashStream] 广播.
///
/// UI 层 (例如 desktop_home_screen) 订阅 [crashStream] 弹出对话框.
class Cs2CrashMonitorService {
  static final Cs2CrashMonitorService _instance =
      Cs2CrashMonitorService._internal();
  factory Cs2CrashMonitorService() => _instance;
  Cs2CrashMonitorService._internal();

  final GamePathService _gamePathService = GamePathService();
  final GameStatusService _gameStatusService = GameStatusService();

  StreamSubscription<GameStatusEvent>? _statusSubscription;
  bool _initialized = false;

  /// 游戏开启时已存在的 .mdmp 文件路径. 用于在游戏关闭后筛出 "新增" 的崩溃文件.
  final Set<String> _baselineDumps = <String>{};

  /// 已经处理过的 dump 路径, 避免同一份文件重复弹窗.
  /// 使用有上限的环形列表 + 集合, 防止长期运行后无限增长.
  final Set<String> _seenDumps = <String>{};
  final List<String> _seenDumpsOrder = <String>[];
  static const int _seenDumpsCap = 200;

  /// 在内存中缓存上一次的扫描结果 (用于"未在游戏运行时收到状态事件"等边界情况).
  bool _baselineCaptured = false;

  /// 互斥标志: 同一时刻只允许一个 IO 任务 (抓基线 / 扫描) 在跑, 防止并发竞态.
  bool _ioBusy = false;

  /// 落盘容差: mdmp 在游戏崩溃后可能尚未写完, 加一段等待时间.
  static const Duration _dumpFlushGrace = Duration(milliseconds: 800);

  final _crashController = StreamController<Cs2CrashDetectedEvent>.broadcast();

  /// 检测到崩溃文件时的事件流.
  Stream<Cs2CrashDetectedEvent> get crashStream => _crashController.stream;

  /// 初始化 (仅桌面 Windows 生效).
  Future<void> initialize() async {
    if (_initialized) return;
    if (!PlatformUtils.isDesktopPlatform || !Platform.isWindows) {
      LogService.d('[Cs2CrashMonitor] 非 Windows 桌面平台, 跳过初始化');
      return;
    }
    _initialized = true;

    // 启动时如果游戏已经在运行, 提前抓一次基线.
    if (_gameStatusService.isGameRunning) {
      await _runIo(_captureBaseline);
    }

    _statusSubscription = _gameStatusService.statusStream.listen(_onStatus);
    LogService.d('[Cs2CrashMonitor] 已初始化');
  }

  void _onStatus(GameStatusEvent event) {
    if (event.isRunning) {
      // 游戏开启 (或重新检测到运行) -> 抓基线.
      // 仅在还没抓过 / 之前的会话已结束时抓, 避免每次状态刷新都扫一次.
      if (!_baselineCaptured) {
        unawaited(_runIo(_captureBaseline));
      }
    } else {
      // 游戏关闭 -> 与基线对比, 找出新增 dump.
      if (_baselineCaptured) {
        unawaited(_runIo(_scanForNewDumps));
      }
    }
  }

  /// 互斥执行 IO 任务: 同一时刻只允许一个抓基线 / 扫描在跑.
  ///
  /// GameStatusService 状态流可能在 3 秒轮询里短时间内连发多次事件, 配合
  /// async/await 会出现 "上一个还没跑完, 下一个又开始" 的并发竞态; 这里用一个
  /// 简单的标志位串行化所有 IO 任务. 任务多到挤压时直接丢弃, 因为下一次
  /// 事件总会再触发同样的逻辑.
  Future<void> _runIo(Future<void> Function() task) async {
    if (_ioBusy) return;
    _ioBusy = true;
    try {
      await task();
    } finally {
      _ioBusy = false;
    }
  }

  void _markSeen(String path) {
    if (_seenDumps.add(path)) {
      _seenDumpsOrder.add(path);
      while (_seenDumpsOrder.length > _seenDumpsCap) {
        final oldest = _seenDumpsOrder.removeAt(0);
        _seenDumps.remove(oldest);
      }
    }
  }

  Future<String?> _resolveDumpDir() async {
    final gamePath = await _gamePathService.getGamePath();
    if (gamePath == null || gamePath.isEmpty) return null;
    return '$gamePath\\game\\bin\\win64';
  }

  /// 抓取游戏启动时的 .mdmp 基线.
  Future<void> _captureBaseline() async {
    try {
      final dirPath = await _resolveDumpDir();
      if (dirPath == null) {
        LogService.d('[Cs2CrashMonitor] 未配置游戏路径, 跳过基线');
        return;
      }
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        LogService.d('[Cs2CrashMonitor] dump 目录不存在: $dirPath');
        // 即便目录不存在也算"已抓基线" (空集合), 这样新生成的 dump 仍能被发现.
        _baselineDumps.clear();
        _baselineCaptured = true;
        return;
      }
      final dumps = await _listDumps(dir);
      _baselineDumps
        ..clear()
        ..addAll(dumps);
      _baselineCaptured = true;
      LogService.d(
        '[Cs2CrashMonitor] 已抓取 .mdmp 基线 (${_baselineDumps.length} 个) -> $dirPath',
      );
    } catch (e) {
      LogService.e('[Cs2CrashMonitor] 抓取基线失败', e);
    }
  }

  /// 扫描新增 dump 并解析.
  Future<void> _scanForNewDumps() async {
    try {
      final dirPath = await _resolveDumpDir();
      if (dirPath == null) return;
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        _baselineCaptured = false;
        return;
      }

      // 给游戏一点时间把 mdmp 写完整再读, 避免 FormatException.
      await Future.delayed(_dumpFlushGrace);

      final current = await _listDumps(dir);
      // 取差集
      final newOnes = current
          .where((p) => !_baselineDumps.contains(p) && !_seenDumps.contains(p))
          .toList();

      if (newOnes.isEmpty) {
        LogService.d('[Cs2CrashMonitor] 游戏退出, 未发现新 .mdmp');
      } else {
        LogService.i('[Cs2CrashMonitor] 检测到 ${newOnes.length} 个新崩溃文件');
        // 按修改时间升序处理, 保证最旧的先弹 (一般实战中大概率只有 1 个).
        newOnes.sort((a, b) {
          try {
            final ta = File(a).statSync().modified;
            final tb = File(b).statSync().modified;
            return ta.compareTo(tb);
          } catch (_) {
            return 0;
          }
        });
        for (final path in newOnes) {
          _markSeen(path);
          await _analyzeAndEmit(path);
        }
      }

      // 不论结果如何, 把当前文件集合作为下次会话的基线.
      _baselineDumps
        ..clear()
        ..addAll(current);
      // 标记基线已结束, 等下一次"游戏启动"事件再重抓.
      _baselineCaptured = false;
    } catch (e) {
      LogService.e('[Cs2CrashMonitor] 扫描 dump 失败', e);
      _baselineCaptured = false;
    }
  }

  Future<List<String>> _listDumps(Directory dir) async {
    final results = <String>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File &&
            entity.path.toLowerCase().endsWith('.mdmp')) {
          results.add(entity.path);
        }
      }
    } catch (e) {
      LogService.w('[Cs2CrashMonitor] 列举 .mdmp 失败: $e');
    }
    return results;
  }

  Future<void> _analyzeAndEmit(String path) async {
    try {
      LogService.d('[Cs2CrashMonitor] 解析崩溃文件: $path');
      final summary = await CrashInspector.analyze(path);
      if (_crashController.isClosed) return;
      _crashController.add(
        Cs2CrashDetectedEvent(summary: summary, detectedAt: DateTime.now()),
      );
      LogService.i(
        '[Cs2CrashMonitor] 已分析: ${summary.fileName} severity=${summary.severity.name}',
      );
    } catch (e, st) {
      LogService.e('[Cs2CrashMonitor] 解析 .mdmp 失败: $path', e, st);
    }
  }

  /// 销毁 (热重载或退出时调用; 单例应用内一般不会用到).
  Future<void> dispose() async {
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    if (!_crashController.isClosed) {
      await _crashController.close();
    }
    _initialized = false;
  }
}
