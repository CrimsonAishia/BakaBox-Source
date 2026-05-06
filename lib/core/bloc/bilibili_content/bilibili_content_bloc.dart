import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/bilibili_content_models.dart';
import '../../api/bilibili_api.dart';
import '../../services/bilibili_service.dart';
import '../../utils/log_service.dart';
import '../../utils/error_utils.dart';
import 'bilibili_content_event.dart';
import 'bilibili_content_state.dart';

class BilibiliContentBloc
    extends Bloc<BilibiliContentEvent, BilibiliContentState> {
  final BilibiliApi _api = BilibiliApi();
  final BilibiliService _bilibiliService = BilibiliService();

  BilibiliContentBloc() : super(const BilibiliContentState()) {
    on<BilibiliContentFetchRequested>(_onFetch);
    on<BilibiliContentFetchMyRequested>(_onFetchMy);
    on<BilibiliContentTabChanged>(_onTabChanged);
    on<BilibiliContentAddRequested>(_onAdd);
    on<BilibiliContentUpdateRequested>(_onUpdate);
    on<BilibiliContentDeleteRequested>(_onDelete);
    on<BilibiliContentToggleLiveRoomRequested>(_onToggleLiveRoom);
    on<BilibiliContentRefreshStatusRequested>(_onRefreshStatus);
    on<BilibiliContentSearchChanged>(_onSearch);
    on<BilibiliContentVideoAuditFilterChanged>(_onVideoAuditFilterChanged);
    on<BilibiliContentVideoCategoryFilterChanged>(
      _onVideoCategoryFilterChanged,
    );
    on<BilibiliContentIncreaseLiveRoomViewRequested>(_onIncreaseLiveRoomView);
    on<BilibiliContentIncreaseVideoViewRequested>(_onIncreaseVideoView);
    on<BilibiliContentClearOperationResult>(_onClearOperationResult);
    on<BilibiliContentVideoSortChanged>(_onVideoSortChanged);
    on<BilibiliContentFetchCategoriesRequested>(_onFetchCategories);
  }

  Future<void> _onFetch(
    BilibiliContentFetchRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    // 优先使用事件中的tabIndex，否则使用当前状态
    final targetTabIndex = event.tabIndex ?? state.currentTabIndex;
    // 优先使用事件中的pageIndex，否则默认第1页
    final targetPageIndex = event.pageIndex ?? 1;

    // 判断是否为强制刷新（用户主动刷新）
    final isForceRefresh = event.refresh == true;

    // 发送加载状态（但不阻断已显示的数据）
    emit(
      state.copyWith(
        status: BilibiliContentStatus.loading,
        isRefreshing: isForceRefresh,
        currentTabIndex: targetTabIndex,
        currentPage: targetPageIndex,
      ),
    );

    try {
      // 根据tabIndex只获取对应tab的数据
      if (targetTabIndex == 0) {
        // 直播间tab
        final liveRoomResult = await _api.getLiveRooms(
          pageIndex: targetPageIndex,
          pageSize: 16,
          keyword: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        );

        final liveRooms = liveRoomResult.list;
        final liveRoomsTotal = liveRoomResult.total;

        emit(
          state.copyWith(
            status: BilibiliContentStatus.loaded,
            liveRooms: targetPageIndex == 1 ? liveRooms : [...state.liveRooms, ...liveRooms],
            liveRoomsTotal: liveRoomsTotal,
            isRefreshing: false,
            hasLoadedLiveRooms: true,
          ),
        );
      } else {
        // 视频tab
        final videoResult = await _api.getVideos(
          pageIndex: targetPageIndex,
          pageSize: 16,
          sort: state.videoSort,
          categoryId: state.videoCategoryFilter,
          keyword: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        );

        final videos = videoResult.list;
        final videosTotal = videoResult.total;

        emit(
          state.copyWith(
            status: BilibiliContentStatus.loaded,
            videos: targetPageIndex == 1 ? videos : [...state.videos, ...videos],
            videosTotal: videosTotal,
            isRefreshing: false,
            hasLoadedVideos: true,
          ),
        );
      }
    } catch (e) {
      LogService.e('获取B站内容失败: $e');
      emit(
        state.copyWith(
          status: BilibiliContentStatus.error,
          errorMessage: ErrorUtils.getErrorMessage(e, defaultMessage: '获取内容失败'),
        ),
      );
    }
  }

  /// 获取我的内容（用户中心使用）
  Future<void> _onFetchMy(
    BilibiliContentFetchMyRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _api.getMyLiveRoom(),
        _api.getMyVideos(),
      ]);

      final myLiveRoom = results[0] as LiveRoom?;
      final myVideos = results[1] as List<BilibiliVideo>;

      // 取第一个视频作为当前选中的视频
      final myVideo = myVideos.isNotEmpty ? myVideos.first : null;

      emit(
        state.copyWith(
          myLiveRoomId: myLiveRoom?.id,
          myVideoId: myVideo?.id,
          myLiveRoom: myLiveRoom,
          myVideo: myVideo,
          myVideos: myVideos,
        ),
      );

      // 获取到我的直播间后，获取B站详情
      if (myLiveRoom != null) {
        final roomInfo = await _bilibiliService.getRoomInfo(myLiveRoom.roomId);
        if (roomInfo != null) {
          final updatedRoom = myLiveRoom.copyWith(
            title: roomInfo.title,
            coverUrl: roomInfo.coverUrl,
          );
          emit(state.copyWith(myLiveRoom: updatedRoom));
        }
      }
    } catch (e) {
      LogService.e('获取我的内容失败: $e');
    }
  }

  Future<void> _onTabChanged(
    BilibiliContentTabChanged event,
    Emitter<BilibiliContentState> emit,
  ) async {
    // 切换Tab时重置分页到第一页
    final shouldResetPage = state.currentPage != 1;

    // 切换到视频Tab时，重置分类和排序到默认状态
    if (event.tabIndex == 1) {
      final shouldReset =
          state.videoCategoryFilter != null || state.videoSort != 'view_count';
      if (shouldReset || shouldResetPage) {
        emit(
          state.copyWith(
            currentTabIndex: event.tabIndex,
            currentPage: 1,
            clearVideoCategoryFilter: shouldReset,
            videoSort: 'view_count',
          ),
        );
      } else {
        emit(state.copyWith(currentTabIndex: event.tabIndex, currentPage: 1));
      }
    } else {
      if (shouldResetPage) {
        emit(state.copyWith(currentTabIndex: event.tabIndex, currentPage: 1));
      } else {
        emit(state.copyWith(currentTabIndex: event.tabIndex));
      }
    }
  }

  Future<void> _onAdd(
    BilibiliContentAddRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    LogService.d(
      '[BilibiliContentBloc] _onAdd: contentType=${event.contentType}, contentId=${event.contentId}',
    );
    LogService.d(
      '[BilibiliContentBloc] Current state: myLiveRoomId=${state.myLiveRoomId}, myVideoId=${state.myVideoId}',
    );
    try {
      if (event.contentType == BilibiliContentType.liveRoom) {
        // 检查是否已有直播间
        if (state.myLiveRoomId != null) {
          emit(state.copyWith(errorMessage: '您已添加过直播间'));
          return;
        }

        // 从B站获取直播间信息
        final roomId = BilibiliService.extractRoomId(event.contentId);
        if (roomId == null) {
          emit(state.copyWith(errorMessage: '直播间ID格式不正确'));
          return;
        }

        final roomInfo = await _bilibiliService.getRoomInfo(roomId);
        if (roomInfo == null) {
          emit(state.copyWith(errorMessage: '无法获取直播间信息，请检查ID是否正确'));
          return;
        }

        // 如果事件中没有提供额外数据，且我们需要它们作为兜底
        int? popularity = event.popularity;
        int? followerCount = event.followerCount;
        
        if (popularity == null) {
          final roomStatus = await _bilibiliService.getRoomStatus(roomId);
          popularity = roomStatus?.viewCount;
        }
        
        if (followerCount == null && roomInfo.userId != null) {
          final userInfo = await _bilibiliService.getUserInfo(roomInfo.userId!);
          followerCount = userInfo?.follower;
        }

        final newRoom = await _api.addLiveRoom(
          roomId: roomId,
          title: event.title ?? roomInfo.title,
          coverUrl: event.coverUrl ?? roomInfo.coverUrl,
          ownerUid: event.ownerUid ?? roomInfo.userId,
          ownerName: event.ownerName ?? roomInfo.userName,
          liveStatus: event.liveStatus ?? roomInfo.liveStatus,
          popularity: popularity,
          followerCount: followerCount,
        );

        emit(
          state.copyWith(
            liveRooms: [newRoom, ...state.liveRooms],
            myLiveRoomId: newRoom.id,
            myLiveRoom: newRoom,
            errorMessage: null,
            lastOperationSuccess: true,
            lastOperationMessage: '直播间添加成功',
          ),
        );
      } else {
        // 从B站获取视频信息
        final bvid = BilibiliService.extractBvid(event.contentId);
        if (bvid == null) {
          emit(state.copyWith(errorMessage: '视频BV号格式不正确'));
          return;
        }

        final videoInfo = await _bilibiliService.getVideoInfo(bvid);
        if (videoInfo == null) {
          emit(state.copyWith(errorMessage: '无法获取视频信息，请检查BV号是否正确'));
          return;
        }

        final newVideo = await _api.addVideo(
          bvid: bvid,
          title: event.title ?? videoInfo.title,
          coverUrl: event.coverUrl ?? videoInfo.coverUrl,
          ownerUid: event.ownerUid ?? videoInfo.mid,
          ownerName: event.ownerName ?? videoInfo.author,
          ownerFace: event.ownerFace ?? videoInfo.ownerFace,
          publishedAt:
              event.publishedAt ?? videoInfo.publishedAt?.toIso8601String(),
          duration: event.duration ?? videoInfo.duration,
          categoryId: event.categoryId,
          playCount: event.playCount ?? videoInfo.viewCount,
          likeCount: event.likeCount ?? videoInfo.likeCount,
          coinCount: event.coinCount ?? videoInfo.coinCount,
          favoriteCount: event.favoriteCount ?? videoInfo.favoriteCount,
        );

        emit(
          state.copyWith(
            videos: [newVideo, ...state.videos],
            myVideos: [newVideo, ...state.myVideos],
            myVideoId: newVideo.id,
            myVideo: newVideo,
            errorMessage: null,
            lastOperationSuccess: true,
            lastOperationMessage: '视频添加成功',
          ),
        );
      }
    } catch (e) {
      LogService.e('添加B站内容失败: $e');
      final errorMsg = ErrorUtils.getErrorMessage(e, defaultMessage: '添加失败');
      emit(
        state.copyWith(
          errorMessage: errorMsg,
          lastOperationSuccess: false,
          lastOperationMessage: errorMsg,
        ),
      );
    }
  }

  Future<void> _onUpdate(
    BilibiliContentUpdateRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    LogService.d(
      '[BilibiliContentBloc] _onUpdate: id=${event.id}, contentType=${event.contentType}',
    );
    try {
      if (event.contentType == BilibiliContentType.liveRoom) {
        int? popularity = event.popularity;
        int? followerCount = event.followerCount;
        
        // 当更新直播间但缺乏新数据时，尝试拉取一下
        if (event.roomId != null && popularity == null) {
          final roomStatus = await _bilibiliService.getRoomStatus(event.roomId!);
          popularity = roomStatus?.viewCount;
        }
        if (event.ownerUid != null && followerCount == null) {
          final userInfo = await _bilibiliService.getUserInfo(event.ownerUid!);
          followerCount = userInfo?.follower;
        }

        final updatedRoom = await _api.updateLiveRoom(
          id: event.id,
          roomId: event.roomId,
          title: event.title,
          coverUrl: event.coverUrl,
          ownerUid: event.ownerUid,
          ownerName: event.ownerName,
          liveStatus: event.liveStatus,
          popularity: popularity ?? event.popularity,
          followerCount: followerCount ?? event.followerCount,
        );

        final updatedList = state.liveRooms.map((room) {
          return room.id == event.id ? updatedRoom : room;
        }).toList();

        // 更新 myLiveRoom
        final updatedMyLiveRoom = state.myLiveRoom?.id == event.id
            ? updatedRoom
            : state.myLiveRoom;

        emit(
          state.copyWith(
            liveRooms: updatedList,
            myLiveRoom: updatedMyLiveRoom,
            errorMessage: null,
            lastOperationSuccess: true,
            lastOperationMessage: '直播间更新成功',
          ),
        );
      } else {
        int? playCount = event.playCount;
        int? likeCount = event.likeCount;
        int? coinCount = event.coinCount;
        int? favoriteCount = event.favoriteCount;
        
        // 当更新视频且有 bvid 时，作为兜底拉取最新统计
        if (event.bvid != null && playCount == null) {
          final videoInfo = await _bilibiliService.getVideoInfo(event.bvid!);
          if (videoInfo != null) {
            playCount = videoInfo.viewCount;
            likeCount = videoInfo.likeCount;
            coinCount = videoInfo.coinCount;
            favoriteCount = videoInfo.favoriteCount;
          }
        }

        final updatedVideo = await _api.updateVideo(
          id: event.id,
          bvid: event.bvid,
          title: event.title,
          coverUrl: event.coverUrl,
          ownerUid: event.ownerUid,
          ownerName: event.ownerName,
          ownerFace: event.ownerFace,
          publishedAt: event.publishedAt,
          duration: event.duration,
          categoryId: event.categoryId,
          playCount: playCount ?? event.playCount,
          likeCount: likeCount ?? event.likeCount,
          coinCount: coinCount ?? event.coinCount,
          favoriteCount: favoriteCount ?? event.favoriteCount,
        );

        final updatedList = state.videos.map((video) {
          return video.id == event.id ? updatedVideo : video;
        }).toList();

        // 也更新 myVideos 列表
        final updatedMyVideos = state.myVideos.map((video) {
          return video.id == event.id ? updatedVideo : video;
        }).toList();

        // 更新 myVideo
        final updatedMyVideo = state.myVideo?.id == event.id
            ? updatedVideo
            : state.myVideo;

        emit(
          state.copyWith(
            videos: updatedList,
            myVideos: updatedMyVideos,
            myVideo: updatedMyVideo,
            errorMessage: null,
            lastOperationSuccess: true,
            lastOperationMessage: '视频更新成功',
          ),
        );
      }
    } catch (e) {
      LogService.e('编辑B站内容失败: $e');
      final errorMsg = ErrorUtils.getErrorMessage(e, defaultMessage: '编辑失败');
      emit(
        state.copyWith(
          errorMessage: errorMsg,
          lastOperationSuccess: false,
          lastOperationMessage: errorMsg,
        ),
      );
    }
  }

  Future<void> _onDelete(
    BilibiliContentDeleteRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    LogService.d(
      '[BilibiliContentBloc] _onDelete: id=${event.id}, contentType=${event.contentType}',
    );
    try {
      if (event.contentType == BilibiliContentType.liveRoom) {
        await _api.deleteLiveRoom(event.id);

        final updatedList = state.liveRooms
            .where((room) => room.id != event.id)
            .toList();
        final currentMyLiveRoom = state.myLiveRoomId == event.id
            ? null
            : state.myLiveRoom;

        emit(
          state.copyWith(
            liveRooms: updatedList,
            myLiveRoomId: currentMyLiveRoom?.id,
            myLiveRoom: currentMyLiveRoom,
            errorMessage: null,
            lastOperationSuccess: true,
            lastOperationMessage: '直播间删除成功',
          ),
        );
      } else {
        await _api.deleteVideo(event.id);

        final updatedList = state.videos
            .where((video) => video.id != event.id)
            .toList();
        final updatedMyVideos = state.myVideos
            .where((video) => video.id != event.id)
            .toList();
        final currentMyVideo = state.myVideo?.id == event.id
            ? null
            : state.myVideo;

        emit(
          state.copyWith(
            videos: updatedList,
            myVideos: updatedMyVideos,
            myVideoId: currentMyVideo?.id,
            myVideo: currentMyVideo,
            errorMessage: null,
            lastOperationSuccess: true,
            lastOperationMessage: '视频删除成功',
          ),
        );
      }
    } catch (e) {
      LogService.e('删除失败: $e');
      final errorMsg = ErrorUtils.getErrorMessage(e, defaultMessage: '删除失败');
      emit(
        state.copyWith(
          errorMessage: errorMsg,
          lastOperationSuccess: false,
          lastOperationMessage: errorMsg,
        ),
      );
    }
  }

  Future<void> _onToggleLiveRoom(
    BilibiliContentToggleLiveRoomRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    LogService.d(
      '[BilibiliContentBloc] _onToggleLiveRoom: id=${event.id}, enabled=${event.enabled}',
    );
    try {
      final updatedRoom = await _api.toggleLiveRoom(
        id: event.id,
        enabled: event.enabled,
      );

      final updatedList = state.liveRooms.map((room) {
        return room.id == event.id ? updatedRoom : room;
      }).toList();

      // 如果更新的是我的直播间，同时更新 myLiveRoom
      final updatedMyLiveRoom = state.myLiveRoom?.id == event.id
          ? updatedRoom
          : state.myLiveRoom;

      emit(
        state.copyWith(
          liveRooms: updatedList,
          myLiveRoom: updatedMyLiveRoom,
          errorMessage: null,
        ),
      );
    } catch (e) {
      LogService.e('切换直播间状态失败: $e');
      final errorMsg = ErrorUtils.getErrorMessage(e, defaultMessage: '切换状态失败');
      emit(state.copyWith(errorMessage: errorMsg));
    }
  }

  Future<void> _onRefreshStatus(
    BilibiliContentRefreshStatusRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    if (state.liveRooms.isEmpty) return;

    // 设置刷新状态
    emit(state.copyWith(isRefreshing: true));

    try {
      add(const BilibiliContentFetchRequested(tabIndex: 0, refresh: true));
    } catch (e) {
      // 静默失败，不影响用户体验
      emit(state.copyWith(isRefreshing: false));
    }
  }

  void _onSearch(
    BilibiliContentSearchChanged event,
    Emitter<BilibiliContentState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
    // 搜索时强制获取最新数据
    add(const BilibiliContentFetchRequested(refresh: true));
  }

  void _onVideoAuditFilterChanged(
    BilibiliContentVideoAuditFilterChanged event,
    Emitter<BilibiliContentState> emit,
  ) {
    if (event.auditStatus == null) {
      emit(state.copyWith(clearVideoAuditFilter: true));
    } else {
      emit(state.copyWith(videoAuditFilter: event.auditStatus));
    }
  }

  void _onVideoCategoryFilterChanged(
    BilibiliContentVideoCategoryFilterChanged event,
    Emitter<BilibiliContentState> emit,
  ) {
    if (event.categoryId == null) {
      emit(state.copyWith(clearVideoCategoryFilter: true));
    } else {
      emit(state.copyWith(videoCategoryFilter: event.categoryId));
    }
    // 切换分类后强制获取最新视频列表
    add(const BilibiliContentFetchRequested(tabIndex: 1, refresh: true));
  }

  Future<void> _onFetchCategories(
    BilibiliContentFetchCategoriesRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    try {
      final categories = await _api.getVideoCategories();
      emit(state.copyWith(videoCategories: categories));
    } catch (e) {
      LogService.e('获取视频分类列表失败: $e');
    }
  }

  /// 增加直播间点击数
  Future<void> _onIncreaseLiveRoomView(
    BilibiliContentIncreaseLiveRoomViewRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    try {
      await _api.increaseLiveRoomViewCount(event.id);
    } catch (e) {
      // 静默失败，不影响用户体验
    }
  }

  /// 增加视频点击数
  Future<void> _onIncreaseVideoView(
    BilibiliContentIncreaseVideoViewRequested event,
    Emitter<BilibiliContentState> emit,
  ) async {
    try {
      await _api.increaseVideoViewCount(event.id);
    } catch (e) {
      // 静默失败，不影响用户体验
    }
  }

  /// 清除操作结果状态
  Future<void> _onClearOperationResult(
    BilibiliContentClearOperationResult event,
    Emitter<BilibiliContentState> emit,
  ) async {
    emit(state.copyWith(clearLastOperation: true));
  }

  void _onVideoSortChanged(
    BilibiliContentVideoSortChanged event,
    Emitter<BilibiliContentState> emit,
  ) {
    if (state.videoSort == event.sort) return;
    emit(state.copyWith(videoSort: event.sort));
    // 切换排序后强制获取最新数据
    add(const BilibiliContentFetchRequested(tabIndex: 1, refresh: true));
  }
}
