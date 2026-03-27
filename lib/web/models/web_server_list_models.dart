import 'package:flutter/material.dart';

/// Web 端服务器列表页面的数据模型
class WebServerListData {
  final String title;
  final String subtitle;
  final DateTime? updatedAt;
  final List<WebServerCategory> categories;

  const WebServerListData({
    required this.title,
    required this.subtitle,
    required this.categories,
    this.updatedAt,
  });

  factory WebServerListData.empty() {
    return const WebServerListData(
      title: 'BakaBox Web Server List',
      subtitle: '等待服务器快照推送',
      categories: [],
    );
  }

  factory WebServerListData.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] as List<dynamic>? ?? const [];
    return WebServerListData(
      title: json['title'] as String? ?? 'BakaBox Web Server List',
      subtitle: json['subtitle'] as String? ?? '服务器列表数据由 WS 推送',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      categories: categoriesJson
          .whereType<Map<String, dynamic>>()
          .map(WebServerCategory.fromJson)
          .toList(),
    );
  }
}

class WebServerCategory {
  final String name;
  final bool isLoading;
  final List<WebServerItem> servers;

  const WebServerCategory({
    required this.name,
    required this.servers,
    this.isLoading = false,
  });

  factory WebServerCategory.fromJson(Map<String, dynamic> json) {
    final serversJson = json['servers'] as List<dynamic>? ?? const [];
    return WebServerCategory(
      name: json['name'] as String? ?? '未命名分类',
      isLoading: json['isLoading'] as bool? ?? false,
      servers: serversJson
          .whereType<Map<String, dynamic>>()
          .map(WebServerItem.fromJson)
          .toList(),
    );
  }

  int get onlinePlayers {
    var total = 0;
    for (final server in servers) {
      total += server.players ?? 0;
    }
    return total;
  }
}

class WebServerItem {
  final String id;
  final String name;
  final String? address;
  final String? mapName;
  final String? mapLabel;
  final String? mapImageUrl;
  final List<WebServerTag> tags;
  final int? players;
  final int? maxPlayers;
  final int? runtimeMinutes;
  final int? weeklyOccurrences;
  final int? ping;
  final bool isOffline;
  final bool isLoading;
  final bool isCustom;
  final WebServerScore? score;
  final Color? accentColor;

  const WebServerItem({
    required this.id,
    required this.name,
    this.address,
    this.mapName,
    this.mapLabel,
    this.mapImageUrl,
    this.tags = const [],
    this.players,
    this.maxPlayers,
    this.runtimeMinutes,
    this.weeklyOccurrences,
    this.ping,
    this.isOffline = false,
    this.isLoading = false,
    this.isCustom = false,
    this.score,
    this.accentColor,
  });

  factory WebServerItem.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List<dynamic>? ?? const [];
    return WebServerItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名服务器',
      address: json['address'] as String?,
      mapName: json['mapName'] as String?,
      mapLabel: json['mapLabel'] as String?,
      mapImageUrl: json['mapImageUrl'] as String?,
      tags: tagsJson
          .whereType<Map<String, dynamic>>()
          .map(WebServerTag.fromJson)
          .toList(),
      players: _asInt(json['players']),
      maxPlayers: _asInt(json['maxPlayers']),
      runtimeMinutes: _asInt(json['runtimeMinutes']),
      weeklyOccurrences: _asInt(json['weeklyOccurrences']),
      ping: _asInt(json['ping']),
      isOffline: json['isOffline'] as bool? ?? false,
      isLoading: json['isLoading'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? false,
      score: json['score'] is Map<String, dynamic>
          ? WebServerScore.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      accentColor: _parseColor(json['accentColor'] as String?),
    );
  }

  String get displayMapName {
    if (mapLabel != null && mapLabel!.isNotEmpty && mapName != null) {
      return '$mapLabel ($mapName)';
    }
    if (mapLabel != null && mapLabel!.isNotEmpty) {
      return mapLabel!;
    }
    if (mapName != null && mapName!.isNotEmpty) {
      return mapName!;
    }
    return '-';
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static Color? _parseColor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }

    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    final colorValue = int.tryParse(hex, radix: 16);
    return colorValue == null ? null : Color(colorValue);
  }
}

class WebServerTag {
  final String name;
  final Color? color;

  const WebServerTag({
    required this.name,
    this.color,
  });

  factory WebServerTag.fromJson(Map<String, dynamic> json) {
    return WebServerTag(
      name: json['name'] as String? ?? '',
      color: WebServerItem._parseColor(json['color'] as String?),
    );
  }
}

class WebServerScore {
  final int ctScore;
  final int tScore;
  final String? dataQuality;

  const WebServerScore({
    required this.ctScore,
    required this.tScore,
    this.dataQuality,
  });

  factory WebServerScore.fromJson(Map<String, dynamic> json) {
    return WebServerScore(
      ctScore: WebServerItem._asInt(json['ctScore']) ?? 0,
      tScore: WebServerItem._asInt(json['tScore']) ?? 0,
      dataQuality: json['dataQuality'] as String?,
    );
  }
}
