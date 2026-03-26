import 'package:source_server/source_server.dart';
import '../utils/log_service.dart';

class SourceServerInfo {
  final String name;
  final String map;
  final int players;
  final int maxPlayers;
  final int bots;
  final String game;
  final String version;
  final bool vac;
  final bool passwordProtected;
  final String os;
  final int ping;
  final String gameType;

  SourceServerInfo({
    required this.name,
    required this.map,
    required this.players,
    required this.maxPlayers,
    required this.bots,
    required this.game,
    required this.version,
    required this.vac,
    required this.passwordProtected,
    required this.os,
    required this.ping,
    required this.gameType,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'map': map,
    'players': players,
    'max_players': maxPlayers,
    'bots': bots,
    'game': game,
    'version': version,
    'vac': vac,
    'password_protected': passwordProtected,
    'os': os,
    'ping': ping,
    'game_type': gameType,
  };
}

class SourceServerPlayer {
  final String name;
  final int score;
  final double duration;

  SourceServerPlayer({
    required this.name,
    required this.score,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'duration': duration,
  };
}

class SourceServerService {
  static const int defaultTimeout = 5000;

  static Future<SourceServerInfo?> getServerInfo(
    String ip,
    int port, {
    int? timeout,
  }) async {
    SourceServer? server;
    final stopwatch = Stopwatch()..start();

    try {
      server = await SourceServer.connect(
        ip,
        port,
        timeout: Duration(milliseconds: timeout ?? defaultTimeout),
      );
      final info = await server.getInfo();
      stopwatch.stop();

      String osName = 'unknown';
      if (info.os.toString().contains('windows')) {
        osName = 'windows';
      } else if (info.os.toString().contains('linux')) {
        osName = 'linux';
      }

      bool vacEnabled = info.vac.toString().contains('secured');
      bool hasPassword = info.visibility.toString().contains('private');

      String gameType = 'Unknown';
      if (info.game.toLowerCase().contains('counter-strike 2')) {
        gameType = 'CS2';
      } else if (info.game.toLowerCase().contains('counter-strike')) {
        gameType = 'CSGO';
      }

      return SourceServerInfo(
        name: info.name,
        map: info.map,
        players: info.players,
        maxPlayers: info.maxPlayers,
        bots: info.bots,
        game: info.game,
        version: info.version,
        vac: vacEnabled,
        passwordProtected: hasPassword,
        os: osName,
        ping: stopwatch.elapsedMilliseconds,
        gameType: gameType,
      );
    } catch (e) {
      LogService.d('获取服务器信息失败 ($ip:$port): $e', e);
      return null;
    } finally {
      server?.close();
    }
  }

  static Future<List<SourceServerPlayer>> getServerPlayers(
    String ip,
    int port, {
    int? timeout,
  }) async {
    SourceServer? server;
    try {
      server = await SourceServer.connect(
        ip,
        port,
        timeout: Duration(milliseconds: timeout ?? defaultTimeout),
      );
      final players = await server.getPlayers();
      return players
          .map(
            (p) => SourceServerPlayer(
              name: p.name,
              score: p.score,
              duration: p.duration,
            ),
          )
          .toList();
    } catch (e) {
      LogService.e('获取玩家列表失败 ($ip:$port): $e', e);
      return [];
    } finally {
      server?.close();
    }
  }

  static Future<bool> isServerOnline(
    String ip,
    int port, {
    int? timeout,
  }) async {
    final info = await getServerInfo(ip, port, timeout: timeout);
    return info != null;
  }

  static Future<int> measurePing(String ip, int port, {int? timeout}) async {
    final stopwatch = Stopwatch()..start();
    final info = await getServerInfo(ip, port, timeout: timeout);
    stopwatch.stop();
    return info != null ? stopwatch.elapsedMilliseconds : -1;
  }

  static Future<Map<String, SourceServerInfo?>> batchQuery(
    List<String> addresses, {
    int? timeout,
  }) async {
    final results = <String, SourceServerInfo?>{};
    final futures = addresses.map((address) async {
      try {
        final parts = address.split(':');
        if (parts.length != 2) return null;
        final info = await getServerInfo(
          parts[0],
          int.parse(parts[1]),
          timeout: timeout,
        );
        return MapEntry(address, info);
      } catch (e) {
        LogService.e('查询服务器失败 ($address): $e', e);
        return MapEntry(address, null);
      }
    });
    final responses = await Future.wait(futures);
    for (final response in responses) {
      if (response != null) results[response.key] = response.value;
    }
    return results;
  }
}
