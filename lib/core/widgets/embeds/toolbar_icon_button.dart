import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// 工具栏图标按钮通用外壳
///
/// 与 quill 内置工具栏按钮在视觉尺寸/圆角/hover 反馈上保持一致：
/// - 28×28 命中区
/// - hover 时填充浅色背景 + 描边色加深
/// - 禁用时降低不透明度
///
/// 给攻略编辑器中三个自定义按钮（插入图片 / 插入引用 / 插入 B 站视频）使用，
/// 解决「相对 quill 自带按钮没有 hover 反馈」的问题。
class ToolbarIconButton extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 提示
  final String tooltip;

  /// 点击回调，为 null 时按钮置灰
  final VoidCallback? onTap;

  /// 自定义图标颜色（默认使用工具栏二级文本色）
  final Color? color;

  /// 当处于「正在加载/上传中」状态时显示 spinner 替代图标
  final bool loading;

  /// 是否处于「禁用」外观（如已达图片上限）。比 onTap=null 多一层提示色。
  final bool disabled;

  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
    this.loading = false,
    this.disabled = false,
  });

  @override
  State<ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<ToolbarIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.disabled || widget.onTap == null;

    final defaultColor = isDark
        ? AppColors.slate400
        : AppColors.slate500;
    final disabledColor =
        isDark ? AppColors.slate600 : AppColors.slate300;

    final iconColor = disabled
        ? disabledColor
        : (_hover
            ? (isDark ? Colors.white : AppColors.primary)
            : (widget.color ?? defaultColor));

    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEFF6FF);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) {
          if (!disabled) setState(() => _hover = true);
        },
        onExit: (_) {
          if (_hover) setState(() => _hover = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: !disabled && _hover ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: disabled ? null : widget.onTap,
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(widget.icon, size: 16, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
