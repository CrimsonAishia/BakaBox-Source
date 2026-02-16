import 'dart:io';

import '../utils/log_service.dart';
import 'game_launcher_service.dart';
import 'gsi_service.dart';

/// Steam 用户信息服务
/// 
/// 从 Windows 注册表获取当前登录用户的 SteamID3，
/// 然后从 userdata/localconfig.vdf 读取 PersonaName
class SteamUserService {
  static final SteamUserService _instance = SteamUserService._internal();
  factory SteamUserService() => _instance;
  SteamUserService._internal();

  final GameLauncherService _gameLauncher = GameLauncherService();
  final GsiService _gsiService = GsiService();

  String? _cachedSteamUsername;
  DateTime? _cacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// 获取当前 Steam 用户昵称
  Future<String?> getCurrentUsername() async {
    // 检查缓存
    if (_cachedSteamUsername != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheExpiry) {
        return _cachedSteamUsername;
      }
    }

    // 从注册表获取（仅 Windows）
    final username = await _getUsernameFromRegistry();
    if (username != null && username.isNotEmpty) {
      _cachedSteamUsername = username;
      _cacheTime = DateTime.now();
      LogService.d('[SteamUserService] 获取用户名: $username');
      return username;
    }

    // GSI 备选（游戏运行时）
    final gsiUsername = _gsiService.latestState?.player?.name;
    if (gsiUsername != null && gsiUsername.isNotEmpty) {
      _cachedSteamUsername = gsiUsername;
      _cacheTime = DateTime.now();
      LogService.d('[SteamUserService] 从 GSI 获取用户名: $gsiUsername');
      return gsiUsername;
    }

    LogService.d('[SteamUserService] 未能获取 Steam 用户名');
    return null;
  }

  /// 从 Windows 注册表获取 ActiveUser，然后读取 localconfig.vdf
  Future<String?> _getUsernameFromRegistry() async {
    if (!Platform.isWindows) return null;

    try {
      // 读取注册表 ActiveUser (SteamID3)
      final result = await Process.run(
        'reg',
        ['query', r'HKCU\Software\Valve\Steam\ActiveProcess', '/v', 'ActiveUser'],
        runInShell: true,
      );

      if (result.exitCode != 0) return null;

      // 解析：ActiveUser    REG_DWORD    0x12345678
      final match = RegExp(r'ActiveUser\s+REG_DWORD\s+0x([0-9a-fA-F]+)')
          .firstMatch(result.stdout.toString());
      if (match == null) return null;

      final steamId3 = int.parse(match.group(1)!, radix: 16);
      if (steamId3 == 0) return null;

      // 读取 localconfig.vdf
      String? steamPath = await _gameLauncher.getSteamPath();
      steamPath ??= await _gameLauncher.detectSteamPath();
      if (steamPath == null) return null;

      final configPath = '$steamPath\\userdata\\$steamId3\\config\\localconfig.vdf';
      final file = File(configPath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final nameMatch = RegExp(r'"PersonaName"\s+"([^"]*)"').firstMatch(content);
      return nameMatch?.group(1);
    } catch (e) {
      LogService.e('[SteamUserService] 获取用户名失败', e);
      return null;
    }
  }

  void clearCache() {
    _cachedSteamUsername = null;
    _cacheTime = null;
  }
}
