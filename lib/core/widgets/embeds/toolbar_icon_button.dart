import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// 工具栏图标按钮通用外壳
///
/// 直接复用 Material [IconButton]，并套用与 flutter_quill 内置工具栏按钮
/// （[QuillToolbarIconButton] → [QuillIconTheme]）**完全一致**的 [ButtonStyle]：
/// - 32×32 命中区、圆角 6
/// - hover 时通过 `overlayColor` 叠加浅色高亮（而非自绘背景），与官方按钮的
///   涟漪/高亮反馈机制相同，避免出现「颜色/尺寸/动画不一致」的问题
/// - 图标颜色固定为工具栏二级文本色，不随 hover 变色（与官方一致）
/// - 禁用时使用更浅的禁用色
///
/// 供攻略编辑器的自定义按钮（插入图片 / 插入引用 / B站视频 / 分割线 / 文字色 / 背景色）使用。
class ToolbarIconButton extends StatelessWidget {
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

  /// 图标尺寸（默认 16，与工具栏其它按钮一致）
  final double iconSize;

  /// 按钮命中区尺寸（默认 32，与工具栏其它按钮一致）
  final double buttonSize;

  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
    this.loading = false,
    this.disabled = false,
    this.iconSize = 16,
    this.buttonSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = disabled || onTap == null || loading;

    final defaultColor = isDark ? AppColors.slate400 : AppColors.slate500;
    final disabledColor = isDark ? AppColors.slate600 : AppColors.slate300;
    final iconColor = isDisabled ? disabledColor : (color ?? defaultColor);

    // 与 RichTextEditor._buildIconTheme 中官方按钮的 hover overlay 完全一致
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEFF6FF);

    return IconButton(
      tooltip: tooltip,
      onPressed: isDisabled ? null : onTap,
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: buttonSize,
        maxWidth: buttonSize,
        minHeight: buttonSize,
        maxHeight: buttonSize,
      ),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return hoverBg;
          }
          return null;
        }),
      ),
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Icon(icon, color: iconColor),
    );
  }
}
