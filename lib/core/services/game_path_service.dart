import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_service.dart';

/// 游戏路径验证结果
class PathValidationResult {
  final bool isValid;
  final String? error;

  const PathValidationResult({required this.isValid, this.error});
}

/// 游戏路径服务 - 统一管理 CS2 和 Steam 路径的检测、验证、存储
class GamePathService {
  static final GamePathService _instance = GamePathService._internal();
  factory GamePathService() => _instance;
  GamePathService._internal();

  static const String _keyGamePath = 'game_path';
  static const String _keySteamPath = 'steam_path';

  // ==================== 路径获取 ====================

  /// 获取游戏路径
  Future<String?> getGamePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGamePath);
  }

  /// 获取 Steam 路径
  Future<String?> getSteamPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySteamPath);
  }

  /// 检查游戏路径是否已配置
  Future<bool> hasGamePath() async {
    final path = await getGamePath();
    return path != null && path.isNotEmpty;
  }

  /// 检查 Steam 路径是否已配置
  Future<bool> hasSteamPath() async {
    final path = await getSteamPath();
    return path != null && path.isNotEmpty;
  }

  // ==================== 路径设置 ====================

  /// 设置游戏路径
  Future<bool> setGamePath(String path) async {
    final validation = await validateGamePath(path);
    if (!validation.isValid) {
      LogService.w('[GamePathService] 游戏路径验证失败: ${validation.error}');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGamePath, path);
    LogService.i('[GamePathService] 游戏路径已设置: $path');
    return true;
  }

  /// 设置 Steam 路径
  Future<bool> setSteamPath(String path) async {
    final validation = await validateSteamPath(path);
    if (!validation.isValid) {
      LogService.w('[GamePathService] Steam路径验证失败: ${validation.error}');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySteamPath, path);
    LogService.i('[GamePathService] Steam路径已设置: $path');
    return true;
  }

  /// 清除游戏路径
  Future<void> clearGamePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGamePath);
    LogService.i('[GamePathService] 游戏路径已清除');
  }

  /// 清除 Steam 路径
  Future<void> clearSteamPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySteamPath);
    LogService.i('[GamePathService] Steam路径已清除');
  }

  // ==================== 路径检测 ====================

  /// 自动检测游戏路径
  Future<String?> detectGamePath() async {
    LogService.d('[GamePathService] 开始自动检测游戏路径...');

    // 首先尝试获取 Steam 路径
    String? steamPath = await getSteamPath();
    if (steamPath == null || steamPath.isEmpty) {
      steamPath = await detectSteamPath();
    }

    if (steamPath == null) {
      // 尝试常见路径
      return await _detectFromCommonPaths();
    }

    try {
      if (Platform.isWindows) {
        return await _detectGamePathWindows(steamPath);
      } else if (Platform.isMacOS) {
        return await _detectGamePathMacOS(steamPath);
      } else if (Platform.isLinux) {
        return await _detectGamePathLinux(steamPath);
      }
    } catch (e) {
      LogService.e('[GamePathService] 检测游戏路径失败', e);
    }

    return await _detectFromCommonPaths();
  }

  /// 自动检测 Steam 路径
  Future<String?> detectSteamPath() async {
    LogService.d('[GamePathService] 开始自动检测Steam路径...');

    try {
      if (Platform.isWindows) {
        return await _detectSteamPathWindows();
      } else if (Platform.isMacOS) {
        return await _detectSteamPathMacOS();
      } else if (Platform.isLinux) {
        return await _detectSteamPathLinux();
      }
    } catch (e) {
      LogService.e('[GamePathService] 检测Steam路径失败', e);
    }
    return null;
  }

  /// 尝试自动检测并保存游戏路径
  Future<bool> tryAutoDetectAndSaveGamePath() async {
    if (await hasGamePath()) {
      return true;
    }

    final detectedPath = await detectGamePath();
    if (detectedPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGamePath, detectedPath);
      LogService.i('[GamePathService] 已自动保存游戏路径: $detectedPath');
      return true;
    }

    return false;
  }

  /// 尝试自动检测并保存 Steam 路径
  Future<bool> tryAutoDetectAndSaveSteamPath() async {
    if (await hasSteamPath()) {
      return true;
    }

    final detectedPath = await detectSteamPath();
    if (detectedPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySteamPath, detectedPath);
      LogService.i('[GamePathService] 已自动保存Steam路径: $detectedPath');
      return true;
    }

    return false;
  }

  // ==================== 路径验证 ====================

  /// 验证游戏路径
  Future<PathValidationResult> validateGamePath(String path) async {
    if (path.isEmpty) {
      return const PathValidationResult(isValid: false, error: '路径不能为空');
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      return const PathValidationResult(isValid: false, error: '目录不存在');
    }

    // 检查是否包含 CS2 游戏文件
    if (Platform.isWindows) {
      final cs2Exe = File('$path\\game\\bin\\win64\\cs2.exe');
      if (!await cs2Exe.exists()) {
        return const PathValidationResult(
          isValid: false,
          error: '未找到CS2游戏文件，请确认选择的是正确的游戏安装目录',
        );
      }
    } else {
      // macOS / Linux
      final cfgDir = Directory('$path${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg');
      if (!await cfgDir.exists()) {
        return const PathValidationResult(
          isValid: false,
          error: '未找到游戏配置目录，请确认选择的是正确的游戏安装目录',
        );
      }
    }

    return const PathValidationResult(isValid: true);
  }

  /// 验证 Steam 路径
  Future<PathValidationResult> validateSteamPath(String path) async {
    if (path.isEmpty) {
      return const PathValidationResult(isValid: false, error: '路径不能为空');
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      return const PathValidationResult(isValid: false, error: '目录不存在');
    }

    // 检查是否包含 Steam 特征文件
    if (Platform.isWindows) {
      final steamExe = File('$path\\steam.exe');
      if (!await steamExe.exists()) {
        return const PathValidationResult(
          isValid: false,
          error: '未找到Steam程序，请确认选择的是正确的Steam安装目录',
        );
      }
    } else {
      final steamApps = Directory('$path/steamapps');
      if (!await steamApps.exists()) {
        return const PathValidationResult(
          isValid: false,
          error: '未找到steamapps目录，请确认选择的是正确的Steam安装目录',
        );
      }
    }

    return const PathValidationResult(isValid: true);
  }

  // ==================== 路径工具 ====================

  /// 获取 autoexec.cfg 文件路径
  Future<String?> getAutoexecPath() async {
    final gamePath = await getGamePath();
    if (gamePath == null || gamePath.isEmpty) {
      return null;
    }
    return '$gamePath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg${Platform.pathSeparator}autoexec.cfg';
  }

  /// 获取 cfg 目录路径
  Future<String?> getCfgDirPath() async {
    final gamePath = await getGamePath();
    if (gamePath == null || gamePath.isEmpty) {
      return null;
    }
    return '$gamePath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg';
  }

  // ==================== 私有方法 - Windows ====================

  Future<String?> _detectSteamPathWindows() async {
    // 常见 Steam 安装路径
    final commonPaths = [
      r'C:\Program Files (x86)\Steam',
      r'C:\Program Files\Steam',
      r'D:\Steam',
      r'D:\Program Files (x86)\Steam',
      r'E:\Steam',
      r'F:\Steam',
    ];

    for (final path in commonPaths) {
      final steamExe = File('$path\\steam.exe');
      if (await steamExe.exists()) {
        LogService.d('[GamePathService] 检测到Steam路径: $path');
        return path;
      }
    }

    // 尝试从注册表读取（通过环境变量）
    // Steam 通常会设置环境变量
    final programFiles = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final defaultPath = '$programFiles\\Steam';
    final steamExe = File('$defaultPath\\steam.exe');
    if (await steamExe.exists()) {
      return defaultPath;
    }

    return null;
  }

  Future<String?> _detectGamePathWindows(String steamPath) async {
    // CS2 默认安装路径
    final gamePath = '$steamPath\\steamapps\\common\\Counter-Strike Global Offensive';
    final cs2Exe = File('$gamePath\\game\\bin\\win64\\cs2.exe');

    if (await cs2Exe.exists()) {
      LogService.d('[GamePathService] 检测到游戏路径: $gamePath');
      return gamePath;
    }

    // 检查其他可能的 Steam 库文件夹
    final libraryFoldersFile = File('$steamPath\\steamapps\\libraryfolders.vdf');
    if (await libraryFoldersFile.exists()) {
      try {
        final content = await libraryFoldersFile.readAsString();
        final pathRegex = RegExp(r'"path"\s+"([^"]+)"');
        final matches = pathRegex.allMatches(content);

        for (final match in matches) {
          final libPath = match.group(1)?.replaceAll('\\\\', '\\');
          if (libPath != null && libPath != steamPath) {
            final altGamePath = '$libPath\\steamapps\\common\\Counter-Strike Global Offensive';
            final altCs2Exe = File('$altGamePath\\game\\bin\\win64\\cs2.exe');
            if (await altCs2Exe.exists()) {
              LogService.d('[GamePathService] 在Steam库中检测到游戏路径: $altGamePath');
              return altGamePath;
            }
          }
        }
      } catch (e) {
        LogService.d('[GamePathService] 解析Steam库文件夹失败: $e');
      }
    }

    return null;
  }

  // ==================== 私有方法 - macOS ====================

  Future<String?> _detectSteamPathMacOS() async {
    final home = Platform.environment['HOME'];
    if (home == null) return null;

    final commonPaths = [
      '$home/Library/Application Support/Steam',
      '/Users/Shared/Steam',
    ];

    for (final path in commonPaths) {
      final steamApps = Directory('$path/steamapps');
      if (await steamApps.exists()) {
        LogService.d('[GamePathService] 检测到Steam路径 (macOS): $path');
        return path;
      }
    }

    return null;
  }

  Future<String?> _detectGamePathMacOS(String steamPath) async {
    final gamePath = '$steamPath/steamapps/common/Counter-Strike Global Offensive';
    final gameDir = Directory(gamePath);

    if (await gameDir.exists()) {
      LogService.d('[GamePathService] 检测到游戏路径 (macOS): $gamePath');
      return gamePath;
    }
    return null;
  }

  // ==================== 私有方法 - Linux ====================

  Future<String?> _detectSteamPathLinux() async {
    final home = Platform.environment['HOME'];
    if (home == null) return null;

    final commonPaths = [
      '$home/.steam/steam',
      '$home/.local/share/Steam',
      '$home/.steam/debian-installation',
    ];

    for (final path in commonPaths) {
      final steamApps = Directory('$path/steamapps');
      if (await steamApps.exists()) {
        LogService.d('[GamePathService] 检测到Steam路径 (Linux): $path');
        return path;
      }
    }

    return null;
  }

  Future<String?> _detectGamePathLinux(String steamPath) async {
    final gamePath = '$steamPath/steamapps/common/Counter-Strike Global Offensive';
    final gameDir = Directory(gamePath);

    if (await gameDir.exists()) {
      LogService.d('[GamePathService] 检测到游戏路径 (Linux): $gamePath');
      return gamePath;
    }
    return null;
  }

  // ==================== 私有方法 - 通用 ====================

  /// 从常见路径列表检测
  Future<String?> _detectFromCommonPaths() async {
    final commonPaths = _getCommonGamePaths();

    for (final path in commonPaths) {
      String expandedPath = path;
      if (path.startsWith('~')) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          expandedPath = path.replaceFirst('~', home);
        }
      }

      final dir = Directory(expandedPath);
      if (await dir.exists()) {
        final cfgDir = Directory('$expandedPath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg');
        if (await cfgDir.exists()) {
          LogService.i('[GamePathService] 从常见路径检测到游戏: $expandedPath');
          return expandedPath;
        }
      }
    }

    LogService.d('[GamePathService] 未能从常见路径检测到游戏');
    return null;
  }

  List<String> _getCommonGamePaths() {
    if (Platform.isWindows) {
      return [
        r'C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive',
        r'C:\Program Files\Steam\steamapps\common\Counter-Strike Global Offensive',
        r'D:\Steam\steamapps\common\Counter-Strike Global Offensive',
        r'D:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive',
        r'E:\Steam\steamapps\common\Counter-Strike Global Offensive',
        r'E:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive',
        r'F:\Steam\steamapps\common\Counter-Strike Global Offensive',
        r'F:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/Users/Shared/Steam/steamapps/common/Counter-Strike Global Offensive',
        '~/Library/Application Support/Steam/steamapps/common/Counter-Strike Global Offensive',
      ];
    } else {
      return [
        '~/.steam/steam/steamapps/common/Counter-Strike Global Offensive',
        '~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive',
      ];
    }
  }
}
