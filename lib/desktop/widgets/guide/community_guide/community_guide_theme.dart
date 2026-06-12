import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// 攻略社区桌面端主题颜色辅助类
///
/// 集中管理所有与亮/暗主题相关的颜色和不透明度，避免在组件代码中散落三元判断。
///
/// 用法：
/// ```dart
/// final colors = CommunityGuideColors.of(context);
/// Container(color: colors.scaffoldBg);
/// ```
class CommunityGuideColors {
  final bool isDark;

  /// 品牌强调色（亮/暗模式相同）
  final Color accentBlue;

  /// 红色（点赞 / 必填）
  final Color likeRed;

  /// 模块底色（Scaffold 背景）
  final Color scaffoldBg;

  /// 卡片底色
  final Color cardBg;

  /// 工具栏毛玻璃底色
  final Color toolbarBg;

  /// 工具栏描边
  final Color toolbarBorder;

  /// 详情弹窗外层底色（90% 内嵌弹窗）
  final Color detailOverlayBg;

  /// 内容主文本色（标题等）
  final Color textPrimary;

  /// 次级文本色（作者名、说明等）
  final Color textSecondary;

  /// 三级文本色（占位、计数等）
  final Color textTertiary;

  /// 图标主色
  final Color iconPrimary;

  /// 输入框 hint 色
  final Color hintText;

  /// 输入框填充
  final Color inputFill;

  /// 输入框描边
  final Color inputBorder;

  /// 分类按钮（未选中）背景
  final Color chipInactiveBg;

  /// 分类按钮（未选中）文字
  final Color chipInactiveText;

  /// 标签 chip（次要）背景
  final Color tagSecondaryBg;

  /// 通用半透明蒙层（详情遮罩）
  final Color scrim;

  /// 卡片阴影色
  final Color shadow;

  /// 骨架屏底色
  final Color skeletonBg;

  /// 骨架条底色
  final Color skeletonBar;

  /// 个人资料卡背景（mine 专用）
  final Color profileCardBg;

  /// 个人资料卡分隔线
  final Color profileCardDivider;

  /// 三点菜单底色
  final Color menuBg;

  /// 标签 chip（次要）文字色（应用于次级 chip 在亮色下的可读色）
  final Color tagSecondaryText;

  /// 标签 chip（主要 / 高亮）文字色 —— 在暗色为浅蓝，亮色为强调蓝
  final Color tagPrimaryText;

  /// hover 状态高亮色（输入框/按钮悬浮背景）
  final Color hoverHighlight;

  factory CommunityGuideColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const CommunityGuideColors.dark()
        : const CommunityGuideColors.light();
  }

  // ── 暗色 ────────────────────────────────────────────────────────────────────
  const CommunityGuideColors.dark()
      : isDark = true,
        accentBlue = const Color(0xFF2196F3),
        likeRed = const Color(0xFFFF4D6D),
        scaffoldBg = const Color(0xFF0B1426),
        cardBg = const Color(0xFF1A2842),
        toolbarBg = const Color(0x801E293B), // 0xFF1E293B @ 50%
        toolbarBorder = const Color(0x14FFFFFF),
        detailOverlayBg = const Color(0xFF0B1426),
        textPrimary = Colors.white,
        textSecondary = const Color(0xC7FFFFFF), // white 78%
        textTertiary = const Color(0x8CFFFFFF), // white 55%
        iconPrimary = Colors.white,
        hintText = const Color(0xA6FFFFFF),
        inputFill = const Color(0x14FFFFFF),
        inputBorder = const Color(0x2EFFFFFF),
        chipInactiveBg = const Color(0xFF253246),
        chipInactiveText = const Color(0xC7FFFFFF),
        tagSecondaryBg = const Color(0xD937474F),
        scrim = const Color(0x80000000),
        shadow = const Color(0x47000000),
        skeletonBg = const Color(0x0AFFFFFF),
        skeletonBar = const Color(0x0FFFFFFF),
        profileCardBg = const Color(0xFF1A2842),
        profileCardDivider = const Color(0x14FFFFFF),
        menuBg = const Color(0xFF253246),
        tagSecondaryText = const Color(0xC7FFFFFF),
        tagPrimaryText = const Color(0xFF90CAF9),
        hoverHighlight = AppColors.slate700;

  // ── 亮色 ────────────────────────────────────────────────────────────────────
  const CommunityGuideColors.light()
      : isDark = false,
        accentBlue = const Color(0xFF2196F3),
        likeRed = const Color(0xFFFF4D6D),
        scaffoldBg = AppColors.slate100,
        cardBg = Colors.white,
        toolbarBg = const Color(0xCCFFFFFF), // white 80%
        toolbarBorder = const Color(0x14000000),
        detailOverlayBg = const Color(0xFFF5F7FB),
        textPrimary = AppColors.gray800,
        textSecondary = const Color(0xFF4B5563),
        textTertiary = AppColors.gray500,
        iconPrimary = AppColors.gray700,
        hintText = AppColors.gray400,
        inputFill = AppColors.slate50,
        inputBorder = AppColors.slate200,
        chipInactiveBg = AppColors.slate200,
        chipInactiveText = AppColors.gray700,
        tagSecondaryBg = AppColors.gray200,
        scrim = const Color(0x66000000),
        shadow = const Color(0x1A000000),
        skeletonBg = const Color(0x0F000000),
        skeletonBar = const Color(0x14000000),
        profileCardBg = Colors.white,
        profileCardDivider = AppColors.slate200,
        menuBg = Colors.white,
        tagSecondaryText = AppColors.gray700,
        tagPrimaryText = const Color(0xFF1976D2),
        hoverHighlight = AppColors.slate300;
}
