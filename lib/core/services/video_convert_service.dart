import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/log_service.dart';

/// 视频转换进度回调
typedef VideoConvertProgressCallback =
    void Function(double progress, String status);

/// 视频转换结果
class VideoConvertResult {
  final bool success;
  final String? outputPath;
  final String? error;
  final int? fileSizeBytes;

  const VideoConvertResult({
    required this.success,
    this.outputPath,
    this.error,
    this.fileSizeBytes,
  });

  factory VideoConvertResult.success(String outputPath, int fileSizeBytes) {
    return VideoConvertResult(
      success: true,
      outputPath: outputPath,
      fileSizeBytes: fileSizeBytes,
    );
  }

  factory VideoConvertResult.failure(String error) {
    return VideoConvertResult(success: false, error: error);
  }
}

/// 视频转换服务
///
/// 使用 FFmpeg 将视频转换为 WebM 格式（VP9 编码）并降为 1080p
///
/// 注意：需要系统安装 FFmpeg 并添加到 PATH
class VideoConvertService {
  /// 最大输出分辨率（1080p）
  static const int maxHeight = 1080;

  /// 视频比特率（适中质量）
  static const String videoBitrate = '2M';

  /// 音频比特率
  static const String audioBitrate = '128k';

  /// 检查 FFmpeg 是否可用
  static Future<bool> isFFmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      LogService.w('FFmpeg 不可用: $e');
      return false;
    }
  }

  /// 获取视频信息
  static Future<VideoInfo?> getVideoInfo(String inputPath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=width,height,duration',
        '-of',
        'csv=p=0',
        inputPath,
      ]);

      if (result.exitCode != 0) {
        LogService.e('获取视频信息失败: ${result.stderr}');
        return null;
      }

      final output = result.stdout.toString().trim();
      final parts = output.split(',');
      if (parts.length >= 2) {
        return VideoInfo(
          width: int.tryParse(parts[0]) ?? 0,
          height: int.tryParse(parts[1]) ?? 0,
          duration: parts.length > 2 ? double.tryParse(parts[2]) : null,
        );
      }
      return null;
    } catch (e) {
      LogService.e('获取视频信息异常', e);
      return null;
    }
  }

  /// 转换视频为 WebM 格式（VP9 + Opus）
  ///
  /// 参数:
  /// - [inputPath]: 输入视频路径
  /// - [onProgress]: 进度回调
  ///
  /// 返回:
  /// - [VideoConvertResult]: 转换结果
  static Future<VideoConvertResult> convertToWebM(
    String inputPath, {
    VideoConvertProgressCallback? onProgress,
  }) async {
    // 检查 FFmpeg
    if (!await isFFmpegAvailable()) {
      return VideoConvertResult.failure('FFmpeg 未安装或不在系统 PATH 中');
    }

    // 检查输入文件
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      return VideoConvertResult.failure('输入文件不存在');
    }

    onProgress?.call(0.0, '正在分析视频...');

    // 获取视频信息
    final videoInfo = await getVideoInfo(inputPath);
    if (videoInfo == null) {
      return VideoConvertResult.failure('无法读取视频信息');
    }

    // 计算输出分辨率（保持宽高比，最大 1080p）
    String scaleFilter;
    if (videoInfo.height > maxHeight) {
      // 需要缩放：高度限制为 1080，宽度按比例缩放（确保是偶数）
      scaleFilter = 'scale=-2:$maxHeight';
    } else {
      // 不需要缩放，但确保宽高是偶数（VP9 要求）
      scaleFilter = 'scale=trunc(iw/2)*2:trunc(ih/2)*2';
    }

    // 生成输出文件路径
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = path.join(tempDir.path, 'video_$timestamp.webm');

    onProgress?.call(0.1, '正在转换视频...');

    try {
      // FFmpeg 转换命令
      // VP9 编码 + Opus 音频，适合网页播放
      final process = await Process.start('ffmpeg', [
        '-i', inputPath,
        '-c:v', 'libvpx-vp9', // VP9 视频编码
        '-b:v', videoBitrate, // 视频比特率
        '-crf', '30', // 质量因子（0-63，越低质量越好）
        '-vf', scaleFilter, // 缩放滤镜
        '-c:a', 'libopus', // Opus 音频编码
        '-b:a', audioBitrate, // 音频比特率
        '-deadline', 'good', // 编码速度（realtime/good/best）
        '-cpu-used', '2', // CPU 使用级别（0-5，越高越快但质量越低）
        '-row-mt', '1', // 启用行级多线程
        '-y', // 覆盖输出文件
        outputPath,
      ]);

      // 监听 stderr 获取进度（FFmpeg 输出进度信息到 stderr）
      final stderrBuffer = StringBuffer();
      double lastProgress = 0.1;

      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);

        // 解析进度（FFmpeg 输出格式：time=00:00:05.00）
        final timeMatch = RegExp(
          r'time=(\d+):(\d+):(\d+\.\d+)',
        ).firstMatch(data);
        if (timeMatch != null &&
            videoInfo.duration != null &&
            videoInfo.duration! > 0) {
          final hours = int.parse(timeMatch.group(1)!);
          final minutes = int.parse(timeMatch.group(2)!);
          final seconds = double.parse(timeMatch.group(3)!);
          final currentTime = hours * 3600 + minutes * 60 + seconds;
          final progress = (currentTime / videoInfo.duration!).clamp(0.1, 0.95);

          if (progress > lastProgress) {
            lastProgress = progress;
            onProgress?.call(
              progress,
              '正在转换视频... ${(progress * 100).toInt()}%',
            );
          }
        }
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        LogService.e('FFmpeg 转换失败: ${stderrBuffer.toString()}');
        return VideoConvertResult.failure('视频转换失败，请检查视频格式');
      }

      // 检查输出文件
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        return VideoConvertResult.failure('转换后的文件不存在');
      }

      final fileSize = await outputFile.length();
      onProgress?.call(1.0, '转换完成');

      LogService.i(
        '视频转换成功: $outputPath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
      );
      return VideoConvertResult.success(outputPath, fileSize);
    } catch (e) {
      LogService.e('视频转换异常', e);
      return VideoConvertResult.failure('视频转换异常: $e');
    }
  }

  /// 清理临时文件
  static Future<void> cleanupTempFile(String? filePath) async {
    if (filePath == null) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        LogService.i('已清理临时文件: $filePath');
      }
    } catch (e) {
      LogService.w('清理临时文件失败: $e');
    }
  }
}

/// 视频信息
class VideoInfo {
  final int width;
  final int height;
  final double? duration;

  const VideoInfo({required this.width, required this.height, this.duration});

  @override
  String toString() => 'VideoInfo(${width}x$height, duration: $duration)';
}
