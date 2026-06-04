import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';
import '../../models/map_contribution_models.dart';

abstract class GuideEditorEvent extends Equatable {
  const GuideEditorEvent();
  @override
  List<Object?> get props => [];
}

/// 从草稿初始化编辑器
class InitFromDraft extends GuideEditorEvent {
  final String? draftId;
  const InitFromDraft({this.draftId});
  @override
  List<Object?> get props => [draftId];
}

/// 从服务端已有攻略初始化编辑器（编辑模式）
class InitFromServer extends GuideEditorEvent {
  final int? guideId;
  const InitFromServer({this.guideId});
  @override
  List<Object?> get props => [guideId];
}

/// 更新标题
class UpdateTitle extends GuideEditorEvent {
  final String title;
  const UpdateTitle(this.title);
  @override
  List<Object?> get props => [title];
}

/// 更新封面
class UpdateCover extends GuideEditorEvent {
  final String? coverUrl;
  const UpdateCover(this.coverUrl);
  @override
  List<Object?> get props => [coverUrl];
}

/// 更新摘要
class UpdateSummary extends GuideEditorEvent {
  final String? summary;
  const UpdateSummary(this.summary);
  @override
  List<Object?> get props => [summary];
}

/// 更新正文内容（防抖 3s 后自动触发本地保存）
class UpdateContent extends GuideEditorEvent {
  final String content;
  final int plainTextLength;
  const UpdateContent(this.content, {this.plainTextLength = 0});
  @override
  List<Object?> get props => [content, plainTextLength];
}

/// 更新分类
class UpdateCategory extends GuideEditorEvent {
  final String code;
  const UpdateCategory(this.code);
  @override
  List<Object?> get props => [code];
}

/// 更新标签
class UpdateTags extends GuideEditorEvent {
  final List<String> tags;
  const UpdateTags(this.tags);
  @override
  List<Object?> get props => [tags];
}

/// 更新关联地图
class UpdateMap extends GuideEditorEvent {
  final MapInfo? mapInfo;
  const UpdateMap(this.mapInfo);
  @override
  List<Object?> get props => [mapInfo];
}

/// 插入 B 站视频嵌入
class InsertBilibiliEmbed extends GuideEditorEvent {
  final VideoEmbed videoEmbed;
  const InsertBilibiliEmbed(this.videoEmbed);
  @override
  List<Object?> get props => [videoEmbed];
}

/// 保存草稿请求
///
/// [manual] 为 true 时表示用户手动点击保存按钮
class SaveDraftRequested extends GuideEditorEvent {
  final bool manual;
  const SaveDraftRequested({this.manual = false});
  @override
  List<Object?> get props => [manual];
}

/// 发布请求（触发校验 → 发布）
class PublishRequested extends GuideEditorEvent {
  const PublishRequested();
}

/// 离开编辑器请求（检查未保存内容）
class LeaveRequested extends GuideEditorEvent {
  const LeaveRequested();
}

/// 解决草稿冲突
///
/// [useRemote] 为 true 时使用云端版本覆盖本地；
/// 为 false 时强制以本地版本覆盖云端。
class ResolveDraftConflict extends GuideEditorEvent {
  final bool useRemote;
  const ResolveDraftConflict({required this.useRemote});
  @override
  List<Object?> get props => [useRemote];
}
