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

  /// 判断是否为 CS:Source 服务器
  ///
  /// 根据 gameType 字段判断：
  /// - 如果包含 "source" 或 "cs:s"，或等于 "css"（不区分大小写），返回 true
  static bool isCssServer(String? gameType) {
    if (gameType == null || gameType.isEmpty) {
      return false;
    }

    final lower = gameType.toLowerCase();
    return lower == 'css' || lower.contains('source') || lower.contains('cs:s');
  }

  // ─── 各游戏的 Steam AppID ───────────────────────────────
  /// CS2 / CSGO Legacy 共用的 AppID
  static const int cs2AppId = 730;

  /// 独立版 CSGO 的 AppID（2026 年 3 月回归 Steam 后使用的新 AppID）
  static const int csgoStandaloneAppId = 4465480;

  /// Counter-Strike: Source 的 AppID
  static const int cssAppId = 240;

  /// 根据服务器的 appId 与 gameType 解析对应的游戏客户端类型
  ///
  /// 解析优先级：appId（最权威）> gameType 字符串
  ///
  /// 说明：
  /// - AppID 730 同时被 CS2 与 CSGO Legacy（csgo_legacy 测试分支）使用，
  ///   需要再结合 gameType 区分
  /// - 独立版 CSGO 使用独立的 AppID 4465480
  /// - 无 appId 时回退到 gameType；此时无法区分独立版/Legacy CSGO，
  ///   保守按 Legacy 处理以保持既有行为
  static GameClient resolveGameClient({int? appId, String? gameType}) {
    if (appId != null) {
      switch (appId) {
        case csgoStandaloneAppId:
          return GameClient.csgoStandalone;
        case cssAppId:
          return GameClient.css;
        case cs2AppId:
          return isCsgoServer(gameType)
              ? GameClient.csgoLegacy
              : GameClient.cs2;
      }
    }

    // 无 appId（或非已知 AppID），回退到 gameType 字符串判断
    if (isCssServer(gameType)) {
      return GameClient.css;
    }
    if (isCsgoServer(gameType)) {
      return GameClient.csgoLegacy;
    }
    return GameClient.cs2;
  }

  /// 将简短游戏类型（`cs2` / `csgo` / `css`）转换为展示名称
  static String displayNameForShortType(String shortType) {
    switch (shortType) {
      case 'cs2':
        return 'CS2';
      case 'csgo':
        return 'CSGO';
      case 'css':
        return 'CS:Source';
      default:
        return shortType.toUpperCase();
    }
  }
}

enum ServerPopularityStatus { empty, low, medium, high, full }

/// 游戏客户端类型
enum GameClient {
  /// Counter-Strike 2（AppID 730，进程 cs2.exe）
  cs2,

  /// 独立版 CSGO（AppID 4465480，进程 csgo.exe），可通过 Steam URL 自动启动
  csgoStandalone,

  /// 旧版 CSGO Legacy（AppID 730 的 csgo_legacy 测试分支，进程 csgo.exe），
  /// 无法通过 steam://run/730 指定分支，必须由用户在 Steam 中手动启动
  csgoLegacy,

  /// Counter-Strike: Source（AppID 240，进程 hl2.exe）
  css,
}

extension GameClientInfo on GameClient {
  /// 用于构建 `steam://run/<appId>` 与 `-applaunch <appId>`
  String get steamAppId {
    switch (this) {
      case GameClient.cs2:
      case GameClient.csgoLegacy:
        return '${ServerItemUtils.cs2AppId}';
      case GameClient.csgoStandalone:
        return '${ServerItemUtils.csgoStandaloneAppId}';
      case GameClient.css:
        return '${ServerItemUtils.cssAppId}';
    }
  }

  /// 是否可以通过 Steam URL（`steam://run/<appId>`）自动启动
  ///
  /// CSGO Legacy 是 730 的测试分支，无法通过 URL 指定分支，必须手动启动
  bool get canAutoLaunch => this != GameClient.csgoLegacy;

  /// 简短类型标识，与 GameStatusService.runningGameType 对齐
  String get shortType {
    switch (this) {
      case GameClient.cs2:
        return 'cs2';
      case GameClient.csgoStandalone:
      case GameClient.csgoLegacy:
        return 'csgo';
      case GameClient.css:
        return 'css';
    }
  }

  /// 用于展示的名称
  String get displayName {
    switch (this) {
      case GameClient.cs2:
        return 'CS2';
      case GameClient.csgoStandalone:
      case GameClient.csgoLegacy:
        return 'CSGO';
      case GameClient.css:
        return 'CS:Source';
    }
  }

  /// 构建连接服务器用的 Steam URL：`steam://run/<appId>//+connect <addr> [+password <pwd>]`
  String buildConnectUrl(String serverAddress, [String? password]) {
    final base = 'steam://run/$steamAppId//+connect $serverAddress';
    if (password != null && password.isNotEmpty) {
      return '$base +password $password';
    }
    return base;
  }
}
