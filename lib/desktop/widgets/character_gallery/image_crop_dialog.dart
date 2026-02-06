import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'character_gallery_theme.dart';

/// 图片调整弹窗
/// 用于在上传前对图片进行正方形裁剪
class ImageCropDialog extends StatefulWidget {
  final File imageFile;
  final double aspectRatio;
  final String title;

  /// 最大分辨率（宽或高的最大像素），默认 1024
  final int maxResolution;

  const ImageCropDialog({
    super.key,
    required this.imageFile,
    this.aspectRatio = 1.0,
    this.title = '调整图片',
    this.maxResolution = 1024,
  });

  /// 显示调整弹窗，返回处理后的图片数据
  static Future<Uint8List?> show(
    BuildContext context, {
    required File imageFile,
    double aspectRatio = 1.0,
    String title = '调整图片',
    int maxResolution = 1024,
  }) async {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageCropDialog(
        imageFile: imageFile,
        aspectRatio: aspectRatio,
        title: title,
        maxResolution: maxResolution,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final CropController _cropController = CropController();
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _isCropping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      setState(() {
        _imageData = bytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '无法读取图片: $e';
        _isLoading = false;
      });
    }
  }

  void _onCrop() {
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  void _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final scaled = await _scaleImage(croppedImage);
          if (mounted) {
            setState(() => _isCropping = false);
            Navigator.of(context).pop(scaled);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isCropping = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('图片处理失败: $e')),
            );
          }
        }
      case CropFailure():
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('处理失败，请重试')));
    }
  }

  /// 按最大分辨率等比缩放图片，不超过则原样返回
  Future<Uint8List> _scaleImage(Uint8List imageData) async {
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final origW = srcImage.width;
    final origH = srcImage.height;
    final maxRes = widget.maxResolution;

    // 不需要缩放
    if (origW <= maxRes && origH <= maxRes) {
      srcImage.dispose();
      return imageData;
    }

    // 等比缩放
    int targetW, targetH;
    if (origW >= origH) {
      targetW = maxRes;
      targetH = (origH * maxRes / origW).round();
    } else {
      targetH = maxRes;
      targetW = (origW * maxRes / origH).round();
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(0, 0, origW.toDouble(), origH.toDouble()),
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(targetW, targetH);
    srcImage.dispose();

    final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
    resized.dispose();
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        height: 640,
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(scrollBrown, inkColor, vermillion),
            // 裁剪区域
            Expanded(child: _buildCropArea(scrollBrown, vermillion)),
            // 底部按钮
            _buildFooter(scrollBrown, vermillion, inkColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color scrollBrown, Color inkColor, Color vermillion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scrollBrown.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // 图标容器
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: vermillion.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.crop_square_rounded, color: vermillion, size: 18),
          ),
          const SizedBox(width: 12),
          // 标题
          Text(
            widget.title,
            style: TextStyle(
              color: inkColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 关闭按钮
          IconButton(
            onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: inkColor.withValues(alpha: 0.5),
              size: 20,
            ),
            splashRadius: 18,
            tooltip: '取消',
          ),
        ],
      ),
    );
  }

  Widget _buildCropArea(Color scrollBrown, Color vermillion) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: vermillion,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(
                color: scrollBrown.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }

    final cropBgColor = Colors.grey.shade900;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(16), // 添加内边距，让角点有空间显示
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Crop(
            image: _imageData!,
            controller: _cropController,
            onCropped: _onCropped,
            aspectRatio: widget.aspectRatio,
            initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
              size: 1.0, // 默认最大裁剪区域
              aspectRatio: widget.aspectRatio,
            ),
            baseColor: cropBgColor,
            maskColor: Colors.black.withValues(alpha: 0.6),
            radius: 0,
            clipBehavior: Clip.none, // 不裁剪，让角点可以显示
            cornerDotBuilder: (size, edgeAlignment) => SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: vermillion, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            interactive: false, // 禁用图片拖动和缩放
            fixCropRect: false, // 允许拖动裁剪框
            overlayBuilder: (context, rect) => SizedBox.expand(
              child: CustomPaint(
                painter: _CropGridPainter(),
              ),
            ),
          ),
          // 处理中遮罩
          if (_isCropping)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: vermillion,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '处理中...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
    );
  }

  Widget _buildFooter(Color scrollBrown, Color vermillion, Color inkColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          // 操作提示
          Icon(
            Icons.info_outline,
            size: 14,
            color: inkColor.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 6),
          Text(
            '拖动选框调整区域，图片将以正方形保存',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          // 取消按钮
          TextButton(
            onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: scrollBrown,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          // 确认按钮
          ElevatedButton(
            onPressed: _isCropping || _imageData == null ? null : _onCrop,
            style: ElevatedButton.styleFrom(
              backgroundColor: vermillion,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isCropping) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(_isCropping ? '处理中' : '完成'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 裁剪区域三等分网格线画笔
class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final thirdW = size.width / 3;
    final thirdH = size.height / 3;

    // 竖线
    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), paint);
    canvas.drawLine(
        Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), paint);

    // 横线
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), paint);
    canvas.drawLine(
        Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
