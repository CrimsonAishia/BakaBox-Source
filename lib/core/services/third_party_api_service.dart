import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/server_models.dart';
import '../utils/log_service.dart';

class CS2ZeServerData {
  final String gameType;
  final String? imageUrl;
  final String? map;
  final String? mapCn;
  final int? maxPlayers;
  final String name;
  final bool online;
  final int players;
  final String serverKey;
  final List<String> serverTags;

  CS2ZeServerData({
    required this.gameType,
    this.imageUrl,
    this.map,
    this.mapCn,
    this.maxPlayers,
    required this.name,
    required this.online,
    required this.players,
    required this.serverKey,
    required this.serverTags,
  });

  factory CS2ZeServerData.fromJson(Map<String, dynamic> json) {
    return CS2ZeServerData(
      gameType: json['game_type'] as String? ?? 'cs2',
      imageUrl: json['image_url'] as String?,
      map: json['map'] as String?,
      mapCn: json['map_cn'] as String?,
      maxPlayers: json['max_players'] as int?,
      name: json['name'] as String? ?? 'Unknown Server',
      online: json['online'] as bool? ?? false,
      players: json['players'] as int? ?? 0,
      serverKey: json['server_key'] as String? ?? '',
      serverTags: (json['server_tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// 转换为通用 ServerInfo 用于更新卡片
  ServerInfo toServerInfo() {
    return ServerInfo(
      hostName: name,
      map: map,
      players: players,
      maxPlayers: maxPlayers,
      gameType: gameType,
    );
  }
}

class ThirdPartyApiService {
  static const String cs2zeApiUrl = 'https://public.cs2ze.org/servers.json';

  /// 获取 CS2ZE 的全部服务器数据
  /// 返回：Map<类别名称, 类别下服务器列表>
  static Future<Map<String, List<CS2ZeServerData>>> fetchCS2ZeServers() async {
    try {
      final response = await http.get(Uri.parse(cs2zeApiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final Map<String, List<CS2ZeServerData>> result = {};
        
        data.forEach((key, value) {
          if (value is List) {
            result[key] = value.map((e) => CS2ZeServerData.fromJson(e as Map<String, dynamic>)).toList();
          }
        });
        
        return result;
      } else {
        throw Exception('Failed to load data, status code: ${response.statusCode}');
      }
    } catch (e) {
      LogService.e('Fetch CS2ZE servers failed: $e', e);
      rethrow;
    }
  }

  /// 快速查询 CS2ZE 服务器（用于刷新），返回按 serverKey (IP:Port) 索引的 Map
  static Future<Map<String, CS2ZeServerData>> fetchCS2ZeServersMap() async {
    final grouped = await fetchCS2ZeServers();
    final Map<String, CS2ZeServerData> map = {};
    for (var list in grouped.values) {
      for (var server in list) {
        if (server.serverKey.isNotEmpty) {
          map[server.serverKey] = server;
        }
      }
    }
    return map;
  }
}
