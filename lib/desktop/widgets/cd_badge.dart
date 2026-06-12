import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/map_cd/map_cd_bloc.dart';
import '../../core/bloc/map_cd/map_cd_event.dart';
import '../../core/bloc/map_cd/map_cd_state.dart';
import '../../core/constants/app_colors.dart';

/// 地图CD徽章
///
/// [triggerOnHover] = true  → 鼠标悬停时自动加载（地图数据库卡片）
/// [triggerOnHover] = false → 点击时手动加载（订阅列表）
class MapCdBadge extends StatelessWidget {
  final String mapName;
  final bool triggerOnHover;

  const MapCdBadge({
    super.key,
    required this.mapName,
    this.triggerOnHover = true,
  });

  void _load(BuildContext context) {
    final bloc = context.read<MapCdBloc>();
    if (bloc.state.shouldLoad(mapName)) {
      bloc.add(LoadMapCd(mapName));
    }
  }

  /// 强制刷新：清除缓存后重新加载
  void _refresh(BuildContext context) {
    final bloc = context.read<MapCdBloc>();
    bloc.add(ClearMapCdCache(mapName));
    bloc.add(LoadMapCd(mapName));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCdBloc, MapCdState>(
      builder: (context, state) {
        final isLoading = state.isLoading(mapName);
        final cdInfo = state.getCd(mapName);
        final error = state.getError(mapName);
        final hasCache = state.isCacheValid(mapName);

        // 未加载且无缓存
        if (!isLoading && cdInfo == null && error == null && !hasCache) {
          if (triggerOnHover) {
            // hover模式：直接显示占位，由外部MouseRegion触发加载
            return _CdBadgeShell(
              borderColor: Colors.white.withValues(alpha: 0.25),
              glowColor: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 5),
                  _CdBadgeText(
                    label: 'CD: ?',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            );
          } else {
            // 点击模式：显示明确的"点击获取CD"按钮
            return GestureDetector(
              onTap: () => _load(context),
              child: _CdBadgeShell(
                borderColor: AppColors.indigo500.withValues(alpha: 0.5),
                glowColor: AppColors.indigo500.withValues(alpha: 0.15),
                clickable: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 15,
                      color: const Color(0xFF818CF8),
                    ),
                    const SizedBox(width: 5),
                    _CdBadgeText(
                      label: '点击获取CD',
                      color: const Color(0xFF818CF8),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        // 加载中
        if (isLoading) {
          return _CdBadgeShell(
            borderColor: Colors.blue.withValues(alpha: 0.6),
            glowColor: Colors.blue.withValues(alpha: 0.25),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade300,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _CdBadgeText(label: '获取中', color: Colors.blue.shade300),
              ],
            ),
          );
        }

        // 加载失败 - 点击可重试
        if (error != null) {
          return GestureDetector(
            onTap: () => _load(context),
            child: _CdBadgeShell(
              borderColor: Colors.orange.withValues(alpha: 0.6),
              glowColor: Colors.orange.withValues(alpha: 0.2),
              clickable: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: Colors.orange.shade300,
                  ),
                  const SizedBox(width: 5),
                  _CdBadgeText(label: '失败', color: Colors.orange.shade300),
                ],
              ),
            ),
          );
        }

        // 地图不存在
        if (cdInfo == null) {
          return _CdBadgeShell(
            borderColor: Colors.white.withValues(alpha: 0.2),
            glowColor: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.remove_circle_outline,
                  size: 15,
                  color: Colors.white38,
                ),
                const SizedBox(width: 5),
                _CdBadgeText(
                  label: '无数据',
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          );
        }

        // 显示CD信息
        final cd = cdInfo.currentNominateCd;
        final isAvailable = cd == 0;
        final accentColor = isAvailable
            ? AppColors.emerald500
            : AppColors.red500;

        return GestureDetector(
          onTap: () => _refresh(context),
          child: _CdBadgeShell(
            borderColor: accentColor.withValues(alpha: 0.8),
            glowColor: accentColor.withValues(alpha: 0.3),
            clickable: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAvailable ? Icons.check_circle_rounded : Icons.schedule,
                  size: 15,
                  color: accentColor,
                ),
                const SizedBox(width: 5),
                _CdBadgeText(
                  label: isAvailable ? '可预订' : 'CD：$cd',
                  color: accentColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// CD徽章外壳 - 统一样式，底部显示数据来源，支持 hover 效果
class _CdBadgeShell extends StatefulWidget {
  final Widget child;
  final Color borderColor;
  final Color glowColor;
  final bool clickable;

  const _CdBadgeShell({
    required this.child,
    required this.borderColor,
    required this.glowColor,
    this.clickable = false,
  });

  @override
  State<_CdBadgeShell> createState() => _CdBadgeShellState();
}

class _CdBadgeShellState extends State<_CdBadgeShell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _isHovered && widget.clickable;

    return Tooltip(
      message: '冷却数据来源: s.zombieden.cn',
      preferBelow: true,
      child: MouseRegion(
        cursor: widget.clickable
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: hovered
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovered
                  ? widget.borderColor.withValues(alpha: 1.0)
                  : widget.borderColor,
              width: hovered ? 2.0 : 1.5,
            ),
            boxShadow: [
              if (widget.glowColor != Colors.transparent)
                BoxShadow(
                  color: hovered
                      ? widget.glowColor.withValues(
                          alpha: widget.glowColor.a * 1.6 > 1.0
                              ? 1.0
                              : widget.glowColor.a * 1.6,
                        )
                      : widget.glowColor,
                  blurRadius: hovered ? 14 : 10,
                  spreadRadius: hovered ? 2 : 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              widget.child,
              const SizedBox(height: 3),
              Text(
                's.zombieden.cn',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CD徽章文字
class _CdBadgeText extends StatelessWidget {
  final String label;
  final Color color;

  const _CdBadgeText({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.5,
        height: 1,
      ),
    );
  }
}
