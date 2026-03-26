import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/video_convert_service.dart';
import '../../../core/services/file_upload_service.dart';
import '../../../core/utils/log_service.dart';
import 'character_gallery_theme.dart';

/// 视频上传状态
enum VideoUploadStatus {
  idle,
  selecting,
  converting,
  uploading,
  completed,
  error,
}

/// 视频上传结果
class VideoUploadResult {
  final int? fileId;
  final String? url;
  final String? error;

  const VideoUploadResult({this.fileId, this.url, this.error});

  bool get isSuccess => fileId != null && url != null;
}

/// 视频上传组件
///
/// 支持选择视频文件，自动转换为 WebM 格式（1080p），然后上传
class VideoUploadWidget extends StatefulWidget {
  final String? currentVideoUrl;
  final ValueChanged<VideoUploadResult>? onUploadComplete;
  final bool enabled;

  const VideoUploadWidget({
    super.key,
    this.currentVideoUrl,
    this.onUploadComplete,
    this.enabled = true,
  });

  @override
  State<VideoUploadWidget> createState() => _VideoUploadWidgetState();
}

class _VideoUploadWidgetState extends State<VideoUploadWidget> {
  VideoUploadStatus _status = VideoUploadStatus.idle;
  String _statusText = '';
  double _progress = 0.0;
  int? _uploadedFileId;
  String? _uploadedUrl;
  String? _errorMessage;
  String? _selectedFileName;

  final FileUploadService _uploadService = FileUploadService();

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '演示视频',
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _buildUploadArea(context),
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        if (widget.currentVideoUrl != null && _uploadedUrl == null) ...[
          const SizedBox(height: 4),
          Text(
            '当前已有视频',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadArea(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: inputBg,
        border: Border.all(
          color: _status == VideoUploadStatus.error
              ? Colors.red
              : _status == VideoUploadStatus.completed
              ? Colors.green
              : scrollBrown.withValues(alpha: 0.4),
          width: _status == VideoUploadStatus.completed ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_status) {
      case VideoUploadStatus.idle:
        return _buildIdleContent(context);
      case VideoUploadStatus.selecting:
        return _buildLoadingContent(context, '正在选择文件...');
      case VideoUploadStatus.converting:
        return _buildProgressContent(context, '转换中', _statusText);
      case VideoUploadStatus.uploading:
        return _buildProgressContent(context, '上传中', _statusText);
      case VideoUploadStatus.completed:
        return _buildCompletedContent(context);
      case VideoUploadStatus.error:
        return _buildErrorContent(context);
    }
  }

  Widget _buildIdleContent(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return InkWell(
      onTap: widget.enabled ? _selectAndUploadVideo : null,
      borderRadius: BorderRadius.circular(4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 28,
              color: widget.enabled
                  ? scrollBrown
                  : scrollBrown.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 4),
            Text(
              widget.currentVideoUrl != null ? '点击更换视频' : '点击上传视频',
              style: TextStyle(
                color: widget.enabled
                    ? scrollBrown
                    : scrollBrown.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
            Text(
              '支持 MP4/MOV/AVI，自动转换为 WebM',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context, String text) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: vermillion),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressContent(
    BuildContext context,
    String title,
    String detail,
  ) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFileName ?? title,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: inkColor.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  color: vermillion,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: scrollBrown.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(vermillion),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedContent(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return InkWell(
      onTap: widget.enabled ? _selectAndUploadVideo : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedFileName ?? '视频已上传',
                    style: TextStyle(
                      color: inkColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '点击可重新选择',
                    style: TextStyle(
                      color: inkColor.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.refresh, color: scrollBrown, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return InkWell(
      onTap: widget.enabled ? _selectAndUploadVideo : null,
      borderRadius: BorderRadius.circular(4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(height: 4),
            Text(
              '上传失败，点击重试',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAndUploadVideo() async {
    setState(() {
      _status = VideoUploadStatus.selecting;
      _errorMessage = null;
    });

    try {
      // 选择视频文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _status = VideoUploadStatus.idle);
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() {
          _status = VideoUploadStatus.error;
          _errorMessage = '无法获取文件路径';
        });
        return;
      }

      _selectedFileName = result.files.first.name;

      // 检查 FFmpeg
      if (!await VideoConvertService.isFFmpegAvailable()) {
        setState(() {
          _status = VideoUploadStatus.error;
          _errorMessage = 'FFmpeg 未安装，请先安装 FFmpeg';
        });
        widget.onUploadComplete?.call(
          const VideoUploadResult(error: 'FFmpeg 未安装'),
        );
        return;
      }

      // 转换视频
      setState(() {
        _status = VideoUploadStatus.converting;
        _progress = 0.0;
        _statusText = '正在分析视频...';
      });

      final convertResult = await VideoConvertService.convertToWebM(
        filePath,
        onProgress: (progress, status) {
          setState(() {
            _progress = progress;
            _statusText = status;
          });
        },
      );

      if (!convertResult.success) {
        setState(() {
          _status = VideoUploadStatus.error;
          _errorMessage = convertResult.error ?? '视频转换失败';
        });
        widget.onUploadComplete?.call(
          VideoUploadResult(error: convertResult.error),
        );
        return;
      }

      // 上传视频
      setState(() {
        _status = VideoUploadStatus.uploading;
        _progress = 0.0;
        _statusText = '准备上传...';
      });

      final uploadResult = await _uploadService.uploadImage(
        File(convertResult.outputPath!),
        onProgress: (progress) {
          setState(() {
            _progress = progress.progress;
            _statusText =
                '${(progress.uploadedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(progress.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
          });
        },
      );

      // 清理临时文件
      await VideoConvertService.cleanupTempFile(convertResult.outputPath);

      setState(() {
        _status = VideoUploadStatus.completed;
        _uploadedFileId = uploadResult.fileId;
        _uploadedUrl = uploadResult.url;
      });

      widget.onUploadComplete?.call(
        VideoUploadResult(fileId: uploadResult.fileId, url: uploadResult.url),
      );

      LogService.i('视频上传成功: fileId=${uploadResult.fileId}');
    } catch (e) {
      LogService.e('视频上传失败', e);
      setState(() {
        _status = VideoUploadStatus.error;
        _errorMessage = '上传失败: $e';
      });
      widget.onUploadComplete?.call(VideoUploadResult(error: e.toString()));
    }
  }

  /// 获取上传的文件ID（供外部使用）
  int? get uploadedFileId => _uploadedFileId;
}
