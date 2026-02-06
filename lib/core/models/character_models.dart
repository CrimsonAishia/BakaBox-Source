import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';

part 'character_models.g.dart';

/// 角色分类
enum CharacterCategory {
  @JsonValue('touhou')
  touhou,
  @JsonValue('zombie')
  zombie,
  @JsonValue('normal')
  normal,
}

/// 获取途径类型
enum AcquisitionType {
  @JsonValue('gold')
  gold,
  @JsonValue('points')
  points,
  @JsonValue('custom')
  custom,
  @JsonValue('')
  unknown,
}

/// 子模型类型
enum SubModelType {
  @JsonValue('default')
  default_,
  @JsonValue('skin')
  skin,
  @JsonValue('seasonal')
  seasonal,
  @JsonValue('collab')
  collab,
  @JsonValue('special')
  special,
}

/// 符卡类型
enum SpellCardType {
  @JsonValue('normal')
  normal,
  @JsonValue('ultimate')
  ultimate,
  @JsonValue('passive')
  passive,
}

/// 符卡评级
enum SpellCardTier {
  @JsonValue('T0')
  t0,
  @JsonValue('T1')
  t1,
  @JsonValue('T2')
  t2,
  @JsonValue('T3')
  t3,
  @JsonValue('T4')
  t4,
  @JsonValue('T5')
  t5,
  @JsonValue('unranked')
  unranked,
}

/// 获取评级显示标签
extension SpellCardTierExtension on SpellCardTier {
  String get label => switch (this) {
    SpellCardTier.t0 => 'T0 - 最强',
    SpellCardTier.t1 => 'T1 - 强力',
    SpellCardTier.t2 => 'T2 - 优秀',
    SpellCardTier.t3 => 'T3 - 中等',
    SpellCardTier.t4 => 'T4 - 一般',
    SpellCardTier.t5 => 'T5 - 较弱',
    SpellCardTier.unranked => '未评级',
  };

  String get shortLabel => switch (this) {
    SpellCardTier.t0 => 'T0',
    SpellCardTier.t1 => 'T1',
    SpellCardTier.t2 => 'T2',
    SpellCardTier.t3 => 'T3',
    SpellCardTier.t4 => 'T4',
    SpellCardTier.t5 => 'T5',
    SpellCardTier.unranked => '未评',
  };
}

/// 僵尸技能类型
enum ZombieSkillType {
  @JsonValue('active')
  active,
  @JsonValue('passive')
  passive,
}

/// 预览图集
@JsonSerializable()
class CharacterPreviewImages extends Equatable {
  final String front;
  final String left;
  final String right;
  final String back;

  const CharacterPreviewImages({
    required this.front,
    required this.left,
    required this.right,
    required this.back,
  });

  factory CharacterPreviewImages.fromJson(Map<String, dynamic> json) =>
      _$CharacterPreviewImagesFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterPreviewImagesToJson(this);

  @override
  List<Object?> get props => [front, left, right, back];
}

/// 获取途径信息
@JsonSerializable()
class AcquisitionInfo extends Equatable {
  @JsonKey(unknownEnumValue: AcquisitionType.unknown)
  final AcquisitionType type;
  final int? cost;
  final String? customSource;

  const AcquisitionInfo({required this.type, this.cost, this.customSource});

  factory AcquisitionInfo.fromJson(Map<String, dynamic> json) =>
      _$AcquisitionInfoFromJson(json);
  Map<String, dynamic> toJson() => _$AcquisitionInfoToJson(this);

  @override
  List<Object?> get props => [type, cost, customSource];
}

/// 符卡
@JsonSerializable()
class SpellCard extends Equatable {
  final int id;
  final int? subModelId; // 所属子模型ID，空表示角色通用符卡
  final String name;
  final SpellCardType type;
  @JsonKey(unknownEnumValue: SpellCardTier.unranked)
  final SpellCardTier? tier; // 符卡评级
  final String description;
  final String? iconUrl;
  final String? videoUrl; // 演示视频URL（WebM格式）
  final double? cost; // 消耗资源（普通符卡消耗P点，终极符卡消耗B点）
  final double? cooldown;
  final String? damage;
  final List<String>? tips;

  const SpellCard({
    required this.id,
    this.subModelId,
    required this.name,
    required this.type,
    this.tier,
    required this.description,
    this.iconUrl,
    this.videoUrl,
    this.cost,
    this.cooldown,
    this.damage,
    this.tips,
  });

  factory SpellCard.fromJson(Map<String, dynamic> json) =>
      _$SpellCardFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardToJson(this);

  @override
  List<Object?> get props => [
    id,
    subModelId,
    name,
    type,
    tier,
    description,
    iconUrl,
    videoUrl,
    cost,
    cooldown,
    damage,
    tips,
  ];
}

/// 僵尸技能
@JsonSerializable()
class ZombieSkill extends Equatable {
  final int id;
  final String name;
  final ZombieSkillType type;
  final String description;
  final String? iconUrl;
  final String? videoUrl; // 演示视频URL（WebM格式）
  final double? cooldown;
  final String? damage;
  final String? range;
  final String? special;
  final List<String>? tips;

  const ZombieSkill({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.iconUrl,
    this.videoUrl,
    this.cooldown,
    this.damage,
    this.range,
    this.special,
    this.tips,
  });

  factory ZombieSkill.fromJson(Map<String, dynamic> json) =>
      _$ZombieSkillFromJson(json);
  Map<String, dynamic> toJson() => _$ZombieSkillToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    description,
    iconUrl,
    videoUrl,
    cooldown,
    damage,
    range,
    special,
    tips,
  ];
}

/// 子模型
@JsonSerializable()
class CharacterSubModel extends Equatable {
  final int id;
  final int? characterId; // 在角色详情的子模型列表中可能不返回
  final String name;
  final SubModelType type;
  final String? description;
  final String thumbnailUrl;
  final CharacterPreviewImages? preview;
  final String? glbModelUrl;
  final AcquisitionInfo? acquisition;
  @JsonKey(defaultValue: false)
  final bool isDefault;
  @JsonKey(defaultValue: 0)
  final int sortOrder;

  const CharacterSubModel({
    required this.id,
    this.characterId,
    required this.name,
    required this.type,
    this.description,
    required this.thumbnailUrl,
    this.preview,
    this.glbModelUrl,
    this.acquisition,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory CharacterSubModel.fromJson(Map<String, dynamic> json) =>
      _$CharacterSubModelFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterSubModelToJson(this);

  @override
  List<Object?> get props => [
    id,
    characterId,
    name,
    type,
    description,
    thumbnailUrl,
    preview,
    glbModelUrl,
    acquisition,
    isDefault,
    sortOrder,
  ];
}

/// 角色模型
@JsonSerializable()
class CharacterModel extends Equatable {
  final int id;
  final String name;
  final String? nameEn;
  final CharacterCategory category;
  final String description;
  final String thumbnailUrl;
  final CharacterPreviewImages? preview;
  final String? glbModelUrl;
  final AcquisitionInfo? acquisition;
  final List<CharacterSubModel>? subModels;
  final int? defaultSubModelId;
  final List<SpellCard>? spellCards;
  final List<ZombieSkill>? zombieSkills;
  @ServerTimeConverter()
  final DateTime createdAt;
  @JsonKey(defaultValue: 0)
  final int viewCount;
  @JsonKey(defaultValue: 0)
  final int contributorCount;

  const CharacterModel({
    required this.id,
    required this.name,
    this.nameEn,
    required this.category,
    required this.description,
    required this.thumbnailUrl,
    this.preview,
    this.glbModelUrl,
    this.acquisition,
    this.subModels,
    this.defaultSubModelId,
    this.spellCards,
    this.zombieSkills,
    required this.createdAt,
    this.viewCount = 0,
    this.contributorCount = 0,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) =>
      _$CharacterModelFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterModelToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    nameEn,
    category,
    description,
    thumbnailUrl,
    preview,
    glbModelUrl,
    acquisition,
    subModels,
    defaultSubModelId,
    spellCards,
    zombieSkills,
    createdAt,
    viewCount,
    contributorCount,
  ];
}

/// 角色列表项（简化版，用于列表展示）
@JsonSerializable()
class CharacterListItem extends Equatable {
  final int id;
  final String name;
  final String? nameEn;
  final CharacterCategory category;
  final String thumbnailUrl;
  final AcquisitionInfo? acquisition;
  final int viewCount;
  final bool hasSpellCards;
  final bool hasZombieSkills;
  final int subModelCount;

  const CharacterListItem({
    required this.id,
    required this.name,
    this.nameEn,
    required this.category,
    required this.thumbnailUrl,
    this.acquisition,
    required this.viewCount,
    required this.hasSpellCards,
    required this.hasZombieSkills,
    required this.subModelCount,
  });

  factory CharacterListItem.fromJson(Map<String, dynamic> json) =>
      _$CharacterListItemFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterListItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    name,
    nameEn,
    category,
    thumbnailUrl,
    acquisition,
    viewCount,
    hasSpellCards,
    hasZombieSkills,
    subModelCount,
  ];
}

/// 角色列表响应
@JsonSerializable()
class CharacterListResponse extends Equatable {
  final List<CharacterListItem> list;
  final int total;
  final int page;
  final int pageSize;

  const CharacterListResponse({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory CharacterListResponse.fromJson(Map<String, dynamic> json) =>
      _$CharacterListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterListResponseToJson(this);

  @override
  List<Object?> get props => [list, total, page, pageSize];
}

/// 创建符卡请求
@JsonSerializable()
class CreateSpellCardRequest extends Equatable {
  final int characterId;
  final int? subModelId; // 所属子模型ID，空表示角色通用符卡
  final String name;
  final SpellCardType type;
  final String description;
  final String? iconUrl;
  final double? cost; // 消耗资源（普通符卡消耗P点，终极符卡消耗B点）
  final double? cooldown;
  final String? damage;
  final List<String>? tips;

  const CreateSpellCardRequest({
    required this.characterId,
    this.subModelId,
    required this.name,
    required this.type,
    required this.description,
    this.iconUrl,
    this.cost,
    this.cooldown,
    this.damage,
    this.tips,
  });

  factory CreateSpellCardRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateSpellCardRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateSpellCardRequestToJson(this);

  @override
  List<Object?> get props => [
    characterId,
    subModelId,
    name,
    type,
    description,
    iconUrl,
    cost,
    cooldown,
    damage,
    tips,
  ];
}

/// 创建符卡响应
@JsonSerializable()
class CreateSpellCardResponse extends Equatable {
  final int id;

  const CreateSpellCardResponse({required this.id});

  factory CreateSpellCardResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateSpellCardResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreateSpellCardResponseToJson(this);

  @override
  List<Object?> get props => [id];
}

/// 创建僵尸技能请求
@JsonSerializable()
class CreateZombieSkillRequest extends Equatable {
  final int characterId;
  final String name;
  final ZombieSkillType type;
  final String description;
  final String? iconUrl;
  final double? cooldown;
  final String? damage;
  final String? range;
  final String? special;
  final List<String>? tips;

  const CreateZombieSkillRequest({
    required this.characterId,
    required this.name,
    required this.type,
    required this.description,
    this.iconUrl,
    this.cooldown,
    this.damage,
    this.range,
    this.special,
    this.tips,
  });

  factory CreateZombieSkillRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateZombieSkillRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateZombieSkillRequestToJson(this);

  @override
  List<Object?> get props => [
    characterId,
    name,
    type,
    description,
    iconUrl,
    cooldown,
    damage,
    range,
    special,
    tips,
  ];
}

/// 创建僵尸技能响应
@JsonSerializable()
class CreateZombieSkillResponse extends Equatable {
  final int id;

  const CreateZombieSkillResponse({required this.id});

  factory CreateZombieSkillResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateZombieSkillResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreateZombieSkillResponseToJson(this);

  @override
  List<Object?> get props => [id];
}

/// 编辑符卡请求
@JsonSerializable()
class EditSpellCardRequest extends Equatable {
  final int id;
  final String? description;
  final String? damage;
  final double? cost;
  final double? cooldown;
  final List<String>? tips;
  final String? editReason;

  const EditSpellCardRequest({
    required this.id,
    this.description,
    this.damage,
    this.cost,
    this.cooldown,
    this.tips,
    this.editReason,
  });

  factory EditSpellCardRequest.fromJson(Map<String, dynamic> json) =>
      _$EditSpellCardRequestFromJson(json);
  Map<String, dynamic> toJson() => _$EditSpellCardRequestToJson(this);

  @override
  List<Object?> get props => [
    id,
    description,
    damage,
    cost,
    cooldown,
    tips,
    editReason,
  ];
}

/// 编辑僵尸技能请求
@JsonSerializable()
class EditZombieSkillRequest extends Equatable {
  final int id;
  final String? description;
  final String? damage;
  final String? range;
  final double? cooldown;
  final String? special;
  final List<String>? tips;
  final String? editReason;

  const EditZombieSkillRequest({
    required this.id,
    this.description,
    this.damage,
    this.range,
    this.cooldown,
    this.special,
    this.tips,
    this.editReason,
  });

  factory EditZombieSkillRequest.fromJson(Map<String, dynamic> json) =>
      _$EditZombieSkillRequestFromJson(json);
  Map<String, dynamic> toJson() => _$EditZombieSkillRequestToJson(this);

  @override
  List<Object?> get props => [
    id,
    description,
    damage,
    range,
    cooldown,
    special,
    tips,
    editReason,
  ];
}

/// 编辑获取来源请求
@JsonSerializable()
class EditAcquisitionRequest extends Equatable {
  final AcquisitionType type;
  final int? cost;
  final String? customSource;
  final String editReason; // 必填

  const EditAcquisitionRequest({
    required this.type,
    this.cost,
    this.customSource,
    required this.editReason,
  });

  factory EditAcquisitionRequest.fromJson(Map<String, dynamic> json) =>
      _$EditAcquisitionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$EditAcquisitionRequestToJson(this);

  @override
  List<Object?> get props => [type, cost, customSource, editReason];
}

/// 编辑获取来源响应
@JsonSerializable()
class EditAcquisitionResponse extends Equatable {
  final int version;

  const EditAcquisitionResponse({required this.version});

  factory EditAcquisitionResponse.fromJson(Map<String, dynamic> json) =>
      _$EditAcquisitionResponseFromJson(json);
  Map<String, dynamic> toJson() => _$EditAcquisitionResponseToJson(this);

  @override
  List<Object?> get props => [version];
}

/// 编辑目标类型
enum EditTargetType {
  @JsonValue('sub_model')
  subModel,
  @JsonValue('spell_card')
  spellCard,
  @JsonValue('zombie_skill')
  zombieSkill,
}

/// 编辑历史项
@JsonSerializable()
class ContentEditHistoryItem extends Equatable {
  final int id;
  final int editorId;
  final String? editorName;
  final String? editorAvatar;
  final String fieldChanged;
  final String? oldValue;
  final String? newValue;
  final String? editReason;
  final String editedAt; // 服务器返回格式 "2026-02-01 15:30:00"
  final int version;

  const ContentEditHistoryItem({
    required this.id,
    required this.editorId,
    this.editorName,
    this.editorAvatar,
    required this.fieldChanged,
    this.oldValue,
    this.newValue,
    this.editReason,
    required this.editedAt,
    required this.version,
  });

  factory ContentEditHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$ContentEditHistoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$ContentEditHistoryItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    editorId,
    editorName,
    editorAvatar,
    fieldChanged,
    oldValue,
    newValue,
    editReason,
    editedAt,
    version,
  ];
}

/// 编辑历史响应
@JsonSerializable()
class ContentEditHistoryResponse extends Equatable {
  final List<ContentEditHistoryItem> list;
  final int total;
  final int page;
  final int pageSize;

  const ContentEditHistoryResponse({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory ContentEditHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$ContentEditHistoryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ContentEditHistoryResponseToJson(this);

  @override
  List<Object?> get props => [list, total, page, pageSize];
}

// ============ 统一编辑 API 相关模型 ============

/// 获取途径编辑数据
@JsonSerializable()
class AcquisitionEditData extends Equatable {
  final AcquisitionType type;
  final int? cost;
  final String? customSource;

  const AcquisitionEditData({required this.type, this.cost, this.customSource});

  factory AcquisitionEditData.fromJson(Map<String, dynamic> json) =>
      _$AcquisitionEditDataFromJson(json);
  Map<String, dynamic> toJson() => _$AcquisitionEditDataToJson(this);

  @override
  List<Object?> get props => [type, cost, customSource];
}

/// 符卡编辑项
@JsonSerializable()
class SpellCardEditItem extends Equatable {
  final int id;
  final String? description;
  final String? damage;
  final double? cost;
  final double? cooldown;
  final List<String>? tips;
  final int? videoFileId; // 演示视频文件ID
  final String? tier; // 评级 T0/T1/T2/T3/T4/T5/unranked

  const SpellCardEditItem({
    required this.id,
    this.description,
    this.damage,
    this.cost,
    this.cooldown,
    this.tips,
    this.videoFileId,
    this.tier,
  });

  factory SpellCardEditItem.fromJson(Map<String, dynamic> json) =>
      _$SpellCardEditItemFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardEditItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    description,
    damage,
    cost,
    cooldown,
    tips,
    videoFileId,
    tier,
  ];
}

/// 新增符卡项
@JsonSerializable()
class SpellCardCreateItem extends Equatable {
  final String name;
  final String type; // normal/ultimate/passive
  final String? tier; // 评级 T0/T1/T2/T3/T4/T5/unranked
  final String? description;
  final String? iconUrl;
  final int? videoFileId;
  final double? cost;
  final double? cooldown;
  final String? damage;
  final List<String>? tips;

  const SpellCardCreateItem({
    required this.name,
    required this.type,
    this.tier,
    this.description,
    this.iconUrl,
    this.videoFileId,
    this.cost,
    this.cooldown,
    this.damage,
    this.tips,
  });

  factory SpellCardCreateItem.fromJson(Map<String, dynamic> json) =>
      _$SpellCardCreateItemFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardCreateItemToJson(this);

  @override
  List<Object?> get props => [
    name,
    type,
    tier,
    description,
    iconUrl,
    videoFileId,
    cost,
    cooldown,
    damage,
    tips,
  ];
}

/// 符卡编辑数据
@JsonSerializable()
class SpellCardsEditData extends Equatable {
  final List<SpellCardCreateItem>? creates;
  final List<SpellCardEditItem>? updates;
  final List<int>? deletes;

  const SpellCardsEditData({this.creates, this.updates, this.deletes});

  factory SpellCardsEditData.fromJson(Map<String, dynamic> json) =>
      _$SpellCardsEditDataFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardsEditDataToJson(this);

  @override
  List<Object?> get props => [creates, updates, deletes];
}

/// 僵尸技能编辑项
@JsonSerializable()
class ZombieSkillEditItem extends Equatable {
  final int id;
  final String? description;
  final String? damage;
  final String? range;
  final double? cooldown;
  final String? special;
  final List<String>? tips;
  final int? videoFileId; // 演示视频文件ID

  const ZombieSkillEditItem({
    required this.id,
    this.description,
    this.damage,
    this.range,
    this.cooldown,
    this.special,
    this.tips,
    this.videoFileId,
  });

  factory ZombieSkillEditItem.fromJson(Map<String, dynamic> json) =>
      _$ZombieSkillEditItemFromJson(json);
  Map<String, dynamic> toJson() => _$ZombieSkillEditItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    description,
    damage,
    range,
    cooldown,
    special,
    tips,
    videoFileId,
  ];
}

/// 新增僵尸技能项
@JsonSerializable()
class ZombieSkillCreateItem extends Equatable {
  final String name;
  final String type; // active/passive
  final String? description;
  final String? iconUrl;
  final int? videoFileId;
  final double? cooldown;
  final String? damage;
  final String? range;
  final String? special;
  final List<String>? tips;

  const ZombieSkillCreateItem({
    required this.name,
    required this.type,
    this.description,
    this.iconUrl,
    this.videoFileId,
    this.cooldown,
    this.damage,
    this.range,
    this.special,
    this.tips,
  });

  factory ZombieSkillCreateItem.fromJson(Map<String, dynamic> json) =>
      _$ZombieSkillCreateItemFromJson(json);
  Map<String, dynamic> toJson() => _$ZombieSkillCreateItemToJson(this);

  @override
  List<Object?> get props => [
    name,
    type,
    description,
    iconUrl,
    videoFileId,
    cooldown,
    damage,
    range,
    special,
    tips,
  ];
}

/// 僵尸技能编辑数据
@JsonSerializable()
class ZombieSkillsEditData extends Equatable {
  final List<ZombieSkillCreateItem>? creates;
  final List<ZombieSkillEditItem>? updates;
  final List<int>? deletes;

  const ZombieSkillsEditData({this.creates, this.updates, this.deletes});

  factory ZombieSkillsEditData.fromJson(Map<String, dynamic> json) =>
      _$ZombieSkillsEditDataFromJson(json);
  Map<String, dynamic> toJson() => _$ZombieSkillsEditDataToJson(this);

  @override
  List<Object?> get props => [creates, updates, deletes];
}

/// 统一编辑子模型请求
@JsonSerializable()
class SubModelUnifiedEditRequest extends Equatable {
  final String editReason;
  final String? description;
  final AcquisitionEditData? acquisition;
  final SpellCardsEditData? spellCards;
  final ZombieSkillsEditData? zombieSkills;

  const SubModelUnifiedEditRequest({
    required this.editReason,
    this.description,
    this.acquisition,
    this.spellCards,
    this.zombieSkills,
  });

  factory SubModelUnifiedEditRequest.fromJson(Map<String, dynamic> json) =>
      _$SubModelUnifiedEditRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SubModelUnifiedEditRequestToJson(this);

  @override
  List<Object?> get props => [
    editReason,
    description,
    acquisition,
    spellCards,
    zombieSkills,
  ];
}

/// 统一编辑子模型响应
@JsonSerializable()
class SubModelUnifiedEditResponse extends Equatable {
  final int subModelVersion;
  final List<String> editedFields;

  const SubModelUnifiedEditResponse({
    required this.subModelVersion,
    required this.editedFields,
  });

  factory SubModelUnifiedEditResponse.fromJson(Map<String, dynamic> json) =>
      _$SubModelUnifiedEditResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SubModelUnifiedEditResponseToJson(this);

  @override
  List<Object?> get props => [subModelVersion, editedFields];
}

/// 审核状态
enum AuditStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

/// 我的编辑申请项
@JsonSerializable()
class MyEditRequestItem extends Equatable {
  final int id;
  final int characterId;
  final String characterName;
  final int subModelId;
  final String subModelName;
  final int userId;
  final String? userName;
  final String editReason;
  final String editData;
  final AuditStatus auditStatus;
  final String? auditRemark;
  final String? auditAt;
  final String createdAt;

  const MyEditRequestItem({
    required this.id,
    required this.characterId,
    required this.characterName,
    required this.subModelId,
    required this.subModelName,
    required this.userId,
    this.userName,
    required this.editReason,
    required this.editData,
    required this.auditStatus,
    this.auditRemark,
    this.auditAt,
    required this.createdAt,
  });

  factory MyEditRequestItem.fromJson(Map<String, dynamic> json) =>
      _$MyEditRequestItemFromJson(json);
  Map<String, dynamic> toJson() => _$MyEditRequestItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    characterId,
    characterName,
    subModelId,
    subModelName,
    userId,
    userName,
    editReason,
    editData,
    auditStatus,
    auditRemark,
    auditAt,
    createdAt,
  ];
}

/// 我的编辑申请列表响应
@JsonSerializable()
class MyEditRequestListResponse extends Equatable {
  final List<MyEditRequestItem> items;
  final int total;

  const MyEditRequestListResponse({required this.items, required this.total});

  factory MyEditRequestListResponse.fromJson(Map<String, dynamic> json) =>
      _$MyEditRequestListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MyEditRequestListResponseToJson(this);

  @override
  List<Object?> get props => [items, total];
}

// ============ 统一编辑历史 API 相关模型 ============

/// 统一编辑历史项（按子模型聚合）
@JsonSerializable()
class UnifiedEditHistoryItem extends Equatable {
  final int id;
  final EditTargetType targetType;
  final int targetId;
  final String? targetName; // 符卡/技能名称
  final String?
  spellCardType; // 符卡类型（仅targetType为spell_card时有值）：normal/ultimate/passive
  final String?
  zombieSkillType; // 僵尸技能类型（仅targetType为zombie_skill时有值）：active/passive
  final int editorId;
  final String? editorName;
  final String? editorAvatar;
  final String fieldChanged;
  final String? oldValue;
  final String? newValue;
  final String? editReason;
  final String editedAt;
  final int version;

  const UnifiedEditHistoryItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.spellCardType,
    this.zombieSkillType,
    required this.editorId,
    this.editorName,
    this.editorAvatar,
    required this.fieldChanged,
    this.oldValue,
    this.newValue,
    this.editReason,
    required this.editedAt,
    required this.version,
  });

  factory UnifiedEditHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$UnifiedEditHistoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$UnifiedEditHistoryItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    targetType,
    targetId,
    targetName,
    spellCardType,
    zombieSkillType,
    editorId,
    editorName,
    editorAvatar,
    fieldChanged,
    oldValue,
    newValue,
    editReason,
    editedAt,
    version,
  ];
}

/// 统一编辑历史响应
@JsonSerializable()
class UnifiedEditHistoryResponse extends Equatable {
  final List<UnifiedEditHistoryItem> list;
  final int total;

  const UnifiedEditHistoryResponse({required this.list, required this.total});

  factory UnifiedEditHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$UnifiedEditHistoryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UnifiedEditHistoryResponseToJson(this);

  @override
  List<Object?> get props => [list, total];
}

// ============ 编辑申请管理 API 相关模型 ============

/// 待审核状态查询响应
@JsonSerializable()
class PendingRequestCheckResponse extends Equatable {
  final bool hasPending;
  final int? requestId;

  const PendingRequestCheckResponse({required this.hasPending, this.requestId});

  factory PendingRequestCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$PendingRequestCheckResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PendingRequestCheckResponseToJson(this);

  @override
  List<Object?> get props => [hasPending, requestId];
}

/// 编辑申请操作响应（修改/删除）
@JsonSerializable()
class EditRequestOperationResponse extends Equatable {
  final bool success;

  const EditRequestOperationResponse({required this.success});

  factory EditRequestOperationResponse.fromJson(Map<String, dynamic> json) =>
      _$EditRequestOperationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$EditRequestOperationResponseToJson(this);

  @override
  List<Object?> get props => [success];
}

/// 编辑申请详情响应
@JsonSerializable()
class EditRequestDetailResponse extends Equatable {
  final int id;
  final int characterId;
  final String characterName;
  final int subModelId;
  final String subModelName;
  final String editReason;
  final String editData; // JSON 字符串，包含编辑内容
  final AuditStatus auditStatus;
  final String? auditRemark;
  final String? auditAt;
  final String createdAt;

  const EditRequestDetailResponse({
    required this.id,
    required this.characterId,
    required this.characterName,
    required this.subModelId,
    required this.subModelName,
    required this.editReason,
    required this.editData,
    required this.auditStatus,
    this.auditRemark,
    this.auditAt,
    required this.createdAt,
  });

  factory EditRequestDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$EditRequestDetailResponseFromJson(json);
  Map<String, dynamic> toJson() => _$EditRequestDetailResponseToJson(this);

  /// 解析 editData JSON 字符串为结构化数据
  EditRequestParsedData? get parsedEditData {
    try {
      final Map<String, dynamic> json = Map<String, dynamic>.from(
        jsonDecode(editData) as Map,
      );
      return EditRequestParsedData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    id,
    characterId,
    characterName,
    subModelId,
    subModelName,
    editReason,
    editData,
    auditStatus,
    auditRemark,
    auditAt,
    createdAt,
  ];
}

/// 编辑申请解析后的数据
@JsonSerializable()
class EditRequestParsedData extends Equatable {
  final String? description;
  final AcquisitionEditData? acquisition;
  final SpellCardsEditData? spellCards;
  final ZombieSkillsEditData? zombieSkills;

  const EditRequestParsedData({
    this.description,
    this.acquisition,
    this.spellCards,
    this.zombieSkills,
  });

  factory EditRequestParsedData.fromJson(Map<String, dynamic> json) =>
      _$EditRequestParsedDataFromJson(json);
  Map<String, dynamic> toJson() => _$EditRequestParsedDataToJson(this);

  @override
  List<Object?> get props => [
    description,
    acquisition,
    spellCards,
    zombieSkills,
  ];
}

// ============ 符卡评级列表 API 相关模型 ============

/// 符卡评级列表项（包含角色信息）
@JsonSerializable()
class SpellCardTierItem extends Equatable {
  final int id;
  final int characterId;
  final String characterName;
  final int? subModelId;
  final String name;
  final SpellCardType type;
  @JsonKey(unknownEnumValue: SpellCardTier.unranked)
  final SpellCardTier tier;
  final String? description;
  final String? iconUrl;
  final int? cost;
  final int? cooldown;
  final String? damage;

  const SpellCardTierItem({
    required this.id,
    required this.characterId,
    required this.characterName,
    this.subModelId,
    required this.name,
    required this.type,
    required this.tier,
    this.description,
    this.iconUrl,
    this.cost,
    this.cooldown,
    this.damage,
  });

  factory SpellCardTierItem.fromJson(Map<String, dynamic> json) =>
      _$SpellCardTierItemFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardTierItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    characterId,
    characterName,
    subModelId,
    name,
    type,
    tier,
    description,
    iconUrl,
    cost,
    cooldown,
    damage,
  ];
}

/// 符卡评级分组
@JsonSerializable()
class SpellCardTierGroup extends Equatable {
  final String tier;
  final String tierLabel;
  final List<SpellCardTierItem> spellCards;
  final int count;

  const SpellCardTierGroup({
    required this.tier,
    required this.tierLabel,
    required this.spellCards,
    required this.count,
  });

  factory SpellCardTierGroup.fromJson(Map<String, dynamic> json) =>
      _$SpellCardTierGroupFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardTierGroupToJson(this);

  @override
  List<Object?> get props => [tier, tierLabel, spellCards, count];
}

/// 符卡评级列表响应
@JsonSerializable()
class SpellCardTierListResponse extends Equatable {
  final List<SpellCardTierGroup> tiers;
  final int totalCount;

  const SpellCardTierListResponse({
    required this.tiers,
    required this.totalCount,
  });

  factory SpellCardTierListResponse.fromJson(Map<String, dynamic> json) =>
      _$SpellCardTierListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SpellCardTierListResponseToJson(this);

  @override
  List<Object?> get props => [tiers, totalCount];
}
