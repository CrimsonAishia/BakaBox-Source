import 'package:equatable/equatable.dart';
import '../../models/playtime_models.dart';

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
  final String? editReason;

  const UpdateTag({
    required this.tagId,
    required this.name,
    this.color,
    this.editReason,
  });

  @override
  List<Object?> get props => [tagId, name, color, editReason];
}

/// 删除标签
class DeleteTag extends MapTagEvent {
  final int tagId;
  final String? editReason;

  const DeleteTag({required this.tagId, this.editReason});

  @override
  List<Object?> get props => [tagId, editReason];
}

/// 撤销变更申请
class CancelTagChangeRequest extends MapTagEvent {
  final int tagId;

  const CancelTagChangeRequest({required this.tagId});

  @override
  List<Object?> get props => [tagId];
}

/// 加载当前用户的游玩时长（含可选地图维度）
class LoadUserPlaytime extends MapTagEvent {
  /// 地图名（带上后会查询「您在本图玩了多久」）
  final String? mapName;

  const LoadUserPlaytime({this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 内部事件：游玩时长心跳推送的状态更新
///
/// 由 [MapTagBloc] 订阅 `PlaytimeReportService.statusStream` 时自动派发，
/// 让弹窗在用户玩到达标的瞬间自动解锁投票按钮。
class PlaytimeStatusUpdated extends MapTagEvent {
  final UserPlaytimeStatus status;

  const PlaytimeStatusUpdated(this.status);

  @override
  List<Object?> get props => [status];
}

/// 清除错误
class ClearTagError extends MapTagEvent {
  const ClearTagError();
}
