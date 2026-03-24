import 'package:equatable/equatable.dart';

abstract class MapTagEvent extends Equatable {
  const MapTagEvent();

  @override
  List<Object?> get props => [];
}

/// 加载全局标签列表
class LoadTagList extends MapTagEvent {
  const LoadTagList();
}

/// 加载地图的标签投票列表
class LoadMapTagList extends MapTagEvent {
  final String mapName;

  const LoadMapTagList({required this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 投票/取消投票
class ToggleTagVote extends MapTagEvent {
  final int tagId;
  /// 投票类型: 'up' 或 'down'
  final String? voteType;

  const ToggleTagVote({required this.tagId, this.voteType});

  @override
  List<Object?> get props => [tagId, voteType];
}

/// 提交新标签
class SubmitTag extends MapTagEvent {
  final String name;
  /// 标签颜色，十六进制格式如 #FF5733
  final String? color;
  /// 审核通过后自动为该地图投一票
  final bool autoVote;

  const SubmitTag({required this.name, this.color, this.autoVote = false});

  @override
  List<Object?> get props => [name, color, autoVote];
}

/// 刷新标签列表
class RefreshTagList extends MapTagEvent {
  const RefreshTagList();
}

/// 刷新地图标签投票列表
class RefreshMapTagList extends MapTagEvent {
  const RefreshMapTagList();
}

/// 加载用户自己的标签
class LoadUserTags extends MapTagEvent {
  const LoadUserTags();
}

/// 刷新用户标签列表
class RefreshUserTags extends MapTagEvent {
  const RefreshUserTags();
}

/// 更新标签
class UpdateTag extends MapTagEvent {
  final int tagId;
  final String name;
  /// 标签颜色，十六进制格式如 #FF5733
  final String? color;

  const UpdateTag({required this.tagId, required this.name, this.color});

  @override
  List<Object?> get props => [tagId, name, color];
}

/// 删除标签
class DeleteTag extends MapTagEvent {
  final int tagId;

  const DeleteTag({required this.tagId});

  @override
  List<Object?> get props => [tagId];
}

/// 清除错误
class ClearTagError extends MapTagEvent {
  const ClearTagError();
}
