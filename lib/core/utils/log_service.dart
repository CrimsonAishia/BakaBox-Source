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
  
  /// 获取 logger 实例，如果未初始化则创建一个简单的 logger
  static Logger get _log {
    if (_logger == null) {
      _logger = Logger(
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
    }
    return _logger!;
  }
  
  static Future<void> init() async {
    if (_initialized) return;
    
    // 确保 logger 已创建
    _log;
    
    await _initFileLogging();
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
  
  static Future<void> _openLogFile() async {
    final today = _fileDateFormat.format(DateTime.now());
    final logFile = '${AppDirectoryService.logsPath}${Platform.pathSeparator}bakabox_$today.log';
    
    if (_currentLogFile == logFile && _fileSink != null) return;
    
    await _fileSink?.flush();
    await _fileSink?.close();
    
    final file = File(logFile);
    _fileSink = file.openWrite(mode: FileMode.append);
    _currentLogFile = logFile;
  }
  
  static void _writeToFile(LogLevel level, String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    if (_fileSink == null) return;
    
    try {
      // 检查是否需要切换日志文件（跨天）
      final today = _fileDateFormat.format(DateTime.now());
      if (_currentLogFile?.contains(today) != true) {
        _openLogFile();
      }
      
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
    await _fileSink?.flush();
  }
  
  static Future<void> clearLogs() async {
    try {
      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;
      
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (await logsDir.exists()) {
        await for (final file in logsDir.list()) {
          if (file is File && file.path.endsWith('.log')) {
            await file.delete();
          }
        }
      }
      
      await _openLogFile();
      i('日志文件已清除');
    } catch (e) {
      _log.e('清除日志失败', error: e);
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
      file.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
    } catch (e) {
      _log.e('写入自定义日志文件失败', error: e);
    }
  }
  
  static Future<void> dispose() async {
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
    _initialized = false;
  }
}
