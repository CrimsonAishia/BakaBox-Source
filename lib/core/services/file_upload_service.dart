import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../api/file_upload_api.dart';
import '../models/upload_models.dart';
import '../utils/log_service.dart';
import '../utils/file_validation_utils.dart';

/// 用于流式 MD5 计算的累加器
class _DigestAccumulator implements Sink<Digest> {
  Digest? _digest;
  
  Digest get digest => _digest!;
  
  @override
  void add(Digest data) {
    _digest = data;
  }
  
  @override
  void close() {}
}

/// 文件上传服务
/// 
/// 提供文件上传功能，包括：
/// - MD5 计算
/// - 分片上传
/// - 上传队列管理
/// - 重试逻辑
/// - 进度跟踪
class FileUploadService {
  /// 分片大小（5MB）
  static const int chunkSize = 5 * 1024 * 1024;
  
  /// 分类名称
  static const String categoryName = 'bakabox_issues';
  
  /// 最大重试次数
  static const int maxRetries = 3;
  
  /// 重试延迟（指数退避）
  static const Duration initialRetryDelay = Duration(seconds: 1);
  
  /// 最大并发上传数
  static const int maxConcurrentUploads = 3;

  final FileUploadApi _api = FileUploadApi();
  
  /// 上传队列
  final List<_UploadTask> _uploadQueue = [];
  
  /// 当前正在上传的任务数
  int _activeUploads = 0;
  
  /// 是否正在处理队列
  bool _isProcessingQueue = false;

  /// 上传图片文件
  /// 
  /// 参数:
  /// - [file]: 要上传的文件
  /// - [onProgress]: 进度回调（可选）
  /// 
  /// 返回:
  /// - [UploadResult]: 上传结果，包含文件 URL 等信息
  Future<UploadResult> uploadImage(
    File file, {
    Function(UploadProgress progress)? onProgress,
  }) async {
    // 验证文件
    final validation = FileValidationUtils.validateFile(file);
    if (!validation.isValid) {
      throw FileValidationException(validation.errorMessage ?? '文件验证失败');
    }

    final fileName = file.path.split('/').last.split('\\').last;
    final fileSize = file.lengthSync();

    // 创建上传任务
    final task = _UploadTask(
      file: file,
      fileName: fileName,
      fileSize: fileSize,
      onProgress: onProgress,
    );

    // 添加到队列
    _uploadQueue.add(task);
    
    // 开始处理队列
    _processQueue();

    // 等待任务完成
    return await task.completer.future;
  }

  /// 处理上传队列
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_uploadQueue.isNotEmpty && _activeUploads < maxConcurrentUploads) {
        final task = _uploadQueue.removeAt(0);
        _activeUploads++;
        
        // 异步执行上传任务
        _executeUploadTask(task).then((_) {
          _activeUploads--;
          _processQueue(); // 继续处理队列
        });
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// 执行上传任务
  Future<void> _executeUploadTask(_UploadTask task) async {
    try {
      // 更新状态：计算哈希
      task.updateProgress(UploadProgress(
        fileName: task.fileName,
        totalBytes: task.fileSize,
        uploadedBytes: 0,
        progress: 0.0,
        status: UploadStatus.hashing,
      ));

      // 计算 MD5
      final fileMD5 = await calculateMD5(task.file);
      LogService.i('文件 MD5: $fileMD5');

      // 初始化上传
      final initResponse = await _initUploadWithRetry(
        fileName: task.fileName,
        fileSize: task.fileSize,
        fileMD5: fileMD5,
      );

      // 如果文件已存在（秒传）
      if (initResponse.isExists) {
        LogService.i('文件已存在，使用秒传: ${initResponse.url}');
        
        task.updateProgress(UploadProgress(
          fileName: task.fileName,
          totalBytes: task.fileSize,
          uploadedBytes: task.fileSize,
          progress: 1.0,
          status: UploadStatus.completed,
        ));

        task.completer.complete(UploadResult(
          fileId: initResponse.fileId,
          url: initResponse.url,
          cdnUrl: initResponse.url,
          fileName: task.fileName,
          fileSize: task.fileSize,
          fileMD5: fileMD5,
        ));
        return;
      }

      // 更新状态：上传中
      task.updateProgress(UploadProgress(
        fileName: task.fileName,
        totalBytes: task.fileSize,
        uploadedBytes: 0,
        progress: 0.0,
        status: UploadStatus.uploading,
      ));

      // 执行分片上传
      await _uploadChunks(
        task: task,
        uploadId: initResponse.uploadId,
        fileKey: initResponse.fileKey,
        fileMD5: fileMD5,
      );

      // 完成上传
      final completeResponse = await _completeUploadWithRetry(
        uploadId: initResponse.uploadId,
        fileKey: initResponse.fileKey,
        fileMD5: fileMD5,
      );

      // 更新状态：完成
      task.updateProgress(UploadProgress(
        fileName: task.fileName,
        totalBytes: task.fileSize,
        uploadedBytes: task.fileSize,
        progress: 1.0,
        status: UploadStatus.completed,
      ));

      task.completer.complete(UploadResult(
        fileId: completeResponse.fileId,
        url: completeResponse.url,
        cdnUrl: completeResponse.url,
        fileName: task.fileName,
        fileSize: task.fileSize,
        fileMD5: fileMD5,
      ));
    } catch (e) {
      LogService.e('上传失败: ${task.fileName}', e);
      
      task.updateProgress(UploadProgress(
        fileName: task.fileName,
        totalBytes: task.fileSize,
        uploadedBytes: 0,
        progress: 0.0,
        status: UploadStatus.failed,
        error: e.toString(),
      ));

      task.completer.completeError(e);
    }
  }

  /// 计算文件 MD5
  /// 
  /// 使用流式读取 + isolate 避免阻塞 UI 线程
  /// 
  /// 参数:
  /// - [file]: 要计算 MD5 的文件
  /// 
  /// 返回:
  /// - MD5 哈希值（十六进制字符串）
  Future<String> calculateMD5(File file) async {
    try {
      // 使用 compute 在隔离线程中计算 MD5，避免阻塞 UI
      return await compute(_calculateMD5InIsolate, file.path);
    } catch (e) {
      LogService.e('计算 MD5 失败', e);
      rethrow;
    }
  }
  
  /// 在隔离线程中计算 MD5（同步读取，compute 不支持 async）
  static String _calculateMD5InIsolate(String filePath) {
    final file = File(filePath);
    final output = _DigestAccumulator();
    final input = md5.startChunkedConversion(output);
    
    // 同步读取文件
    final bytes = file.readAsBytesSync();
    input.add(bytes);
    input.close();
    
    return output.digest.toString();
  }

  /// 上传分片
  Future<void> _uploadChunks({
    required _UploadTask task,
    required String uploadId,
    required String fileKey,
    required String fileMD5,
  }) async {
    final file = task.file;
    final fileSize = task.fileSize;
    final totalChunks = (fileSize / chunkSize).ceil();

    LogService.i('开始分片上传: $totalChunks 个分片, 文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');

    // 如果只有一个分片，直接上传
    if (totalChunks == 1) {
      final chunkData = await _readChunk(file, 0, fileSize);
      await _uploadPartWithRetry(
        uploadId: uploadId,
        partNumber: 1,
        fileKey: fileKey,
        data: chunkData,
      );

      task.updateProgress(UploadProgress(
        fileName: task.fileName,
        totalBytes: fileSize,
        uploadedBytes: fileSize,
        progress: 1.0,
        status: UploadStatus.uploading,
      ));
      return;
    }

    // 多分片并发上传（最多 3 个并发）
    final List<Future<void>> uploadFutures = [];
    int uploadedBytes = 0;
    
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < fileSize) ? start + chunkSize : fileSize;
      final partNumber = i + 1;

      // 创建上传任务
      final uploadFuture = _uploadChunkPart(
        file: file,
        start: start,
        end: end,
        uploadId: uploadId,
        partNumber: partNumber,
        fileKey: fileKey,
      ).then((_) {
        uploadedBytes = end;
        final progress = uploadedBytes / fileSize;
        
        task.updateProgress(UploadProgress(
          fileName: task.fileName,
          totalBytes: fileSize,
          uploadedBytes: uploadedBytes,
          progress: progress,
          status: UploadStatus.uploading,
        ));

        LogService.i('分片 $partNumber/$totalChunks 上传完成');
      });
      
      uploadFutures.add(uploadFuture);
      
      // 每 3 个分片等待一次（控制并发数）
      if (uploadFutures.length >= maxConcurrentUploads) {
        await Future.wait(uploadFutures);
        uploadFutures.clear();
      }
    }
    
    // 等待剩余的上传任务完成
    if (uploadFutures.isNotEmpty) {
      await Future.wait(uploadFutures);
    }
  }
  
  /// 上传单个分片
  Future<void> _uploadChunkPart({
    required File file,
    required int start,
    required int end,
    required String uploadId,
    required int partNumber,
    required String fileKey,
  }) async {
    // 读取分片数据
    final chunkData = await _readChunk(file, start, end);
    
    // 上传分片（带重试）
    await _uploadPartWithRetry(
      uploadId: uploadId,
      partNumber: partNumber,
      fileKey: fileKey,
      data: chunkData,
    );
  }

  /// 读取文件分片
  Future<Uint8List> _readChunk(File file, int start, int end) async {
    final randomAccessFile = await file.open(mode: FileMode.read);
    try {
      await randomAccessFile.setPosition(start);
      final length = end - start;
      final buffer = await randomAccessFile.read(length);
      return Uint8List.fromList(buffer);
    } finally {
      await randomAccessFile.close();
    }
  }

  /// 初始化上传（带重试）
  Future<InitUploadResponse> _initUploadWithRetry({
    required String fileName,
    required int fileSize,
    required String fileMD5,
  }) async {
    return await _retryOperation(
      () => _api.initMultipart(
        fileName: fileName,
        fileSize: fileSize,
        fileMD5: fileMD5,
        categoryName: categoryName,
      ),
      operationName: '初始化上传',
    );
  }

  /// 上传分片（带重试）
  Future<PartUploadResponse> _uploadPartWithRetry({
    required String uploadId,
    required int partNumber,
    required String fileKey,
    required Uint8List data,
  }) async {
    return await _retryOperation(
      () => _api.uploadPart(
        uploadId: uploadId,
        partNumber: partNumber,
        fileKey: fileKey,
        data: data,
      ),
      operationName: '上传分片 $partNumber',
    );
  }

  /// 完成上传（带重试）
  Future<CompleteUploadResponse> _completeUploadWithRetry({
    required String uploadId,
    required String fileKey,
    required String fileMD5,
  }) async {
    return await _retryOperation(
      () => _api.completeMultipart(
        uploadId: uploadId,
        fileKey: fileKey,
        fileMD5: fileMD5,
        categoryName: categoryName,
      ),
      operationName: '完成上传',
    );
  }

  /// 重试操作
  /// 
  /// 使用指数退避策略重试操作
  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    int attempt = 0;
    Duration delay = initialRetryDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries) {
          LogService.e('$operationName 失败，已达到最大重试次数', e);
          rethrow;
        }

        LogService.w('$operationName 失败，${delay.inSeconds}秒后重试 ($attempt/$maxRetries)');
        await Future.delayed(delay);
        
        // 指数退避
        delay *= 2;
      }
    }
  }

  /// 取消上传
  Future<void> cancelUpload({
    required String uploadId,
    required String fileKey,
  }) async {
    try {
      await _api.cancelMultipart(
        uploadId: uploadId,
        fileKey: fileKey,
      );
    } catch (e) {
      LogService.e('取消上传失败', e);
    }
  }

  /// 上传图片到图床（简单上传，适用于图片）
  ///
  /// 与 OSS 分片上传相比：
  /// - 更简单，无需计算 MD5 和分片
  /// - 适用于图片文件
  /// - 返回 CDN 加速 URL
  Future<UploadResult> uploadToImageBed(
    File file, {
    String? categoryName,
    Function(UploadProgress progress)? onProgress,
  }) async {
    // 验证文件
    final validation = FileValidationUtils.validateFile(file);
    if (!validation.isValid) {
      throw FileValidationException(validation.errorMessage ?? '文件验证失败');
    }

    final fileName = file.path.split('/').last.split('\\').last;
    final fileSize = file.lengthSync();

    // 更新状态：上传中
    onProgress?.call(UploadProgress(
      fileName: fileName,
      totalBytes: fileSize,
      uploadedBytes: 0,
      progress: 0.0,
      status: UploadStatus.uploading,
    ));

    try {
      // 读取文件数据
      final fileData = await file.readAsBytes();

      // 上传到图床（带重试）
      final response = await _retryOperation(
        () => _api.uploadToImageBed(
          data: fileData,
          filename: fileName,
          categoryName: categoryName,
        ),
        operationName: '图床上传',
      );

      // 更新状态：完成
      onProgress?.call(UploadProgress(
        fileName: fileName,
        totalBytes: fileSize,
        uploadedBytes: fileSize,
        progress: 1.0,
        status: UploadStatus.completed,
      ));

      LogService.i('图床上传成功: $fileName');

      return UploadResult(
        fileId: response.fileId,
        url: response.url,
        cdnUrl: response.url,
        fileName: fileName,
        fileSize: fileSize,
        fileMD5: '', // 图床上传不需要 MD5
      );
    } catch (e) {
      LogService.e('图床上传失败: $fileName', e);

      onProgress?.call(UploadProgress(
        fileName: fileName,
        totalBytes: fileSize,
        uploadedBytes: 0,
        progress: 0.0,
        status: UploadStatus.failed,
        error: e.toString(),
      ));

      rethrow;
    }
  }
}

/// 上传任务
class _UploadTask {
  final File file;
  final String fileName;
  final int fileSize;
  final Function(UploadProgress progress)? onProgress;
  final Completer<UploadResult> completer = Completer<UploadResult>();

  _UploadTask({
    required this.file,
    required this.fileName,
    required this.fileSize,
    this.onProgress,
  });

  void updateProgress(UploadProgress progress) {
    onProgress?.call(progress);
  }
}

/// 文件验证异常
class FileValidationException implements Exception {
  final String message;
  
  FileValidationException(this.message);

  @override
  String toString() => message;
}
