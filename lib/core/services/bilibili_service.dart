import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/guide_models.dart';

/// B站 API 服务
///
/// 用于获取B站直播间和视频的相关数据
class BilibiliService {
  static const String _baseUrl = 'https://api.bilibili.com';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bilibili.com',
  };

  /// 直播间信息缓存
  /// Key: roomId, Value: { data: BilibiliRoomInfo, timestamp: int }
  static final Map<String, _CacheEntry<BilibiliRoomInfo>> _roomInfoCache = {};

  /// 视频信息缓存
  /// Key: bvid, Value: { data: BilibiliVideoInfo, timestamp: int }
  static final Map<String, _CacheEntry<BilibiliVideoInfo>> _videoInfoCache = {};

  /// 用户信息缓存
  /// Key: mid, Value: { data: BilibiliUserInfo, timestamp: int }
  static final Map<String, _CacheEntry<BilibiliUserInfo>> _userInfoCache = {};

  /// 直播状态缓存（UID -> 直播状态）
  /// Key: uid, Value: { data: BilibiliLiveStatus, timestamp: int }
  static final Map<String, _CacheEntry<BilibiliLiveStatus>> _liveStatusCache =
      {};

  /// 直播间缓存有效期（30秒）
  static const Duration _roomCacheDuration = Duration(seconds: 30);

  /// 视频缓存有效期（5分钟）
  static const Duration _videoCacheDuration = Duration(minutes: 5);

  /// 用户信息缓存有效期（30秒）
  static const Duration _userCacheDuration = Duration(seconds: 30);

  /// 直播状态缓存有效期（30秒）
  static const Duration _liveStatusCacheDuration = Duration(seconds: 30);

  /// 视频元数据缓存（用于攻略社区 fetchMeta）
  /// Key: bvid, Value: { data: VideoEmbed, timestamp: int }
  static final Map<String, _CacheEntry<VideoEmbed>> _videoMetaCache = {};

  /// 视频元数据缓存有效期（30分钟）
  static const Duration _videoMetaCacheDuration = Duration(minutes: 30);

  /// 从URL中提取直播间ID
  /// 支持格式:
  /// - https://live.bilibili.com/123456
  /// - https://live.bilibili.com/live/123456
  /// - 123456
  static String? extractRoomId(String input) {
    if (input.isEmpty) return null;

    // 如果是纯数字，直接返回
    if (RegExp(r'^\d+$').hasMatch(input)) {
      return input;
    }

    // 从URL中提取
    final regex = RegExp(r'live\.bilibili\.com[/\w]*?(\d+)');
    final match = regex.firstMatch(input);
    return match?.group(1);
  }

  /// 从URL中提取BV号
  /// 支持格式:
  /// - https://www.bilibili.com/video/BV1xx411c7mD
  /// - BV1xx411c7mD
  /// - 1xx411c7mD
  static String? extractBvid(String input) {
    if (input.isEmpty) return null;

    // 如果是BV号格式，直接返回
    if (input.startsWith('BV')) {
      return input;
    }

    // 如果是纯数字（短链接的avid），需要转换，这里简化处理
    if (RegExp(r'^\d+$').hasMatch(input)) {
      return null;
    }

    // 从URL中提取BV号
    final regex = RegExp(r'BV[\w]+');
    final match = regex.firstMatch(input);
    return match?.group(0);
  }

  /// 获取B站视频元数据（封面/标题/时长），带 30 分钟内存缓存 + 失败兜底返回 null
  ///
  /// 用于攻略社区视频嵌入场景。
  /// [url] B站视频链接或 BV 号
  /// 返回: [VideoEmbed]，失败时返回 null（不抛异常）
  static Future<VideoEmbed?> fetchMeta(String url) async {
    if (url.isEmpty) return null;

    final bvid = extractBvid(url);
    if (bvid == null) return null;

    // 检查缓存
    final cached = _videoMetaCache[bvid];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.bilibili.com/x/web-interface/view?bvid=$bvid',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final videoData = data['data'] as Map<String, dynamic>;
          final videoEmbed = VideoEmbed(
            bvid: bvid,
            url: 'https://www.bilibili.com/video/$bvid/',
            title: videoData['title'] as String?,
            coverUrl: videoData['pic'] as String?,
            durationSec: videoData['duration'] as int?,
          );

          // 写入缓存
          _videoMetaCache[bvid] = _CacheEntry(
            data: videoEmbed,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            cacheDuration: _videoMetaCacheDuration,
          );

          return videoEmbed;
        }
      }
    } catch (_) {
      // 失败兜底：返回 null，不抛异常
    }

    return null;
  }

  /// 获取直播间信息（带缓存，默认1小时）
  ///
  /// [bypassCache] 为 true 时强制从API获取最新数据
  /// 返回: 直播间详细信息，包含直播状态、人气值等
  Future<BilibiliRoomInfo?> getRoomInfo(
    String roomId, {
    bool bypassCache = false,
  }) async {
    // 先检查是否是短号，如果是短号则转换为真实room_id
    final realRoomId = await _resolveRealRoomId(roomId);
    if (realRoomId == null) {
      return null;
    }

    // 检查缓存（使用真实room_id）
    if (!bypassCache) {
      final cached = _roomInfoCache[realRoomId];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.live.bilibili.com/xlive/web-room/v1/index/getRoomBaseInfo?req_biz=web_room_com&room_ids=$realRoomId',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final byRoomIds =
              data['data']['by_room_ids'] as Map<String, dynamic>?;
          if (byRoomIds != null && byRoomIds.containsKey(realRoomId)) {
            final roomInfo = byRoomIds[realRoomId] as Map<String, dynamic>;

            final result = BilibiliRoomInfo(
              roomId: roomInfo['room_id']?.toString() ?? realRoomId,
              title: roomInfo['title'] ?? '',
              coverUrl: roomInfo['cover'] ?? '',
              description: roomInfo['description'],
              userName: roomInfo['uname'],
              userId: roomInfo['uid']?.toString(),
              liveStatus: roomInfo['live_status'] ?? 0,
              liveTime: 0,
              areaId: roomInfo['area_id'] ?? 0,
              areaName: roomInfo['area_name'],
              parentAreaId: roomInfo['parent_area_id'] ?? 0,
              parentAreaName: roomInfo['parent_area_name'],
            );

            // 更新缓存
            _roomInfoCache[realRoomId] = _CacheEntry(
              data: result,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              cacheDuration: _roomCacheDuration,
            );

            return result;
          }
        }
      }
    } catch (e) {
      // 忽略错误，返回null
    }
    return null;
  }

  /// 将短号转换为真实的room_id
  ///
  /// B站直播间URL中的数字可能是短号，需要通过API获取真实room_id
  /// API: /room/v1/Room/get_info 可以处理短号并返回真实room_id
  Future<String?> _resolveRealRoomId(String inputRoomId) async {
    if (inputRoomId.isEmpty) return null;

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.live.bilibili.com/room/v1/Room/get_info?room_id=$inputRoomId',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final realRoomId = data['data']['room_id'];
          if (realRoomId != null) {
            return realRoomId.toString();
          }
        }
      }
    } catch (e) {
      // 忽略错误
    }
    // 如果转换失败，返回原始输入（可能是真实room_id）
    return inputRoomId;
  }

  /// 获取直播间实时状态

  ///
  /// 返回: 直播状态、人气值等信息
  Future<BilibiliRoomStatus?> getRoomStatus(String roomId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/x/web-interface/room/roominfo?room_id=$roomId&mask=1',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          return BilibiliRoomStatus.fromJson(data['data']);
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 批量获取直播间实时状态
  ///
  /// 使用B站批量接口，单次最多查询20个直播间
  /// 批量获取直播间实时状态（直播状态、观看人数）
  /// 使用 room/v1/Room/get_info API，可以获取 online（观看人数）字段
  /// 注意：该API只支持单个room_id，需要逐个请求
  /// [roomIds] 直播间ID列表
  /// 返回: 每个直播间的状态信息
  Future<Map<String, BilibiliRoomStatus>> getRoomStatusBatch(
    List<String> roomIds,
  ) async {
    if (roomIds.isEmpty) return {};

    // 限制单次请求数量
    final limitedIds = roomIds.take(20).toList();
    final result = <String, BilibiliRoomStatus>{};

    try {
      // 该API只支持单个room_id，需要逐个请求
      // 为了性能，使用并发请求
      final futures = limitedIds.map((roomId) => _getRoomStatus(roomId));
      final statuses = await Future.wait(futures);

      for (final status in statuses) {
        if (status != null && status.roomId.isNotEmpty) {
          result[status.roomId] = status;
        }
      }
    } catch (e) {
      // 忽略错误，返回已获取的结果
    }
    return result;
  }

  /// 使用 UID 批量获取直播状态（推荐，带缓存）
  ///
  /// 使用 B站官方批量接口: /room/v1/Room/get_status_info_by_uids
  /// [uids] 主播UID列表
  /// [bypassCache] 为 true 时强制从API获取最新数据
  /// 返回: `Map<uid, BilibiliLiveStatus>`
  Future<Map<String, BilibiliLiveStatus>> getLiveStatusByUids(
    List<String> uids, {
    bool bypassCache = false,
  }) async {
    if (uids.isEmpty) return {};

    final result = <String, BilibiliLiveStatus>{};
    final uidsToFetch = <String>[];

    // 检查缓存
    if (!bypassCache) {
      for (final uid in uids) {
        final cached = _liveStatusCache[uid];
        if (cached != null && !cached.isExpired) {
          result[uid] = cached.data;
        } else {
          uidsToFetch.add(uid);
        }
      }
      // 如果全部命中缓存，直接返回
      if (uidsToFetch.isEmpty) {
        return result;
      }
    } else {
      uidsToFetch.addAll(uids);
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://api.live.bilibili.com/room/v1/Room/get_status_info_by_uids',
            ),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'uids': uidsToFetch}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final dataMap = data['data'] as Map<String, dynamic>;
          for (final entry in dataMap.entries) {
            final uid = entry.key;
            final info = entry.value as Map<String, dynamic>;
            final status = BilibiliLiveStatus.fromJson(info);
            result[uid] = status;
            // 更新缓存
            _liveStatusCache[uid] = _CacheEntry(
              data: status,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              cacheDuration: _liveStatusCacheDuration,
            );
          }
        }
      }
    } catch (e) {
      // 忽略错误，返回已获取的结果（包括缓存命中的数据）
    }
    return result;
  }

  /// 获取单个直播间状态
  Future<BilibiliRoomStatus?> _getRoomStatus(String roomId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.live.bilibili.com/room/v1/Room/get_info?room_id=$roomId',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          return BilibiliRoomStatus.fromJson(data['data']);
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 批量获取直播间详细信息（标题、封面等）
  Future<Map<String, BilibiliRoomInfo>> getRoomInfoBatch(
    List<String> roomIds,
  ) async {
    if (roomIds.isEmpty) return {};

    // 限制单次请求数量
    final limitedIds = roomIds.take(20).toList();

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.live.bilibili.com/xlive/web-room/v1/index/getRoomBaseInfo?req_biz=web_room_com&room_ids=${limitedIds.join(",")}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      final result = <String, BilibiliRoomInfo>{};

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final byRoomIds =
              data['data']['by_room_ids'] as Map<String, dynamic>?;
          if (byRoomIds != null) {
            for (final entry in byRoomIds.entries) {
              final roomInfo = entry.value as Map<String, dynamic>;
              result[entry.key] = BilibiliRoomInfo(
                roomId: roomInfo['room_id']?.toString() ?? entry.key,
                title: roomInfo['title'] ?? '',
                coverUrl: roomInfo['cover'] ?? '',
                description: roomInfo['description'],
                userName: roomInfo['uname'],
                userId: roomInfo['uid']?.toString(),
                liveStatus: roomInfo['live_status'] ?? 0,
                liveTime: 0,
                areaId: roomInfo['area_id'] ?? 0,
                areaName: roomInfo['area_name'],
                parentAreaId: roomInfo['parent_area_id'] ?? 0,
                parentAreaName: roomInfo['parent_area_name'],
              );
            }
          }
        }
      }
      return result;
    } catch (e) {
      // 忽略错误，返回空结果
    }
    return {};
  }

  /// 获取视频信息（带缓存，默认1小时）
  ///
  /// [bypassCache] 为 true 时强制从API获取最新数据
  /// 返回: 视频详细信息，包含播放量、点赞数等
  Future<BilibiliVideoInfo?> getVideoInfo(
    String bvid, {
    bool bypassCache = false,
  }) async {
    // 检查缓存
    if (!bypassCache) {
      final cached = _videoInfoCache[bvid];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/x/web-interface/view?bvid=$bvid'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final result = BilibiliVideoInfo.fromJson(data['data']);

          // 更新缓存
          _videoInfoCache[bvid] = _CacheEntry(
            data: result,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            cacheDuration: _videoCacheDuration,
          );

          return result;
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 获取用户信息（带缓存，默认30秒）
  ///
  /// [bypassCache] 为 true 时强制从API获取最新数据
  /// 返回: 用户详细信息，包含粉丝数等
  Future<BilibiliUserInfo?> getUserInfo(
    String mid, {
    bool bypassCache = false,
  }) async {
    // 检查缓存
    if (!bypassCache) {
      final cached = _userInfoCache[mid];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/x/web-interface/card?mid=$mid'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['data'] != null) {
          final result = BilibiliUserInfo.fromJson(data['data']);

          // 更新缓存
          _userInfoCache[mid] = _CacheEntry(
            data: result,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            cacheDuration: _userCacheDuration,
          );

          return result;
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }
}

/// 直播间信息
class BilibiliRoomInfo {
  final String roomId;
  final String title;
  final String coverUrl;
  final String? description;
  final String? userName;
  final String? userId;
  final int liveStatus;
  final int liveTime;
  final int areaId;
  final String? areaName;
  final int parentAreaId;
  final String? parentAreaName;

  BilibiliRoomInfo({
    required this.roomId,
    required this.title,
    required this.coverUrl,
    this.description,
    this.userName,
    this.userId,
    this.liveStatus = 0,
    this.liveTime = 0,
    this.areaId = 0,
    this.areaName,
    this.parentAreaId = 0,
    this.parentAreaName,
  });

  factory BilibiliRoomInfo.fromJson(Map<String, dynamic> json) {
    return BilibiliRoomInfo(
      roomId: json['room_id']?.toString() ?? '',
      title: json['title'] ?? '',
      coverUrl: json['cover'] ?? json['keyframe'] ?? '',
      description: json['description'],
      userName: json['uname'],
      userId: json['uid']?.toString(),
      liveStatus: json['live_status'] ?? 0,
      liveTime: json['live_time'] ?? 0,
      areaId: json['area_id'] ?? 0,
      areaName: json['area_name'],
      parentAreaId: json['parent_area_id'] ?? 0,
      parentAreaName: json['parent_area_name'],
    );
  }

  /// 是否直播中
  bool get isLive => liveStatus == 1;

  /// 是否轮播中
  bool get isPlayback => liveStatus == 2;
}

/// 直播间实时状态
class BilibiliRoomStatus {
  final String roomId;
  final int liveStatus;
  final int viewCount;
  final int followerCount;

  BilibiliRoomStatus({
    required this.roomId,
    this.liveStatus = 0,
    this.viewCount = 0,
    this.followerCount = 0,
  });

  factory BilibiliRoomStatus.fromJson(Map<String, dynamic> json) {
    return BilibiliRoomStatus(
      roomId: json['room_id']?.toString() ?? '',
      liveStatus: json['live_status'] ?? 0,
      viewCount: json['online'] ?? 0,
    );
  }

  /// 是否直播中
  bool get isLive => liveStatus == 1;

  /// 是否轮播中
  bool get isPlayback => liveStatus == 2;
}

/// 使用 UID 批量查询返回的直播状态
class BilibiliLiveStatus {
  final String uid;
  final String? uname;
  final int roomId;
  final int liveStatus;
  final String? title;
  final String? coverFromUser;
  final String? keyframe;
  final int? online;
  final int? area;
  final String? areaName;
  final int? areaV2Id;
  final String? areaV2Name;
  final String? areaV2ParentName;
  final int? areaV2ParentId;
  final String? tagName;
  final String? tags;

  BilibiliLiveStatus({
    required this.uid,
    this.uname,
    required this.roomId,
    this.liveStatus = 0,
    this.title,
    this.coverFromUser,
    this.keyframe,
    this.online,
    this.area,
    this.areaName,
    this.areaV2Id,
    this.areaV2Name,
    this.areaV2ParentName,
    this.areaV2ParentId,
    this.tagName,
    this.tags,
  });

  factory BilibiliLiveStatus.fromJson(Map<String, dynamic> json) {
    return BilibiliLiveStatus(
      uid: json['uid']?.toString() ?? '',
      uname: json['uname'],
      roomId: json['room_id'] ?? 0,
      liveStatus: json['live_status'] ?? 0,
      title: json['title'],
      coverFromUser: json['cover_from_user'],
      keyframe: json['keyframe'],
      online: json['online'],
      area: json['area'],
      areaName: json['area_name'],
      areaV2Id: json['area_v2_id'],
      areaV2Name: json['area_v2_name'],
      areaV2ParentName: json['area_v2_parent_name'],
      areaV2ParentId: json['area_v2_parent_id'],
      tagName: json['tag_name'],
      tags: json['tags'],
    );
  }

  /// 是否直播中
  bool get isLive => liveStatus == 1;

  /// 是否轮播中
  bool get isPlayback => liveStatus == 2;
}

/// 视频信息
class BilibiliVideoInfo {
  final String bvid;
  final String title;
  final String coverUrl;
  final String? description;
  final String? author;
  final String? mid;
  final String? ownerFace;
  final int viewCount;
  final int likeCount;
  final int coinCount;
  final int favoriteCount;
  final int shareCount;
  final DateTime? publishedAt;
  final int duration;

  BilibiliVideoInfo({
    required this.bvid,
    required this.title,
    required this.coverUrl,
    this.description,
    this.author,
    this.mid,
    this.ownerFace,
    this.viewCount = 0,
    this.likeCount = 0,
    this.coinCount = 0,
    this.favoriteCount = 0,
    this.shareCount = 0,
    this.publishedAt,
    this.duration = 0,
  });

  factory BilibiliVideoInfo.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final stat = json['stat'] as Map<String, dynamic>?;

    int? pubDate;
    if (json['pubdate'] != null) {
      pubDate = json['pubdate'] as int;
    }

    return BilibiliVideoInfo(
      bvid: json['bvid'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['pic'] ?? '',
      description: json['desc'],
      author: owner?['name'],
      mid: owner?['mid']?.toString(),
      ownerFace: owner?['face'],
      viewCount: stat?['view'] ?? 0,
      likeCount: stat?['like'] ?? 0,
      coinCount: stat?['coin'] ?? 0,
      favoriteCount: stat?['favorite'] ?? 0,
      shareCount: stat?['share'] ?? 0,
      publishedAt: pubDate != null
          ? DateTime.fromMillisecondsSinceEpoch(pubDate * 1000)
          : null,
      duration: json['duration'] ?? 0,
    );
  }

  /// 格式化时长
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 用户信息
class BilibiliUserInfo {
  final String mid;
  final String name;
  final String? face;
  final int follower;
  final int following;
  final int level;

  BilibiliUserInfo({
    required this.mid,
    required this.name,
    this.face,
    this.follower = 0,
    this.following = 0,
    this.level = 0,
  });

  factory BilibiliUserInfo.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>?;
    final cardFans = card?['fans'];
    final cardFriend = card?['friend'];
    final cardLevel = card?['level'];
    return BilibiliUserInfo(
      mid: json['mid']?.toString() ?? '',
      name: json['name'] ?? card?['name'] ?? '',
      face: json['face'] ?? card?['face'],
      follower: int.tryParse(cardFans?.toString() ?? '0') ?? 0,
      following: int.tryParse(cardFriend?.toString() ?? '0') ?? 0,
      level: int.tryParse(cardLevel?.toString() ?? '0') ?? 0,
    );
  }
}

/// 缓存条目
class _CacheEntry<T> {
  final T data;
  final int timestamp;
  final Duration cacheDuration;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.cacheDuration,
  });

  bool get isExpired {
    return DateTime.now().millisecondsSinceEpoch - timestamp >=
        cacheDuration.inMilliseconds;
  }
}
