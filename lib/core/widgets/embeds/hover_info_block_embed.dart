import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../constants/app_colors.dart';

/// 悬浮引用徽章自定义 Embed 类型标识
const String hoverInfoEmbedType = 'hoverInfo';

/// 悬浮引用类型
enum HoverInfoType {
  map,
  character,
  weapon,
  knife,
  spellCard;

  static HoverInfoType fromString(String value) {
    return HoverInfoType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HoverInfoType.map,
    );
  }
}

/// 悬浮引用徽章 Embed
///
/// 在文本流里渲染为彩色徽章（圆角小标签 + 图标 + label），
/// 鼠标悬停弹出详情卡片。
///
/// Delta 格式:
/// ```jsonc
/// { "insert": { "hoverInfo": {
///     "type": "map",          // map | character | weapon | knife | spellCard
///     "id": "de_dust2",
///     "label": "Dust II",
///     "iconUrl": "..."
/// } } }
/// ```
///
/// 注意：作为内联 embed，使用 [Embeddable]（非 BlockEmbed），
/// 以便与文字同行排列。
class HoverInfoBlockEmbed extends CustomBlockEmbed {
  HoverInfoBlockEmbed(Map<String, dynamic> data)
      : super(hoverInfoEmbedType, jsonEncode(data));

  factory HoverInfoBlockEmbed.create({
    required HoverInfoType type,
    required String id,
    required String label,
    String? iconUrl,
  }) {
    return HoverInfoBlockEmbed({
      'type': type.name,
      'id': id,
      'label': label,
      'iconUrl': iconUrl ?? '',
    });
  }

  static HoverInfoData? parseData(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return HoverInfoData.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}

/// 悬浮引用数据结构
class HoverInfoData {
  final HoverInfoType type;
  final String id;
  final String label;
  final String iconUrl;

  const HoverInfoData({
    required this.type,
    required this.id,
    required this.label,
    this.iconUrl = '',
  });

  factory HoverInfoData.fromJson(Map<String, dynamic> json) {
    return HoverInfoData(
      type: HoverInfoType.fromString(json['type'] as String? ?? 'map'),
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'label': label,
        'iconUrl': iconUrl,
      };
}

/// 各引用类型的主题色与图标
class HoverInfoColors {
  const HoverInfoColors._();

  static Color color(HoverInfoType type) {
    switch (type) {
      case HoverInfoType.map:
        return AppColors.blue500; // 蓝
      case HoverInfoType.character:
        return AppColors.violet500; // 紫
      case HoverInfoType.weapon:
        return AppColors.amber500; // 橙
      case HoverInfoType.knife:
        return const Color(0xFFEC4899); // 粉
      case HoverInfoType.spellCard:
        return AppColors.red600; // 朱红
    }
  }

  static IconData icon(HoverInfoType type) {
    switch (type) {
      case HoverInfoType.map:
        return Icons.map_outlined;
      case HoverInfoType.character:
        return Icons.person_outline_rounded;
      case HoverInfoType.weapon:
        return Icons.gps_fixed_rounded;
      case HoverInfoType.knife:
        return Icons.content_cut_rounded;
      case HoverInfoType.spellCard:
        return Icons.auto_awesome_rounded;
    }
  }
}
