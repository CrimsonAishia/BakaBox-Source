import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/core.dart';
import 'live_room_card_mobile.dart';
import 'video_card_mobile.dart';

/// 移动端直播间网格
class LiveRoomGridMobile extends StatelessWidget {
  final List<LiveRoom> rooms;
  final int total;
  final ScrollController scrollController;

  const LiveRoomGridMobile({
    super.key,
    required this.rooms,
    required this.total,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          _EmptyState(icon: Icons.live_tv, text: '暂无直播间'),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 8.0;
        const cardGap = 8.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final columns = math.max(2, (availableWidth / 220).floor());
        final cardWidth = (availableWidth - cardGap * (columns - 1)) / columns;
        // 卡片高度：封面(16:10) + 信息区域(~95)
        final cardHeight = cardWidth * 10 / 16 + 95;

        return GridView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 6,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: cardGap,
            mainAxisSpacing: cardGap,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            return LiveRoomCardMobile(
              room: rooms[index],
              onTap: () {
                context.read<BilibiliContentBloc>().add(
                  BilibiliContentIncreaseLiveRoomViewRequested(
                    id: rooms[index].id,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 移动端视频网格
class VideoGridMobile extends StatelessWidget {
  final List<BilibiliVideo> videos;
  final int total;
  final ScrollController scrollController;

  const VideoGridMobile({
    super.key,
    required this.videos,
    required this.total,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          _EmptyState(icon: Icons.video_library, text: '暂无视频'),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 8.0;
        const cardGap = 8.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final columns = math.max(2, (availableWidth / 220).floor());
        final cardWidth = (availableWidth - cardGap * (columns - 1)) / columns;
        // 卡片高度：封面(16:10) + 信息区域(~95)
        final cardHeight = cardWidth * 10 / 16 + 95;

        return GridView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 6,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: cardGap,
            mainAxisSpacing: cardGap,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            return VideoCardMobile(
              video: videos[index],
              onTap: () {
                context.read<BilibiliContentBloc>().add(
                  BilibiliContentIncreaseVideoViewRequested(
                    id: videos[index].id,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
