import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/file_upload_service.dart';
import '../../../core/services/image_url_service.dart';
import '../../../core/utils/log_service.dart';
import 'character_gallery_theme.dart';
import 'image_crop_dialog.dart';

/// 预览图上传状态
enum PreviewImageUploadStatus { idle, selecting, uploading, completed, error }

/// 预览图上传结果
class PreviewImageUploadResult {
  final int? fileId;
  final String? url;
  final String? error;

  const PreviewImageUploadResult({this.fileId, this.url, this.error});

  bool get isSuccess => fileId != null && url != null;
}

/// 单个预览图上传组件
class PreviewImageUploadItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? currentImageUrl;
  final ValueChanged<PreviewImageUploadResult>? onUploadComplete;
  final bool enabled;

  const PreviewImageUploadItem({
    super.key,
    required this.label,
    required this.icon,
    this.currentImageUrl,
    this.onUploadComplete,
    this.enabled = true,
  });

  @override
  State<PreviewImageUploadItem> createState() => _PreviewImageUploadItemState();
}

class _PreviewImageUploadItemState extends State<PreviewImageUploadItem>
    with AutomaticKeepAliveClientMixin {
  PreviewImageUploadStatus _status = PreviewImageUploadStatus.idle;
  double _progress = 0.0;
  int? _uploadedFileId;
  String? _uploadedUrl;
  bool _isHovered = false;

  final FileUploadService _uploadService = FileUploadService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 标签
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 14, color: scrollBrown),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: TextStyle(
                color: scrollBrown,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 上传区域
        _buildUploadArea(context, inputBg, scrollBrown),
      ],
    );
  }

  Widget _buildUploadArea(
    BuildContext context,
    Color inputBg,
    Color scrollBrown,
  ) {
    final isUploaded = _uploadedUrl != null || widget.currentImageUrl != null;
    final displayUrl = _uploadedUrl ?? widget.currentImageUrl;
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return MouseRegion(
      cursor: widget.enabled && _status != PreviewImageUploadStatus.uploading
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled && _status != PreviewImageUploadStatus.uploading
            ? _selectAndUploadImage
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: inputBg,
            border: Border.all(
              color: _status == PreviewImageUploadStatus.error
                  ? Colors.red
                  : _status == PreviewImageUploadStatus.completed
                  ? Colors.green
                  : _isHovered && widget.enabled
                  ? vermillion
                  : scrollBrown.withValues(alpha: 0.4),
              width: _status == PreviewImageUploadStatus.completed
                  ? 2
                  : _isHovered && widget.enabled
                  ? 2
                  : 1,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: _isHovered && widget.enabled
                ? [
                    BoxShadow(
                      color: vermillion.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              _buildContent(context, isUploaded, displayUrl),
              // Hover 遮罩
              if (_isHovered &&
                  widget.enabled &&
                  _status == PreviewImageUploadStatus.idle)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Icon(
                        isUploaded ? Icons.refresh : Icons.add_photo_alternate,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isUploaded,
    String? displayUrl,
  ) {
    switch (_status) {
      case PreviewImageUploadStatus.idle:
        if (isUploaded && displayUrl != null) {
          return _buildPreviewContent(context, displayUrl);
        }
        return _buildIdleContent(context);
      case PreviewImageUploadStatus.selecting:
        return _buildLoadingContent(context, '选择中...');
      case PreviewImageUploadStatus.uploading:
        return _buildUploadingContent(context);
      case PreviewImageUploadStatus.completed:
        return _buildPreviewContent(context, displayUrl!);
      case PreviewImageUploadStatus.error:
        return _buildErrorContent(context);
    }
  }

  Widget _buildIdleContent(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 24,
            color: widget.enabled
                ? scrollBrown
                : scrollBrown.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 2),
          Text(
            '上传',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
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
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: vermillion),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingContent(BuildContext context) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(_progress * 100).toInt()}%',
            style: TextStyle(
              color: vermillion,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: scrollBrown.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(vermillion),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context, String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildIdleContent(context),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingContent(context, '加载中');
          },
        ),
        // 悬停提示
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.enabled ? _selectAndUploadImage : null,
              child: Container(color: Colors.black.withValues(alpha: 0.0)),
            ),
          ),
        ),
        // 更换图标
        if (widget.enabled)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 22),
          const SizedBox(height: 2),
          Text('失败', style: TextStyle(color: Colors.red.shade700, fontSize: 9)),
        ],
      ),
    );
  }

  Future<void> _selectAndUploadImage() async {
    setState(() {
      _status = PreviewImageUploadStatus.selecting;
    });

    try {
      // 选择图片文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _status = PreviewImageUploadStatus.idle);
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() {
          _status = PreviewImageUploadStatus.error;
        });
        return;
      }

      // 检查文件大小（限制 10MB）
      final fileSize = await File(filePath).length();
      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          setState(() => _status = PreviewImageUploadStatus.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片文件不能超过 10MB')),
          );
        }
        return;
      }

      // 弹出裁剪窗口
      if (!mounted) return;
      final croppedData = await ImageCropDialog.show(
        context,
        imageFile: File(filePath),
        aspectRatio: 1.0, // 正方形
        title: '调整${widget.label}',
      );

      if (croppedData == null) {
        // 用户取消了裁剪
        setState(() => _status = PreviewImageUploadStatus.idle);
        return;
      }

      // 开始上传裁剪后的图片
      setState(() {
        _status = PreviewImageUploadStatus.uploading;
        _progress = 0.0;
      });

      // 保存裁剪后的图片到临时文件
      final tempDir = await Directory.systemTemp.createTemp('crop_');
      final tempFile = File(
        '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(croppedData);

      // 使用图床上传
      final uploadResult = await _uploadService.uploadToImageBed(
        tempFile,
        categoryName: 'character_preview',
      );

      // 删除临时文件
      try {
        await tempFile.delete();
        await tempDir.delete();
      } catch (_) {
        // 忽略删除临时文件的错误
      }

      setState(() {
        _status = PreviewImageUploadStatus.completed;
        _uploadedFileId = uploadResult.fileId;
        _uploadedUrl = uploadResult.url;
        _progress = 1.0;
      });

      widget.onUploadComplete?.call(
        PreviewImageUploadResult(
          fileId: uploadResult.fileId,
          url: uploadResult.url,
        ),
      );

      LogService.i('预览图上传成功: ${widget.label}, fileId=${uploadResult.fileId}');
    } catch (e) {
      LogService.e('预览图上传失败: ${widget.label}', e);
      setState(() {
        _status = PreviewImageUploadStatus.error;
      });
      widget.onUploadComplete?.call(
        PreviewImageUploadResult(error: e.toString()),
      );
    }
  }

  /// 获取上传的文件ID（供外部使用）
  int? get uploadedFileId => _uploadedFileId;
}

/// 预览图上传组件（包含所有预览图位置）
class PreviewImagesUploadWidget extends StatefulWidget {
  final String? thumbnailUrl;
  final String? frontUrl;
  final String? leftUrl;
  final String? rightUrl;
  final String? backUrl;
  final String? handUrl;
  final String? legUrl;
  // 支持通过 fileId 加载预览图（用于待审核申请的预填充）
  final int? thumbnailFileId;
  final int? frontFileId;
  final int? leftFileId;
  final int? rightFileId;
  final int? backFileId;
  final int? handFileId;
  final int? legFileId;
  final ValueChanged<Map<String, int?>>? onChanged;
  final bool enabled;

  const PreviewImagesUploadWidget({
    super.key,
    this.thumbnailUrl,
    this.frontUrl,
    this.leftUrl,
    this.rightUrl,
    this.backUrl,
    this.handUrl,
    this.legUrl,
    this.thumbnailFileId,
    this.frontFileId,
    this.leftFileId,
    this.rightFileId,
    this.backFileId,
    this.handFileId,
    this.legFileId,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<PreviewImagesUploadWidget> createState() =>
      PreviewImagesUploadWidgetState();
}

class PreviewImagesUploadWidgetState extends State<PreviewImagesUploadWidget>
    with AutomaticKeepAliveClientMixin {
  int? _thumbnailFileId;
  int? _frontFileId;
  int? _leftFileId;
  int? _rightFileId;
  int? _backFileId;
  int? _handFileId;
  int? _legFileId;

  // 从 fileId 加载的 URL（用于待审核申请预填充）
  String? _thumbnailUrlFromFileId;
  String? _frontUrlFromFileId;
  String? _leftUrlFromFileId;
  String? _rightUrlFromFileId;
  String? _backUrlFromFileId;
  String? _handUrlFromFileId;
  String? _legUrlFromFileId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 如果有 fileId，预先加载 URL
    _loadUrlsFromFileIds();
    // 初始化 fileId（用于预填充场景）
    _thumbnailFileId = widget.thumbnailFileId;
    _frontFileId = widget.frontFileId;
    _leftFileId = widget.leftFileId;
    _rightFileId = widget.rightFileId;
    _backFileId = widget.backFileId;
    _handFileId = widget.handFileId;
    _legFileId = widget.legFileId;
  }

  Future<void> _loadUrlsFromFileIds() async {
    if (widget.thumbnailFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.thumbnailFileId!);
        if (mounted) setState(() => _thumbnailUrlFromFileId = url);
      } catch (_) {}
    }
    if (widget.frontFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.frontFileId!);
        if (mounted) setState(() => _frontUrlFromFileId = url);
      } catch (_) {}
    }
    if (widget.leftFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.leftFileId!);
        if (mounted) setState(() => _leftUrlFromFileId = url);
      } catch (_) {}
    }
    if (widget.rightFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.rightFileId!);
        if (mounted) setState(() => _rightUrlFromFileId = url);
      } catch (_) {}
    }
    if (widget.backFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.backFileId!);
        if (mounted) setState(() => _backUrlFromFileId = url);
      } catch (_) {}
    }
    if (widget.handFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.handFileId!);
        if (mounted) setState(() => _handUrlFromFileId = url);
      } catch (_) {}
    }
    if (widget.legFileId != null) {
      try {
        final url = await ImageUrlService.instance.getSignedUrlById(widget.legFileId!);
        if (mounted) setState(() => _legUrlFromFileId = url);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 缩略图（单独一行，较大）
        _buildThumbnailSection(context, inkColor),
        const SizedBox(height: 20),
        // 四方向预览图
        _buildPreviewsSection(context, inkColor),
      ],
    );
  }

  Widget _buildThumbnailSection(BuildContext context, Color inkColor) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    // 优先使用从 fileId 加载的 URL，其次使用传入的 URL
    final thumbnailUrl = _thumbnailUrlFromFileId ?? widget.thumbnailUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_outlined, size: 16, color: scrollBrown),
            const SizedBox(width: 6),
            Text(
              '缩略图',
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '（角色列表中显示的图片）',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          height: 120,
          child: _ThumbnailUploadItem(
            currentImageUrl: thumbnailUrl,
            enabled: widget.enabled,
            onUploadComplete: (result) {
              if (result.isSuccess) {
                _thumbnailFileId = result.fileId;
                _notifyChanged();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewsSection(BuildContext context, Color inkColor) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    // 优先使用从 fileId 加载的 URL，其次使用传入的 URL
    final frontUrl = _frontUrlFromFileId ?? widget.frontUrl;
    final leftUrl = _leftUrlFromFileId ?? widget.leftUrl;
    final rightUrl = _rightUrlFromFileId ?? widget.rightUrl;
    final backUrl = _backUrlFromFileId ?? widget.backUrl;
    final handUrl = _handUrlFromFileId ?? widget.handUrl;
    final legUrl = _legUrlFromFileId ?? widget.legUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.view_in_ar_outlined, size: 16, color: scrollBrown),
            const SizedBox(width: 6),
            Text(
              '预览图',
              style: TextStyle(
                color: scrollBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '（角色详情页中展示的多方向预览）',
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            PreviewImageUploadItem(
              label: '正面',
              icon: Icons.person_outline,
              currentImageUrl: frontUrl,
              enabled: widget.enabled,
              onUploadComplete: (result) {
                if (result.isSuccess) {
                  _frontFileId = result.fileId;
                  _notifyChanged();
                }
              },
            ),
            PreviewImageUploadItem(
              label: '左侧',
              icon: Icons.arrow_back,
              currentImageUrl: leftUrl,
              enabled: widget.enabled,
              onUploadComplete: (result) {
                if (result.isSuccess) {
                  _leftFileId = result.fileId;
                  _notifyChanged();
                }
              },
            ),
            PreviewImageUploadItem(
              label: '右侧',
              icon: Icons.arrow_forward,
              currentImageUrl: rightUrl,
              enabled: widget.enabled,
              onUploadComplete: (result) {
                if (result.isSuccess) {
                  _rightFileId = result.fileId;
                  _notifyChanged();
                }
              },
            ),
            PreviewImageUploadItem(
              label: '背面',
              icon: Icons.person_outline,
              currentImageUrl: backUrl,
              enabled: widget.enabled,
              onUploadComplete: (result) {
                if (result.isSuccess) {
                  _backFileId = result.fileId;
                  _notifyChanged();
                }
              },
            ),
            PreviewImageUploadItem(
              label: '手部',
              icon: Icons.pan_tool_outlined,
              currentImageUrl: handUrl,
              enabled: widget.enabled,
              onUploadComplete: (result) {
                if (result.isSuccess) {
                  _handFileId = result.fileId;
                  _notifyChanged();
                }
              },
            ),
            PreviewImageUploadItem(
              label: '腿部',
              icon: Icons.airline_seat_legroom_normal,
              currentImageUrl: legUrl,
              enabled: widget.enabled,
              onUploadComplete: (result) {
                if (result.isSuccess) {
                  _legFileId = result.fileId;
                  _notifyChanged();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _notifyChanged() {
    widget.onChanged?.call({
      'thumbnailFileId': _thumbnailFileId,
      'previewFrontId': _frontFileId,
      'previewLeftId': _leftFileId,
      'previewRightId': _rightFileId,
      'previewBackId': _backFileId,
      'previewHandId': _handFileId,
      'previewLegId': _legFileId,
    });
  }

  /// 获取预览图编辑数据
  Map<String, int?> get uploadedFileIds => {
    'thumbnailFileId': _thumbnailFileId,
    'previewFrontId': _frontFileId,
    'previewLeftId': _leftFileId,
    'previewRightId': _rightFileId,
    'previewBackId': _backFileId,
    'previewHandId': _handFileId,
    'previewLegId': _legFileId,
  };

  /// 是否有任何上传
  bool get hasAnyUpload =>
      _thumbnailFileId != null ||
      _frontFileId != null ||
      _leftFileId != null ||
      _rightFileId != null ||
      _backFileId != null ||
      _handFileId != null ||
      _legFileId != null;
}

/// 缩略图上传组件（较大尺寸）
class _ThumbnailUploadItem extends StatefulWidget {
  final String? currentImageUrl;
  final ValueChanged<PreviewImageUploadResult>? onUploadComplete;
  final bool enabled;

  const _ThumbnailUploadItem({
    this.currentImageUrl,
    this.onUploadComplete,
    this.enabled = true,
  });

  @override
  State<_ThumbnailUploadItem> createState() => _ThumbnailUploadItemState();
}

class _ThumbnailUploadItemState extends State<_ThumbnailUploadItem>
    with AutomaticKeepAliveClientMixin {
  PreviewImageUploadStatus _status = PreviewImageUploadStatus.idle;
  double _progress = 0.0;
  String? _uploadedUrl;
  bool _isHovered = false;

  final FileUploadService _uploadService = FileUploadService();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final isUploaded = _uploadedUrl != null || widget.currentImageUrl != null;
    final displayUrl = _uploadedUrl ?? widget.currentImageUrl;

    return MouseRegion(
      cursor: widget.enabled && _status != PreviewImageUploadStatus.uploading
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled && _status != PreviewImageUploadStatus.uploading
            ? _selectAndUploadImage
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: inputBg,
            border: Border.all(
              color: _status == PreviewImageUploadStatus.error
                  ? Colors.red
                  : _status == PreviewImageUploadStatus.completed
                  ? Colors.green
                  : _isHovered && widget.enabled
                  ? vermillion
                  : scrollBrown.withValues(alpha: 0.4),
              width: _status == PreviewImageUploadStatus.completed
                  ? 2
                  : _isHovered && widget.enabled
                  ? 2
                  : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered && widget.enabled
                ? [
                    BoxShadow(
                      color: vermillion.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              _buildContent(context, isUploaded, displayUrl),
              // Hover 遮罩
              if (_isHovered &&
                  widget.enabled &&
                  _status == PreviewImageUploadStatus.idle)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUploaded
                                ? Icons.refresh
                                : Icons.add_photo_alternate,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isUploaded ? '点击更换' : '点击上传',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isUploaded,
    String? displayUrl,
  ) {
    switch (_status) {
      case PreviewImageUploadStatus.idle:
        if (isUploaded && displayUrl != null) {
          return _buildPreviewContent(context, displayUrl);
        }
        return _buildIdleContent(context);
      case PreviewImageUploadStatus.selecting:
        return _buildLoadingContent(context, '选择中...');
      case PreviewImageUploadStatus.uploading:
        return _buildUploadingContent(context);
      case PreviewImageUploadStatus.completed:
        return _buildPreviewContent(context, displayUrl!);
      case PreviewImageUploadStatus.error:
        return _buildErrorContent(context);
    }
  }

  Widget _buildIdleContent(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: widget.enabled
                ? scrollBrown
                : scrollBrown.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            '点击上传缩略图',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          Text(
            '建议尺寸 200x200',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.35),
              fontSize: 9,
            ),
          ),
        ],
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
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingContent(BuildContext context) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(_progress * 100).toInt()}%',
            style: TextStyle(
              color: vermillion,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
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

  Widget _buildPreviewContent(BuildContext context, String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIdleContent(context),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingContent(context, '加载中');
          },
        ),
        // 更换提示
        if (widget.enabled)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text(
                    '更换',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 28),
          const SizedBox(height: 4),
          Text(
            '上传失败，点击重试',
            style: TextStyle(color: Colors.red.shade700, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _selectAndUploadImage() async {
    setState(() {
      _status = PreviewImageUploadStatus.selecting;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _status = PreviewImageUploadStatus.idle);
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() {
          _status = PreviewImageUploadStatus.error;
        });
        return;
      }

      // 检查文件大小（限制 10MB）
      final fileSize = await File(filePath).length();
      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          setState(() => _status = PreviewImageUploadStatus.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片文件不能超过 10MB')),
          );
        }
        return;
      }

      // 弹出裁剪窗口
      if (!mounted) return;
      final croppedData = await ImageCropDialog.show(
        context,
        imageFile: File(filePath),
        aspectRatio: 1.0, // 正方形
        title: '调整缩略图',
      );

      if (croppedData == null) {
        // 用户取消了裁剪
        setState(() => _status = PreviewImageUploadStatus.idle);
        return;
      }

      // 开始上传裁剪后的图片
      setState(() {
        _status = PreviewImageUploadStatus.uploading;
        _progress = 0.0;
      });

      // 保存裁剪后的图片到临时文件
      final tempDir = await Directory.systemTemp.createTemp('crop_');
      final tempFile = File(
        '${tempDir.path}/cropped_thumb_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(croppedData);

      // 使用图床上传
      final uploadResult = await _uploadService.uploadToImageBed(
        tempFile,
        categoryName: 'character_thumbnail',
      );

      // 删除临时文件
      try {
        await tempFile.delete();
        await tempDir.delete();
      } catch (_) {
        // 忽略删除临时文件的错误
      }

      setState(() {
        _status = PreviewImageUploadStatus.completed;
        _uploadedUrl = uploadResult.url;
        _progress = 1.0;
      });

      widget.onUploadComplete?.call(
        PreviewImageUploadResult(
          fileId: uploadResult.fileId,
          url: uploadResult.url,
        ),
      );

      LogService.i('缩略图上传成功: fileId=${uploadResult.fileId}');
    } catch (e) {
      LogService.e('缩略图上传失败', e);
      setState(() {
        _status = PreviewImageUploadStatus.error;
      });
      widget.onUploadComplete?.call(
        PreviewImageUploadResult(error: e.toString()),
      );
    }
  }
}
