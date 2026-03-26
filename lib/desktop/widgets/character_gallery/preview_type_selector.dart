import 'package:flutter/material.dart';
import '../../../core/utils/toast_utils.dart';
import 'character_gallery_theme.dart';
import 'preview_images_upload_widget.dart';
import 'video_embed_dialog.dart';

/// 预览媒体类型选择器（编辑弹窗用）
///
/// 支持选择：无预览 / 图片 / 视频外链
/// 暂不支持视频上传（video类型）
class PreviewTypeSelector extends StatefulWidget {
  final String initialType; // none/image/video_url
  final int? initialFileId;
  final String? initialVideoUrl;
  final String? currentImageUrl; // 当前已有的图片URL（编辑模式）
  final ValueChanged<PreviewMediaData> onChanged;
  final bool enabled;

  const PreviewTypeSelector({
    super.key,
    this.initialType = 'none',
    this.initialFileId,
    this.initialVideoUrl,
    this.currentImageUrl,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<PreviewTypeSelector> createState() => _PreviewTypeSelectorState();
}

class _PreviewTypeSelectorState extends State<PreviewTypeSelector> {
  late String _selectedType;
  int? _fileId;
  String? _uploadedImageUrl;
  late TextEditingController _videoUrlController;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _fileId = widget.initialFileId;
    _videoUrlController = TextEditingController(
      text: widget.initialVideoUrl ?? '',
    );
  }

  @override
  void dispose() {
    _videoUrlController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(
      PreviewMediaData(
        previewType: _selectedType,
        previewFileId: _selectedType == 'image' ? _fileId : null,
        previewVideoUrl: _selectedType == 'video_url'
            ? _videoUrlController.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预览媒体',
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // 类型选择
        Row(
          children: [
            _buildTypeChip('none', '无', Icons.block, Colors.grey),
            const SizedBox(width: 8),
            _buildTypeChip(
              'image',
              '图片',
              Icons.image_outlined,
              const Color(0xFF4A90D9),
            ),
            const SizedBox(width: 8),
            _buildTypeChip(
              'video_url',
              '视频外链',
              Icons.link,
              const Color(0xFFFB7299),
            ),
          ],
        ),
        // 根据类型显示对应的输入区域
        if (_selectedType == 'image') ...[
          const SizedBox(height: 12),
          _buildImageUploadArea(context),
        ],
        if (_selectedType == 'video_url') ...[
          const SizedBox(height: 12),
          _buildVideoUrlInput(context, inkColor, scrollBrown),
        ],
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return Expanded(
      child: GestureDetector(
        onTap: widget.enabled
            ? () {
                setState(() => _selectedType = type);
                _notifyChange();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : inputBg,
            border: Border.all(
              color: isSelected ? color : scrollBrown.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : inkColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : inkColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadArea(BuildContext context) {
    final displayUrl = _uploadedImageUrl ?? widget.currentImageUrl;

    return PreviewImageUploadItem(
      label: '预览图片',
      icon: Icons.image_outlined,
      currentImageUrl: displayUrl,
      enabled: widget.enabled,
      onUploadComplete: (result) {
        if (result.isSuccess) {
          setState(() {
            _fileId = result.fileId;
            _uploadedImageUrl = result.url;
          });
          _notifyChange();
        }
      },
    );
  }

  Widget _buildVideoUrlInput(
    BuildContext context,
    Color inkColor,
    Color scrollBrown,
  ) {
    final inputBg = CharacterGalleryTheme.getInputBackground(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _videoUrlController,
                enabled: widget.enabled,
                style: TextStyle(color: inkColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '粘贴B站视频链接或视频直链',
                  hintStyle: TextStyle(
                    color: inkColor.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: scrollBrown.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: scrollBrown.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: vermillion, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.play_circle_outline,
                      size: 18,
                      color: scrollBrown.withValues(alpha: 0.6),
                    ),
                    tooltip: '预览视频',
                    onPressed: () => _previewVideoUrl(context),
                  ),
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '支持 Bilibili 视频链接和视频直链（mp4/webm）',
          style: TextStyle(
            color: inkColor.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _previewVideoUrl(BuildContext context) async {
    final url = _videoUrlController.text.trim();
    if (url.isEmpty) {
      ToastUtils.showWarning(context, '请先输入视频链接');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ToastUtils.showWarning(context, '请输入有效的URL（以 http:// 或 https:// 开头）');
      return;
    }

    if (!VideoEmbedDialog.canEmbed(url)) {
      if (context.mounted) {
        ToastUtils.showWarning(context, '仅支持 Bilibili 视频链接和视频直链（mp4/webm）');
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => VideoEmbedDialog(videoUrl: url),
      );
    }
  }
}

/// 预览媒体数据
class PreviewMediaData {
  final String previewType; // none/image/video_url
  final int? previewFileId;
  final String? previewVideoUrl;

  const PreviewMediaData({
    required this.previewType,
    this.previewFileId,
    this.previewVideoUrl,
  });
}
