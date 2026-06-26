import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

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
      final key = Registry.openPath(RegistryHive.currentUser, path: r'Software\Valve\Steam');
      final steamPath = key.getValueAsString('SteamPath');
      key.close();
      if (steamPath != null && steamPath.isNotEmpty) {
        return steamPath.replaceAll('/', '\\');
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
      int? activeUser;
      try {
        final key = Registry.openPath(RegistryHive.currentUser, path: r'Software\Valve\Steam\ActiveProcess');
        activeUser = key.getValueAsInt('ActiveUser');
        key.close();
      } catch (e) {
        LogService.d('[SteamUserService] 读取 ActiveUser 失败: $e');
      }

      if (activeUser == null || activeUser == 0) return null;

      final steamId3 = activeUser;

      // 直接从注册表获取 Steam 路径，不依赖 GameLauncherService
      String? steamPath = await _getSteamPathFromRegistry();
      if (steamPath == null) return null;

      final configPath =
          '$steamPath\\userdata\\$steamId3\\config\\localconfig.vdf';
      final file = File(configPath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final nameMatch = RegExp(
        r'"PersonaName"\s+"([^"]*)"',
      ).firstMatch(content);
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
      int? activeUser;
      try {
        final key = Registry.openPath(RegistryHive.currentUser, path: r'Software\Valve\Steam\ActiveProcess');
        activeUser = key.getValueAsInt('ActiveUser');
        key.close();
      } catch (e) {
        LogService.d('[SteamUserService] 读取 ActiveUser 失败: $e');
      }

      if (activeUser == null || activeUser == 0) return null;

      final steamId3 = activeUser;

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
