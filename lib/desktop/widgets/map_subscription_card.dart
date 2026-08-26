import 'package:flutter/material.dart';

import '../../core/widgets/map_background.dart';
import '../../core/constants/app_colors.dart';

/// 地图订阅卡片组件
///
/// 统一用于订阅列表和搜索结果的地图卡片样式
class MapSubscriptionCard extends StatefulWidget {
  /// 地图显示名称
  final String displayName;

  /// 地图技术名称（如 de_dust2）
  final String mapName;

  /// 地图背景图片 URL
  final String? mapBackground;

  /// 分类范围描述（如 "全部分类" 或 "2个分类"）
  final String? scopeText;

  /// 是否已订阅
  final bool isSubscribed;

  /// 是否显示为搜索结果样式（稍小一点）
  final bool isCompact;

  /// 点击卡片回调
  final VoidCallback? onTap;

  /// 点击编辑按钮回调（编辑地图信息）
  final VoidCallback? onEdit;

  /// 点击分类按钮回调
  final VoidCallback? onScopeTap;

  /// 点击删除按钮回调
  final VoidCallback? onDelete;

  /// 编辑按钮是否在删除按钮左边（默认 false，在删除按钮右边）
  final bool editBeforeDelete;

  /// 右侧自定义操作区域（完全替代默认操作区域）
  final Widget? trailing;

  /// 底部自定义操作区域（如放在地图名下方的新行）
  final Widget? bottomActions;

  const MapSubscriptionCard({
    super.key,
    required this.displayName,
    required this.mapName,
    this.mapBackground,
    this.scopeText,
    this.isSubscribed = false,
    this.isCompact = false,
    this.onTap,
    this.onEdit,
    this.onScopeTap,
    this.onDelete,
    this.editBeforeDelete = false,
    this.trailing,
    this.bottomActions,
  });

  @override
  State<MapSubscriptionCard> createState() => _MapSubscriptionCardState();
}

class _MapSubscriptionCardState extends State<MapSubscriptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackground = widget.mapBackground != null;
    final cardHeight = widget.isCompact
        ? 64.0
        : (widget.bottomActions != null ? 100.0 : 72.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 3 : 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: hasBackground
                ? null
                : Border.all(
                    color: _isHovered
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.gray300)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.gray200),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.15 : 0.08),
                blurRadius: _isHovered ? 8 : 4,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: cardHeight,
              child: Stack(
                children: [
                  // 全宽地图背景
                  if (hasBackground)
                    Positioned.fill(
                      child: MapBackground(
                        mapName: widget.mapName,
                        imageUrl: widget.mapBackground,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                      ),
                    ),
                  // 无背景时的底色
                  if (!hasBackground)
                    Positioned.fill(
                      child: Container(
                        color: isDark
                            ? const Color(0xFF1A1A2E)
                            : const Color(0xFFF8F9FA),
                      ),
                    ),
                  // 渐变遮罩 - 增强文字可读性
                  if (hasBackground)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  // 内容
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // 地图名
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.map_outlined,
                                              size: widget.isCompact ? 16 : 18,
                                              color: hasBackground
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white70
                                                        : AppColors.gray500),
                                              shadows: hasBackground
                                                  ? [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              widget.displayName,
                                              style: TextStyle(
                                                fontSize: widget.isCompact
                                                    ? 14
                                                    : 15,
                                                fontWeight: FontWeight.w600,
                                                color: hasBackground
                                                    ? Colors.white
                                                    : (isDark
                                                          ? Colors.white
                                                          : AppColors.gray800),
                                                shadows: hasBackground
                                                    ? [
                                                        Shadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          blurRadius: 4,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // 副标题：显示 mapName（仅当与 displayName 不同时）
                                      if (widget.displayName !=
                                          widget.mapName) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 20,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.translate,
                                                size: widget.isCompact
                                                    ? 12
                                                    : 14,
                                                color: hasBackground
                                                    ? Colors.white70
                                                    : (isDark
                                                          ? Colors.white54
                                                          : AppColors.gray400),
                                                shadows: hasBackground
                                                    ? [
                                                        Shadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          blurRadius: 4,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                widget.mapName,
                                                style: TextStyle(
                                                  fontSize: widget.isCompact
                                                      ? 11
                                                      : 12,
                                                  color: hasBackground
                                                      ? Colors.white70
                                                      : (isDark
                                                            ? Colors.white54
                                                            : AppColors
                                                                  .gray500),
                                                  shadows: hasBackground
                                                      ? [
                                                          Shadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                            blurRadius: 4,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // 右侧操作区
                                if (widget.trailing != null) widget.trailing!,
                                // 分类范围按钮
                                if (widget.scopeText != null &&
                                    widget.onScopeTap != null)
                                  _buildScopeButton(isDark, hasBackground),
                                // 已订阅标签（仅当没有自定义 trailing 且没有删除/分类按钮时显示）
                                if (widget.isSubscribed &&
                                    widget.trailing == null &&
                                    widget.onDelete == null &&
                                    widget.onScopeTap == null)
                                  _buildSubscribedBadge(isDark, hasBackground),
                                if (widget.onEdit != null &&
                                    widget.editBeforeDelete &&
                                    widget.isSubscribed) ...[
                                  const SizedBox(width: 6),
                                  _MiniActionButton(
                                    icon: Icons.edit_rounded,
                                    tooltip: '编辑地图信息',
                                    baseColor: Colors.white,
                                    onTap: widget.onEdit!,
                                  ),
                                ],
                                // 删除按钮
                                if (widget.onDelete != null) ...[
                                  const SizedBox(width: 6),
                                  _MiniActionButton(
                                    icon: Icons.delete_outline_rounded,
                                    tooltip: '删除订阅',
                                    baseColor: Colors.red.shade400,
                                    onTap: widget.onDelete!,
                                  ),
                                ],
                                // 编辑按钮（editBeforeDelete=false 时在删除按钮后显示，仅已订阅且有背景图时）
                                if (widget.onEdit != null &&
                                    !widget.editBeforeDelete &&
                                    hasBackground &&
                                    widget.isSubscribed) ...[
                                  const SizedBox(width: 6),
                                  _MiniActionButton(
                                    icon: Icons.edit_rounded,
                                    tooltip: '编辑地图信息',
                                    baseColor: Colors.white,
                                    onTap: widget.onEdit!,
                                  ),
                                ],
                              ],
                            ),
                            if (widget.bottomActions != null) ...[
                              const Spacer(),
                              widget.bottomActions!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeButton(bool isDark, bool hasBackground) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onScopeTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hasBackground
                  ? Colors.black.withValues(alpha: 0.4)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.gray200),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasBackground
                    ? Colors.white.withValues(alpha: 0.3)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.gray300),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 13,
                  color: hasBackground
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.scopeText!,
                  style: TextStyle(
                    fontSize: 11,
                    color: hasBackground
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribedBadge(bool isDark, bool hasBackground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasBackground
            ? AppColors.emerald500.withValues(alpha: 0.3)
            : AppColors.emerald500.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasBackground
              ? AppColors.emerald500.withValues(alpha: 0.5)
              : AppColors.emerald500.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: hasBackground ? Colors.white : AppColors.emerald500,
          ),
          const SizedBox(width: 4),
          Text(
            '已订阅',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasBackground ? Colors.white : AppColors.emerald500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 右上角小图标按钮（带 Hover 和发光效果）
class _MiniActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color baseColor;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.tooltip,
    required this.baseColor,
    required this.onTap,
  });

  @override
  State<_MiniActionButton> createState() => _MiniActionButtonState();
}

class _MiniActionButtonState extends State<_MiniActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _isHovered;
    final color = hovered
        ? widget.baseColor
        : Colors.white.withValues(alpha: 0.6);
    final borderColor = hovered
        ? widget.baseColor.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.2);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hovered
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: hovered ? 2.0 : 1.5,
              ),
              boxShadow: [
                if (hovered)
                  BoxShadow(
                    color: widget.baseColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
