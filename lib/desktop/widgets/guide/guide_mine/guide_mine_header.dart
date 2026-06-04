import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/guide_mine/guide_mine_bloc.dart';
import '../../../../core/bloc/guide_mine/guide_mine_event.dart';
import '../../../../core/bloc/guide_mine/guide_mine_state.dart';
import '../community_guide/community_guide_format.dart';
import '../community_guide/community_guide_theme.dart';
import 'guide_mine_back_button.dart';
import 'guide_mine_ring_avatar.dart';
import 'guide_mine_tab_bar.dart';

/// 「我的中心」页头：标题行 / 返回按钮 / 个人资料卡 / 工具栏（Tab + 新建按钮）
class GuideMineHeader extends StatelessWidget {
  final GuideMineState state;
  final VoidCallback? onBack;
  final VoidCallback? onCreateGuide;
  final int selectedTabIndex;
  final ValueChanged<int> onSelectTab;
  final GlobalKey publishedPillKey;
  final VoidCallback onOpenPublishedFilter;
  final Map<MineTab, int> tabCounts;

  const GuideMineHeader({
    super.key,
    required this.state,
    required this.selectedTabIndex,
    required this.onSelectTab,
    required this.publishedPillKey,
    required this.onOpenPublishedFilter,
    required this.tabCounts,
    this.onBack,
    this.onCreateGuide,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：返回按钮 + 标题
          Row(
            children: [
              if (onBack != null) ...[
                GuideMineBackButton(onTap: onBack!),
                const SizedBox(width: 12),
              ],
              Text(
                '我的中心',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 个人资料卡片
          _ProfileCard(tabCounts: tabCounts),
          const SizedBox(height: 6),
          // 工具栏（Tab 胶囊 + 新建按钮）
          GuideMineToolbar(
            state: state,
            selectedTabIndex: selectedTabIndex,
            onSelectTab: onSelectTab,
            publishedPillKey: publishedPillKey,
            onOpenPublishedFilter: onOpenPublishedFilter,
            tabCounts: tabCounts,
            onCreateGuide: onCreateGuide,
          ),
        ],
      ),
    );
  }
}

/// 个人资料卡片（头像 + 用户名 + UID + 统计数据）
class _ProfileCard extends StatelessWidget {
  final Map<MineTab, int> tabCounts;

  const _ProfileCard({required this.tabCounts});

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    return BlocBuilder<AuthBloc, dynamic>(
      builder: (context, authState) {
        final userInfo = context.read<AuthBloc>().state.userInfo;
        final username = userInfo?.username ?? '未登录';
        final avatar = userInfo?.avatar;
        final userGroup = userInfo?.userGroup;
        final isPrivileged =
            userGroup == 'admin' || userGroup == 'moderator';

        return BlocBuilder<GuideMineBloc, GuideMineState>(
          buildWhen: (a, b) =>
              a.stats != b.stats || a.total != b.total || a.tab != b.tab,
          builder: (context, state) {
            // 攻略数：优先使用后端 stats；guideCount=0 时回退到 published tab 缓存
            final guideCount = state.stats.guideCount > 0
                ? state.stats.guideCount
                : (tabCounts[MineTab.published] ?? 0);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.profileCardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GuideMineRingAvatar(
                    avatarUrl: (avatar?.isNotEmpty ?? false) ? avatar : null,
                    fallback: username,
                    size: 88,
                    ringColor: colors.accentBlue,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (isPrivileged) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.verified,
                                color: colors.accentBlue,
                                size: 22,
                              ),
                            ],
                          ],
                        ),
                        if (userInfo?.uid != null &&
                            userInfo!.uid.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'UID · ${userInfo.uid}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 分隔线
                  Container(
                    width: 1,
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: colors.profileCardDivider,
                  ),
                  // 统计区（2x2 网格）
                  Expanded(
                    flex: 5,
                    child: _StatsGrid(
                      guideCount: guideCount,
                      totalViews: state.stats.totalViews,
                      totalLikes: state.stats.totalLikes,
                      totalFavorites: state.stats.totalFavorites,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int guideCount;
  final int totalViews;
  final int totalLikes;
  final int totalFavorites;

  const _StatsGrid({
    required this.guideCount,
    required this.totalViews,
    required this.totalLikes,
    required this.totalFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ProfileStat(
              icon: Icons.menu_book_outlined,
              label: '攻略数',
              value: formatGuideCount(guideCount),
            ),
            _ProfileStat(
              icon: Icons.remove_red_eye_outlined,
              label: '总浏览',
              value: formatGuideCount(totalViews),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ProfileStat(
              icon: Icons.favorite_border,
              label: '获赞数',
              value: formatGuideCount(totalLikes),
            ),
            _ProfileStat(
              icon: Icons.bookmark_border,
              label: '收藏数',
              value: formatGuideCount(totalFavorites),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: colors.textTertiary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
