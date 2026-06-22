import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api/guide_api.dart';
import '../../models/guide_models.dart';
import '../../services/analytics_service.dart';
import '../../services/file_upload_service.dart';
import '../../services/image_url_service.dart';
import '../../utils/log_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/file_validation_utils.dart';
import '../image_upload_button.dart';
import 'guide_tokens.dart';

/// 通用举报对话框
///
/// 支持举报攻略 / 评论 / 用户等目标。
/// 使用 `ReportDialog.show(context, targetId, targetType)` 打开。
class ReportDialog extends StatefulWidget {
  final int targetId;
  final String targetType;

  const ReportDialog({
    super.key,
    required this.targetId,
    required this.targetType,
  });

  /// 打开举报对话框
  static Future<void> show(
    BuildContext context, {
    required int targetId,
    required String targetType,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ReportDialog(targetId: targetId, targetType: targetType),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();
  final List<String> _evidenceImages = [];
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  final _uploadService = FileUploadService();

  /// 最大证据图片数量
  static const int _maxImages = 3;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isDescriptionRequired => _selectedReason == ReportReason.other;

  bool get _canSubmit =>
      _selectedReason != null &&
      !_isSubmitting &&
      !_isUploadingImage &&
      (!_isDescriptionRequired ||
          _descriptionController.text.trim().isNotEmpty);

  Future<void> _pickImage() async {
    if (_evidenceImages.length >= _maxImages) {
      ToastUtils.showWarning(context, '最多上传 $_maxImages 张证据图');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final validation = FileValidationUtils.validateFile(file);

      if (!validation.isValid) {
        if (mounted) {
          ToastUtils.showError(context, validation.errorMessage ?? '文件验证失败');
        }
        return;
      }

      setState(() => _isUploadingImage = true);

      final uploadResult = await _uploadService.uploadToImageBed(
        file,
        categoryName: 'bakabox_guides',
      );

      final imageRef = ImageUrlService.createFileIdRef(uploadResult.fileId);

      if (mounted) {
        setState(() {
          _evidenceImages.add(imageRef);
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      LogService.e('上传证据图失败', e);
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ToastUtils.showError(context, '上传图片失败，请重试');
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _evidenceImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    if (_isDescriptionRequired && _descriptionController.text.trim().isEmpty) {
      ToastUtils.showWarning(context, '选择「其他」时请填写具体说明');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final report = GuideReport(
        targetId: widget.targetId,
        targetType: widget.targetType,
        reason: _selectedReason!,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        evidenceImages: _evidenceImages,
      );

      await GuideApi().report(report);

      // 上报埋点 guide_report（fire-and-forget）
      AnalyticsService.instance.trackEvent('guide_report', {
        'targetId': widget.targetId,
        'targetType': widget.targetType,
        'reason': _selectedReason!.name,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ToastUtils.showSuccess(context, '举报已提交，我们会在 24 小时内处理');
      }
    } catch (e) {
      LogService.e('提交举报失败', e);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastUtils.showError(context, '提交举报失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final bgColor = GuideTokens.dialogBg(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor =
        theme.textTheme.bodySmall?.color ?? GuideTokens.textSecondary(context);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '举报',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: secondaryTextColor),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 举报原因
            Text(
              '请选择举报原因',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Radio 列表
                    RadioGroup<ReportReason>(
                      groupValue: _selectedReason,
                      onChanged: (value) {
                        if (!_isSubmitting) {
                          setState(() => _selectedReason = value);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ReportReason.values
                            .map(
                              (reason) =>
                                  _buildReasonTile(reason, textColor, theme),
                            )
                            .toList(),
                      ),
                    ),

                    // 描述文本框
                    const SizedBox(height: 12),
                    Text(
                      _isDescriptionRequired ? '详细说明（必填）' : '详细说明（选填）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      maxLength: 200,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '请描述具体情况...',
                        hintStyle: TextStyle(color: secondaryTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: GuideTokens.border(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: GuideTokens.border(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    // 证据图片
                    const SizedBox(height: 12),
                    Text(
                      '证据截图（选填，最多 $_maxImages 张）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImageSection(isDark, secondaryTextColor),
                  ],
                ),
              ),
            ),

            // 提交按钮
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white60,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('提交举报'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonTile(
    ReportReason reason,
    Color textColor,
    ThemeData theme,
  ) {
    return RadioListTile<ReportReason>(
      title: Text(
        reason.label,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
      value: reason,
      activeColor: theme.colorScheme.primary,
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildImageSection(bool isDark, Color secondaryTextColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 已上传的图片预览
        ..._evidenceImages.asMap().entries.map(
          (entry) => _buildImageThumb(entry.key, isDark),
        ),
        // 上传按钮
        if (_evidenceImages.length < _maxImages)
          ImageUploadButton(
            onPressed: _pickImage,
            isUploading: _isUploadingImage,
          ),
      ],
    );
  }

  Widget _buildImageThumb(int index, bool isDark) {
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark
                ? GuideTokens.fallbackBgDark
                : GuideTokens.fallbackBgLight,
            border: Border.all(color: GuideTokens.border(context)),
          ),
          child: const Center(
            child: Icon(Icons.image, size: 28, color: GuideTokens.fallbackIcon),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: _isSubmitting ? null : () => _removeImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: GuideTokens.statusRejected,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
