import 'dart:io';

import '../services/crash_inspector/crash_inspector.dart';
import '../services/game_path_service.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
/// 本地崩溃文件扫描服务
///
/// 扫描 `<gamePath>\game\bin\win64\*.mdmp`，仅 Windows 桌面端可用。
class LocalCrashService {
  static final LocalCrashService _instance = LocalCrashService._internal();
  factory LocalCrashService() => _instance;
  LocalCrashService._internal();

  final GamePathService _gamePathService = GamePathService();

  /// 当前是否已配置 CS2 游戏路径。
  Future<bool> hasGamePath() => _gamePathService.hasGamePath();

  /// 列出本地崩溃文件元信息（不解析）。
  Future<List<LocalCrashFileInfo>> listLocalDumps() async {
    if (!PlatformUtils.isDesktopPlatform || !Platform.isWindows) {
      return const [];
    }
    final dir = await _resolveDumpDir();
    if (dir == null) return const [];
    final dumpDir = Directory(dir);
    if (!await dumpDir.exists()) return const [];

    final results = <LocalCrashFileInfo>[];
    try {
      await for (final entity in dumpDir.list(followLinks: false)) {
        if (entity is File &&
            entity.path.toLowerCase().endsWith('.mdmp')) {
          try {
            final stat = await entity.stat();
            results.add(
              LocalCrashFileInfo(
                path: entity.path,
                fileName: _basename(entity.path),
                size: stat.size,
                modified: stat.modified,
              ),
            );
          } catch (e) {
            LogService.w('[LocalCrash] stat 失败 ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      LogService.w('[LocalCrash] 列举 .mdmp 失败: $e');
    }
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  /// 解析单个 mdmp，返回 UI 摘要。
  Future<CrashSummary> analyze(String path) async {
    return CrashInspector.analyze(path);
  }

  /// 删除单个 mdmp 文件。
  Future<bool> deleteDump(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (e) {
      LogService.w('[LocalCrash] 删除 mdmp 失败: $e');
      return false;
    }
  }

  Future<String?> _resolveDumpDir() async {
    final gamePath = await _gamePathService.getGamePath();
    if (gamePath == null || gamePath.isEmpty) return null;
    return '$gamePath\\game\\bin\\win64';
  }

  String _basename(String p) {
    var idx = -1;
    for (var i = p.length - 1; i >= 0; i--) {
      final c = p[i];
      if (c == '/' || c == '\\') {
        idx = i;
        break;
      }
    }
    return idx >= 0 ? p.substring(idx + 1) : p;
  }
}

/// 本地 mdmp 文件元信息（未解析时的轻量条目）。
class LocalCrashFileInfo {
  final String path;
  final String fileName;
  final int size;
  final DateTime modified;

  const LocalCrashFileInfo({
    required this.path,
    required this.fileName,
    required this.size,
    required this.modified,
  });
}
