import 'package:flutter/material.dart';

import 'package:flutter_quill/flutter_quill.dart';

import '../models/report_models.dart';
import '../utils/log_service.dart';
import '../utils/toast_utils.dart';
import 'guide/guide_tokens.dart';
import 'rich_text_editor.dart';

/// 举报原因项配置
class ReportReasonItem<T> {
  final T value;
  final String label;
  
  const ReportReasonItem({
    required this.value,
    required this.label,
  });
}

/// 通用举报对话框
///
/// 使用 `CommonReportDialog.show(context, onSubmit: ...)` 打开。
class CommonReportDialog<T> extends StatefulWidget {
  final Future<void> Function(ReportPayload<T> payload) onSubmit;
  final bool showPenalties;
  final List<ReportReasonItem<T>> reasons;

  const CommonReportDialog({
    super.key,
    required this.onSubmit,
    required this.reasons,
    this.showPenalties = false,
  }) : assert(reasons.length > 0, 'reasons 不能为空');

  /// 打开通用举报对话框
  static Future<void> show<T>(
    BuildContext context, {
    required Future<void> Function(ReportPayload<T> payload) onSubmit,
    required List<ReportReasonItem<T>> reasons,
    bool showPenalties = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommonReportDialog<T>(
        onSubmit: onSubmit,
        reasons: reasons,
        showPenalties: showPenalties,
      ),
    );
  }

  @override
  State<CommonReportDialog<T>> createState() => _CommonReportDialogState<T>();
}

class _CommonReportDialogState<T> extends State<CommonReportDialog<T>> {
  T? _selectedReason;
  final _quillController = QuillController.basic();
  final List<String> _evidenceImages = [];
  bool _isSubmitting = false;

  /// 最大证据图片数量
  static const int _maxImages = 5;

  // Penalties State
  bool _clearMapVotes = false;
  bool _clearAllVotes = false;
  bool _banHours = false;
  final _banHoursController = TextEditingController();
  bool _banPermanent = false;
  bool _penaltyOther = false;
  final _penaltyOtherController = TextEditingController();

  @override
  void dispose() {
    _quillController.dispose();
    _banHoursController.dispose();
    _penaltyOtherController.dispose();
    super.dispose();
  }

  // 假设 "other" 或者是最后的选项需要强制填写说明
  // 因为 T 是泛型，这里我们假设选中了 reasons 的最后一项则必填说明
  bool get _isDescriptionRequired {
    if (_selectedReason == null || widget.reasons.isEmpty) return false;
    return _selectedReason == widget.reasons.last.value;
  }

  bool get _canSubmit =>
      _selectedReason != null &&
      !_isSubmitting &&
      (!_isDescriptionRequired ||
          _quillController.document.toPlainText().trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) return;

    if (_isDescriptionRequired && _quillController.document.toPlainText().trim().isEmpty) {
      ToastUtils.showWarning(context, '选择该项时请填写具体说明');
      return;
    }

    // Prepare penalties
    List<String>? penalties;
    if (widget.showPenalties) {
      penalties = [];
      if (_clearMapVotes) penalties.add('clear_map_votes');
      if (_clearAllVotes) penalties.add('clear_all_votes');
      if (_banHours) {
        final hrs = _banHoursController.text.trim();
        if (hrs.isEmpty) {
          ToastUtils.showWarning(context, '请填写封禁小时数');
          return;
        }
        penalties.add('ban_vote_hours:$hrs');
      }
      if (_banPermanent) penalties.add('ban_vote_permanent');
      if (_penaltyOther) {
        final otherTxt = _penaltyOtherController.text.trim();
        if (otherTxt.isEmpty) {
          ToastUtils.showWarning(context, '请填写其他惩罚说明');
          return;
        }
        penalties.add('other:$otherTxt');
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = ReportPayload<T>(
        reason: _selectedReason as T,
        description: _quillController.document.toPlainText().trim().isNotEmpty
            ? _quillController.document.toPlainText().trim()
            : null,
        evidenceImages: _evidenceImages,
        penalties: penalties,
      );

      await widget.onSubmit(payload);

      if (mounted) {
        Navigator.of(context).pop();
        ToastUtils.showSuccess(context, '举报已提交，我们会在 24 小时内处理');
      }
    } catch (e) {
      LogService.e('提交举报失败', e);
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = GuideTokens.dialogBg(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor =
        theme.textTheme.bodySmall?.color ?? GuideTokens.textSecondary(context);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
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
                    // 使用 IgnorePointer 防止在提交时更改单选框
                    IgnorePointer(
                      ignoring: _isSubmitting,
                      child: RadioGroup<T>(
                        groupValue: _selectedReason,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedReason = value);
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.reasons
                              .map(
                                (reason) =>
                                    _buildReasonTile(reason, textColor, theme),
                              )
                              .toList(),
                        ),
                      ),
                    ),

                    // 描述文本框及附件区域
                    const SizedBox(height: 12),
                    Text(
                      _isDescriptionRequired
                          ? '详细说明与截图（必填说明，最多 $_maxImages 张截图）'
                          : '详细说明与截图（选填，最多 $_maxImages 张截图）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 240,
                      child: RichTextEditor(
                        controller: _quillController,
                        showToolbar: false,
                        maxImages: _maxImages,
                        hintText: '请描述具体情况...',
                        onImagesChanged: (images) {
                          setState(() {
                            _evidenceImages.clear();
                            _evidenceImages.addAll(images);
                          });
                        },
                      ),
                    ),

                    // 惩罚多选
                    if (widget.showPenalties) ...[
                      const SizedBox(height: 16),
                      Text(
                        '建议惩罚（多选）',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPenaltiesSection(textColor, theme),
                    ],
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
    ReportReasonItem<T> reason,
    Color textColor,
    ThemeData theme,
  ) {
    return RadioListTile<T>(
      title: Text(
        reason.label,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
      value: reason.value,
      activeColor: theme.colorScheme.primary,
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPenaltiesSection(Color textColor, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCheckboxTile(
          '清空当前地图所有投票',
          _clearMapVotes,
          (val) => setState(() => _clearMapVotes = val ?? false),
          textColor,
          theme,
        ),
        _buildCheckboxTile(
          '清空所有地图的投票',
          _clearAllVotes,
          (val) => setState(() => _clearAllVotes = val ?? false),
          textColor,
          theme,
        ),
        Row(
          children: [
            Expanded(
              child: _buildCheckboxTile(
                '禁止投票X小时',
                _banHours,
                (val) => setState(() => _banHours = val ?? false),
                textColor,
                theme,
              ),
            ),
            if (_banHours)
              SizedBox(
                width: 80,
                height: 32,
                child: TextField(
                  controller: _banHoursController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '小时数',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
        _buildCheckboxTile(
          '永久禁止投票',
          _banPermanent,
          (val) => setState(() => _banPermanent = val ?? false),
          textColor,
          theme,
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildCheckboxTile(
                '其他',
                _penaltyOther,
                (val) => setState(() => _penaltyOther = val ?? false),
                textColor,
                theme,
              ),
            ),
            if (_penaltyOther)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _penaltyOtherController,
                    decoration: const InputDecoration(
                      hintText: '具体惩罚说明',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckboxTile(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
    Color textColor,
    ThemeData theme,
  ) {
    return CheckboxListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      ),
      value: value,
      onChanged: _isSubmitting ? null : onChanged,
      activeColor: theme.colorScheme.primary,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
