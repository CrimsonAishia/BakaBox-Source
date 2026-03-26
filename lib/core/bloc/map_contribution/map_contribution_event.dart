import 'package:equatable/equatable.dart';
import '../../models/map_contribution_models.dart';

abstract class MapContributionEvent extends Equatable {
  const MapContributionEvent();
  @override
  List<Object?> get props => [];
}

/// 加载名称贡献列表
class LoadNameContributions extends MapContributionEvent {
  final String mapName;

  const LoadNameContributions({required this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 加载背景贡献列表
class LoadBackgroundContributions extends MapContributionEvent {
  final String mapName;

  const LoadBackgroundContributions({required this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 加载所有贡献（名称和背景）
class LoadAllContributions extends MapContributionEvent {
  final String mapName;

  const LoadAllContributions({required this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 提交名称贡献
class SubmitNameContribution extends MapContributionEvent {
  final String mapName;
  final String name;

  const SubmitNameContribution({required this.mapName, required this.name});

  @override
  List<Object?> get props => [mapName, name];
}

/// 提交背景贡献
class SubmitBackgroundContribution extends MapContributionEvent {
  final String mapName;
  final int fileId;

  const SubmitBackgroundContribution({
    required this.mapName,
    required this.fileId,
  });

  @override
  List<Object?> get props => [mapName, fileId];
}

/// 投票/取消投票
class ToggleVote extends MapContributionEvent {
  final int contributionId;
  final VoteType voteType;

  const ToggleVote(this.contributionId, this.voteType);

  @override
  List<Object?> get props => [contributionId, voteType];
}

/// 刷新名称贡献列表
class RefreshNameContributions extends MapContributionEvent {
  const RefreshNameContributions();
}

/// 刷新背景贡献列表
class RefreshBackgroundContributions extends MapContributionEvent {
  const RefreshBackgroundContributions();
}

/// 更新名称贡献（仅审核失败的可修改）
class UpdateNameContribution extends MapContributionEvent {
  final int id;
  final String name;

  const UpdateNameContribution({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

/// 更新背景贡献（仅审核失败的可修改）
class UpdateBackgroundContribution extends MapContributionEvent {
  final int id;
  final int fileId;

  const UpdateBackgroundContribution({required this.id, required this.fileId});

  @override
  List<Object?> get props => [id, fileId];
}

/// 删除名称贡献（仅审核失败的可删除）
class DeleteNameContribution extends MapContributionEvent {
  final int id;

  const DeleteNameContribution({required this.id});

  @override
  List<Object?> get props => [id];
}

/// 删除背景贡献（仅审核失败的可删除）
class DeleteBackgroundContribution extends MapContributionEvent {
  final int id;

  const DeleteBackgroundContribution({required this.id});

  @override
  List<Object?> get props => [id];
}

/// 清除错误
class ClearContributionError extends MapContributionEvent {
  const ClearContributionError();
}

/// 重置状态
class ResetContributionState extends MapContributionEvent {
  const ResetContributionState();
}

/// 加载所有地图列表
class LoadAllMaps extends MapContributionEvent {
  final MapListRequest request;

  const LoadAllMaps({required this.request});

  @override
  List<Object?> get props => [request];
}

/// 加载我的地图贡献列表（按地图分组）
class LoadMyMapContributions extends MapContributionEvent {
  final MapContributionListRequest request;

  const LoadMyMapContributions({required this.request});

  @override
  List<Object?> get props => [request];
}

/// 刷新所有地图列表
class RefreshAllMaps extends MapContributionEvent {
  const RefreshAllMaps();
}

/// 刷新我的地图贡献列表
class RefreshMyMapContributions extends MapContributionEvent {
  const RefreshMyMapContributions();
}
