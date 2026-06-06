import 'dart:io';
import 'dart:async';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 路径失效类型
enum InvalidPathType {
  game, // 游戏路径失效
  steam, // Steam 路径失效
}

/// 游戏路径验证结果
class PathValidationResult {
  final bool isValid;
  final String? error;
  // 当 isValid=false 时，标识具体哪条路径失效（仅在 verifyCurrentPaths 中填充）
  final InvalidPathType? invalidType;

  const PathValidationResult({
    required this.isValid,
    this.error,
    this.invalidType,
  });
}

/// 游戏路径服务 - 统一管理 CS2 和 Steam 路径的检测、验证、存储
class GamePathService {
  static final GamePathService _instance = GamePathService._internal();
  factory GamePathService() => _instance;
  GamePathService._internal();

  static const String _keyGamePath = 'game_path';
  static const String _keySteamPath = 'steam_path';

  // 路径失效事件流
  final _pathInvalidController =
      StreamController<PathValidationResult>.broadcast();
  Stream<PathValidationResult> get onPathInvalidStream =>
      _pathInvalidController.stream;

  // ==================== 路径获取 ====================

  /// 获取游戏路径
  Future<String?> getGamePath() async {
    return StorageUtils.getString(_keyGamePath);
  }

  /// 获取 Steam 路径
  Future<String?> getSteamPath() async {
    return StorageUtils.getString(_keySteamPath);
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

    await StorageUtils.setString(_keyGamePath, path);
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

    await StorageUtils.setString(_keySteamPath, path);
    LogService.i('[GamePathService] Steam路径已设置: $path');
    return true;
  }

  /// 清除游戏路径
  Future<void> clearGamePath() async {
    await StorageUtils.remove(_keyGamePath);
    LogService.i('[GamePathService] 游戏路径已清除');
  }

  /// 清除 Steam 路径
  Future<void> clearSteamPath() async {
    await StorageUtils.remove(_keySteamPath);
    LogService.i('[GamePathService] Steam路径已清除');
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
      final cfgDir = Directory(
        '$path${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg',
      );
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

  /// 验证当前存储的路径是否仍然有效（用于检测移动目录或更换硬盘的情况）
  /// 如果只传入了部分路径配置，则只验证已配置的。如果全部未配置，视为"没有失效"（因为本来就没有）。
  Future<PathValidationResult> verifyCurrentPaths() async {
    final gamePath = await getGamePath();
    final steamPath = await getSteamPath();

    // 如果都没配置，则不存在"路径失效"的问题
    if ((gamePath == null || gamePath.isEmpty) &&
        (steamPath == null || steamPath.isEmpty)) {
      return const PathValidationResult(isValid: true);
    }

    PathValidationResult? gameFailure;
    PathValidationResult? steamFailure;

    if (gamePath != null && gamePath.isNotEmpty) {
      final result = await validateGamePath(gamePath);
      if (!result.isValid) {
        gameFailure = PathValidationResult(
          isValid: false,
          error: '游戏路径已失效: ${result.error}',
          invalidType: InvalidPathType.game,
        );
      }
    }

    if (steamPath != null && steamPath.isNotEmpty) {
      final result = await validateSteamPath(steamPath);
      if (!result.isValid) {
        steamFailure = PathValidationResult(
          isValid: false,
          error: 'Steam路径已失效: ${result.error}',
          invalidType: InvalidPathType.steam,
        );
      }
    }

    // 没有任何失效
    if (gameFailure == null && steamFailure == null) {
      return const PathValidationResult(isValid: true);
    }

    // 仅一项失效：返回该项的具体类型
    if (gameFailure != null && steamFailure == null) {
      _pathInvalidController.add(gameFailure);
      return gameFailure;
    }
    if (steamFailure != null && gameFailure == null) {
      _pathInvalidController.add(steamFailure);
      return steamFailure;
    }

    // 双项失效：合并错误信息，invalidType 留空表示两者都失效（消费者应通过细分字段判断）
    final combined = PathValidationResult(
      isValid: false,
      error: '${gameFailure!.error}\n${steamFailure!.error}',
    );
    _pathInvalidController.add(combined);
    return combined;
  }

  /// 单独检查游戏路径是否仍然有效（不发流，仅用于细分判断）
  Future<bool> isGamePathStillValid() async {
    try {
      final path = await getGamePath();
      if (path == null || path.isEmpty) return true; // 未配置视为不失效
      final result = await validateGamePath(path);
      return result.isValid;
    } catch (e) {
      // 网络盘断开、未挂载磁盘、IO 错误等：视为失效，让上层提示用户
      LogService.w('[GamePathService] 校验游戏路径时发生异常，视为失效: $e');
      return false;
    }
  }

  /// 单独检查 Steam 路径是否仍然有效（不发流，仅用于细分判断）
  Future<bool> isSteamPathStillValid() async {
    try {
      final path = await getSteamPath();
      if (path == null || path.isEmpty) return true; // 未配置视为不失效
      final result = await validateSteamPath(path);
      return result.isValid;
    } catch (e) {
      LogService.w('[GamePathService] 校验Steam路径时发生异常，视为失效: $e');
      return false;
    }
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
}
