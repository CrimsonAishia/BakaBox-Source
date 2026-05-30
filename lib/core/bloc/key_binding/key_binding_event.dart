import 'package:equatable/equatable.dart';
import '../../models/key_config_models.dart';

/// 按键绑定事件基类
abstract class KeyBindingEvent extends Equatable {
  const KeyBindingEvent();
  @override
  List<Object?> get props => [];
}

/// 加载配置列表
class KeyBindingLoadConfigs extends KeyBindingEvent {
  final bool showSuccessMessage;
  const KeyBindingLoadConfigs({this.showSuccessMessage = false});
  @override
  List<Object?> get props => [showSuccessMessage];
}

/// 加载分类列表
class KeyBindingLoadCategories extends KeyBindingEvent {}

/// 选择配置
class KeyBindingSelectConfig extends KeyBindingEvent {
  final KeyConfig config;
  const KeyBindingSelectConfig(this.config);
  @override
  List<Object?> get props => [config];
}

/// 清除选中的配置
class KeyBindingClearSelection extends KeyBindingEvent {}

/// 设置按键绑定
class KeyBindingSetKeyBinding extends KeyBindingEvent {
  final String label;
  final String key;
  const KeyBindingSetKeyBinding({required this.label, required this.key});
  @override
  List<Object?> get props => [label, key];
}

/// 清除按键绑定
class KeyBindingClearKeyBinding extends KeyBindingEvent {
  final String label;
  const KeyBindingClearKeyBinding(this.label);
  @override
  List<Object?> get props => [label];
}

/// 清除所有按键绑定
class KeyBindingClearAllKeyBindings extends KeyBindingEvent {}

/// 应用配置到 autoexec.cfg
class KeyBindingApplyConfig extends KeyBindingEvent {
  final KeyConfig config;
  final Map<String, String> keyBindings;
  const KeyBindingApplyConfig({
    required this.config,
    required this.keyBindings,
  });
  @override
  List<Object?> get props => [config, keyBindings];
}

/// 移除已应用的配置
class KeyBindingRemoveAppliedConfig extends KeyBindingEvent {
  final String configId;
  const KeyBindingRemoveAppliedConfig(this.configId);
  @override
  List<Object?> get props => [configId];
}

/// 加载 autoexec.cfg 内容
class KeyBindingLoadAutoexecContent extends KeyBindingEvent {}

/// 保存 autoexec.cfg 内容
class KeyBindingSaveAutoexecContent extends KeyBindingEvent {
  final String content;
  const KeyBindingSaveAutoexecContent(this.content);
  @override
  List<Object?> get props => [content];
}

/// 创建 autoexec.cfg 文件
class KeyBindingCreateAutoexecFile extends KeyBindingEvent {}

/// 发布配置
class KeyBindingPublishConfig extends KeyBindingEvent {
  final KeyConfigCreateRequest request;
  const KeyBindingPublishConfig(this.request);
  @override
  List<Object?> get props => [request];
}

/// 删除配置
class KeyBindingDeleteConfig extends KeyBindingEvent {
  final int id;
  final String? editReason;
  const KeyBindingDeleteConfig(this.id, {this.editReason});
  @override
  List<Object?> get props => [id, editReason];
}

/// 更新配置
class KeyBindingUpdateConfig extends KeyBindingEvent {
  final int id;
  final KeyConfigCreateRequest request;
  final String? editReason;
  const KeyBindingUpdateConfig({
    required this.id,
    required this.request,
    this.editReason,
  });
  @override
  List<Object?> get props => [id, request, editReason];
}

/// 设置分类筛选
class KeyBindingSetCategoryFilter extends KeyBindingEvent {
  final int? categoryId;
  const KeyBindingSetCategoryFilter(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

/// 设置搜索关键词
class KeyBindingSetSearchKeyword extends KeyBindingEvent {
  final String? keyword;
  const KeyBindingSetSearchKeyword(this.keyword);
  @override
  List<Object?> get props => [keyword];
}

/// 设置是否显示用户自己的配置
class KeyBindingSetShowMyConfigs extends KeyBindingEvent {
  final bool showMyConfigs;
  const KeyBindingSetShowMyConfigs(this.showMyConfigs);
  @override
  List<Object?> get props => [showMyConfigs];
}

/// 在文件管理器中打开 autoexec.cfg 目录
class KeyBindingOpenInExplorer extends KeyBindingEvent {}

/// 复制 autoexec.cfg 内容到剪贴板
class KeyBindingCopyAutoexecContent extends KeyBindingEvent {}

/// 清除消息（成功/错误）
class KeyBindingClearMessages extends KeyBindingEvent {}

/// 加载用户自己的配置列表
class KeyBindingLoadMyConfigs extends KeyBindingEvent {
  final bool showSuccessMessage;
  const KeyBindingLoadMyConfigs({this.showSuccessMessage = false});
  @override
  List<Object?> get props => [showSuccessMessage];
}

/// 投票
class KeyBindingVote extends KeyBindingEvent {
  final int configId;
  final KeyConfigVoteType voteType;
  const KeyBindingVote({required this.configId, required this.voteType});
  @override
  List<Object?> get props => [configId, voteType];
}

/// 加载评论列表
class KeyBindingLoadComments extends KeyBindingEvent {
  final int configId;
  final int page;
  const KeyBindingLoadComments({required this.configId, this.page = 1});
  @override
  List<Object?> get props => [configId, page];
}

/// 发表评论
class KeyBindingAddComment extends KeyBindingEvent {
  final int configId;
  final String content;
  final List<String>? images;
  final int? replyToId;
  const KeyBindingAddComment({
    required this.configId,
    required this.content,
    this.images,
    this.replyToId,
  });
  @override
  List<Object?> get props => [configId, content, images, replyToId];
}

/// 清除评论列表
class KeyBindingClearComments extends KeyBindingEvent {}

/// 加载我的变更申请列表
class KeyBindingLoadChangeRequests extends KeyBindingEvent {
  final bool showSuccessMessage;
  const KeyBindingLoadChangeRequests({this.showSuccessMessage = false});
  @override
  List<Object?> get props => [showSuccessMessage];
}

/// 撤销变更申请
class KeyBindingCancelChangeRequest extends KeyBindingEvent {
  final int configId;
  const KeyBindingCancelChangeRequest(this.configId);
  @override
  List<Object?> get props => [configId];
}
