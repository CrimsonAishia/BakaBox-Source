import '../../../core/models/character_models.dart';

/// 符卡编辑数据
class SpellCardEditData {
  final String? description;
  final String? damage;
  final int? cooldown;
  final int? cost;
  final SpellCardTier? tier;

  SpellCardEditData({
    this.description,
    this.damage,
    this.cooldown,
    this.cost,
    this.tier,
  });
}

/// 符卡创建数据
class SpellCardCreateData {
  final String name;
  final String type;
  final String? description;
  final String? damage;
  final int? cooldown;
  final int? cost;
  final SpellCardTier? tier;

  SpellCardCreateData({
    required this.name,
    required this.type,
    this.description,
    this.damage,
    this.cooldown,
    this.cost,
    this.tier,
  });
}

/// 僵尸技能编辑数据
class ZombieSkillEditData {
  final String? description;
  final String? damage;
  final int? cooldown;
  final String? range;
  final String? special;

  ZombieSkillEditData({
    this.description,
    this.damage,
    this.cooldown,
    this.range,
    this.special,
  });
}

/// 僵尸技能创建数据
class ZombieSkillCreateData {
  final String name;
  final String type;
  final String? description;
  final String? damage;
  final int? cooldown;
  final String? range;
  final String? special;

  ZombieSkillCreateData({
    required this.name,
    required this.type,
    this.description,
    this.damage,
    this.cooldown,
    this.range,
    this.special,
  });
}
