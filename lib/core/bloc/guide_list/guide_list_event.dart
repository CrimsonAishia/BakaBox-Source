import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';

abstract class GuideListEvent extends Equatable {
  const GuideListEvent();
  @override
  List<Object?> get props => [];
}

/// 加载攻略列表
///
/// [reset] 为 true 时重置到第 1 页；false 时加载下一页。
class LoadGuides extends GuideListEvent {
  final bool reset;
  const LoadGuides({this.reset = false});
  @override
  List<Object?> get props => [reset];
}

/// 切换筛选条件
class ChangeFilter extends GuideListEvent {
  final GuideFilter filter;
  const ChangeFilter(this.filter);
  @override
  List<Object?> get props => [filter];
}

/// 切换排序方式
class ChangeSort extends GuideListEvent {
  final GuideSortBy sortBy;
  const ChangeSort(this.sortBy);
  @override
  List<Object?> get props => [sortBy];
}

/// 切换搜索关键词（内部 debounce 400ms）
class ChangeKeyword extends GuideListEvent {
  final String keyword;
  const ChangeKeyword(this.keyword);
  @override
  List<Object?> get props => [keyword];
}

/// 刷新单条攻略（详情互动后调用，仅替换 items 中对应项，不重置分页）
class RefreshGuide extends GuideListEvent {
  final int id;
  const RefreshGuide(this.id);
  @override
  List<Object?> get props => [id];
}

/// 列表项乐观点赞切换（不等待接口，失败后回滚）
class ToggleLikeOptimistic extends GuideListEvent {
  final int id;
  const ToggleLikeOptimistic(this.id);
  @override
  List<Object?> get props => [id];
}

/// 列表项乐观收藏切换（不等待接口，失败后回滚）
class ToggleFavoriteOptimistic extends GuideListEvent {
  final int id;
  const ToggleFavoriteOptimistic(this.id);
  @override
  List<Object?> get props => [id];
}

/// 攻略筛选条件
class GuideFilter extends Equatable {
  final String? category;
  final List<String>? tags;
  final bool? hasVideo;
  final int? authorId;
  final String? mapName;

  const GuideFilter({
    this.category,
    this.tags,
    this.hasVideo,
    this.authorId,
    this.mapName,
  });

  const GuideFilter.empty()
    : category = null,
      tags = null,
      hasVideo = null,
      authorId = null,
      mapName = null;

  GuideFilter copyWith({
    String? category,
    bool clearCategory = false,
    List<String>? tags,
    bool clearTags = false,
    bool? hasVideo,
    bool clearHasVideo = false,
    int? authorId,
    bool clearAuthorId = false,
    String? mapName,
    // clearXxx=true 时将对应字段置 null，优先级高于同名 newValue 参数
    bool clearMapName = false,
  }) {
    return GuideFilter(
      category: clearCategory ? null : (category ?? this.category),
      tags: clearTags ? null : (tags ?? this.tags),
      hasVideo: clearHasVideo ? null : (hasVideo ?? this.hasVideo),
      authorId: clearAuthorId ? null : (authorId ?? this.authorId),
      mapName: clearMapName ? null : (mapName ?? this.mapName),
    );
  }

  @override
  List<Object?> get props => [category, tags, hasVideo, authorId, mapName];
}
