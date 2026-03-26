import 'package:flutter/material.dart';

/// 图片上传按钮组件
///
/// 显示上传按钮和上传进度
class ImageUploadButton extends StatelessWidget {
  /// 点击回调
  final VoidCallback onPressed;

  /// 是否正在上传
  final bool isUploading;

  /// 上传进度 (0.0 - 1.0)
  final double? progress;

  /// 是否使用紧凑模式（移动端）
  final bool compact;

  const ImageUploadButton({
    super.key,
    required this.onPressed,
    this.isUploading = false,
    this.progress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactButton(context);
    }
    return _buildFullButton(context);
  }

  /// 构建完整按钮（桌面端）
  Widget _buildFullButton(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: isUploading ? null : onPressed,
        icon: isUploading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              )
            : const Icon(Icons.image, size: 18),
        label: Text(
          isUploading
              ? (progress != null
                    ? '上传中 ${(progress! * 100).toInt()}%'
                    : '上传中...')
              : '上传图片',
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  /// 构建紧凑按钮（移动端）
  Widget _buildCompactButton(BuildContext context) {
    return IconButton(
      onPressed: isUploading ? null : onPressed,
      icon: isUploading
          ? Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress,
                  ),
                ),
                const Icon(Icons.image, size: 12),
              ],
            )
          : const Icon(Icons.image),
      tooltip: '上传图片',
    );
  }
}
