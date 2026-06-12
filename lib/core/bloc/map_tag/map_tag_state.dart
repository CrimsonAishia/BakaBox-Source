import 'package:equatable/equatable.dart';
import '../../models/map_tag_models.dart';

class MapTagState extends Equatable {
  /// 全局标签列表
  final List<MapTag> tagList;

  /// 用户自己的标签列表
  final List<MapTag> userTags;

  /// 地图的标签投票列表
  final List<MapTagVoteSimple> mapTagVotes;

  /// 我的标签变更申请列表
  final List<MapTagChangeRequest> myChangeRequests;

  /// 是否正在加载全局标签列表
  final bool isLoadingTagList;

  /// 是否正在加载用户标签列表
  final bool isLoadingUserTags;

  /// 是否正在加载地图标签投票列表
  final bool isLoadingMapTagVotes;

  /// 是否正在提交
  final bool isSubmitting;

  /// 是否正在投票
  final bool isVoting;

  /// 提交成功标识
  final bool submitSuccess;

  /// 删除成功标识
  final bool deleteSuccess;

  /// 撤销变更申请成功标识
  final bool cancelSuccess;

  /// 错误信息
  final String? error;

  /// 当前地图名称
  final String? currentMapName;

  /// 无反对票时达到显示门槛所需的最小赞成票数
  /// 来自标签列表接口，用于面向用户的提示文案
  final int? displayMinVotes;

  const MapTagState({
    this.tagList = const [],
    this.userTags = const [],
    this.mapTagVotes = const [],
    this.myChangeRequests = const [],
    this.isLoadingTagList = false,
    this.isLoadingUserTags = false,
    this.isLoadingMapTagVotes = false,
    this.isSubmitting = false,
    this.isVoting = false,
    this.submitSuccess = false,
    this.deleteSuccess = false,
    this.cancelSuccess = false,
    this.error,
    this.currentMapName,
    this.displayMinVotes,
  });

  /// 是否正在加载
  bool get isLoading =>
      isLoadingTagList || isLoadingUserTags || isLoadingMapTagVotes;

  /// 标签列表是否为空（全局标签 + 用户标签都为空）
  bool get isTagListEmpty =>
      tagList.isEmpty &&
      userTags.isEmpty &&
      !isLoadingTagList &&
      !isLoadingUserTags;

  /// 地图标签投票列表是否为空
  bool get isMapTagVotesEmpty => mapTagVotes.isEmpty && !isLoadingMapTagVotes;

  /// 获取所有需要显示的标签（用户标签在前，全局标签在后）
  List<MapTag> get allDisplayTags {
    final all = <MapTag>[];
    // 用户标签排在前面
    all.addAll(userTags);
    // 全局标签排在后面（过滤掉已经在用户标签中显示的）
    final userTagIds = userTags.map((t) => t.id).toSet();
    for (final tag in tagList) {
      if (!userTagIds.contains(tag.id)) {
        all.add(tag);
      }
    }
    return all;
  }

  /// 根据 tagId 获取地图投票记录
  MapTagVoteSimple? getMapTagVoteByTagId(int tagId) {
    try {
      return mapTagVotes.firstWhere((v) => v.tagId == tagId);
    } catch (e) {
      return null;
    }
  }

  /// 检查某个标签是否已投票
  bool hasVotedTag(int tagId) {
    final vote = getMapTagVoteByTagId(tagId);
    return vote?.hasVoted ?? false;
  }

  /// 检查某个标签是否有票数（任何用户投的赞成/反对票）
  bool hasAnyVotes(int tagId) {
    final vote = getMapTagVoteByTagId(tagId);
    if (vote == null) return false;
    return vote.voteCount != 0 || (vote.upCount + vote.downCount) > 0;
  }

  /// 检查某个标签是否有待审核的变更申请
  bool hasPendingChangeRequest(int tagId) {
    return myChangeRequests.any(
      (req) => req.tagId == tagId && req.auditStatus == AuditStatus.pending,
    );
  }

  MapTagState copyWith({
    List<MapTag>? tagList,
    List<MapTag>? userTags,
    List<MapTagVoteSimple>? mapTagVotes,
    List<MapTagChangeRequest>? myChangeRequests,
    bool? isLoadingTagList,
    bool? isLoadingUserTags,
    bool? isLoadingMapTagVotes,
    bool? isSubmitting,
    bool? isVoting,
    bool? submitSuccess,
    bool? deleteSuccess,
    bool? cancelSuccess,
    String? error,
    bool clearError = false,
    String? currentMapName,
    int? displayMinVotes,
  }) {
    return MapTagState(
      tagList: tagList ?? this.tagList,
      userTags: userTags ?? this.userTags,
      mapTagVotes: mapTagVotes ?? this.mapTagVotes,
      myChangeRequests: myChangeRequests ?? this.myChangeRequests,
      isLoadingTagList: isLoadingTagList ?? this.isLoadingTagList,
      isLoadingUserTags: isLoadingUserTags ?? this.isLoadingUserTags,
      isLoadingMapTagVotes: isLoadingMapTagVotes ?? this.isLoadingMapTagVotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isVoting: isVoting ?? this.isVoting,
      submitSuccess: submitSuccess ?? false,
      deleteSuccess: deleteSuccess ?? false,
      cancelSuccess: cancelSuccess ?? false,
      error: clearError ? null : (error ?? this.error),
      currentMapName: currentMapName ?? this.currentMapName,
      displayMinVotes: displayMinVotes ?? this.displayMinVotes,
    );
  }

  @override
  List<Object?> get props => [
    tagList,
    userTags,
    mapTagVotes,
    myChangeRequests,
    isLoadingTagList,
    isLoadingUserTags,
    isLoadingMapTagVotes,
    isSubmitting,
    isVoting,
    submitSuccess,
    deleteSuccess,
    cancelSuccess,
    error,
    currentMapName,
    displayMinVotes,
  ];
}
