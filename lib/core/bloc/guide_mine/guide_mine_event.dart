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

/// 发布成功后刷新当前列表（不调用接口删除，重新拉取第一页 + 统计）
///
/// 编辑器发布/修改攻略成功后，后端数据已变化（草稿被删、已发布攻略内容或状态
/// 更新为待审核等）。若「我的中心」仍挂载，需重新拉取当前 Tab 第一页以同步最新
/// 内容，避免显示旧的标题 / 摘要 / 状态或已删除的草稿。
class ReloadCurrentList extends GuideMineEvent {
  const ReloadCurrentList();
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

/// 上架攻略（重新发布已下架的攻略）
class PublishGuide extends GuideMineEvent {
  final int guideId;
  const PublishGuide(this.guideId);
  @override
  List<Object?> get props => [guideId];
}
