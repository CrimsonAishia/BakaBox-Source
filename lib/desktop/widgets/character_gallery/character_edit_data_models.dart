import '../../../core/models/character_models.dart';

/// 符卡编辑数据
class SpellCardEditData {
  final String? description;
  final String? damage;
  final double? cooldown;
  final int? cost;
  final SpellCardTier? tier;
  final String? previewType; // none/image/video_url
  final int? previewFileId; // image时的文件ID
  final String? previewVideoUrl; // video_url时的外链地址

  final double? speed; // 弹幕初速
  final int? count; // 弹幕数量
  final double? angle; // 散射角度
  final double? customCd; // 自定义/内置 CD 数值
  final int? puncture; // 穿刺次数
  final int? bounce; // 反弹次数
  final double? explode; // 影响范围 / 爆炸半径
  final double? holdTime; // 持续时间（秒）
  final double? trackSpeed; // 追踪加速 / 转向

  SpellCardEditData({
    this.description,
    this.damage,
    this.cooldown,
    this.cost,
    this.tier,
    this.previewType,
    this.previewFileId,
    this.previewVideoUrl,
    this.speed,
    this.count,
    this.angle,
    this.customCd,
    this.puncture,
    this.bounce,
    this.explode,
    this.holdTime,
    this.trackSpeed,
  });
}

/// 符卡创建数据
class SpellCardCreateData {
  final String name;
  final String type;
  final String? description;
  final String? damage;
  final double? cooldown;
  final int? cost;
  final SpellCardTier? tier;
  final String? previewType; // none/image/video_url
  final int? previewFileId;
  final String? previewVideoUrl;

  final double? speed; // 弹幕初速
  final int? count; // 弹幕数量
  final double? angle; // 散射角度
  final double? customCd; // 自定义/内置 CD 数值
  final int? puncture; // 穿刺次数
  final int? bounce; // 反弹次数
  final double? explode; // 影响范围 / 爆炸半径
  final double? holdTime; // 持续时间（秒）
  final double? trackSpeed; // 追踪加速 / 转向

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
    this.speed,
    this.count,
    this.angle,
    this.customCd,
    this.puncture,
    this.bounce,
    this.explode,
    this.holdTime,
    this.trackSpeed,
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
