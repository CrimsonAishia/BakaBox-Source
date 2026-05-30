import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/models/key_config_models.dart';

/// 配置卡片
class ConfigCard extends StatefulWidget {
  final KeyConfig config;
  final bool selected;
  final bool applied;
  final bool showAuditStatus;
  final VoidCallback onTap;

  const ConfigCard({
    super.key,
    required this.config,
    required this.selected,
    required this.applied,
    this.showAuditStatus = false,
    required this.onTap,
  });

  @override
  State<ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<ConfigCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.config.isOwner;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 只有在 showAuditStatus 为 true 且配置未通过审核时才显示审核状态栏
    // 显示条件：审核中(pending)或已拒绝(rejected)，或已通过但有待审核变更申请
    final showAuditStatusBar =
        widget.showAuditStatus &&
        (widget.config.isPending ||
            widget.config.isRejected ||
            widget.config.hasPendingChange);

    final Color borderColor;
    if (showAuditStatusBar) {
      borderColor = widget.config.isPending
          ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
          : widget.config.hasPendingChange
          ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
          : const Color(0xFFEF4444).withValues(alpha: 0.4);
    } else if (widget.selected) {
      borderColor = const Color(0xFF0080FF);
    } else if (_hovered) {
      borderColor = isDark ? const Color(0xFF475569) : Colors.grey[300]!;
    } else {
      borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF0080FF).withValues(alpha: 0.06)
                : (_hovered
                      ? (isDark ? const Color(0xFF334155) : Colors.grey[50])
                      : (isDark ? const Color(0xFF1E293B) : Colors.white)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showAuditStatusBar)
                _buildAuditStatusBar(widget.config, isDark),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: widget.config.needsKeybind
                                ? const Color(0xFFf59e0b).withValues(alpha: 0.1)
                                : const Color(
                                    0xFF10b981,
                                  ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.config.needsKeybind
                                ? MdiIcons.keyboardOutline
                                : MdiIcons.autoFix,
                            size: 18,
                            color: widget.config.needsKeybind
                                ? const Color(0xFFf59e0b)
                                : const Color(0xFF10b981),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.config.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1a1a2e),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF8b5cf6,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '我的',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF8b5cf6),
                                        ),
                                      ),
                                    ),
                                  if (widget.applied)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF10b981,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '已应用',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF10b981),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.config.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.config.userAvatar != null &&
                            widget.config.userAvatar!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              widget.config.userAvatar!,
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildDefaultAvatar(),
                            ),
                          )
                        else
                          _buildDefaultAvatar(),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.config.userNickname ?? '未知用户',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildVoteCount(
                          widget.config.upCount,
                          widget.config.downCount,
                        ),
                        // 显示应用次数和评论数
                        if (widget.config.isApproved &&
                            (widget.config.useCount > 0 ||
                                widget.config.commentCount > 0)) ...[
                          const SizedBox(width: 8),
                          _buildStatsCount(
                            widget.config.useCount,
                            widget.config.commentCount,
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0080FF,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.config.category,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF0080FF),
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
        ),
      ),
    );
  }

  Widget _buildVoteCount(int upCount, int downCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(MdiIcons.thumbUpOutline, size: 12, color: const Color(0xFF10b981)),
        const SizedBox(width: 2),
        Text(
          '$upCount',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF10b981),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          MdiIcons.thumbDownOutline,
          size: 12,
          color: const Color(0xFFef4444),
        ),
        const SizedBox(width: 2),
        Text(
          '$downCount',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFFef4444),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCount(int useCount, int commentCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (useCount > 0) ...[
          Icon(MdiIcons.downloadOutline, size: 12, color: color),
          const SizedBox(width: 2),
          Text('$useCount', style: TextStyle(fontSize: 10, color: color)),
        ],
        if (useCount > 0 && commentCount > 0) const SizedBox(width: 6),
        if (commentCount > 0) ...[
          Icon(MdiIcons.commentOutline, size: 12, color: color),
          const SizedBox(width: 2),
          Text('$commentCount', style: TextStyle(fontSize: 10, color: color)),
        ],
      ],
    );
  }

  Widget _buildAuditStatusBar(KeyConfig config, bool isDark) {
    // hasPendingChange 优先级最高（已通过但有变更申请）
    if (config.hasPendingChange) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          color: Color(0x1AF59E0B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.clockOutline,
              size: 12,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 6),
            const Text(
              '变更审核中',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      );
    }

    final isPending = config.isPending;
    final statusColor = isPending
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    final statusIcon = isPending
        ? MdiIcons.clockOutline
        : MdiIcons.alertCircleOutline;
    final statusText = isPending ? '审核中' : '已拒绝';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          if (config.isRejected && config.auditRemark.isNotEmpty) ...[
            const SizedBox(width: 4),
            Expanded(
              child: Tooltip(
                message: config.auditRemark,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(
                  '- ${config.auditRemark}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
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

  Widget _buildDefaultAvatar() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.person, size: 12, color: Colors.grey[400]),
    );
  }
}
