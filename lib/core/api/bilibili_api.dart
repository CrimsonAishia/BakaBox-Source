// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/bilibili_content_models.dart';

/// 直播间列表结果
class LiveRoomListResult {
  final List<LiveRoom> list;
  final int total;

  LiveRoomListResult({required this.list, required this.total});
}

/// 视频列表结果
class VideoListResult {
  final List<BilibiliVideo> list;
  final int total;

  VideoListResult({required this.list, required this.total});
}

/// B站内容后端 API
class BilibiliApi {
  Future<LiveRoomListResult> getLiveRooms({
    int pageIndex = 1,
    int pageSize = 20,
    String? keyword,
    String? keywordType,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<VideoListResult> getVideos({
    int pageIndex = 1,
    int pageSize = 20,
    String sort = 'view_count',
    int? categoryId,
    String? keyword,
    String? keywordType,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<LiveRoom?> getMyLiveRoom() async {
    throw UnimplementedError('Stub');
  }

  Future<List<BilibiliVideo>> getMyVideos() async {
    throw UnimplementedError('Stub');
  }

  Future<LiveRoom> addLiveRoom({
    required String roomId,
    String? title,
    String? coverUrl,
    String? ownerUid,
    String? ownerName,
    int? liveStatus,
    int? popularity,
    int? followerCount,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<BilibiliVideo> addVideo({
    required String bvid,
    String? title,
    String? coverUrl,
    String? ownerUid,
    String? ownerName,
    String? ownerFace,
    String? publishedAt,
    int? duration,
    int? categoryId,
    int? playCount,
    int? likeCount,
    int? coinCount,
    int? favoriteCount,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<LiveRoom> updateLiveRoom({
    required String id,
    String? roomId,
    String? title,
    String? coverUrl,
    String? ownerUid,
    String? ownerName,
    int? liveStatus,
    int? popularity,
    int? followerCount,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<LiveRoom> toggleLiveRoom({
    required String id,
    required bool enabled,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<BilibiliVideo> updateVideo({
    required String id,
    String? bvid,
    String? title,
    String? coverUrl,
    String? ownerUid,
    String? ownerName,
    String? ownerFace,
    String? publishedAt,
    int? duration,
    int? categoryId,
    int? playCount,
    int? likeCount,
    int? coinCount,
    int? favoriteCount,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<void> deleteLiveRoom(String id) async {
    throw UnimplementedError('Stub');
  }

  Future<void> deleteVideo(String id) async {
    throw UnimplementedError('Stub');
  }

  Future<void> increaseLiveRoomViewCount(String id) async {
    throw UnimplementedError('Stub');
  }

  Future<void> increaseVideoViewCount(String id) async {
    throw UnimplementedError('Stub');
  }

  Future<List<VideoCategory>> getVideoCategories() async {
    throw UnimplementedError('Stub');
  }
}
