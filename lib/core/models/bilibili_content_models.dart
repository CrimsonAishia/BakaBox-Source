import 'package:json_annotation/json_annotation.dart';

part 'bilibili_content_models.g.dart';

/// 直播间数据模型
@JsonSerializable()
class LiveRoom {
  final String id;
  final String ownerUid;
  final String ownerName;
  final String? ownerFace; // 主播头像
  final String roomId;
  final bool enabled;

  // 从B站API获取的实时信息
  final String? title;
  final String? coverUrl;
  final int liveStatus;
  final int popularity;
  final int viewCount;
  final int followerCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LiveRoom({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    this.ownerFace,
    required this.roomId,
    this.enabled = true,
    this.title,
    this.coverUrl,
    this.liveStatus = 0,
    this.popularity = 0,
    this.viewCount = 0,
    this.followerCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory LiveRoom.fromJson(Map<String, dynamic> json) =>
      _$LiveRoomFromJson(json);
  Map<String, dynamic> toJson() => _$LiveRoomToJson(this);

  /// 是否为直播中
  bool get isLive => liveStatus == 1;

  /// 是否为轮播中
  bool get isPlayback => liveStatus == 2;

  /// 获取显示标题：优先使用B站标题，其次使用ownerName
  String get displayTitle => title ?? ownerName;

  /// 获取显示封面
  String? get displayCover {
    String? url = coverUrl;
    if (url != null && url.startsWith('//')) {
      url = 'https:$url';
    }
    return url;
  }

  /// 获取显示封面（用于图片组件，空字符串会显示占位图）
  String get displayCoverUrl => displayCover ?? '';

  /// 获取显示头像（处理 https:// 协议前缀）
  String? get displayFace {
    String? url = ownerFace;
    if (url != null && url.startsWith('//')) {
      url = 'https:$url';
    }
    return url;
  }

  LiveRoom copyWith({
    String? id,
    String? ownerUid,
    String? ownerName,
    String? ownerFace,
    String? roomId,
    bool? enabled,
    String? title,
    String? coverUrl,
    int? liveStatus,
    int? popularity,
    int? viewCount,
    int? followerCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LiveRoom(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      ownerFace: ownerFace ?? this.ownerFace,
      roomId: roomId ?? this.roomId,
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      liveStatus: liveStatus ?? this.liveStatus,
      popularity: popularity ?? this.popularity,
      viewCount: viewCount ?? this.viewCount,
      followerCount: followerCount ?? this.followerCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 视频数据模型
@JsonSerializable()
class BilibiliVideo {
  final String id;
  final String ownerUid;
  final String ownerName;
  final String? ownerFace;
  final String bvid;
  final String? title;
  final String? coverUrl;
  final int playCount;
  final int viewCount;
  final int likeCount;
  final int coinCount;
  final int favoriteCount;
  final DateTime? publishedAt;
  final int? duration;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // 审核相关字段
  final String? auditStatus;
  final String? auditRemark;
  final DateTime? auditAt;
  final int? auditBy;

  // 分类相关字段
  final int? categoryId;
  final String? category;

  BilibiliVideo({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    this.ownerFace,
    required this.bvid,
    this.title,
    this.coverUrl,
    this.playCount = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.coinCount = 0,
    this.favoriteCount = 0,
    this.publishedAt,
    this.duration,
    required this.createdAt,
    this.updatedAt,
    this.auditStatus,
    this.auditRemark,
    this.auditAt,
    this.auditBy,
    this.categoryId,
    this.category,
  });

  factory BilibiliVideo.fromJson(Map<String, dynamic> json) =>
      _$BilibiliVideoFromJson(json);
  Map<String, dynamic> toJson() => _$BilibiliVideoToJson(this);

  /// 获取显示名称：优先自定义名称，其次B站标题
  String get displayName => title ?? '未命名视频';

  /// 获取显示封面：优先自定义封面，其次B站封面
  String? get displayCover {
    String? url = coverUrl;
    if (url != null && url.startsWith('//')) {
      url = 'https:$url';
    }
    return url;
  }

  /// 获取显示头像（处理 https:// 协议前缀）
  String? get displayFace {
    String? url = ownerFace;
    if (url != null && url.startsWith('//')) {
      url = 'https:$url';
    }
    return url;
  }

  /// 审核状态：pending(待审核)/approved(审核通过)/rejected(审核拒绝)
  String get displayAuditStatus => auditStatus ?? 'pending';

  /// 是否待审核
  bool get isPending => auditStatus == null || auditStatus == 'pending';

  /// 是否审核通过
  bool get isApproved => auditStatus == 'approved';

  /// 是否审核拒绝
  bool get isRejected => auditStatus == 'rejected';

  BilibiliVideo copyWith({
    String? id,
    String? ownerUid,
    String? ownerName,
    String? ownerFace,
    String? bvid,
    String? title,
    String? coverUrl,
    int? playCount,
    int? viewCount,
    int? likeCount,
    int? coinCount,
    int? favoriteCount,
    DateTime? publishedAt,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? auditStatus,
    String? auditRemark,
    DateTime? auditAt,
    int? auditBy,
    int? categoryId,
    String? category,
  }) {
    return BilibiliVideo(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      ownerFace: ownerFace ?? this.ownerFace,
      bvid: bvid ?? this.bvid,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      playCount: playCount ?? this.playCount,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      coinCount: coinCount ?? this.coinCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      publishedAt: publishedAt ?? this.publishedAt,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      auditStatus: auditStatus ?? this.auditStatus,
      auditRemark: auditRemark ?? this.auditRemark,
      auditAt: auditAt ?? this.auditAt,
      auditBy: auditBy ?? this.auditBy,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
    );
  }
}

/// 内容类型枚举
enum BilibiliContentType { liveRoom, video }

/// 视频分类模型
@JsonSerializable()
class VideoCategory {
  final int id;
  final String name;

  const VideoCategory({required this.id, required this.name});

  factory VideoCategory.fromJson(Map<String, dynamic> json) =>
      _$VideoCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$VideoCategoryToJson(this);
}
