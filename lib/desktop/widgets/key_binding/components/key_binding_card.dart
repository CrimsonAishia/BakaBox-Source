import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/signed_network_image.dart';
import '../../guide/community_guide/community_guide_fallback.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/rich_text_viewer.dart';
import '../../../../core/services/quill_delta_codec.dart';

class KeyBindingCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? category;
  final bool isApplied;
  final Map<String, String>? appliedBindings;
  final bool showCover;
  final VoidCallback onTap;
  final String? imageUrl;

  // 市场特有属性
  final int fallbackId;
  final String? authorName;
  final String? authorAvatar;
  final int? viewCount;
  final int? useCount;
  final int? commentCount;
  final int? likeCount;
  final DateTime? updatedAt;

  // 我的配置特有属性
  final bool isOwner;
  final bool isApproved;
  final bool isPending;
  final bool hasPendingChange;
  final bool isRejected;
  final String? auditRemark;
  final String? pendingChangeType;

  final VoidCallback? onEdit;
  final void Function(String? reason)? onDelete;
  final VoidCallback? onCancelAudit;
  final VoidCallback? onCancelApply;
  final VoidCallback? onShowHistory;

  const KeyBindingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.category,
    this.isApplied = false,
    this.appliedBindings,
    this.showCover = true,
    required this.onTap,
    this.imageUrl,
    this.fallbackId = 0,
    this.authorName,
    this.authorAvatar,
    this.viewCount,
    this.useCount,
    this.commentCount,
    this.likeCount,
    this.updatedAt,
    this.isOwner = false,
    this.isApproved = false,
    this.isPending = false,
    this.hasPendingChange = false,
    this.isRejected = false,
    this.auditRemark,
    this.pendingChangeType,
    this.onEdit,
    this.onDelete,
    this.onCancelAudit,
    this.onCancelApply,
    this.onShowHistory,
  });

  @override
  State<KeyBindingCard> createState() => _KeyBindingCardState();
}

class _KeyBindingCardState extends State<KeyBindingCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 从 CommunityGuideFallback 中获取渐变色
    final gradientColors = CommunityGuideFallback.gradient(widget.fallbackId);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovering ? -3.0 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _hovering
                    ? (isDark ? 0.4 : 0.15)
                    : (isDark ? 0.2 : 0.05),
              ),
              blurRadius: _hovering ? 20 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.hasPendingChange ||
                        widget.isPending ||
                        widget.isRejected)
                      _buildAuditStatusBar(),
                    // 顶部封面区 (16:9 比例)
                    if (widget.showCover)
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                            widget.hasPendingChange ||
                                    widget.isPending ||
                                    widget.isRejected
                                ? 0
                                : 12,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // 限制最大高度为 16:9 比例下的高度，防止过高的图片（如血针、护甲等近似 1:1 的图）导致卡片拉得太长
                            final maxAllowedHeight =
                                constraints.maxWidth / (16 / 9);
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: maxAllowedHeight,
                              ),
                              child: Stack(
                                children: [
                                  // 1. 底层背景渐变（通过 Positioned.fill 填充满由于图片高度撑开的整个 Stack）
                                  Positioned.fill(
                                    child: _buildGradientFallback(
                                      gradientColors,
                                      showIcon:
                                          widget.imageUrl?.isEmpty ?? true,
                                    ),
                                  ),

                                  // 2. 如果有图片，按照自身比例完全展现，让卡片高度自适应，这样图片上下就不会漏出多余的底色
                                  if (widget.imageUrl?.isNotEmpty == true)
                                    SizedBox(
                                      width: double.infinity,
                                      child: widget.imageUrl!.startsWith('http')
                                          ? SignedNetworkImage(
                                              url: widget.imageUrl!,
                                              fit: BoxFit.contain,
                                              fallback: AspectRatio(
                                                aspectRatio: 16 / 9,
                                                child: Center(
                                                  child: Icon(
                                                    widget.icon,
                                                    size: 48,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Image.asset(
                                              widget.imageUrl!,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => AspectRatio(
                                                    aspectRatio: 16 / 9,
                                                    child: Center(
                                                      child: Icon(
                                                        widget.icon,
                                                        size: 48,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                    )
                                  else
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: const SizedBox(),
                                    ),

                                  if (widget.isApplied)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: _buildCornerBadge(),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // 下方内容区
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1a1a2e),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (widget.description.isNotEmpty) ...[
                                if (QuillDeltaCodec.isDeltaJson(
                                  widget.description,
                                ))
                                  SizedBox(
                                    height: 60, // 限制最大高度约为 3 行
                                    child: ClipRect(
                                      child: IgnorePointer(
                                        child: RichTextViewer(
                                          content: widget.description,
                                          compact: true,
                                          scrollable: false,
                                          textStyle: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: isDark
                                                ? Colors.white54
                                                : AppColors.gray500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    widget.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: isDark
                                          ? Colors.white54
                                          : AppColors.gray500,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ],
                              if (widget.category != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${widget.category}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // 市场数据行
                              if (widget.authorName != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.file_download_outlined,
                                      size: 16,
                                      color: isDark
                                          ? Colors.white38
                                          : AppColors.gray400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.useCount ?? 0}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white38
                                            : AppColors.gray400,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.likeCount != null) ...[
                                      Icon(
                                        Icons.thumb_up_outlined,
                                        size: 16,
                                        color: AppColors.red500.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.likeCount}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white38
                                              : AppColors.gray400,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.commentCount ?? 0}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white38
                                            : AppColors.gray400,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: isDark
                                                ? Colors.white38
                                                : AppColors.gray400,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              widget.updatedAt != null
                                                  ? TimeUtils.formatDateTimeRelative(
                                                      widget.updatedAt!,
                                                    )
                                                  : '未知',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white38
                                                    : AppColors.gray400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (widget.isOwner) ...[
                                      if (widget.onEdit != null ||
                                          widget.onDelete != null ||
                                          widget.onCancelAudit != null)
                                        Visibility(
                                          visible: false,
                                          maintainSize: true,
                                          maintainAnimation: true,
                                          maintainState: true,
                                          child: _KeyBindingCardMoreMenu(
                                            isApproved: widget.isApproved,
                                            isPending: widget.isPending,
                                            hasPendingChange:
                                                widget.hasPendingChange,
                                            onEdit: widget.onEdit,
                                            onDelete: widget.onDelete,
                                            onCancelAudit: widget.onCancelAudit,
                                            onShowHistory: widget.onShowHistory,
                                          ),
                                        ),
                                    ] else if (widget.authorName != null) ...[
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                widget.authorName!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : AppColors.gray700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _buildAvatar(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!widget.showCover && widget.isApplied)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(
                                  widget.hasPendingChange ||
                                          widget.isPending ||
                                          widget.isRejected
                                      ? 0
                                      : 12,
                                ),
                              ),
                              child: _buildCornerBadge(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (widget.isApplied)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_hovering,
                      child: _buildHoverOverlay(isDark),
                    ),
                  ),
                if (widget.isOwner &&
                    (widget.onEdit != null ||
                        widget.onDelete != null ||
                        widget.onCancelAudit != null))
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: _KeyBindingCardMoreMenu(
                      isApproved: widget.isApproved,
                      isPending: widget.isPending,
                      hasPendingChange: widget.hasPendingChange,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      onCancelAudit: widget.onCancelAudit,
                      onShowHistory: widget.onShowHistory,
                      forceLightIcon: widget.isApplied && _hovering,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoverOverlay(bool isDark) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _hovering ? 1.0 : 0.0,
      child: Stack(
        children: [
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.appliedBindings != null &&
                    widget.appliedBindings!.isNotEmpty) ...[
                  const Text(
                    '当前绑定',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.appliedBindings!.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(', '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => widget.onTap(),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('打开'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onCancelApply?.call();
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('取消绑定'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBadge() {
    return CustomPaint(
      painter: _CornerTrianglePainter(
        color: Colors.green.withValues(alpha: 0.92),
      ),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.topRight,
        padding: const EdgeInsets.only(top: 8, right: 8),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildGradientFallback(
    List<Color> gradientColors, {
    bool showIcon = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: showIcon
          ? Center(
              child: Icon(
                widget.icon,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            )
          : null,
    );
  }

  Widget _buildAvatar() {
    final fallback = CommunityGuideFallback.gradient(
      widget.authorName.hashCode,
    );
    final placeholder = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: fallback),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 22,
        height: 22,
        child: SignedNetworkImage(
          url: widget.authorAvatar,
          fallback: placeholder,
          cacheWidth: 64,
          cacheHeight: 64,
        ),
      ),
    );
  }

  Widget _buildAuditStatusBar() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (widget.hasPendingChange) {
      if (widget.pendingChangeType == 'delete') {
        statusText = '删除审核中';
        statusColor = const Color(0xFFEF4444); // Red
        statusIcon = Icons.delete_outline;
      } else {
        statusText = '修改审核中';
        statusColor = const Color(0xFF3B82F6); // Blue
        statusIcon = Icons.edit_outlined;
      }
    } else if (widget.isPending) {
      statusText = '提交审核中';
      statusColor = const Color(0xFFEAB308); // Yellow
      statusIcon = Icons.schedule;
    } else {
      statusText = '未通过';
      statusColor = const Color(0xFFEF4444); // Red
      statusIcon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (widget.isRejected &&
              widget.auditRemark != null &&
              widget.auditRemark!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
              child: Tooltip(
                message: widget.auditRemark!,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(
                  '- ${widget.auditRemark!}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyBindingCardMoreMenu extends StatelessWidget {
  final bool isApproved;
  final bool isPending;
  final bool hasPendingChange;
  final bool forceLightIcon;
  final VoidCallback? onEdit;
  final void Function(String? reason)? onDelete;
  final VoidCallback? onCancelAudit;
  final VoidCallback? onShowHistory;

  const _KeyBindingCardMoreMenu({
    required this.isApproved,
    required this.isPending,
    required this.hasPendingChange,
    this.forceLightIcon = false,
    this.onEdit,
    this.onDelete,
    this.onCancelAudit,
    this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? AppColors.slate800 : Colors.white;
    final menuTextColor = isDark ? Colors.white : Colors.black87;

    final iconColor = forceLightIcon
        ? Colors.white
        : (isDark ? Colors.white54 : Colors.grey[600]);

    final btnBgColor = forceLightIcon
        ? Colors.white.withValues(alpha: 0.15)
        : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03));

    final showCancel = isPending || hasPendingChange;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: btnBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        tooltip: '更多操作',
        icon: Icon(Icons.more_vert, size: 18, color: iconColor),
        padding: EdgeInsets.zero,
        iconSize: 18,
        splashRadius: 16,
        color: menuBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder: (context) {
          return [
            if (onEdit != null)
              PopupMenuItem<String>(
                value: 'edit',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: menuTextColor),
                    const SizedBox(width: 8),
                    Text(
                      '修改',
                      style: TextStyle(color: menuTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (showCancel && onCancelAudit != null)
              PopupMenuItem<String>(
                value: 'cancel_audit',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      size: 14,
                      color: AppColors.amber500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '取消审核',
                      style: const TextStyle(
                        color: AppColors.amber500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (onDelete != null)
              PopupMenuItem<String>(
                value: 'delete',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: Colors.redAccent.shade100,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '删除',
                      style: TextStyle(
                        color: Colors.redAccent.shade100,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (onShowHistory != null)
              PopupMenuItem<String>(
                value: 'history',
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 14, color: menuTextColor),
                    const SizedBox(width: 8),
                    Text(
                      '历史记录',
                      style: TextStyle(color: menuTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ];
        },
        onSelected: (value) {
          if (value == 'edit' || value == 'delete') {
            if (hasPendingChange) {
              ToastUtils.showInfo(context, '当前已有待审核的变更申请，请先取消或等待审核完成');
              return;
            }
          }

          if (value == 'edit') {
            onEdit?.call();
          } else if (value == 'delete') {
            _confirmDelete(context, menuBg, menuTextColor);
          } else if (value == 'cancel_audit') {
            onCancelAudit?.call();
          } else if (value == 'history') {
            onShowHistory?.call();
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Color bgColor, Color textColor) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        String reason = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final isReasonEmpty = reason.trim().isEmpty;
            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                '确认删除',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '删除后将无法恢复，确认删除该配置吗？',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  if (isApproved) ...[
                    const SizedBox(height: 16),
                    Text(
                      '删除理由（必填）',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '已通过的配置删除需要填写理由',
                        hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: textColor.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: textColor.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor, fontSize: 13),
                      onChanged: (val) {
                        setState(() {
                          reason = val;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(
                    '取消',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  ),
                ),
                TextButton(
                  onPressed: (isApproved && isReasonEmpty)
                      ? null
                      : () => Navigator.of(
                          ctx,
                        ).pop(isApproved ? reason.trim() : ''),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        );
      },
    ).then((reasonStr) {
      if (reasonStr != null) {
        onDelete?.call(reasonStr.isEmpty ? null : reasonStr);
      }
    });
  }
}

class _CornerTrianglePainter extends CustomPainter {
  final Color color;

  _CornerTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
