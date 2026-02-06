import 'package:equatable/equatable.dart';
import '../../models/character_models.dart';

abstract class CharacterGalleryEvent extends Equatable {
  const CharacterGalleryEvent();
  @override
  List<Object?> get props => [];
}

/// 加载角色列表
class LoadCharacters extends CharacterGalleryEvent {
  final CharacterCategory? category;
  final String? keyword;
  final int page;
  final String? orderBy;

  const LoadCharacters({
    this.category,
    this.keyword,
    this.page = 1,
    this.orderBy,
  });

  @override
  List<Object?> get props => [category, keyword, page, orderBy];
}

/// 加载更多角色
class LoadMoreCharacters extends CharacterGalleryEvent {}

/// 加载角色详情
class LoadCharacterDetail extends CharacterGalleryEvent {
  final int characterId;

  const LoadCharacterDetail(this.characterId);

  @override
  List<Object?> get props => [characterId];
}

/// 选择子模型
class SelectSubModel extends CharacterGalleryEvent {
  final int subModelId;

  const SelectSubModel(this.subModelId);

  @override
  List<Object?> get props => [subModelId];
}

/// 切换预览图位置
class ChangePreviewPosition extends CharacterGalleryEvent {
  final int position; // 0=front, 1=left, 2=right, 3=back

  const ChangePreviewPosition(this.position);

  @override
  List<Object?> get props => [position];
}

/// 切换分类筛选
class ChangeCategory extends CharacterGalleryEvent {
  final CharacterCategory? category;

  const ChangeCategory(this.category);

  @override
  List<Object?> get props => [category];
}

/// 搜索角色
class SearchCharacters extends CharacterGalleryEvent {
  final String keyword;

  const SearchCharacters(this.keyword);

  @override
  List<Object?> get props => [keyword];
}

/// 清除选中的角色
class ClearSelectedCharacter extends CharacterGalleryEvent {}

/// 加载符卡列表
class LoadSpellCards extends CharacterGalleryEvent {
  final int characterId;
  final int subModelId;

  const LoadSpellCards({required this.characterId, required this.subModelId});

  @override
  List<Object?> get props => [characterId, subModelId];
}

/// 统一编辑子模型（提交审核）
/// 所有编辑都通过此事件提交，包括：描述、获取来源、符卡、僵尸技能
class SubmitUnifiedEdit extends CharacterGalleryEvent {
  final int characterId;
  final int subModelId;
  final String editReason;
  final String? description;
  final AcquisitionEditData? acquisition;
  final List<SpellCardCreateItem>? spellCardCreates;
  final List<SpellCardEditItem>? spellCardUpdates;
  final List<int>? spellCardDeletes;
  final List<ZombieSkillCreateItem>? zombieSkillCreates;
  final List<ZombieSkillEditItem>? zombieSkillUpdates;
  final List<int>? zombieSkillDeletes;
  final PreviewImagesEditData? previewImages;

  const SubmitUnifiedEdit({
    required this.characterId,
    required this.subModelId,
    required this.editReason,
    this.description,
    this.acquisition,
    this.spellCardCreates,
    this.spellCardUpdates,
    this.spellCardDeletes,
    this.zombieSkillCreates,
    this.zombieSkillUpdates,
    this.zombieSkillDeletes,
    this.previewImages,
  });

  @override
  List<Object?> get props => [
    characterId,
    subModelId,
    editReason,
    description,
    acquisition,
    spellCardCreates,
    spellCardUpdates,
    spellCardDeletes,
    zombieSkillCreates,
    zombieSkillUpdates,
    zombieSkillDeletes,
    previewImages,
  ];
}

/// 加载我的编辑申请列表
class LoadMyEditRequests extends CharacterGalleryEvent {
  final int pageIndex;
  final int pageSize;

  const LoadMyEditRequests({this.pageIndex = 1, this.pageSize = 20});

  @override
  List<Object?> get props => [pageIndex, pageSize];
}

/// 检查待审核状态
class CheckPendingRequest extends CharacterGalleryEvent {
  final int subModelId;

  const CheckPendingRequest(this.subModelId);

  @override
  List<Object?> get props => [subModelId];
}

/// 删除编辑申请
class DeleteEditRequest extends CharacterGalleryEvent {
  final int requestId;

  const DeleteEditRequest(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

/// 清除待审核状态
class ClearPendingRequest extends CharacterGalleryEvent {}

/// 修改编辑申请
class UpdateEditRequest extends CharacterGalleryEvent {
  final int requestId;
  final String editReason;
  final String? description;
  final AcquisitionEditData? acquisition;
  final List<SpellCardCreateItem>? spellCardCreates;
  final List<SpellCardEditItem>? spellCardUpdates;
  final List<int>? spellCardDeletes;
  final List<ZombieSkillCreateItem>? zombieSkillCreates;
  final List<ZombieSkillEditItem>? zombieSkillUpdates;
  final List<int>? zombieSkillDeletes;
  final PreviewImagesEditData? previewImages;

  const UpdateEditRequest({
    required this.requestId,
    required this.editReason,
    this.description,
    this.acquisition,
    this.spellCardCreates,
    this.spellCardUpdates,
    this.spellCardDeletes,
    this.zombieSkillCreates,
    this.zombieSkillUpdates,
    this.zombieSkillDeletes,
    this.previewImages,
  });

  @override
  List<Object?> get props => [
    requestId,
    editReason,
    description,
    acquisition,
    spellCardCreates,
    spellCardUpdates,
    spellCardDeletes,
    zombieSkillCreates,
    zombieSkillUpdates,
    zombieSkillDeletes,
    previewImages,
  ];
}

/// 加载符卡评级列表
class LoadSpellCardTierList extends CharacterGalleryEvent {
  final SpellCardType? type; // 可选，筛选符卡类型
  final String? keyword; // 可选，搜索关键词

  const LoadSpellCardTierList({this.type, this.keyword});

  @override
  List<Object?> get props => [type, keyword];
}

/// 从符卡评级列表跳转到角色详情
class NavigateToCharacterFromSpellCard extends CharacterGalleryEvent {
  final int spellCardId;
  final int characterId;
  final int? subModelId;

  const NavigateToCharacterFromSpellCard({
    required this.spellCardId,
    required this.characterId,
    this.subModelId,
  });

  @override
  List<Object?> get props => [spellCardId, characterId, subModelId];
}

/// 切换评级展开/折叠状态
class ToggleTierExpanded extends CharacterGalleryEvent {
  final String tier;

  const ToggleTierExpanded(this.tier);

  @override
  List<Object?> get props => [tier];
}
