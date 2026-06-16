import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';

/// WebView2 环境服务（仅桌面端 Windows 生效）
///
/// 默认情况下 WebView2 会把用户数据目录（缓存）创建在 exe 同级目录，
/// 当程序安装在 `Program Files` 等只读位置时会因无写入权限而失败。
///
/// 这里显式把 `userDataFolder` 指向项目缓存目录（我的文档/BakaBox/cache/webview2），
/// 保证始终可写。
///
/// 对于旧版本已在 exe 同级目录生成数据（登录态、Cookie 等）的用户，
/// 首次启动新版本时会自动把旧数据迁移到新目录，避免丢失登录状态。
class WebViewEnvironmentService {
  WebViewEnvironmentService._();

  static WebViewEnvironment? _environment;
  static bool _initialized = false;

  /// 全局共享的 WebView 环境，非 Windows 平台为 null
  static WebViewEnvironment? get environment => _environment;

  /// 获取绑定了自定义环境的 [CookieManager]。
  ///
  /// 必须使用此方法而非直接调用 `CookieManager.instance()`：
  /// 在 Windows 上，`CookieManager.instance()` 不带 `webViewEnvironment`
  /// 时，插件会回退创建「默认 WebView2 环境」（userDataFolder 为 null），
  /// WebView2 会在 exe 同级目录生成 `<exe名>.exe.WebView2` 缓存目录，
  /// 安装在 Program Files 等只读位置时还会写入失败。
  ///
  /// 显式传入共享环境，确保 Cookie 操作复用同一份可写缓存目录。
  static CookieManager get cookieManager =>
      CookieManager.instance(webViewEnvironment: _environment);

  /// 初始化 WebView 环境
  ///
  /// 必须在创建任何 [InAppWebView] 之前调用，
  /// 且需在 [AppDirectoryService.init] 之后调用。
  static Future<void> init() async {
    if (_initialized) return;
    // 仅 Windows 需要自定义 userDataFolder
    if (!PlatformUtils.isDesktopPlatform || !Platform.isWindows) {
      _initialized = true;
      return;
    }

    try {
      final sep = Platform.pathSeparator;
      final targetPath = '${AppDirectoryService.cachePath}${sep}webview2';
      final targetDir = Directory(targetPath);

      // 仅当新目录还没有任何数据时，才尝试迁移旧数据。
      // 迁移完成或已生成数据后，后续启动都会跳过。
      if (!await _hasData(targetDir)) {
        await _migrateLegacyDataIfNeeded(targetDir);
      }

      // 确保目标目录存在（迁移未发生或失败时）
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      _environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: targetPath),
      );
      LogService.i('WebView2 缓存目录: $targetPath');
    } catch (e) {
      // 初始化失败不阻塞启动，WebView 将回退到默认目录
      LogService.e('WebView 环境初始化失败', e);
    } finally {
      _initialized = true;
    }
  }

  /// 目录是否存在且非空（含有实际数据）
  static Future<bool> _hasData(Directory dir) async {
    if (!await dir.exists()) return false;
    final it = dir.list(followLinks: false);
    await for (final _ in it) {
      return true;
    }
    return false;
  }

  /// 迁移旧版本 WebView2 数据
  ///
  /// 旧版本未指定 userDataFolder，WebView2 会在 exe 同级目录生成
  /// `<exe文件名>.WebView2` 目录（如 `bakabox_app.exe.WebView2`）。
  ///
  /// 迁移采用「先搬到临时暂存目录、成功后原子重命名为正式目录」的方式，
  /// 保证即使复制中途失败，也不会留下半成品的正式目录导致状态损坏。
  static Future<void> _migrateLegacyDataIfNeeded(Directory targetDir) async {
    final sep = Platform.pathSeparator;
    Directory? staging;
    try {
      // 计算旧默认目录：<exe所在目录>/<exe文件名>.WebView2
      final exePath = Platform.resolvedExecutable;
      final lastSep = exePath.lastIndexOf(sep);
      final exeDir = exePath.substring(0, lastSep);
      final exeName = exePath.substring(lastSep + 1);
      final legacyDir = Directory('$exeDir$sep$exeName.WebView2');

      // 旧目录不存在或为空 → 无需迁移
      if (!await _hasData(legacyDir)) return;

      LogService.i(
        '检测到旧 WebView2 数据，开始迁移: ${legacyDir.path} -> ${targetDir.path}',
      );

      // 优先尝试同盘 rename（原子、瞬时完成）。
      // rename 要求目标不存在；此处 targetDir 必为空或不存在（_hasData 已判过）。
      try {
        if (await targetDir.exists()) {
          await targetDir.delete(recursive: true);
        }
        await legacyDir.rename(targetDir.path);
        LogService.i('WebView2 数据迁移完成（rename）');
        return;
      } on FileSystemException {
        // 跨盘等情况 rename 失败，回退到「暂存目录 + 复制 + 原子重命名」
      }

      // 暂存目录与正式目录同级，确保最终 rename 为同盘原子操作
      staging = Directory('${targetDir.path}.migrating');
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      await staging.create(recursive: true);

      await _copyDirectory(legacyDir, staging);

      // 复制完整成功后，再原子切换为正式目录
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await staging.rename(targetDir.path);
      staging = null;

      // 正式目录就绪后删除旧目录。迁移此刻发生在 WebView2 环境创建之前，
      // 旧目录不会被本进程占用，正常都能删掉；个别文件被系统短暂占用时
      // 通过重试兜底，最终仍失败则记录警告（不影响功能）。
      await _deleteWithRetry(legacyDir);

      LogService.i('WebView2 数据迁移完成（copy）');
    } catch (e) {
      // 迁移失败不阻塞启动，最多是用户需要重新登录一次。
      // 清理可能残留的暂存目录，避免占用空间。
      if (staging != null) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {}
      }
      LogService.e('WebView2 数据迁移失败', e);
    }
  }

  /// 删除目录，带少量重试（应对文件被系统短暂占用的情况）
  static Future<void> _deleteWithRetry(Directory dir) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        return;
      } on FileSystemException catch (e) {
        if (attempt == 2) {
          LogService.w('删除旧 WebView2 目录失败（已迁移，可手动清理）: ${dir.path}', e);
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// 递归复制目录内容
  static Future<void> _copyDirectory(Directory source, Directory dest) async {
    final sep = Platform.pathSeparator;
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final name = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;
      final newPath = '${dest.path}$sep$name';
      if (entity is Directory) {
        final newDir = Directory(newPath);
        await newDir.create(recursive: true);
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}
