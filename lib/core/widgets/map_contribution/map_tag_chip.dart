part of '../map_contribution_dialog.dart';

/// 标签网格组件
class _TagGrid extends StatelessWidget {
  final List<MapTag> tags;
  final MapTagState state;
  final bool isDark;
  final bool isUserSection;
  final String mapName;

  const _TagGrid({
    required this.tags,
    required this.state,
    required this.isDark,
    required this.isUserSection,
    required this.mapName,
  });

  @override
  Widget build(BuildContext context) {
    final dialogState = context
        .findAncestorStateOfType<_MapContributionDialogState>();
    if (dialogState == null) {
      return const SizedBox.shrink();
    }

    // 获取后端用户 ID
    final currentUserId = TokenService.instance.userInfo?.id;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;
          final mapVote = state.getMapTagVoteByTagId(tag.id);
          final hasVoted = mapVote?.hasVoted ?? false;
          final voteCount = mapVote?.voteCount ?? 0;
          final upCount = mapVote?.upCount ?? 0;
          final downCount = mapVote?.downCount ?? 0;
          final isOwner =
              state.userTags.any((t) => t.id == tag.id) ||
              (currentUserId != null &&
                  tag.contributor?.userId == currentUserId);

          return TweenAnimationBuilder<double>(
            key: ValueKey('tag_${isUserSection ? 'user_' : ''}${tag.id}'),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 200 + index * 50),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + 0.5 * value,
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: _AnimatedTagChip(
              tag: tag,
              hasVoted: hasVoted,
              voteCount: voteCount,
              upCount: upCount,
              downCount: downCount,
              isVoting: state.isVoting,
              isDark: isDark,
              isOwner: isOwner,
              hasUpvoted: mapVote?.hasUpvoted ?? false,
              hasDownvoted: mapVote?.hasDownvoted ?? false,
              hasPendingChangeRequest: state.hasPendingChangeRequest(tag.id),
              mapName: mapName,
              onVote: (voteType) => dialogState.handleTagVote(tag, voteType),
              onEdit: () => dialogState.showEditTagDialog(tag),
              onDelete: () => dialogState.showDeleteTagDialog(tag),
              onCancelChangeRequest: () =>
                  dialogState.handleCancelChangeRequest(tag),
              onShowVoters: () => dialogState.showTagVotersDialog(mapName, tag),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 标签胶囊组件
class _AnimatedTagChip extends StatefulWidget {
  final MapTag tag;
  final bool hasVoted;
  final int voteCount;
  final int upCount;
  final int downCount;
  final bool isVoting;
  final bool isDark;
  final bool isOwner;
  final bool hasUpvoted;
  final bool hasDownvoted;
  final bool hasPendingChangeRequest;
  final String mapName;
  final void Function(String voteType) onVote;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCancelChangeRequest;
  final VoidCallback onShowVoters;

  const _AnimatedTagChip({
    required this.tag,
    required this.hasVoted,
    required this.voteCount,
    required this.upCount,
    required this.downCount,
    required this.isVoting,
    required this.isDark,
    required this.isOwner,
    required this.hasUpvoted,
    required this.hasDownvoted,
    required this.hasPendingChangeRequest,
    required this.mapName,
    required this.onVote,
    required this.onEdit,
    required this.onDelete,
    required this.onCancelChangeRequest,
    required this.onShowVoters,
  });

  @override
  State<_AnimatedTagChip> createState() => _AnimatedTagChipState();
}

class _AnimatedTagChipState extends State<_AnimatedTagChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isTagHovered = false;
  bool _isOverlayHovered = false;
  bool _isVisible = false;
  Timer? _hideTimer;

  bool get _isHovered => _isTagHovered || _isOverlayHovered;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted && _isVisible && !_isHovered) {
          setState(() {
            _isVisible = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _forceCloseOverlay() {
    _hideTimer?.cancel();
    _isTagHovered = false;
    _isOverlayHovered = false;
    if (mounted) {
      _animController.reverse();
    }
  }

  void _updateHoverState(bool isOverlay, bool isHovered) {
    if (isOverlay) {
      _isOverlayHovered = isHovered;
    } else {
      _isTagHovered = isHovered;
    }

    _hideTimer?.cancel();

    if (_isHovered) {
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
        });
      }
      _animController.forward();
    } else {
      // 延迟 100ms 再执行消失动画，防止跨越间隙时闪烁
      _hideTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && !_isHovered) {
          _animController.reverse();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;

    return PortalTarget(
      visible: _isVisible,
      anchor: const Aligned(
        follower: Alignment.bottomCenter,
        target: Alignment.topCenter,
        offset: Offset(0, 0),
      ),
      portalFollower: MouseRegion(
        onEnter: (_) => _updateHoverState(true, true),
        onExit: (_) => _updateHoverState(true, false),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2.0),
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: _buildTagHoverOverlay(tag),
            ),
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => _updateHoverState(false, true),
        onExit: (_) => _updateHoverState(false, false),
        child: _buildTagMainButton(
          tag,
          widget.hasVoted,
          widget.voteCount,
          widget.isDark,
          _isHovered,
        ),
      ),
    );
  }

  /// 构建标签主按钮
  Widget _buildTagMainButton(
    MapTag tag,
    bool hasVoted,
    int voteCount,
    bool isDark,
    bool isHovered,
  ) {
    // 确定标签的背景色、边框色和文字色
    final Color backgroundColor;
    final Color borderColor;
    final Color textColor;
    final Color badgeBgColor;
    final Color badgeTextColor;

    // 获取标签的自定义颜色
    final tagColor = tag.colorValue;

    // 边框颜色由审核状态决定：审核中黄色、已拒绝红色、已投票绿色
    Color statusBorderColor;
    if (tag.isPending) {
      statusBorderColor = AppColors.amber500;
    } else if (tag.isRejected) {
      statusBorderColor = AppColors.red500;
    } else if (hasVoted) {
      statusBorderColor = AppColors.emerald500;
    } else {
      statusBorderColor = Colors.transparent;
    }

    if (tagColor != null) {
      // 有自定义颜色：背景填满颜色，边框表示状态
      backgroundColor = tagColor;
      final luminance = tagColor.computeLuminance();
      textColor = luminance > 0.5 ? AppColors.gray800 : Colors.white;
      badgeBgColor = luminance > 0.5
          ? Colors.black.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.25);
      badgeTextColor = textColor;
      borderColor = statusBorderColor != Colors.transparent
          ? statusBorderColor
          : (luminance > 0.5
                ? tagColor.withValues(alpha: 0.6)
                : tagColor.withValues(alpha: 0.8));
    } else {
      // 无自定义颜色：背景不变，边框表示状态（isPending/isRejected/hasVoted 共用样式）
      backgroundColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey[100]!;
      textColor = isDark ? Colors.white : Colors.black87;
      badgeBgColor = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey[200]!;
      badgeTextColor = isDark ? Colors.white70 : Colors.grey[600]!;
      borderColor = statusBorderColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      transform: isHovered
          ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHovered && statusBorderColor == Colors.transparent
              ? (tagColor ?? AppColors.primary).withValues(alpha: 0.8)
              : borderColor,
          width: 4,
        ),
        boxShadow: isHovered
            ? [
                BoxShadow(
                  color: (tagColor ?? AppColors.primary).withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 65),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              tag.name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.2,
              ),
            ),
            // 审核中的标签不显示投票数（已拒绝的也没有投票）
            if (!tag.isPending && !tag.isRejected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$voteCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            // 审核状态标签
            if (tag.isUserTag && !tag.isApproved) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tag.isPending ? '审核中' : '已拒绝',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            // 变更审核中状态标签（深色实底，不受 tag 背景色干扰）
            if (widget.hasPendingChangeRequest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                decoration: BoxDecoration(
                  // 深色实底遮罩，对任何 tag 颜色都有强对比
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '变更审核中',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber500,
                        height: 1.2,
                      ),
                    ),
                    if (widget.isOwner) ...[
                      const Text(
                        ' | ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                          height: 1.2,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onCancelChangeRequest,
                          child: const Text(
                            '撤销',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.red500,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.red500,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建标签 Hover 遮罩层
  Widget _buildTagHoverOverlay(MapTag tag) {
    final tagColor = tag.colorValue;
    final shadowColor = (tagColor ?? AppColors.primary).withValues(
      alpha: 0.4,
    );
    final bgColor = AppColors.slate800;

    return IntrinsicWidth(
      child: Container(
        decoration: ShapeDecoration(
          color: bgColor,
          shape: TooltipShapeBorder(
            borderColor: Colors.white.withValues(alpha: 0.3),
          ),
          shadows: [
            BoxShadow(color: shadowColor, blurRadius: 12, spreadRadius: 1),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: _buildTagExpandedPanel(
          tag,
          hasUpvoted: widget.hasUpvoted,
          hasDownvoted: widget.hasDownvoted,
        ),
      ),
    );
  }

  /// 标签展开面板
  Widget _buildTagExpandedPanel(
    MapTag tag, {
    required bool hasUpvoted,
    required bool hasDownvoted,
  }) {
    // 全局标签 (auditStatus == null) 视为已通过
    final isEffectivelyApproved = tag.isApproved || tag.auditStatus == null;

    // 只有已通过的标签才显示投票按钮
    final showVoteButtons = isEffectivelyApproved;

    // 被拒绝时显示拒绝原因
    final auditRemark = tag.auditRemark ?? '';
    // 被拒绝时，有 remark 显示原因，没有 remark 也显示兜底文字
    final showRejectReason = tag.isRejected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 拒绝原因行
        if (showRejectReason) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.cancel_outlined,
                    size: 13,
                    color: AppColors.red500,
                  ),
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    auditRemark.isNotEmpty ? '拒绝原因：$auditRemark' : '审核未通过',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.red500,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        // 操作按钮行
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 投票按钮（审核中的标签不显示）
            if (showVoteButtons) ...[
              // 赞成按钮
              _buildTagVoteButton(
                icon: hasUpvoted ? MdiIcons.thumbUp : MdiIcons.thumbUpOutline,
                isActive: hasUpvoted,
                isUpvote: true,
                label: '${widget.upCount}',
                tooltip: '赞成',
                onTap: widget.isVoting
                    ? null
                    : () {
                        widget.onVote('up');
                      },
              ),
              const SizedBox(width: 4),
              // 反对按钮
              _buildTagVoteButton(
                icon: hasDownvoted
                    ? MdiIcons.thumbDown
                    : MdiIcons.thumbDownOutline,
                isActive: hasDownvoted,
                isUpvote: false,
                onTap: widget.isVoting
                    ? null
                    : () {
                        widget.onVote('down');
                      },
              ),
              const SizedBox(width: 4),
            ],
            // 查看投票用户按钮（已通过的标签才显示）
            if (isEffectivelyApproved)
              _buildTagActionButton(
                icon: MdiIcons.accountGroupOutline,
                tooltip: '查看投票用户',
                color: AppColors.indigo500,
                onTap: () {
                  _forceCloseOverlay();
                  widget.onShowVoters();
                },
              ),
            // 用户自己的标签显示编辑和删除按钮（若不在变更中）
            if (widget.isOwner && !widget.hasPendingChangeRequest) ...[
              const SizedBox(width: 4),
              // 编辑按钮
              _buildTagActionButton(
                icon: MdiIcons.pencilOutline,
                tooltip: isEffectivelyApproved ? '申请变更' : '修改后重新提交',
                color: AppColors.amber500,
                onTap: () {
                  _forceCloseOverlay();
                  widget.onEdit();
                },
              ),
              const SizedBox(width: 4),
              // 删除按钮
              _buildTagActionButton(
                icon: MdiIcons.deleteOutline,
                tooltip: isEffectivelyApproved ? '申请删除' : '删除',
                color: AppColors.red500,
                onTap: () {
                  _forceCloseOverlay();
                  widget.onDelete();
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 标签投票按钮（与编辑/删除按钮一致大小）
  /// [label] 不为 null 时在图标右侧显示文本，如当前票数
  Widget _buildTagVoteButton({
    required IconData icon,
    required bool isActive,
    required bool isUpvote,
    required VoidCallback? onTap,
    String? label,
    String? tooltip,
  }) {
    final activeColor = isUpvote
        ? AppColors.emerald500
        : AppColors.red500;
    final bgColor = Colors.white.withValues(alpha: 0.15);
    final iconColor = Colors.white;

    return Tooltip(
      message: tooltip ?? (isUpvote ? '赞成' : '反对'),
      child: Material(
        color: isActive ? activeColor : bgColor,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: label != null
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                : const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor),
                if (label != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 标签操作按钮
  Widget _buildTagActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
