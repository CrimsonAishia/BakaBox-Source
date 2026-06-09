import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';

/// 我的中心 Tab 枚举
enum MineTab {
  published,
  drafts,
  favorites,
  liked,
  trash;

  String get label => switch (this) {
        MineTab.published => '已发布',
        MineTab.drafts => '草稿箱',
        MineTab.favorites => '我的收藏',
        MineTab.liked => '我赞过的',
        MineTab.trash => '回收站',
      };
}

abstract class GuideMineEvent extends Equatable {
  const GuideMineEvent();
  @override
  List<Object?> get props => [];
}

/// 切换 Tab
class ChangeTab extends GuideMineEvent {
  final MineTab tab;
  const ChangeTab(this.tab);
  @override
  List<Object?> get props => [tab];
}

/// 切换状态筛选（仅 published Tab 使用）
class ChangeStatusFilter extends GuideMineEvent {
  final GuideStatus? status;
  const ChangeStatusFilter(this.status);
  @override
  List<Object?> get props => [status];
}

/// 加载更多（下一页）
class LoadMore extends GuideMineEvent {
  const LoadMore();
}

/// 拉取「我的中心」用户统计概览
class LoadMineStats extends GuideMineEvent {
  const LoadMineStats();
}

/// 删除草稿
class DeleteDraft extends GuideMineEvent {
  final String draftId;
  const DeleteDraft(this.draftId);
  @override
  List<Object?> get props => [draftId];
}

/// 本地移除草稿（不调用接口）
///
/// 用于「编辑器发布成功后已在后端删除对应草稿」的场景：此时草稿箱列表若仍挂载，
/// 需要把残留的草稿卡片就地移除，避免显示已被删除的草稿。
class RemoveDraftLocal extends GuideMineEvent {
  final String draftId;
  const RemoveDraftLocal(this.draftId);
  @override
  List<Object?> get props => [draftId];
}

/// 删除攻略（移入回收站）
class DeleteGuide extends GuideMineEvent {
  final int guideId;
  const DeleteGuide(this.guideId);
  @override
  List<Object?> get props => [guideId];
}

/// 还原攻略（从回收站恢复）
class RestoreGuide extends GuideMineEvent {
  final int guideId;
  const RestoreGuide(this.guideId);
  @override
  List<Object?> get props => [guideId];
}
