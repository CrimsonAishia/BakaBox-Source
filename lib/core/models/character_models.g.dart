// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterPreviewImages _$CharacterPreviewImagesFromJson(
  Map<String, dynamic> json,
) => CharacterPreviewImages(
  front: json['front'] as String,
  left: json['left'] as String,
  right: json['right'] as String,
  back: json['back'] as String,
  hand: json['hand'] as String? ?? '',
  leg: json['leg'] as String? ?? '',
);

Map<String, dynamic> _$CharacterPreviewImagesToJson(
  CharacterPreviewImages instance,
) => <String, dynamic>{
  'front': instance.front,
  'left': instance.left,
  'right': instance.right,
  'back': instance.back,
  'hand': instance.hand,
  'leg': instance.leg,
};

AcquisitionInfo _$AcquisitionInfoFromJson(Map<String, dynamic> json) =>
    AcquisitionInfo(
      type: $enumDecode(
        _$AcquisitionTypeEnumMap,
        json['type'],
        unknownValue: AcquisitionType.unknown,
      ),
      cost: (json['cost'] as num?)?.toInt(),
      customSource: json['customSource'] as String?,
    );

Map<String, dynamic> _$AcquisitionInfoToJson(AcquisitionInfo instance) =>
    <String, dynamic>{
      'type': _$AcquisitionTypeEnumMap[instance.type]!,
      'cost': instance.cost,
      'customSource': instance.customSource,
    };

const _$AcquisitionTypeEnumMap = {
  AcquisitionType.gold: 'gold',
  AcquisitionType.points: 'points',
  AcquisitionType.custom: 'custom',
  AcquisitionType.unknown: '',
};

SpellCard _$SpellCardFromJson(Map<String, dynamic> json) => SpellCard(
  id: (json['id'] as num).toInt(),
  subModelId: (json['subModelId'] as num?)?.toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$SpellCardTypeEnumMap, json['type']),
  tier: $enumDecodeNullable(
    _$SpellCardTierEnumMap,
    json['tier'],
    unknownValue: SpellCardTier.unranked,
  ),
  description: json['description'] as String,
  iconUrl: json['iconUrl'] as String?,
  videoUrl: json['videoUrl'] as String?,
  cost: (json['cost'] as num?)?.toDouble(),
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  damage: json['damage'] as String?,
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$SpellCardToJson(SpellCard instance) => <String, dynamic>{
  'id': instance.id,
  'subModelId': instance.subModelId,
  'name': instance.name,
  'type': _$SpellCardTypeEnumMap[instance.type]!,
  'tier': _$SpellCardTierEnumMap[instance.tier],
  'description': instance.description,
  'iconUrl': instance.iconUrl,
  'videoUrl': instance.videoUrl,
  'cost': instance.cost,
  'cooldown': instance.cooldown,
  'damage': instance.damage,
  'tips': instance.tips,
};

const _$SpellCardTypeEnumMap = {
  SpellCardType.normal: 'normal',
  SpellCardType.ultimate: 'ultimate',
  SpellCardType.passive: 'passive',
};

const _$SpellCardTierEnumMap = {
  SpellCardTier.t0: 'T0',
  SpellCardTier.t1: 'T1',
  SpellCardTier.t2: 'T2',
  SpellCardTier.t3: 'T3',
  SpellCardTier.t4: 'T4',
  SpellCardTier.t5: 'T5',
  SpellCardTier.unranked: 'unranked',
};

ZombieSkill _$ZombieSkillFromJson(Map<String, dynamic> json) => ZombieSkill(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$ZombieSkillTypeEnumMap, json['type']),
  description: json['description'] as String,
  iconUrl: json['iconUrl'] as String?,
  videoUrl: json['videoUrl'] as String?,
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  damage: json['damage'] as String?,
  range: json['range'] as String?,
  special: json['special'] as String?,
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ZombieSkillToJson(ZombieSkill instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$ZombieSkillTypeEnumMap[instance.type]!,
      'description': instance.description,
      'iconUrl': instance.iconUrl,
      'videoUrl': instance.videoUrl,
      'cooldown': instance.cooldown,
      'damage': instance.damage,
      'range': instance.range,
      'special': instance.special,
      'tips': instance.tips,
    };

const _$ZombieSkillTypeEnumMap = {
  ZombieSkillType.active: 'active',
  ZombieSkillType.passive: 'passive',
};

CharacterSubModel _$CharacterSubModelFromJson(Map<String, dynamic> json) =>
    CharacterSubModel(
      id: (json['id'] as num).toInt(),
      characterId: (json['characterId'] as num?)?.toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$SubModelTypeEnumMap, json['type']),
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String,
      preview: json['preview'] == null
          ? null
          : CharacterPreviewImages.fromJson(
              json['preview'] as Map<String, dynamic>,
            ),
      glbModelUrl: json['glbModelUrl'] as String?,
      acquisition: json['acquisition'] == null
          ? null
          : AcquisitionInfo.fromJson(
              json['acquisition'] as Map<String, dynamic>,
            ),
      isDefault: json['isDefault'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CharacterSubModelToJson(CharacterSubModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'characterId': instance.characterId,
      'name': instance.name,
      'type': _$SubModelTypeEnumMap[instance.type]!,
      'description': instance.description,
      'thumbnailUrl': instance.thumbnailUrl,
      'preview': instance.preview,
      'glbModelUrl': instance.glbModelUrl,
      'acquisition': instance.acquisition,
      'isDefault': instance.isDefault,
      'sortOrder': instance.sortOrder,
    };

const _$SubModelTypeEnumMap = {
  SubModelType.default_: 'default',
  SubModelType.skin: 'skin',
  SubModelType.seasonal: 'seasonal',
  SubModelType.collab: 'collab',
  SubModelType.special: 'special',
};

CharacterModel _$CharacterModelFromJson(
  Map<String, dynamic> json,
) => CharacterModel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  nameEn: json['nameEn'] as String?,
  category: $enumDecode(_$CharacterCategoryEnumMap, json['category']),
  description: json['description'] as String,
  thumbnailUrl: json['thumbnailUrl'] as String,
  preview: json['preview'] == null
      ? null
      : CharacterPreviewImages.fromJson(
          json['preview'] as Map<String, dynamic>,
        ),
  glbModelUrl: json['glbModelUrl'] as String?,
  acquisition: json['acquisition'] == null
      ? null
      : AcquisitionInfo.fromJson(json['acquisition'] as Map<String, dynamic>),
  subModels: (json['subModels'] as List<dynamic>?)
      ?.map((e) => CharacterSubModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  defaultSubModelId: (json['defaultSubModelId'] as num?)?.toInt(),
  spellCards: (json['spellCards'] as List<dynamic>?)
      ?.map((e) => SpellCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  zombieSkills: (json['zombieSkills'] as List<dynamic>?)
      ?.map((e) => ZombieSkill.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  contributorCount: (json['contributorCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CharacterModelToJson(CharacterModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameEn': instance.nameEn,
      'category': _$CharacterCategoryEnumMap[instance.category]!,
      'description': instance.description,
      'thumbnailUrl': instance.thumbnailUrl,
      'preview': instance.preview,
      'glbModelUrl': instance.glbModelUrl,
      'acquisition': instance.acquisition,
      'subModels': instance.subModels,
      'defaultSubModelId': instance.defaultSubModelId,
      'spellCards': instance.spellCards,
      'zombieSkills': instance.zombieSkills,
      'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
      'viewCount': instance.viewCount,
      'contributorCount': instance.contributorCount,
    };

const _$CharacterCategoryEnumMap = {
  CharacterCategory.touhou: 'touhou',
  CharacterCategory.zombie: 'zombie',
  CharacterCategory.normal: 'normal',
};

CharacterListItem _$CharacterListItemFromJson(Map<String, dynamic> json) =>
    CharacterListItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      nameEn: json['nameEn'] as String?,
      category: $enumDecode(_$CharacterCategoryEnumMap, json['category']),
      thumbnailUrl: json['thumbnailUrl'] as String,
      acquisition: json['acquisition'] == null
          ? null
          : AcquisitionInfo.fromJson(
              json['acquisition'] as Map<String, dynamic>,
            ),
      viewCount: (json['viewCount'] as num).toInt(),
      hasSpellCards: json['hasSpellCards'] as bool,
      hasZombieSkills: json['hasZombieSkills'] as bool,
      subModelCount: (json['subModelCount'] as num).toInt(),
    );

Map<String, dynamic> _$CharacterListItemToJson(CharacterListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameEn': instance.nameEn,
      'category': _$CharacterCategoryEnumMap[instance.category]!,
      'thumbnailUrl': instance.thumbnailUrl,
      'acquisition': instance.acquisition,
      'viewCount': instance.viewCount,
      'hasSpellCards': instance.hasSpellCards,
      'hasZombieSkills': instance.hasZombieSkills,
      'subModelCount': instance.subModelCount,
    };

CharacterListResponse _$CharacterListResponseFromJson(
  Map<String, dynamic> json,
) => CharacterListResponse(
  list: (json['list'] as List<dynamic>)
      .map((e) => CharacterListItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
);

Map<String, dynamic> _$CharacterListResponseToJson(
  CharacterListResponse instance,
) => <String, dynamic>{
  'list': instance.list,
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

CreateSpellCardRequest _$CreateSpellCardRequestFromJson(
  Map<String, dynamic> json,
) => CreateSpellCardRequest(
  characterId: (json['characterId'] as num).toInt(),
  subModelId: (json['subModelId'] as num?)?.toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$SpellCardTypeEnumMap, json['type']),
  description: json['description'] as String,
  iconUrl: json['iconUrl'] as String?,
  cost: (json['cost'] as num?)?.toDouble(),
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  damage: json['damage'] as String?,
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$CreateSpellCardRequestToJson(
  CreateSpellCardRequest instance,
) => <String, dynamic>{
  'characterId': instance.characterId,
  'subModelId': instance.subModelId,
  'name': instance.name,
  'type': _$SpellCardTypeEnumMap[instance.type]!,
  'description': instance.description,
  'iconUrl': instance.iconUrl,
  'cost': instance.cost,
  'cooldown': instance.cooldown,
  'damage': instance.damage,
  'tips': instance.tips,
};

CreateSpellCardResponse _$CreateSpellCardResponseFromJson(
  Map<String, dynamic> json,
) => CreateSpellCardResponse(id: (json['id'] as num).toInt());

Map<String, dynamic> _$CreateSpellCardResponseToJson(
  CreateSpellCardResponse instance,
) => <String, dynamic>{'id': instance.id};

CreateZombieSkillRequest _$CreateZombieSkillRequestFromJson(
  Map<String, dynamic> json,
) => CreateZombieSkillRequest(
  characterId: (json['characterId'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$ZombieSkillTypeEnumMap, json['type']),
  description: json['description'] as String,
  iconUrl: json['iconUrl'] as String?,
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  damage: json['damage'] as String?,
  range: json['range'] as String?,
  special: json['special'] as String?,
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$CreateZombieSkillRequestToJson(
  CreateZombieSkillRequest instance,
) => <String, dynamic>{
  'characterId': instance.characterId,
  'name': instance.name,
  'type': _$ZombieSkillTypeEnumMap[instance.type]!,
  'description': instance.description,
  'iconUrl': instance.iconUrl,
  'cooldown': instance.cooldown,
  'damage': instance.damage,
  'range': instance.range,
  'special': instance.special,
  'tips': instance.tips,
};

CreateZombieSkillResponse _$CreateZombieSkillResponseFromJson(
  Map<String, dynamic> json,
) => CreateZombieSkillResponse(id: (json['id'] as num).toInt());

Map<String, dynamic> _$CreateZombieSkillResponseToJson(
  CreateZombieSkillResponse instance,
) => <String, dynamic>{'id': instance.id};

EditSpellCardRequest _$EditSpellCardRequestFromJson(
  Map<String, dynamic> json,
) => EditSpellCardRequest(
  id: (json['id'] as num).toInt(),
  description: json['description'] as String?,
  damage: json['damage'] as String?,
  cost: (json['cost'] as num?)?.toDouble(),
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
  editReason: json['editReason'] as String?,
);

Map<String, dynamic> _$EditSpellCardRequestToJson(
  EditSpellCardRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'damage': instance.damage,
  'cost': instance.cost,
  'cooldown': instance.cooldown,
  'tips': instance.tips,
  'editReason': instance.editReason,
};

EditZombieSkillRequest _$EditZombieSkillRequestFromJson(
  Map<String, dynamic> json,
) => EditZombieSkillRequest(
  id: (json['id'] as num).toInt(),
  description: json['description'] as String?,
  damage: json['damage'] as String?,
  range: json['range'] as String?,
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  special: json['special'] as String?,
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
  editReason: json['editReason'] as String?,
);

Map<String, dynamic> _$EditZombieSkillRequestToJson(
  EditZombieSkillRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'damage': instance.damage,
  'range': instance.range,
  'cooldown': instance.cooldown,
  'special': instance.special,
  'tips': instance.tips,
  'editReason': instance.editReason,
};

EditAcquisitionRequest _$EditAcquisitionRequestFromJson(
  Map<String, dynamic> json,
) => EditAcquisitionRequest(
  type: $enumDecode(_$AcquisitionTypeEnumMap, json['type']),
  cost: (json['cost'] as num?)?.toInt(),
  customSource: json['customSource'] as String?,
  editReason: json['editReason'] as String,
);

Map<String, dynamic> _$EditAcquisitionRequestToJson(
  EditAcquisitionRequest instance,
) => <String, dynamic>{
  'type': _$AcquisitionTypeEnumMap[instance.type]!,
  'cost': instance.cost,
  'customSource': instance.customSource,
  'editReason': instance.editReason,
};

EditAcquisitionResponse _$EditAcquisitionResponseFromJson(
  Map<String, dynamic> json,
) => EditAcquisitionResponse(version: (json['version'] as num).toInt());

Map<String, dynamic> _$EditAcquisitionResponseToJson(
  EditAcquisitionResponse instance,
) => <String, dynamic>{'version': instance.version};

ContentEditHistoryItem _$ContentEditHistoryItemFromJson(
  Map<String, dynamic> json,
) => ContentEditHistoryItem(
  id: (json['id'] as num).toInt(),
  editorId: (json['editorId'] as num).toInt(),
  editorName: json['editorName'] as String?,
  editorAvatar: json['editorAvatar'] as String?,
  fieldChanged: json['fieldChanged'] as String,
  oldValue: json['oldValue'] as String?,
  newValue: json['newValue'] as String?,
  editReason: json['editReason'] as String?,
  editedAt: json['editedAt'] as String,
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$ContentEditHistoryItemToJson(
  ContentEditHistoryItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'editorId': instance.editorId,
  'editorName': instance.editorName,
  'editorAvatar': instance.editorAvatar,
  'fieldChanged': instance.fieldChanged,
  'oldValue': instance.oldValue,
  'newValue': instance.newValue,
  'editReason': instance.editReason,
  'editedAt': instance.editedAt,
  'version': instance.version,
};

ContentEditHistoryResponse _$ContentEditHistoryResponseFromJson(
  Map<String, dynamic> json,
) => ContentEditHistoryResponse(
  list: (json['list'] as List<dynamic>)
      .map((e) => ContentEditHistoryItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
);

Map<String, dynamic> _$ContentEditHistoryResponseToJson(
  ContentEditHistoryResponse instance,
) => <String, dynamic>{
  'list': instance.list,
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

AcquisitionEditData _$AcquisitionEditDataFromJson(Map<String, dynamic> json) =>
    AcquisitionEditData(
      type: $enumDecode(_$AcquisitionTypeEnumMap, json['type']),
      cost: (json['cost'] as num?)?.toInt(),
      customSource: json['customSource'] as String?,
    );

Map<String, dynamic> _$AcquisitionEditDataToJson(
  AcquisitionEditData instance,
) => <String, dynamic>{
  'type': _$AcquisitionTypeEnumMap[instance.type]!,
  'cost': instance.cost,
  'customSource': instance.customSource,
};

SpellCardEditItem _$SpellCardEditItemFromJson(Map<String, dynamic> json) =>
    SpellCardEditItem(
      id: (json['id'] as num).toInt(),
      description: json['description'] as String?,
      damage: json['damage'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      cooldown: (json['cooldown'] as num?)?.toDouble(),
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
      videoFileId: (json['videoFileId'] as num?)?.toInt(),
      tier: json['tier'] as String?,
    );

Map<String, dynamic> _$SpellCardEditItemToJson(SpellCardEditItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'damage': instance.damage,
      'cost': instance.cost,
      'cooldown': instance.cooldown,
      'tips': instance.tips,
      'videoFileId': instance.videoFileId,
      'tier': instance.tier,
    };

SpellCardCreateItem _$SpellCardCreateItemFromJson(Map<String, dynamic> json) =>
    SpellCardCreateItem(
      name: json['name'] as String,
      type: json['type'] as String,
      tier: json['tier'] as String?,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      videoFileId: (json['videoFileId'] as num?)?.toInt(),
      cost: (json['cost'] as num?)?.toDouble(),
      cooldown: (json['cooldown'] as num?)?.toDouble(),
      damage: json['damage'] as String?,
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$SpellCardCreateItemToJson(
  SpellCardCreateItem instance,
) => <String, dynamic>{
  'name': instance.name,
  'type': instance.type,
  'tier': instance.tier,
  'description': instance.description,
  'iconUrl': instance.iconUrl,
  'videoFileId': instance.videoFileId,
  'cost': instance.cost,
  'cooldown': instance.cooldown,
  'damage': instance.damage,
  'tips': instance.tips,
};

SpellCardsEditData _$SpellCardsEditDataFromJson(Map<String, dynamic> json) =>
    SpellCardsEditData(
      creates: (json['creates'] as List<dynamic>?)
          ?.map((e) => SpellCardCreateItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      updates: (json['updates'] as List<dynamic>?)
          ?.map((e) => SpellCardEditItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      deletes: (json['deletes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$SpellCardsEditDataToJson(SpellCardsEditData instance) =>
    <String, dynamic>{
      'creates': instance.creates,
      'updates': instance.updates,
      'deletes': instance.deletes,
    };

ZombieSkillEditItem _$ZombieSkillEditItemFromJson(Map<String, dynamic> json) =>
    ZombieSkillEditItem(
      id: (json['id'] as num).toInt(),
      description: json['description'] as String?,
      damage: json['damage'] as String?,
      range: json['range'] as String?,
      cooldown: (json['cooldown'] as num?)?.toDouble(),
      special: json['special'] as String?,
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
      videoFileId: (json['videoFileId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ZombieSkillEditItemToJson(
  ZombieSkillEditItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'damage': instance.damage,
  'range': instance.range,
  'cooldown': instance.cooldown,
  'special': instance.special,
  'tips': instance.tips,
  'videoFileId': instance.videoFileId,
};

ZombieSkillCreateItem _$ZombieSkillCreateItemFromJson(
  Map<String, dynamic> json,
) => ZombieSkillCreateItem(
  name: json['name'] as String,
  type: json['type'] as String,
  description: json['description'] as String?,
  iconUrl: json['iconUrl'] as String?,
  videoFileId: (json['videoFileId'] as num?)?.toInt(),
  cooldown: (json['cooldown'] as num?)?.toDouble(),
  damage: json['damage'] as String?,
  range: json['range'] as String?,
  special: json['special'] as String?,
  tips: (json['tips'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ZombieSkillCreateItemToJson(
  ZombieSkillCreateItem instance,
) => <String, dynamic>{
  'name': instance.name,
  'type': instance.type,
  'description': instance.description,
  'iconUrl': instance.iconUrl,
  'videoFileId': instance.videoFileId,
  'cooldown': instance.cooldown,
  'damage': instance.damage,
  'range': instance.range,
  'special': instance.special,
  'tips': instance.tips,
};

ZombieSkillsEditData _$ZombieSkillsEditDataFromJson(
  Map<String, dynamic> json,
) => ZombieSkillsEditData(
  creates: (json['creates'] as List<dynamic>?)
      ?.map((e) => ZombieSkillCreateItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  updates: (json['updates'] as List<dynamic>?)
      ?.map((e) => ZombieSkillEditItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  deletes: (json['deletes'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$ZombieSkillsEditDataToJson(
  ZombieSkillsEditData instance,
) => <String, dynamic>{
  'creates': instance.creates,
  'updates': instance.updates,
  'deletes': instance.deletes,
};

PreviewImagesEditData _$PreviewImagesEditDataFromJson(
  Map<String, dynamic> json,
) => PreviewImagesEditData(
  thumbnailFileId: (json['thumbnailFileId'] as num?)?.toInt(),
  previewFrontId: (json['previewFrontId'] as num?)?.toInt(),
  previewLeftId: (json['previewLeftId'] as num?)?.toInt(),
  previewRightId: (json['previewRightId'] as num?)?.toInt(),
  previewBackId: (json['previewBackId'] as num?)?.toInt(),
  previewHandId: (json['previewHandId'] as num?)?.toInt(),
  previewLegId: (json['previewLegId'] as num?)?.toInt(),
);

Map<String, dynamic> _$PreviewImagesEditDataToJson(
  PreviewImagesEditData instance,
) => <String, dynamic>{
  'thumbnailFileId': instance.thumbnailFileId,
  'previewFrontId': instance.previewFrontId,
  'previewLeftId': instance.previewLeftId,
  'previewRightId': instance.previewRightId,
  'previewBackId': instance.previewBackId,
  'previewHandId': instance.previewHandId,
  'previewLegId': instance.previewLegId,
};

SubModelUnifiedEditRequest _$SubModelUnifiedEditRequestFromJson(
  Map<String, dynamic> json,
) => SubModelUnifiedEditRequest(
  editReason: json['editReason'] as String,
  description: json['description'] as String?,
  acquisition: json['acquisition'] == null
      ? null
      : AcquisitionEditData.fromJson(
          json['acquisition'] as Map<String, dynamic>,
        ),
  spellCards: json['spellCards'] == null
      ? null
      : SpellCardsEditData.fromJson(json['spellCards'] as Map<String, dynamic>),
  zombieSkills: json['zombieSkills'] == null
      ? null
      : ZombieSkillsEditData.fromJson(
          json['zombieSkills'] as Map<String, dynamic>,
        ),
  previewImages: json['previewImages'] == null
      ? null
      : PreviewImagesEditData.fromJson(
          json['previewImages'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$SubModelUnifiedEditRequestToJson(
  SubModelUnifiedEditRequest instance,
) => <String, dynamic>{
  'editReason': instance.editReason,
  'description': instance.description,
  'acquisition': instance.acquisition,
  'spellCards': instance.spellCards,
  'zombieSkills': instance.zombieSkills,
  'previewImages': instance.previewImages,
};

SubModelUnifiedEditResponse _$SubModelUnifiedEditResponseFromJson(
  Map<String, dynamic> json,
) => SubModelUnifiedEditResponse(
  subModelVersion: (json['subModelVersion'] as num).toInt(),
  editedFields: (json['editedFields'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SubModelUnifiedEditResponseToJson(
  SubModelUnifiedEditResponse instance,
) => <String, dynamic>{
  'subModelVersion': instance.subModelVersion,
  'editedFields': instance.editedFields,
};

MyEditRequestItem _$MyEditRequestItemFromJson(Map<String, dynamic> json) =>
    MyEditRequestItem(
      id: (json['id'] as num).toInt(),
      characterId: (json['characterId'] as num).toInt(),
      characterName: json['characterName'] as String,
      subModelId: (json['subModelId'] as num).toInt(),
      subModelName: json['subModelName'] as String,
      userId: (json['userId'] as num).toInt(),
      userName: json['userName'] as String?,
      editReason: json['editReason'] as String,
      editData: json['editData'] as String,
      auditStatus: $enumDecode(_$AuditStatusEnumMap, json['auditStatus']),
      auditRemark: json['auditRemark'] as String?,
      auditAt: json['auditAt'] as String?,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$MyEditRequestItemToJson(MyEditRequestItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'characterId': instance.characterId,
      'characterName': instance.characterName,
      'subModelId': instance.subModelId,
      'subModelName': instance.subModelName,
      'userId': instance.userId,
      'userName': instance.userName,
      'editReason': instance.editReason,
      'editData': instance.editData,
      'auditStatus': _$AuditStatusEnumMap[instance.auditStatus]!,
      'auditRemark': instance.auditRemark,
      'auditAt': instance.auditAt,
      'createdAt': instance.createdAt,
    };

const _$AuditStatusEnumMap = {
  AuditStatus.pending: 'pending',
  AuditStatus.approved: 'approved',
  AuditStatus.rejected: 'rejected',
};

MyEditRequestListResponse _$MyEditRequestListResponseFromJson(
  Map<String, dynamic> json,
) => MyEditRequestListResponse(
  items: (json['items'] as List<dynamic>)
      .map((e) => MyEditRequestItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$MyEditRequestListResponseToJson(
  MyEditRequestListResponse instance,
) => <String, dynamic>{'items': instance.items, 'total': instance.total};

UnifiedEditHistoryItem _$UnifiedEditHistoryItemFromJson(
  Map<String, dynamic> json,
) => UnifiedEditHistoryItem(
  id: (json['id'] as num).toInt(),
  targetType: $enumDecode(_$EditTargetTypeEnumMap, json['targetType']),
  targetId: (json['targetId'] as num).toInt(),
  targetName: json['targetName'] as String?,
  spellCardType: json['spellCardType'] as String?,
  zombieSkillType: json['zombieSkillType'] as String?,
  editorId: (json['editorId'] as num).toInt(),
  editorName: json['editorName'] as String?,
  editorAvatar: json['editorAvatar'] as String?,
  fieldChanged: json['fieldChanged'] as String,
  oldValue: json['oldValue'] as String?,
  newValue: json['newValue'] as String?,
  editReason: json['editReason'] as String?,
  editedAt: json['editedAt'] as String,
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$UnifiedEditHistoryItemToJson(
  UnifiedEditHistoryItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'targetType': _$EditTargetTypeEnumMap[instance.targetType]!,
  'targetId': instance.targetId,
  'targetName': instance.targetName,
  'spellCardType': instance.spellCardType,
  'zombieSkillType': instance.zombieSkillType,
  'editorId': instance.editorId,
  'editorName': instance.editorName,
  'editorAvatar': instance.editorAvatar,
  'fieldChanged': instance.fieldChanged,
  'oldValue': instance.oldValue,
  'newValue': instance.newValue,
  'editReason': instance.editReason,
  'editedAt': instance.editedAt,
  'version': instance.version,
};

const _$EditTargetTypeEnumMap = {
  EditTargetType.subModel: 'sub_model',
  EditTargetType.spellCard: 'spell_card',
  EditTargetType.zombieSkill: 'zombie_skill',
};

UnifiedEditHistoryResponse _$UnifiedEditHistoryResponseFromJson(
  Map<String, dynamic> json,
) => UnifiedEditHistoryResponse(
  list: (json['list'] as List<dynamic>)
      .map((e) => UnifiedEditHistoryItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$UnifiedEditHistoryResponseToJson(
  UnifiedEditHistoryResponse instance,
) => <String, dynamic>{'list': instance.list, 'total': instance.total};

PendingRequestCheckResponse _$PendingRequestCheckResponseFromJson(
  Map<String, dynamic> json,
) => PendingRequestCheckResponse(
  hasPending: json['hasPending'] as bool,
  requestId: (json['requestId'] as num?)?.toInt(),
);

Map<String, dynamic> _$PendingRequestCheckResponseToJson(
  PendingRequestCheckResponse instance,
) => <String, dynamic>{
  'hasPending': instance.hasPending,
  'requestId': instance.requestId,
};

EditRequestOperationResponse _$EditRequestOperationResponseFromJson(
  Map<String, dynamic> json,
) => EditRequestOperationResponse(success: json['success'] as bool);

Map<String, dynamic> _$EditRequestOperationResponseToJson(
  EditRequestOperationResponse instance,
) => <String, dynamic>{'success': instance.success};

EditRequestDetailResponse _$EditRequestDetailResponseFromJson(
  Map<String, dynamic> json,
) => EditRequestDetailResponse(
  id: (json['id'] as num).toInt(),
  characterId: (json['characterId'] as num).toInt(),
  characterName: json['characterName'] as String,
  subModelId: (json['subModelId'] as num).toInt(),
  subModelName: json['subModelName'] as String,
  editReason: json['editReason'] as String,
  editData: json['editData'] as String,
  auditStatus: $enumDecode(_$AuditStatusEnumMap, json['auditStatus']),
  auditRemark: json['auditRemark'] as String?,
  auditAt: json['auditAt'] as String?,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$EditRequestDetailResponseToJson(
  EditRequestDetailResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'characterId': instance.characterId,
  'characterName': instance.characterName,
  'subModelId': instance.subModelId,
  'subModelName': instance.subModelName,
  'editReason': instance.editReason,
  'editData': instance.editData,
  'auditStatus': _$AuditStatusEnumMap[instance.auditStatus]!,
  'auditRemark': instance.auditRemark,
  'auditAt': instance.auditAt,
  'createdAt': instance.createdAt,
};

EditRequestParsedData _$EditRequestParsedDataFromJson(
  Map<String, dynamic> json,
) => EditRequestParsedData(
  description: json['description'] as String?,
  acquisition: json['acquisition'] == null
      ? null
      : AcquisitionEditData.fromJson(
          json['acquisition'] as Map<String, dynamic>,
        ),
  spellCards: json['spellCards'] == null
      ? null
      : SpellCardsEditData.fromJson(json['spellCards'] as Map<String, dynamic>),
  zombieSkills: json['zombieSkills'] == null
      ? null
      : ZombieSkillsEditData.fromJson(
          json['zombieSkills'] as Map<String, dynamic>,
        ),
  previewImages: json['previewImages'] == null
      ? null
      : PreviewImagesEditData.fromJson(
          json['previewImages'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$EditRequestParsedDataToJson(
  EditRequestParsedData instance,
) => <String, dynamic>{
  'description': instance.description,
  'acquisition': instance.acquisition,
  'spellCards': instance.spellCards,
  'zombieSkills': instance.zombieSkills,
  'previewImages': instance.previewImages,
};

SpellCardTierItem _$SpellCardTierItemFromJson(Map<String, dynamic> json) =>
    SpellCardTierItem(
      id: (json['id'] as num).toInt(),
      characterId: (json['characterId'] as num).toInt(),
      characterName: json['characterName'] as String,
      subModelId: (json['subModelId'] as num?)?.toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$SpellCardTypeEnumMap, json['type']),
      tier: $enumDecode(
        _$SpellCardTierEnumMap,
        json['tier'],
        unknownValue: SpellCardTier.unranked,
      ),
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      cooldown: (json['cooldown'] as num?)?.toDouble(),
      damage: json['damage'] as String?,
    );

Map<String, dynamic> _$SpellCardTierItemToJson(SpellCardTierItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'characterId': instance.characterId,
      'characterName': instance.characterName,
      'subModelId': instance.subModelId,
      'name': instance.name,
      'type': _$SpellCardTypeEnumMap[instance.type]!,
      'tier': _$SpellCardTierEnumMap[instance.tier]!,
      'description': instance.description,
      'iconUrl': instance.iconUrl,
      'cost': instance.cost,
      'cooldown': instance.cooldown,
      'damage': instance.damage,
    };

SpellCardTierGroup _$SpellCardTierGroupFromJson(Map<String, dynamic> json) =>
    SpellCardTierGroup(
      tier: json['tier'] as String,
      tierLabel: json['tierLabel'] as String,
      spellCards: (json['spellCards'] as List<dynamic>)
          .map((e) => SpellCardTierItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$SpellCardTierGroupToJson(SpellCardTierGroup instance) =>
    <String, dynamic>{
      'tier': instance.tier,
      'tierLabel': instance.tierLabel,
      'spellCards': instance.spellCards,
      'count': instance.count,
    };

SpellCardTierListResponse _$SpellCardTierListResponseFromJson(
  Map<String, dynamic> json,
) => SpellCardTierListResponse(
  tiers: (json['tiers'] as List<dynamic>)
      .map((e) => SpellCardTierGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
);

Map<String, dynamic> _$SpellCardTierListResponseToJson(
  SpellCardTierListResponse instance,
) => <String, dynamic>{
  'tiers': instance.tiers,
  'totalCount': instance.totalCount,
};
