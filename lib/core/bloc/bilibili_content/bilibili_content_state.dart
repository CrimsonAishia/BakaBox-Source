import 'package:equatable/equatable.dart';
import '../../models/bilibili_content_models.dart';

/// 状态
enum BilibiliContentStatus { initial, loading, loaded, error }

/// B站内容状态
class BilibiliContentState extends Equatable {
  final BilibiliContentStatus status;
  final List<LiveRoom> liveRooms;
  final List<BilibiliVideo> videos;
  final int currentTabIndex;
  final String? errorMessage;
  final int currentPage;

  // 后端返回的总数
  final int liveRoomsTotal;
  final int videosTotal;
  final String searchQuery;

  // 当前用户的直播间/视频（用于权限判断）
  final String? myLiveRoomId;
  final String? myVideoId;

  // 当前用户的完整直播间/视频数据（从 /my 接口获取）
  final LiveRoom? myLiveRoom;
  final BilibiliVideo? myVideo;
  final List<BilibiliVideo> myVideos; // 用户所有视频列表（包含所有审核状态）

  // 视频排序方式 ('view_count' 按点击数, 'newest' 按发布时间)
  final String videoSort;

  // 视频审核状态筛选 (null = 全部, pending/approved/rejected)
  final String? videoAuditFilter;

  // 视频分类ID筛选 (null = 全部)
  final int? videoCategoryFilter;

  // 视频分类列表
  final List<VideoCategory> videoCategories;

  // 刷新状态（用于显示 loading 动画）
  final bool isRefreshing;

  // 各自 Tab 是否已完成初次加载
  final bool hasLoadedLiveRooms;
  final bool hasLoadedVideos;
  // 最后一次操作结果（用于Toast提示）
  final bool? lastOperationSuccess;
  final String? lastOperationMessage;

  const BilibiliContentState({
    this.status = BilibiliContentStatus.initial,
    this.liveRooms = const [],
    this.videos = const [],
    this.currentTabIndex = 0,
    this.errorMessage,
    this.currentPage = 1,
    this.searchQuery = '',
    this.myLiveRoomId,
    this.myVideoId,
    this.myLiveRoom,
    this.myVideo,
    this.myVideos = const [],
    this.videoSort = 'view_count',
    this.videoAuditFilter,
    this.videoCategoryFilter,
    this.videoCategories = const [],
    this.isRefreshing = false,
    this.hasLoadedLiveRooms = false,
    this.hasLoadedVideos = false,
    this.lastOperationSuccess,
    this.lastOperationMessage,
    this.liveRoomsTotal = 0,
    this.videosTotal = 0,
  });

  /// 当前Tab的内容列表
  List<dynamic> get currentList {
    if (currentTabIndex == 0) {
      return liveRooms;
    } else {
      return videos;
    }
  }

  /// 过滤后的列表
  List<dynamic> get filteredList {
    var list = currentList;
    return list;
  }

  /// 总数量
  int get totalCount => liveRooms.length + videos.length;

  /// 获取直播间数量
  int get liveRoomCount => liveRooms.length;

  /// 获取视频数量
  int get videoCount => videos.length;

  BilibiliContentState copyWith({
    BilibiliContentStatus? status,
    List<LiveRoom>? liveRooms,
    List<BilibiliVideo>? videos,
    int? currentTabIndex,
    String? errorMessage,
    int? currentPage,
    String? searchQuery,
    String? myLiveRoomId,
    String? myVideoId,
    LiveRoom? myLiveRoom,
    BilibiliVideo? myVideo,
    List<BilibiliVideo>? myVideos,
    String? videoSort,
    String? videoAuditFilter,
    bool clearVideoAuditFilter = false,
    int? videoCategoryFilter,
    bool clearVideoCategoryFilter = false,
    List<VideoCategory>? videoCategories,
    bool? isRefreshing,
    bool? hasLoadedLiveRooms,
    bool? hasLoadedVideos,
    bool? lastOperationSuccess,
    String? lastOperationMessage,
    bool clearLastOperation = false,
    int? liveRoomsTotal,
    int? videosTotal,
  }) {
    return BilibiliContentState(
      status: status ?? this.status,
      liveRooms: liveRooms ?? this.liveRooms,
      videos: videos ?? this.videos,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      errorMessage: errorMessage,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      myLiveRoomId: myLiveRoomId ?? this.myLiveRoomId,
      myVideoId: myVideoId ?? this.myVideoId,
      myLiveRoom: myLiveRoom ?? this.myLiveRoom,
      myVideo: myVideo ?? this.myVideo,
      myVideos: myVideos ?? this.myVideos,
      videoSort: videoSort ?? this.videoSort,
      videoAuditFilter: clearVideoAuditFilter
          ? null
          : (videoAuditFilter ?? this.videoAuditFilter),
      videoCategoryFilter: clearVideoCategoryFilter
          ? null
          : (videoCategoryFilter ?? this.videoCategoryFilter),
      videoCategories: videoCategories ?? this.videoCategories,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasLoadedLiveRooms: hasLoadedLiveRooms ?? this.hasLoadedLiveRooms,
      hasLoadedVideos: hasLoadedVideos ?? this.hasLoadedVideos,
      lastOperationSuccess: clearLastOperation
          ? null
          : (lastOperationSuccess ?? this.lastOperationSuccess),
      lastOperationMessage: clearLastOperation
          ? null
          : (lastOperationMessage ?? this.lastOperationMessage),
      liveRoomsTotal: liveRoomsTotal ?? this.liveRoomsTotal,
      videosTotal: videosTotal ?? this.videosTotal,
    );
  }

  @override
  List<Object?> get props => [
    status,
    liveRooms,
    videos,
    currentTabIndex,
    errorMessage,
    currentPage,
    searchQuery,
    myLiveRoomId,
    myVideoId,
    myLiveRoom,
    myVideo,
    myVideos,
    videoSort,
    videoAuditFilter,
    videoCategoryFilter,
    videoCategories,
    isRefreshing,
    hasLoadedLiveRooms,
    hasLoadedVideos,
    lastOperationSuccess,
    lastOperationMessage,
    liveRoomsTotal,
    videosTotal,
  ];
}
