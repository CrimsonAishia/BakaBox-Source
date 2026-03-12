import 'package:flutter/material.dart';
import '../../../core/core.dart';
import 'video_card.dart';
import 'live_room_card.dart';

/// 内容网格组件
class BilibiliContentGrids extends StatelessWidget {
  final ScrollController scrollController;
  final BilibiliContentState state;
  final Function(dynamic, BilibiliContentType) onEdit;
  final Function(String, BilibiliContentType) onDelete;

  const BilibiliContentGrids({
    super.key,
    required this.scrollController,
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: null, // Will be set by parent
      children: [_buildLiveRoomGrid(context), _buildVideoGrid(context)],
    );
  }

  Widget _buildLiveRoomGrid(BuildContext context) {
    final myId = state.myLiveRoomId;
    final itemCount = state.liveRooms.length;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: (itemCount / 3).ceil(),
      itemBuilder: (context, rowIndex) {
        final startIndex = rowIndex * 3;
        final endIndex = (startIndex + 3).clamp(0, itemCount);
        final itemsInRow = endIndex - startIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              for (int i = startIndex; i < endIndex; i++) ...[
                Expanded(
                  flex: itemsInRow,
                  child: SizedBox(
                    height: 255,
                    child: LiveRoomCard(
                      room: state.liveRooms[i],
                      isOwner: state.liveRooms[i].id == myId,
                      onEdit: null,
                      onDelete: null,
                    ),
                  ),
                ),
                if (i < endIndex - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid(BuildContext context) {
    final myId = state.myVideoId;
    final itemCount = state.videos.length;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: (itemCount / 3).ceil(),
      itemBuilder: (context, rowIndex) {
        final startIndex = rowIndex * 3;
        final endIndex = (startIndex + 3).clamp(0, itemCount);
        final itemsInRow = endIndex - startIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              for (int i = startIndex; i < endIndex; i++) ...[
                Expanded(
                  flex: itemsInRow,
                  child: SizedBox(
                    height: 255,
                    child: VideoCard(
                      video: state.videos[i],
                      isOwner: state.videos[i].id == myId,
                      onEdit: null,
                      onDelete: null,
                    ),
                  ),
                ),
                if (i < endIndex - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}
