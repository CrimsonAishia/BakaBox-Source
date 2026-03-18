import 'dart:io';

import '../utils/log_service.dart';

/// Steam 用户信息服务
/// 
/// 从 Windows 注册表获取当前登录用户的 SteamID3，
/// 然后从 userdata/localconfig.vdf 读取 PersonaName
class SteamUserService {
  static final SteamUserService _instance = SteamUserService._internal();
  factory SteamUserService() => _instance;
  SteamUserService._internal();

  // 缓存
  String? _cachedSteamUsername;
  String? _cachedSteamUserId;
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

    LogService.d('[SteamUserService] 未能获取 Steam 用户名');
    return null;
  }

  /// 从 Windows 注册表获取 Steam 路径
  Future<String?> _getSteamPathFromRegistry() async {
    if (!Platform.isWindows) return null;

    try {
      final result = await Process.run(
        'reg',
        ['query', r'HKCU\Software\Valve\Steam', '/v', 'SteamPath'],
        runInShell: true,
      );

      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.contains('SteamPath')) {
          // 格式: "    SteamPath    REG_SZ    C:/Program Files (x86)/Steam"
          final parts = line.split(RegExp(r'\s{4,}'));
          if (parts.length >= 3) {
            var steamPath = parts.last.trim();
            // 将正斜杠转换为反斜杠
            steamPath = steamPath.replaceAll('/', '\\');
            return steamPath;
          }
        }
      }
    } catch (e) {
      LogService.d('[SteamUserService] 获取Steam路径失败: $e');
    }
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

      // 直接从注册表获取 Steam 路径，不依赖 GameLauncherService
      String? steamPath = await _getSteamPathFromRegistry();
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

  /// 获取当前登录的Steam用户ID（仅Windows）
  /// 
  /// 返回 SteamID3 格式的用户ID（纯数字字符串）
  Future<String?> getCurrentSteamUserId() async {
    // 检查缓存
    if (_cachedSteamUserId != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheExpiry) {
        return _cachedSteamUserId;
      }
    }

    if (!Platform.isWindows) return null;

    try {
      final result = await Process.run(
        'reg',
        ['query', r'HKCU\Software\Valve\Steam\ActiveProcess', '/v', 'ActiveUser'],
        runInShell: true,
      );

      if (result.exitCode != 0) return null;

      final match = RegExp(r'ActiveUser\s+REG_DWORD\s+0x([0-9a-fA-F]+)')
          .firstMatch(result.stdout.toString());
      if (match == null) return null;

      final steamId3 = int.parse(match.group(1)!, radix: 16);
      if (steamId3 == 0) return null;

      // 缓存结果
      _cachedSteamUserId = steamId3.toString();
      _cacheTime = DateTime.now();

      return _cachedSteamUserId;
    } catch (e) {
      LogService.d('[SteamUserService] 获取Steam用户ID失败: $e');
      return null;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cachedSteamUsername = null;
    _cachedSteamUserId = null;
    _cacheTime = null;
  }
}
