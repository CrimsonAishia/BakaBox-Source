import 'package:flutter/material.dart';

import '../../models/guide_models.dart';
import 'guide_tokens.dart';

/// 详情页状态横幅（pending / rejected / off_shelf 三态）
///
/// - pending（amber）：「审核中，预计 24 小时内完成」
/// - rejected（red）：显示 rejectReason，可折叠展开
/// - off_shelf（gray）：「该攻略已被下架」
///
/// 用法：
/// ```dart
/// GuideStatusBanner(
///   status: guide.status,
///   rejectReason: guide.rejectReason,
///   onEditTap: () => navigateToEditor(guide.id),
/// )
/// ```
class GuideStatusBanner extends StatefulWidget {
  /// 攻略状态（仅 pending / rejected / offShelf 时显示）
  final GuideStatus status;

  /// 驳回原因（rejected 时使用）
  final String? rejectReason;

  /// 点击「修改后重新提交」回调（rejected 时显示）
  final VoidCallback? onEditTap;

  const GuideStatusBanner({
    super.key,
    required this.status,
    this.rejectReason,
    this.onEditTap,
  });

  @override
  State<GuideStatusBanner> createState() => _GuideStatusBannerState();
}

class _GuideStatusBannerState extends State<GuideStatusBanner> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // 仅三种状态显示 banner
    if (widget.status != GuideStatus.pending &&
        widget.status != GuideStatus.rejected &&
        widget.status != GuideStatus.offShelf) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space16,
        vertical: GuideTokens.space12,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: GuideTokens.borderRadius12,
        border: Border.all(
          color: _borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _statusIcon(),
                size: 18,
                color: _iconColor(),
              ),
              const SizedBox(width: GuideTokens.space8),
              Expanded(
                child: Text(
                  _statusText(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _textColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // rejected 时可展开 + 修改按钮
              if (widget.status == GuideStatus.rejected) ...[
                if (widget.rejectReason != null &&
                    widget.rejectReason!.isNotEmpty)
                  _buildExpandButton(theme),
                if (widget.onEditTap != null)
                  _buildEditButton(theme),
              ],
            ],
          ),
          // 展开的驳回原因
          if (widget.status == GuideStatus.rejected &&
              _isExpanded &&
              widget.rejectReason != null &&
              widget.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: GuideTokens.space8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(GuideTokens.space12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: GuideTokens.borderRadius8,
              ),
              child: Text(
                widget.rejectReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textColor().withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _backgroundColor(BuildContext context) {
    return switch (widget.status) {
      GuideStatus.pending =>
        GuideTokens.statusPending.withValues(alpha: 0.08),
      GuideStatus.rejected =>
        GuideTokens.statusRejected.withValues(alpha: 0.08),
      GuideStatus.offShelf =>
        GuideTokens.statusOffShelf.withValues(alpha: 0.08),
      _ => Colors.transparent,
    };
  }

  Color _borderColor(BuildContext context) {
    return switch (widget.status) {
      GuideStatus.pending =>
        GuideTokens.statusPending.withValues(alpha: 0.2),
      GuideStatus.rejected =>
        GuideTokens.statusRejected.withValues(alpha: 0.2),
      GuideStatus.offShelf =>
        GuideTokens.statusOffShelf.withValues(alpha: 0.2),
      _ => Colors.transparent,
    };
  }

  IconData _statusIcon() {
    return switch (widget.status) {
      GuideStatus.pending => Icons.hourglass_empty_rounded,
      GuideStatus.rejected => Icons.error_outline_rounded,
      GuideStatus.offShelf => Icons.visibility_off_outlined,
      _ => Icons.info_outline,
    };
  }

  Color _iconColor() {
    return switch (widget.status) {
      GuideStatus.pending => GuideTokens.statusPending,
      GuideStatus.rejected => GuideTokens.statusRejected,
      GuideStatus.offShelf => GuideTokens.statusOffShelf,
      _ => Colors.grey,
    };
  }

  Color _textColor() {
    return switch (widget.status) {
      GuideStatus.pending => GuideTokens.statusPending,
      GuideStatus.rejected => GuideTokens.statusRejected,
      GuideStatus.offShelf => GuideTokens.statusOffShelf,
      _ => Colors.grey,
    };
  }

  String _statusText() {
    return switch (widget.status) {
      GuideStatus.pending => '审核中，预计 24 小时内完成',
      GuideStatus.rejected => '该攻略审核未通过',
      GuideStatus.offShelf => '该攻略已被下架',
      _ => '',
    };
  }

  Widget _buildExpandButton(ThemeData theme) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GuideTokens.space8,
          vertical: GuideTokens.space4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isExpanded ? '收起原因' : '查看原因',
              style: theme.textTheme.labelSmall?.copyWith(
                color: GuideTokens.statusRejected,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 14,
              color: GuideTokens.statusRejected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: GuideTokens.space8),
      child: InkWell(
        onTap: widget.onEditTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GuideTokens.space8,
            vertical: GuideTokens.space4,
          ),
          child: Text(
            '修改后重新提交',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
