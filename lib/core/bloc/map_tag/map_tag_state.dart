import 'package:equatable/equatable.dart';
import '../../models/map_tag_models.dart';

class MapTagState extends Equatable {
  /// 全局标签列表
  final List<MapTag> tagList;

  /// 用户自己的标签列表
  final List<MapTag> userTags;

  /// 地图的标签投票列表
  final List<MapTagVoteSimple> mapTagVotes;

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

  /// 错误信息
  final String? error;

  /// 当前地图名称
  final String? currentMapName;

  const MapTagState({
    this.tagList = const [],
    this.userTags = const [],
    this.mapTagVotes = const [],
    this.isLoadingTagList = false,
    this.isLoadingUserTags = false,
    this.isLoadingMapTagVotes = false,
    this.isSubmitting = false,
    this.isVoting = false,
    this.submitSuccess = false,
    this.deleteSuccess = false,
    this.error,
    this.currentMapName,
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

  MapTagState copyWith({
    List<MapTag>? tagList,
    List<MapTag>? userTags,
    List<MapTagVoteSimple>? mapTagVotes,
    bool? isLoadingTagList,
    bool? isLoadingUserTags,
    bool? isLoadingMapTagVotes,
    bool? isSubmitting,
    bool? isVoting,
    bool? submitSuccess,
    bool? deleteSuccess,
    String? error,
    bool clearError = false,
    String? currentMapName,
  }) {
    return MapTagState(
      tagList: tagList ?? this.tagList,
      userTags: userTags ?? this.userTags,
      mapTagVotes: mapTagVotes ?? this.mapTagVotes,
      isLoadingTagList: isLoadingTagList ?? this.isLoadingTagList,
      isLoadingUserTags: isLoadingUserTags ?? this.isLoadingUserTags,
      isLoadingMapTagVotes: isLoadingMapTagVotes ?? this.isLoadingMapTagVotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isVoting: isVoting ?? this.isVoting,
      submitSuccess: submitSuccess ?? false,
      deleteSuccess: deleteSuccess ?? false,
      error: clearError ? null : (error ?? this.error),
      currentMapName: currentMapName ?? this.currentMapName,
    );
  }

  @override
  List<Object?> get props => [
    tagList,
    userTags,
    mapTagVotes,
    isLoadingTagList,
    isLoadingUserTags,
    isLoadingMapTagVotes,
    isSubmitting,
    isVoting,
    submitSuccess,
    deleteSuccess,
    error,
    currentMapName,
  ];
}
