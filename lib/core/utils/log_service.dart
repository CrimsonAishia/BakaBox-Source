import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'app_directory_service.dart';

/// 日志级别
enum LogLevel { debug, info, warning, error, fatal }

/// 统一的日志服务 - 支持全平台文件写入
///
/// 设计原则：
/// 1. 所有文件 I/O 操作在独立的 Zone 中异步执行，永不阻塞 UI
/// 2. 使用消息队列缓冲日志，批量写入提高性能
/// 3. 文件操作失败时降级到内存日志，保证服务可用
/// 4. 热重启时安全清理资源，避免文件句柄泄漏
class LogService {
  static Logger? _logger;
  static bool _initialized = false;
  static IOSink? _fileSink;
  static String? _currentLogFile;
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  static final _fileDateFormat = DateFormat('yyyy-MM-dd');

  /// 最多保留的日志文件数量（默认 7 个）
  static const int maxLogFiles = 7;

  /// 日志消息队列（避免频繁 I/O）
  static final Queue<String> _logQueue = Queue<String>();
  static Timer? _flushTimer;
  static bool _isWriting = false;
  static bool _isInitializing = false;

  /// 文件写入是否可用
  static bool _fileLoggingEnabled = true;

  /// 获取 logger 实例，如果未初始化则创建一个简单的 logger
  static Logger get _log {
    _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: kDebugMode ? 2 : 0,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
      level: kDebugMode ? Level.debug : Level.info,
    );
    return _logger!;
  }

  static Future<void> init() async {
    // 热重启检测：如果已初始化，安全清理
    if (_initialized) {
      debugPrint('检测到重新初始化，清理旧资源');
      await _safeCleanup();
    }

    // 确保 logger 已创建
    _log;

    // 异步初始化文件日志（不阻塞）
    _initFileLoggingAsync();

    // 启动定时刷新（每 500ms 批量写入）
    _startFlushTimer();

    _initialized = true;
    debugPrint('日志服务初始化完成');
  }

  /// 安全清理旧资源（不阻塞）
  static Future<void> _safeCleanup() async {
    _initialized = false;
    _isInitializing = false; // 重置初始化标志

    // 停止定时器
    _flushTimer?.cancel();
    _flushTimer = null;

    // 等待当前写入完成（最多 500ms）
    final deadline = DateTime.now().add(const Duration(milliseconds: 500));
    while (_isWriting && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // 强制重置写入标志（即使超时）
    if (_isWriting) {
      debugPrint('警告：写入操作超时，强制重置');
      _isWriting = false;
    }

    // 重置状态
    _fileLoggingEnabled = false;

    // 清空队列
    _logQueue.clear();

    // 异步关闭文件（不等待）
    final oldSink = _fileSink;
    _fileSink = null;
    _currentLogFile = null;

    if (oldSink != null) {
      // 在后台关闭，不阻塞
      Future.microtask(() async {
        try {
          await oldSink.flush().timeout(const Duration(seconds: 1));
          await oldSink.close().timeout(const Duration(seconds: 1));
        } catch (e) {
          debugPrint('关闭旧日志文件失败（已忽略）: $e');
        }
      });
    }
  }

  /// 启动定时刷新器
  static void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _flushQueueToFile();
    });
  }

  /// 异步初始化文件日志（不阻塞主线程）
  static void _initFileLoggingAsync() {
    // 防止重复初始化
    if (_isInitializing) return;
    _isInitializing = true;

    Future.microtask(() async {
      try {
        // 等待一小段时间，确保 _safeCleanup 完成
        await Future.delayed(const Duration(milliseconds: 100));

        // 再次检查是否已初始化（避免竞态条件）
        if (!_initialized) {
          _isInitializing = false;
          return;
        }

        final logsDir = Directory(AppDirectoryService.logsPath);
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }

        await _openLogFile();

        // 异步清理旧日志
        _cleanupOldLogs();

        debugPrint('文件日志初始化成功: $_currentLogFile');
      } catch (e) {
        debugPrint('文件日志初始化失败，降级到内存日志: $e');
        _fileLoggingEnabled = false;
      } finally {
        _isInitializing = false;
      }
    });
  }

  static Future<void> _openLogFile() async {
    final today = _fileDateFormat.format(DateTime.now());
    final logFile =
        '${AppDirectoryService.logsPath}${Platform.pathSeparator}$today.log';

    // 如果是同一个文件且已打开，直接返回
    if (_currentLogFile == logFile && _fileSink != null) return;

    try {
      // 关闭旧文件
      final oldSink = _fileSink;
      if (oldSink != null) {
        unawaited(_closeOldSink(oldSink));
      }

      // 打开新文件
      final file = File(logFile);
      _fileSink = file.openWrite(mode: FileMode.append);
      _currentLogFile = logFile;
      _fileLoggingEnabled = true;
    } catch (e) {
      debugPrint('打开日志文件失败: $e');
      _fileLoggingEnabled = false;
      _fileSink = null;
      _currentLogFile = null;
    }
  }

  /// 异步关闭旧的 sink，带超时保护
  static Future<void> _closeOldSink(IOSink sink) async {
    try {
      await sink.flush().timeout(const Duration(seconds: 1));
      await sink.close().timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('关闭旧日志文件失败（已忽略）: $e');
    }
  }

  /// 将日志消息加入队列（永不阻塞）
  static void _enqueueLog(String message) {
    try {
      _logQueue.add(message);

      // 队列过大时立即刷新（防止内存溢出）
      if (_logQueue.length > 100) {
        _flushQueueToFile();
      }
    } catch (e) {
      debugPrint('日志入队失败: $e');
    }
  }

  /// 批量刷新队列到文件（异步，不阻塞）
  static void _flushQueueToFile() {
    // 防止并发执行
    if (_isWriting) return;

    // 队列为空时直接返回
    if (_logQueue.isEmpty) return;

    // 文件不可用时，清空队列避免内存泄漏
    if (!_fileLoggingEnabled) {
      _logQueue.clear();
      return;
    }

    final sink = _fileSink;
    if (sink == null) {
      // 文件未打开，清空队列
      _logQueue.clear();
      return;
    }

    // 立即设置标志，防止并发
    _isWriting = true;

    // 提前取出要写入的数据（避免异步执行时队列被修改）
    final batch = <String>[];
    while (_logQueue.isNotEmpty && batch.length < 50) {
      batch.add(_logQueue.removeFirst());
    }

    // 在微任务中执行，避免阻塞当前帧
    Future.microtask(() async {
      try {
        // 再次检查初始化状态（可能在等待期间被清理）
        if (!_initialized) {
          debugPrint('服务已关闭，丢弃 ${batch.length} 条日志');
          return;
        }

        // 检查是否需要切换日志文件（跨天）
        final today = _fileDateFormat.format(DateTime.now());
        final expectedLogFile =
            '${AppDirectoryService.logsPath}${Platform.pathSeparator}$today.log';

        if (_currentLogFile != expectedLogFile) {
          await _openLogFile();
        }

        // 批量写入（使用当前有效的 sink）
        final currentSink = _fileSink;
        if (currentSink != null && batch.isNotEmpty && _fileLoggingEnabled) {
          currentSink.write(batch.join());
        } else if (batch.isNotEmpty) {
          // 文件不可用，丢弃数据（避免无限累积）
          debugPrint('文件不可用，丢弃 ${batch.length} 条日志');
        }
      } catch (e) {
        debugPrint('批量写入日志失败: $e');
        // 写入失败，丢弃数据并禁用文件日志
        _fileLoggingEnabled = false;
        _logQueue.clear(); // 清空队列避免内存泄漏
      } finally {
        _isWriting = false;
      }
    });
  }

  static void _writeToFile(
    LogLevel level,
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (!_fileLoggingEnabled) return;

    try {
      final timestamp = _dateFormat.format(DateTime.now());
      final levelStr = level.name.toUpperCase().padRight(5);
      final buffer = StringBuffer();
      buffer.writeln('[$timestamp] [$levelStr] [$tag] $message');
      if (error != null) buffer.writeln('  Error: $error');
      if (stackTrace != null) buffer.writeln('  StackTrace: $stackTrace');

      // 加入队列，不直接写入文件
      _enqueueLog(buffer.toString());
    } catch (e) {
      debugPrint('日志入队失败: $e');
    }
  }

  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _log.d(message, error: error, stackTrace: stackTrace);
    if (kDebugMode) {
      _writeToFile(LogLevel.debug, 'General', message, error, stackTrace);
    }
  }

  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _log.i(message, error: error, stackTrace: stackTrace);
    _writeToFile(LogLevel.info, 'General', message, error, stackTrace);
  }

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _log.w(message, error: error, stackTrace: stackTrace);
    _writeToFile(LogLevel.warning, 'General', message, error, stackTrace);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _log.e(message, error: error, stackTrace: stackTrace);
    _writeToFile(LogLevel.error, 'General', message, error, stackTrace);
  }

  static void f(String message, [dynamic error, StackTrace? stackTrace]) {
    _log.f(message, error: error, stackTrace: stackTrace);
    _writeToFile(LogLevel.fatal, 'General', message, error, stackTrace);
  }

  static void api(
    String method,
    String url, {
    int? statusCode,
    String? requestData,
    String? responseData,
    dynamic error,
    Duration? duration,
  }) {
    final buffer = StringBuffer();
    buffer.write('[$method] $url');
    if (statusCode != null) buffer.write(' -> $statusCode');
    if (duration != null) buffer.write(' (${duration.inMilliseconds}ms)');
    if (requestData != null && kDebugMode) {
      buffer.write('\n📤 Request: $requestData');
    }
    if (responseData != null && kDebugMode) {
      buffer.write('\n📥 Response: $responseData');
    }

    final msg = buffer.toString();
    if (error != null) {
      _log.e(msg, error: error);
      _writeToFile(LogLevel.error, 'API', msg, error);
    } else if (statusCode != null && statusCode >= 400) {
      _log.w(msg);
      _writeToFile(LogLevel.warning, 'API', msg);
    } else {
      _log.i(msg);
      _writeToFile(LogLevel.info, 'API', msg);
    }
  }

  static void db(String operation, {String? table, dynamic error}) {
    final message = table != null
        ? '🗄️ DB $operation: $table'
        : '🗄️ DB $operation';
    if (error != null) {
      _log.e(message, error: error);
      _writeToFile(LogLevel.error, 'Database', message, error);
    } else {
      _log.d(message);
      if (kDebugMode) {
        _writeToFile(LogLevel.debug, 'Database', message);
      }
    }
  }

  static Future<String?> getLogDirectory() async {
    try {
      return AppDirectoryService.logsPath;
    } catch (e) {
      debugPrint('获取日志目录失败: $e');
      return null;
    }
  }

  static Future<void> flush() async {
    if (!_initialized) return;

    // 即使文件不可用，也尝试刷新队列（清空内存）
    _flushQueueToFile();

    // 等待写入完成（最多 2 秒）
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_isWriting && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 刷新文件缓冲
    if (_fileLoggingEnabled && _fileSink != null) {
      try {
        await _fileSink!.flush().timeout(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('刷新日志文件失败: $e');
      }
    }
  }

  static Future<void> clearLogs() async {
    try {
      // 停止定时器
      _flushTimer?.cancel();

      // 等待当前写入完成（最多 1 秒）
      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (_isWriting && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 强制重置写入标志（即使超时）
      if (_isWriting) {
        debugPrint('警告：写入操作超时，强制重置');
        _isWriting = false;
      }

      // 停止写入
      _fileLoggingEnabled = false;
      _logQueue.clear();

      // 关闭当前文件
      final oldSink = _fileSink;
      _fileSink = null;
      _currentLogFile = null;

      if (oldSink != null) {
        try {
          await oldSink.flush().timeout(const Duration(seconds: 1));
          await oldSink.close().timeout(const Duration(seconds: 1));
        } catch (e) {
          debugPrint('关闭日志文件失败: $e');
        }
      }

      // 删除所有日志文件
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (await logsDir.exists()) {
        await for (final file in logsDir.list()) {
          if (file is File && file.path.endsWith('.log')) {
            try {
              await file.delete();
            } catch (e) {
              debugPrint('删除日志文件失败 ${file.path}: $e');
            }
          }
        }
      }

      // 重新打开新的日志文件并重启定时器
      await _openLogFile();
      _fileLoggingEnabled = true; // 重新启用文件日志
      _startFlushTimer();
      debugPrint('日志文件已清除');
    } catch (e) {
      debugPrint('清除日志失败: $e');
    }
  }

  static Future<List<String>> getLogFiles() async {
    final files = <String>[];
    try {
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (await logsDir.exists()) {
        await for (final file in logsDir.list()) {
          if (file is File && file.path.endsWith('.log')) {
            files.add(file.path);
          }
        }
      }
    } catch (e) {
      debugPrint('获取日志文件列表失败: $e');
    }
    return files..sort();
  }

  static Future<String?> readLogFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('读取日志文件失败: $e');
    }
    return null;
  }

  static void logToFile(String fileName, String message) {
    // 自定义日志文件不受 _fileLoggingEnabled 限制
    try {
      final timestamp = _dateFormat.format(DateTime.now());
      final logMessage = '[$timestamp] $message\n';

      // 异步写入，不阻塞
      Future.microtask(() async {
        try {
          final file = File(
            '${AppDirectoryService.logsPath}${Platform.pathSeparator}$fileName',
          );
          await file
              .writeAsString(logMessage, mode: FileMode.append, flush: true)
              .timeout(const Duration(seconds: 1));
        } catch (e) {
          debugPrint('写入自定义日志文件失败: $e');
        }
      });
    } catch (e) {
      debugPrint('创建自定义日志文件失败: $e');
    }
  }

  /// 清理多余的日志文件，只保留最新的 N 个（异步，不阻塞）
  static void _cleanupOldLogs() {
    Future.microtask(() async {
      try {
        final logsDir = Directory(AppDirectoryService.logsPath);
        if (!await logsDir.exists()) return;

        // 收集所有日志文件及其日期
        final logFiles = <MapEntry<DateTime, File>>[];

        await for (final entity in logsDir.list()) {
          if (entity is File && entity.path.endsWith('.log')) {
            try {
              // 从文件名提取日期（格式：yyyy-MM-dd.log）
              final fileName = entity.path.split(Platform.pathSeparator).last;
              final dateMatch = RegExp(
                r'(\d{4}-\d{2}-\d{2})\.log$',
              ).firstMatch(fileName);

              if (dateMatch != null) {
                final dateStr = dateMatch.group(1)!;
                final fileDate = DateTime.parse(dateStr);
                logFiles.add(MapEntry(fileDate, entity));
              }
            } catch (e) {
              debugPrint('处理日志文件失败 ${entity.path}: $e');
            }
          }
        }

        // 如果日志文件数量不超过限制，无需清理
        if (logFiles.length <= maxLogFiles) {
          debugPrint('当前日志文件数量: ${logFiles.length}，无需清理');
          return;
        }

        // 按日期降序排序（最新的在前）
        logFiles.sort((a, b) => b.key.compareTo(a.key));

        // 删除超出限制的旧文件（跳过当前正在使用的文件）
        int deletedCount = 0;
        for (int i = maxLogFiles; i < logFiles.length; i++) {
          try {
            final file = logFiles[i].value;
            final fileName = file.path.split(Platform.pathSeparator).last;

            // 跳过当前正在使用的文件
            if (file.path == _currentLogFile) {
              debugPrint('跳过当前日志文件: $fileName');
              continue;
            }

            await file.delete();
            deletedCount++;
            debugPrint('已删除旧日志: $fileName');
          } catch (e) {
            debugPrint('删除日志文件失败: $e');
          }
        }

        if (deletedCount > 0) {
          debugPrint('清理完成，共删除 $deletedCount 个旧日志文件，保留最新 $maxLogFiles 个');
        }
      } catch (e) {
        debugPrint('清理旧日志失败: $e');
      }
    });
  }

  /// 手动触发清理旧日志（可在设置页面调用）
  static Future<int> cleanupOldLogsManually() async {
    try {
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (!await logsDir.exists()) return 0;

      // 收集所有日志文件及其日期
      final logFiles = <MapEntry<DateTime, File>>[];

      await for (final entity in logsDir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          try {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final dateMatch = RegExp(
              r'(\d{4}-\d{2}-\d{2})\.log$',
            ).firstMatch(fileName);

            if (dateMatch != null) {
              final dateStr = dateMatch.group(1)!;
              final fileDate = DateTime.parse(dateStr);
              logFiles.add(MapEntry(fileDate, entity));
            }
          } catch (e) {
            debugPrint('处理日志文件失败 ${entity.path}: $e');
          }
        }
      }

      // 如果日志文件数量不超过限制，无需清理
      if (logFiles.length <= maxLogFiles) {
        debugPrint('当前日志文件数量: ${logFiles.length}，无需清理');
        return 0;
      }

      // 按日期降序排序（最新的在前）
      logFiles.sort((a, b) => b.key.compareTo(a.key));

      // 删除超出限制的旧文件（跳过当前正在使用的文件）
      int deletedCount = 0;
      for (int i = maxLogFiles; i < logFiles.length; i++) {
        try {
          final file = logFiles[i].value;

          // 跳过当前正在使用的文件
          if (file.path == _currentLogFile) {
            debugPrint('跳过当前日志文件: ${file.path}');
            continue;
          }

          await file.delete();
          deletedCount++;
        } catch (e) {
          debugPrint('删除日志文件失败: $e');
        }
      }

      debugPrint('手动清理完成，共删除 $deletedCount 个旧日志文件');
      return deletedCount;
    } catch (e) {
      debugPrint('手动清理旧日志失败: $e');
      return 0;
    }
  }

  static Future<void> dispose() async {
    if (!_initialized) return;

    await _safeCleanup();
  }
}
