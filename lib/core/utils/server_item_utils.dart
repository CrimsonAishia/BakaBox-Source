import '../models/server_models.dart';

/// 服务器列表项的工具类
class ServerItemUtils {
  ServerItemUtils._();

  static ServerInfo? getServerInfo(ExtendedServerItem server) {
    if (server.serverData != null) return server.serverData;
    if (server.serverItem.serverData == null) return null;
    try {
      return ServerInfo.fromJson(server.serverItem.serverData!);
    } catch (e) {
      return null;
    }
  }

  static String getServerName(ExtendedServerItem server) {
    final serverInfo = getServerInfo(server);
    return serverInfo?.hostName ?? server.serverItem.address ?? '未知服务器';
  }

  static String getMapName(ExtendedServerItem server) {
    final serverInfo = getServerInfo(server);
    return serverInfo?.map ?? '未知地图';
  }

  static String getMapDisplayName(ExtendedServerItem server) {
    final mapName = getMapName(server);
    if (server.mapInfo != null && server.mapInfo!.mapLabel.isNotEmpty) {
      return '${server.mapInfo!.mapLabel}($mapName)';
    }
    return formatMapName(mapName);
  }

  static String? getMapBackgroundUrl(ExtendedServerItem server) {
    return server.mapInfo?.mapUrl;
  }

  static int getCurrentPlayers(ExtendedServerItem server) {
    final serverInfo = getServerInfo(server);
    return serverInfo?.players ?? 0;
  }

  static int getMaxPlayers(ExtendedServerItem server) {
    final serverInfo = getServerInfo(server);
    return serverInfo?.maxPlayers ?? 64;
  }

  static String getServerAddress(ExtendedServerItem server) {
    return server.serverItem.address ??
        server.serverItem.serverAddress ??
        '未知地址';
  }

  static bool hasServerData(ExtendedServerItem server) {
    return getServerInfo(server) != null;
  }

  static String getServerStatusText(ExtendedServerItem server) {
    if (server.hasError) return '数据获取失败';
    if (server.isLoading) return '数据获取中...';
    if (!hasServerData(server)) return '服务器离线或数据缺失';
    return '';
  }

  static String formatMapName(String mapName) {
    String formatted = mapName;
    if (formatted.startsWith('de_')) {
      formatted = formatted.substring(3);
    } else if (formatted.startsWith('cs_')) {
      formatted = formatted.substring(3);
    } else if (formatted.startsWith('aim_')) {
      formatted = formatted.substring(4);
    }
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }
    return formatted;
  }

  static double getPlayerPercentage(ExtendedServerItem server) {
    final current = getCurrentPlayers(server);
    final max = getMaxPlayers(server);
    if (max <= 0) return 0.0;
    return (current / max).clamp(0.0, 1.0);
  }

  static bool isServerFull(ExtendedServerItem server) {
    return getCurrentPlayers(server) >= getMaxPlayers(server);
  }

  static bool isServerEmpty(ExtendedServerItem server) {
    return getCurrentPlayers(server) == 0;
  }

  static ServerPopularityStatus getPopularityStatus(ExtendedServerItem server) {
    final percentage = getPlayerPercentage(server);
    if (percentage >= 0.9) return ServerPopularityStatus.full;
    if (percentage >= 0.7) return ServerPopularityStatus.high;
    if (percentage >= 0.3) return ServerPopularityStatus.medium;
    if (percentage > 0) return ServerPopularityStatus.low;
    return ServerPopularityStatus.empty;
  }

  /// 判断是否为 CSGO 服务器
  ///
  /// 根据 gameType 字段判断：
  /// - 如果包含 "csgo" 或 "cs:go"（不区分大小写），返回 true
  /// - 否则返回 false（默认为 CS2）
  static bool isCsgoServer(String? gameType) {
    if (gameType == null || gameType.isEmpty) {
      return false;
    }

    final lowerGameType = gameType.toLowerCase();
    return lowerGameType.contains('csgo') || lowerGameType.contains('cs:go');
  }
}

enum ServerPopularityStatus { empty, low, medium, high, full }
