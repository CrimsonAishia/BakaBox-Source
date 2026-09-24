import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/constants/app_colors.dart';
import '../router/mobile_router.dart';

class DiscoverMobile extends StatefulWidget {
  const DiscoverMobile({super.key});

  @override
  State<DiscoverMobile> createState() => _DiscoverMobileState();
}

class _DiscoverMobileState extends State<DiscoverMobile>
    with TickerProviderStateMixin {
  late AnimationController _iconAnimationController;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iconAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate900 : AppColors.slate100,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          _buildFixedAppBar(context, theme, colorScheme),
          SliverToBoxAdapter(child: _buildContent(context, isDark)),
        ],
      ),
    );
  }

  Widget _buildFixedAppBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: theme.appBarTheme.backgroundColor,
      surfaceTintColor: theme.appBarTheme.backgroundColor,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      collapsedHeight: 80,
      forceElevated: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.appBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.amber500, Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amber500.withValues(alpha: 0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    )
                    .animate(controller: _iconAnimationController)
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 200.ms),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '发现',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.appBarTheme.foregroundColor,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 2),
                      Text(
                        '探索应用内的各项功能与服务',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              theme.appBarTheme.foregroundColor?.withValues(
                                alpha: 0.7,
                              ) ??
                              colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final features = [
      {
        'title': '直播 / 视频',
        'subtitle': '观看 B站 内容',
        'icon': Icons.live_tv,
        'color': const Color(0xFF00A1D6),
        'route': MobileRoutes.bilibiliContent,
      },
      {
        'title': '人物图鉴',
        'subtitle': '浏览游戏角色',
        'icon': MdiIcons.cardsOutline,
        'color': const Color(0xFFEC4899),
        'route': MobileRoutes.characterGallery,
      },
      {
        'title': '地图数据库',
        'subtitle': '查阅地图与历史',
        'icon': Icons.map_outlined,
        'color': AppColors.primary,
        'route': MobileRoutes.mapDatabase,
      },
      {
        'title': '攻略',
        'subtitle': '浏览玩家攻略',
        'icon': Icons.menu_book,
        'color': const Color(0xFF4CAF50),
        'route': MobileRoutes.communityGuide,
      },
      {
        'title': '问题反馈',
        'subtitle': '提交意见与建议',
        'icon': MdiIcons.messageTextOutline,
        'color': AppColors.violet500,
        'route': MobileRoutes.issues,
      },
      {
        'title': '更新日志',
        'subtitle': '追踪服务器动态',
        'icon': MdiIcons.fileDocumentOutline,
        'color': AppColors.red500,
        'route': MobileRoutes.updateLogs,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          final color = feature['color'] as Color;

          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 600),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: ScaleAnimation(
                  scale: 0.9,
                  child: _buildFeatureCard(
                    context: context,
                    title: feature['title'] as String,
                    subtitle: feature['subtitle'] as String,
                    icon: feature['icon'] as IconData,
                    color: color,
                    onTap: () => context.push(feature['route'] as String),
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : theme.shadowColor.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // 右侧装饰性大图标水印
                Positioned(
                  right: -10,
                  bottom: -20,
                  child: Icon(
                    icon,
                    size: 85,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : color.withValues(alpha: 0.08),
                  ),
                ),
                // 核心内容区
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧文字区域
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 右侧明显的圆形导向箭头
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: isDark ? color.withValues(alpha: 0.9) : color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
