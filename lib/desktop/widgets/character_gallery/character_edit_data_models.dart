import '../../../core/models/character_models.dart';

/// 符卡编辑数据
class SpellCardEditData {
  final String? description;
  final String? damage;
  final double? cooldown;
  final double? cost;
  final SpellCardTier? tier;
  final String? previewType; // none/image/video_url
  final int? previewFileId; // image时的文件ID
  final String? previewVideoUrl; // video_url时的外链地址

  SpellCardEditData({
    this.description,
    this.damage,
    this.cooldown,
    this.cost,
    this.tier,
    this.previewType,
    this.previewFileId,
    this.previewVideoUrl,
  });
}

/// 符卡创建数据
class SpellCardCreateData {
  final String name;
  final String type;
  final String? description;
  final String? damage;
  final double? cooldown;
  final double? cost;
  final SpellCardTier? tier;
  final String? previewType; // none/image/video_url
  final int? previewFileId;
  final String? previewVideoUrl;

  SpellCardCreateData({
    required this.name,
    required this.type,
    this.description,
    this.damage,
    this.cooldown,
    this.cost,
    this.tier,
    this.previewType,
    this.previewFileId,
    this.previewVideoUrl,
  });
}

/// 僵尸技能编辑数据
class ZombieSkillEditData {
  final String? description;
  final String? damage;
  final double? cooldown;
  final String? range;
  final String? special;
  final String? previewType; // none/image/video_url
  final int? previewFileId;
  final String? previewVideoUrl;

  ZombieSkillEditData({
    this.description,
    this.damage,
    this.cooldown,
    this.range,
    this.special,
    this.previewType,
    this.previewFileId,
    this.previewVideoUrl,
  });
}

/// 僵尸技能创建数据
class ZombieSkillCreateData {
  final String name;
  final String type;
  final String? description;
  final String? damage;
  final double? cooldown;
  final String? range;
  final String? special;
  final String? previewType; // none/image/video_url
  final int? previewFileId;
  final String? previewVideoUrl;

  ZombieSkillCreateData({
    required this.name,
    required this.type,
    this.description,
    this.damage,
    this.cooldown,
    this.range,
    this.special,
    this.previewType,
    this.previewFileId,
    this.previewVideoUrl,
  });
}
