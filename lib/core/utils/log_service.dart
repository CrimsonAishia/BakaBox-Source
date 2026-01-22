import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'app_directory_service.dart';

/// 日志级别
enum LogLevel { debug, info, warning, error, fatal }

/// 统一的日志服务 - 支持全平台文件写入
class LogService {
  static Logger? _logger;
  static bool _initialized = false;
  static IOSink? _fileSink;
  static String? _currentLogFile;
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  static final _fileDateFormat = DateFormat('yyyy-MM-dd');
  
  /// 最多保留的日志文件数量（默认 7 个）
  static const int maxLogFiles = 7;
  
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
    if (_initialized) return;
    
    // 确保 logger 已创建
    _log;
    
    await _initFileLogging();
    
    // 清理过期日志
    await _cleanupOldLogs();
    
    _initialized = true;
    i('日志服务初始化完成');
  }
  
  static Future<void> _initFileLogging() async {
    try {
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      await _openLogFile();
      _log.i('文件日志初始化成功: $_currentLogFile');
    } catch (e) {
      _log.w('文件日志初始化失败: $e');
    }
  }
  
  static bool _isRotating = false;
  
  static Future<void> _openLogFile() async {
    final today = _fileDateFormat.format(DateTime.now());
    final logFile = '${AppDirectoryService.logsPath}${Platform.pathSeparator}bakabox_$today.log';
    
    if (_currentLogFile == logFile && _fileSink != null) return;
    
    _isRotating = true;
    
    try {
      // 先保存旧的 sink
      final oldSink = _fileSink;
      
      // 尝试打开新文件
      final file = File(logFile);
      final newSink = file.openWrite(mode: FileMode.append);
      
      // 更新引用
      _fileSink = newSink;
      _currentLogFile = logFile;
      
      // 异步关闭旧的 sink（不阻塞），添加超时防止内存泄漏
      if (oldSink != null) {
        _closeOldSinkSafely(oldSink);
      }
    } catch (e) {
      debugPrint('切换日志文件异常: $e');
      rethrow;
    } finally {
      _isRotating = false;
    }
  }
  
  /// 安全关闭旧的 sink，带超时保护
  static void _closeOldSinkSafely(IOSink sink) {
    sink.flush()
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('刷新旧日志文件超时，强制关闭');
        },
      )
      .then((_) => sink.close())
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('关闭旧日志文件超时');
        },
      )
      .catchError((e) {
        debugPrint('关闭旧日志文件失败: $e');
      });
  }
  
  static void _writeToFile(LogLevel level, String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    try {
      if (_fileSink == null) return;
      
      // 检查是否需要切换日志文件（跨天）- 使用精确匹配
      final today = _fileDateFormat.format(DateTime.now());
      final expectedLogFile = '${AppDirectoryService.logsPath}${Platform.pathSeparator}bakabox_$today.log';
      
      if (_currentLogFile != expectedLogFile && !_isRotating) {
        // 异步切换日志文件，不阻塞当前写入
        _openLogFile().catchError((e) {
          debugPrint('切换日志文件失败: $e');
        });
        // 切换期间跳过本次写入，避免写入到错误的文件
        return;
      }
      
      // 如果正在切换中，跳过写入
      if (_isRotating) return;
      
      final timestamp = _dateFormat.format(DateTime.now());
      final levelStr = level.name.toUpperCase().padRight(5);
      final buffer = StringBuffer();
      buffer.writeln('[$timestamp] [$levelStr] [$tag] $message');
      if (error != null) buffer.writeln('  Error: $error');
      if (stackTrace != null) buffer.writeln('  StackTrace: $stackTrace');
      
      _fileSink?.write(buffer.toString());
    } catch (e) {
      debugPrint('写入日志文件失败: $e');
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
  
  static void api(String method, String url, {
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
    if (requestData != null && kDebugMode) buffer.write('\n📤 Request: $requestData');
    if (responseData != null && kDebugMode) buffer.write('\n📥 Response: $responseData');
    
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
    final message = table != null ? '🗄️ DB $operation: $table' : '🗄️ DB $operation';
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
      _log.e('获取日志目录失败', error: e);
      return null;
    }
  }
  
  static Future<void> flush() async {
    try {
      await _fileSink?.flush();
    } catch (e) {
      debugPrint('刷新日志文件失败: $e');
    }
  }
  
  static Future<void> clearLogs() async {
    // 使用 _isRotating 标志防止并发写入
    if (_isRotating) {
      debugPrint('日志正在切换中，无法清除');
      return;
    }
    
    _isRotating = true;
    
    try {
      // 先关闭当前文件
      final oldSink = _fileSink;
      _fileSink = null;
      _currentLogFile = null;
      
      if (oldSink != null) {
        try {
          await oldSink.flush();
          await oldSink.close();
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
      
      // 重新打开新的日志文件
      await _openLogFile();
      i('日志文件已清除');
    } catch (e) {
      _log.e('清除日志失败', error: e);
    } finally {
      _isRotating = false;
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
      _log.e('获取日志文件列表失败', error: e);
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
      _log.e('读取日志文件失败', error: e);
    }
    return null;
  }
  
  static void logToFile(String fileName, String message) {
    try {
      final file = File('${AppDirectoryService.logsPath}${Platform.pathSeparator}$fileName');
      final timestamp = _dateFormat.format(DateTime.now());
      // 使用异步写入避免阻塞，但不等待完成
      file.writeAsString('[$timestamp] $message\n', mode: FileMode.append, flush: true).catchError((e) {
        debugPrint('写入自定义日志文件失败: $e');
        return file; // 返回文件对象以满足类型要求
      });
    } catch (e) {
      debugPrint('创建自定义日志文件失败: $e');
    }
  }
  
  /// 清理多余的日志文件，只保留最新的 N 个
  static Future<void> _cleanupOldLogs() async {
    try {
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (!await logsDir.exists()) return;
      
      // 收集所有日志文件及其日期
      final logFiles = <MapEntry<DateTime, File>>[];
      
      await for (final entity in logsDir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          try {
            // 从文件名提取日期（格式：bakabox_yyyy-MM-dd.log）
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final dateMatch = RegExp(r'bakabox_(\d{4}-\d{2}-\d{2})\.log').firstMatch(fileName);
            
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
      
      // 删除超出限制的旧文件
      int deletedCount = 0;
      for (int i = maxLogFiles; i < logFiles.length; i++) {
        try {
          final file = logFiles[i].value;
          final fileName = file.path.split(Platform.pathSeparator).last;
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
            final dateMatch = RegExp(r'bakabox_(\d{4}-\d{2}-\d{2})\.log').firstMatch(fileName);
            
            if (dateMatch != null) {
              final dateStr = dateMatch.group(1)!;
              final fileDate = DateTime.parse(dateStr);
              logFiles.add(MapEntry(fileDate, entity));
            }
          } catch (e) {
            _log.w('处理日志文件失败 ${entity.path}', error: e);
          }
        }
      }
      
      // 如果日志文件数量不超过限制，无需清理
      if (logFiles.length <= maxLogFiles) {
        i('当前日志文件数量: ${logFiles.length}，无需清理');
        return 0;
      }
      
      // 按日期降序排序（最新的在前）
      logFiles.sort((a, b) => b.key.compareTo(a.key));
      
      // 删除超出限制的旧文件
      int deletedCount = 0;
      for (int i = maxLogFiles; i < logFiles.length; i++) {
        try {
          await logFiles[i].value.delete();
          deletedCount++;
        } catch (e) {
          _log.w('删除日志文件失败', error: e);
        }
      }
      
      i('手动清理完成，共删除 $deletedCount 个旧日志文件');
      return deletedCount;
    } catch (e) {
      _log.e('手动清理旧日志失败', error: e);
      return 0;
    }
  }
  
  static Future<void> dispose() async {
    try {
      await _fileSink?.flush();
      await _fileSink?.close();
    } catch (e) {
      debugPrint('关闭日志文件失败: $e');
    } finally {
      _fileSink = null;
      _currentLogFile = null;
      _isRotating = false;
      _initialized = false;
    }
  }
}
