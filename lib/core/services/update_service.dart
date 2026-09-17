import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/env_config.dart';
import '../api/update_api.dart';
import '../exceptions/app_exception.dart';
import '../models/update_models.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';
import '../utils/log_service.dart';
import '../utils/version_utils.dart';
import 'app_info_service.dart';
import 'floating_window_service.dart';
import 'notification_window_service.dart';

/// 更新异常
class UpdateException implements AppException {
  @override
  final String message;

  const UpdateException(this.message);
}

/// 下载被用户取消异常
class UpdateCancelledException implements AppException {
  @override
  final String message;

  const UpdateCancelledException([this.message = '下载已取消']);
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();

  factory UpdateService() {
    return _instance;
  }

  UpdateService._internal() {
    _startQueueWorker();
  }

  final UpdateApi _updateApi = UpdateApi();
  static const String _keyLastCheckTime = 'last_update_check_time';
  static const String _keyPendingInstallVersion = 'pending_install_version';
  static const String _keyPendingInstallFromVersion =
      'pending_install_from_version';
  static const String _keyPendingReports = 'pending_update_reports';
  static const String _keyLastKnownVersion = 'update_last_known_version';
  static const int _minCheckIntervalHours = 6;

  /// 当前下载的取消令牌，用户取消下载时调用 [cancelDownload]
  CancelToken? _downloadCancelToken;

  /// 轮询队列的定时器
  Timer? _queueWorkerTimer;

  /// 取消当前正在进行的下载
  void cancelDownload() {
    if (_downloadCancelToken != null && !_downloadCancelToken!.isCancelled) {
      _downloadCancelToken!.cancel('用户取消下载');
    }
  }

  /// 启动后台上报队列轮询
  void _startQueueWorker() {
    _queueWorkerTimer?.cancel();
    _queueWorkerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final pendingList = StorageUtils.getStringList(_keyPendingReports);
      if (pendingList.isNotEmpty) {
        flushPendingReports().ignore();
      }
    });
  }

  /// 检查并上报安装结果（应用启动时调用）
  ///
  /// 原理（彻底重构版，100% 准确）：
  /// 1. 每次启动读取本地存储的最后一次运行版本（[_keyLastKnownVersion]）。
  /// 2. 只要检测到当前版本 > 最后运行版本，视为发生过升级，立刻上报 `install_success`。
  ///    - 该机制脱离了"App内更新"的绑定，即使用户去官网下载包手动覆盖安装，也能100%准确上报成功。
  /// 3. 如果当前版本未变化，但依然存在 `pendingVersion` 标记，说明用户发起了 App 内更新但最终并未安装。
  ///    - 此时上报 `install_verify_failed`。
  /// 4. 仲裁完成后，将当前版本持久化写入 `lastKnownVersion`，并清除所有 `pending` 标记。
  Future<void> checkAndReportInstallSuccess() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // 获取完整版本号，确保包含 build 号
      String actualCurrentVersion = packageInfo.version;
      if (AppInfoService.instance.isInitialized) {
        actualCurrentVersion = AppInfoService.instance.fullVersion;
      } else {
        actualCurrentVersion =
            '${packageInfo.version}+${packageInfo.buildNumber}';
      }

      final platform = PlatformUtils.isDesktopPlatform ? 'desktop' : 'mobile';
      final os = Platform.operatingSystem;

      // 读取待安装版本号和最后的已知版本号
      final pendingVersion = StorageUtils.getString(_keyPendingInstallVersion);
      final fromVersion = StorageUtils.getString(_keyPendingInstallFromVersion);

      // 如果 lastKnownVersion 为空（例如从旧版本首次升级上来），尝试使用 fromVersion 作为替代
      final lastKnownVersion =
          StorageUtils.getString(_keyLastKnownVersion) ?? fromVersion;

      bool versionChanged = false;

      // 判断基于 lastKnownVersion 的绝对版本变化
      if (lastKnownVersion != null &&
          actualCurrentVersion != lastKnownVersion) {
        int cmp = -1;
        try {
          cmp = VersionUtils.compareVersion(
            actualCurrentVersion,
            lastKnownVersion,
          );
        } catch (_) {
          cmp = actualCurrentVersion == lastKnownVersion ? 0 : -1;
        }

        if (cmp > 0) {
          // 确定发生了升级，统一使用真实的当前版本（包含构建号）作为汇报目标
          final targetVersion = actualCurrentVersion;

          LogService.i(
            '[UpdateService] 检测到应用升级: $lastKnownVersion -> $actualCurrentVersion (汇报目标: $targetVersion)',
          );

          await _enqueueReport(
            UpdateReportRequest(
              platform: platform,
              os: os,
              fromVersion: lastKnownVersion,
              toVersion: targetVersion,
              status: 'install_success',
              errorMessage: null,
            ),
          );
          versionChanged = true;
        } else {
          // 发生了降级（用户手动覆盖了老包）
          LogService.w(
            '[UpdateService] 检测到应用降级: $lastKnownVersion -> $actualCurrentVersion',
          );
          versionChanged = true;
        }
      }

      // 如果版本没有发生变化，但存在 pendingVersion 标记，说明"发起了更新但没成功安装"
      if (!versionChanged && pendingVersion != null) {
        LogService.w(
          '[UpdateService] 检测到应用内更新未生效: '
          '待安装 $pendingVersion，当前仍是 $actualCurrentVersion',
        );
        await _enqueueReport(
          UpdateReportRequest(
            platform: platform,
            os: os,
            fromVersion: fromVersion ?? actualCurrentVersion,
            toVersion: pendingVersion,
            status: 'install_verify_failed',
            errorMessage:
                'Pending version $pendingVersion, but current is $actualCurrentVersion',
          ),
        );
      }

      // 无论如何，更新最后已知版本，并清理遗留的 pending 标记
      await StorageUtils.setString(_keyLastKnownVersion, actualCurrentVersion);
      if (pendingVersion != null) {
        await _clearPendingInstallMarkers();
      }

      // 稍微延迟 3 秒尝试执行一次刷新，即便这次失败，也会有每 30 秒的 _queueWorkerTimer 兜底
      Future.delayed(const Duration(seconds: 3), () {
        flushPendingReports().ignore();
      });
    } catch (e) {
      LogService.e('[UpdateService] 检查更新安装结果失败', e);
    }
  }

  /// 检查更新
  Future<AppUpdateInfo> checkForUpdate() async {
    // 商店版本不支持手动更新
    if (PlatformUtils.isInstalledFromStore) {
      throw const UpdateException('商店版本由 Microsoft Store 自动更新');
    }

    // 每次检查更新时，顺便尝试清空积压的上报队列（此时网络大概率可用）
    flushPendingReports().ignore();

    final updateInfo = await _updateApi.checkForUpdate();
    await _updateLastCheckTime();
    return updateInfo;
  }

  /// 自动检查更新（带间隔限制）
  Future<AppUpdateInfo?> autoCheckForUpdate() async {
    // 开发/测试模式不主动检查更新
    if (EnvConfig.isDev) {
      return null;
    }

    // 商店版本不需要自动检查更新
    if (PlatformUtils.isInstalledFromStore) {
      return null;
    }

    try {
      final shouldCheck = await _shouldCheckForUpdate();
      if (!shouldCheck) {
        return null;
      }
      final updateInfo = await checkForUpdate();
      return updateInfo.hasUpdate ? updateInfo : null;
    } catch (e) {
      // 自动检查失败时返回 null，不抛出异常，避免影响应用启动
      // 用户可以稍后手动检查更新
      return null;
    }
  }

  /// 仅下载更新（不安装）
  Future<String> downloadUpdate(
    AppUpdateInfo updateInfo,
    void Function(DownloadProgress) onProgress,
  ) async {
    // iOS 不支持直接下载安装包，应走 downloadAndInstallUpdate 跳转下载页
    if (PlatformUtils.isIOS) {
      throw const UpdateException('iOS 请前往下载页面更新');
    }

    if (updateInfo.downloadUrl == null &&
        updateInfo.fallbackDownloadUrl == null) {
      throw const UpdateException('下载地址不可用');
    }

    final directory = await getTemporaryDirectory();
    final fileName = _getFileNameFromUrl(
      updateInfo.downloadUrl ?? updateInfo.fallbackDownloadUrl!,
    );
    final savePath = '${directory.path}/$fileName';

    // 为本次下载创建取消令牌
    final cancelToken = CancelToken();
    _downloadCancelToken = cancelToken;

    String downloadedFilePath;
    try {
      downloadedFilePath = await _downloadWithFallback(
        updateInfo: updateInfo,
        savePath: savePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // 用户主动取消：清理半成品文件，抛出取消异常由上层识别
        await _deleteFileQuietly(savePath);
        throw const UpdateCancelledException();
      }
      await _reportResult(
        updateInfo,
        'download_failed',
        errorMessage: _getErrorMessageForReport(e),
      );
      rethrow;
    } catch (e) {
      // 取消可能被包装成 UpdateException 抛出
      if (cancelToken.isCancelled) {
        await _deleteFileQuietly(savePath);
        throw const UpdateCancelledException();
      }
      await _reportResult(
        updateInfo,
        'download_failed',
        errorMessage: _getErrorMessageForReport(e),
      );
      rethrow;
    } finally {
      _downloadCancelToken = null;
    }

    // 校验文件MD5（下载成功后单独处理，不归入 download_failed）
    if (updateInfo.fileMd5 != null) {
      final isValid = await _verifyFileMd5(
        downloadedFilePath,
        updateInfo.fileMd5!,
      );
      // isValid == false 校验不通过；isValid == null 表示 IO 读取失败，
      // 文件状态未知，同样视为不可信，避免安装损坏/不完整的文件。
      if (isValid != true) {
        await _deleteFileQuietly(downloadedFilePath);
        await _reportResult(updateInfo, 'verify_failed');
        throw UpdateException(
          isValid == false ? '文件完整性校验失败\n下载的文件可能已损坏，请重新下载' : '无法校验文件完整性\n请重新下载',
        );
      }
    }

    // 上报下载成功
    await _reportResult(updateInfo, 'download_success');

    return downloadedFilePath;
  }

  /// 安装已下载的更新
  Future<void> installUpdate(String filePath, AppUpdateInfo? updateInfo) async {
    try {
      // 记录待安装版本号（用于下次启动时检测安装成功）
      if (updateInfo != null) {
        await StorageUtils.setString(
          _keyPendingInstallVersion,
          updateInfo.latestVersion,
        );
        await StorageUtils.setString(
          _keyPendingInstallFromVersion,
          updateInfo.currentVersion,
        );
      }

      // 在安装前上报（Windows 会立即退出，必须提前上报）
      if (updateInfo != null) {
        await _reportResult(updateInfo, 'install_started');
      }
      await _installUpdate(filePath);
    } catch (e) {
      // 安装启动失败：清除待安装标记，避免下次启动误报安装成功
      await _clearPendingInstallMarkers();
      // 上报安装启动失败
      if (updateInfo != null) {
        await _reportResult(
          updateInfo,
          'install_failed',
          errorMessage: _getErrorMessageForReport(e),
        );
      }
      rethrow;
    }
  }

  /// 下载并安装更新
  Future<void> downloadAndInstallUpdate(
    AppUpdateInfo updateInfo,
    void Function(DownloadProgress) onProgress,
  ) async {
    // iOS 跳转下载页面
    if (PlatformUtils.isIOS) {
      final url = updateInfo.downloadUrl ?? updateInfo.fallbackDownloadUrl;
      if (url == null) {
        throw const UpdateException('下载地址不可用');
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (updateInfo.downloadUrl == null &&
        updateInfo.fallbackDownloadUrl == null) {
      throw const UpdateException('下载地址不可用');
    }

    final directory = await getTemporaryDirectory();
    final fileName = _getFileNameFromUrl(
      updateInfo.downloadUrl ?? updateInfo.fallbackDownloadUrl!,
    );
    final savePath = '${directory.path}/$fileName';

    // 为本次下载创建取消令牌
    final cancelToken = CancelToken();
    _downloadCancelToken = cancelToken;

    // 下载文件（主地址失败时自动切换备用地址）
    final String filePath;
    try {
      filePath = await _downloadWithFallback(
        updateInfo: updateInfo,
        savePath: savePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        await _deleteFileQuietly(savePath);
        throw const UpdateCancelledException();
      }
      await _reportResult(
        updateInfo,
        'download_failed',
        errorMessage: _getErrorMessageForReport(e),
      );
      rethrow;
    } catch (e) {
      if (cancelToken.isCancelled) {
        await _deleteFileQuietly(savePath);
        throw const UpdateCancelledException();
      }
      await _reportResult(
        updateInfo,
        'download_failed',
        errorMessage: _getErrorMessageForReport(e),
      );
      rethrow;
    } finally {
      _downloadCancelToken = null;
    }

    // 校验文件MD5（下载成功后单独处理，不归入 download_failed）
    if (updateInfo.fileMd5 != null) {
      final isValid = await _verifyFileMd5(filePath, updateInfo.fileMd5!);
      // isValid == null（IO 读取失败）同样视为不可信，不放行安装
      if (isValid != true) {
        await _deleteFileQuietly(filePath);
        await _reportResult(updateInfo, 'verify_failed');
        throw UpdateException(
          isValid == false ? '文件完整性校验失败\n下载的文件可能已损坏，请重新下载' : '无法校验文件完整性\n请重新下载',
        );
      }
    }

    // 上报下载成功
    await _reportResult(updateInfo, 'download_success');

    try {
      // 记录待安装版本号（用于下次启动时检测安装成功）
      await StorageUtils.setString(
        _keyPendingInstallVersion,
        updateInfo.latestVersion,
      );
      await StorageUtils.setString(
        _keyPendingInstallFromVersion,
        updateInfo.currentVersion,
      );

      // 在安装前上报（Windows 会立即退出，必须提前上报）
      await _reportResult(updateInfo, 'install_started');
      await _installUpdate(filePath);
    } catch (e) {
      // 安装启动失败：清除待安装标记，避免下次启动误报安装成功
      await _clearPendingInstallMarkers();
      await _reportResult(
        updateInfo,
        'install_failed',
        errorMessage: _getErrorMessageForReport(e),
      );
      if (e is UpdateException) rethrow;
      throw const UpdateException('安装失败，请手动运行安装包');
    }
  }

  /// 打开应用商店
  Future<void> openAppStore(AppUpdateInfo? updateInfo) async {
    String? url;

    if (updateInfo?.downloadUrl != null) {
      url = updateInfo!.downloadUrl;
    }

    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// 上报用户取消更新（下载中取消）
  Future<void> reportCancelled(AppUpdateInfo updateInfo) async {
    try {
      await _reportResult(updateInfo, 'cancelled');
    } catch (e) {
      // 上报失败静默处理
    }
  }

  /// 上报用户跳过更新（关闭对话框）
  Future<void> reportSkipped(AppUpdateInfo updateInfo) async {
    try {
      await _reportResult(updateInfo, 'skipped');
    } catch (e) {
      // 上报失败静默处理
    }
  }

  /// 是否应该检查更新（间隔限制）
  Future<bool> _shouldCheckForUpdate() async {
    final lastCheckTime = StorageUtils.getInt(_keyLastCheckTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedHours = (now - lastCheckTime) / (1000 * 60 * 60);
    return elapsedHours >= _minCheckIntervalHours;
  }

  /// 更新最后检查时间
  Future<void> _updateLastCheckTime() async {
    await StorageUtils.setInt(
      _keyLastCheckTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 从URL提取文件名
  String _getFileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (fileName.isNotEmpty) return fileName;

    // 根据平台返回默认文件名
    if (PlatformUtils.isAndroid) return 'bakabox_update.apk';
    if (PlatformUtils.isWindows) return 'bakabox_update.exe';
    return 'bakabox_update';
  }

  /// 下载文件，主地址失败时自动切换备用地址
  Future<String> _downloadWithFallback({
    required AppUpdateInfo updateInfo,
    required String savePath,
    required void Function(DownloadProgress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final primaryUrl = updateInfo.downloadUrl;
    final fallbackUrl = updateInfo.fallbackDownloadUrl;

    if ((primaryUrl == null || primaryUrl.isEmpty) &&
        (fallbackUrl == null || fallbackUrl.isEmpty)) {
      throw const UpdateException('下载地址不可用');
    }

    Object? firstTryError;

    // 第一阶段：尝试使用当前已有的地址进行下载（优先主地址）
    try {
      final initialUrl = (primaryUrl != null && primaryUrl.isNotEmpty)
          ? primaryUrl
          : fallbackUrl!;
      return await _updateApi.downloadUpdate(
        initialUrl,
        savePath,
        onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      // 用户主动取消，不再重试，直接向上抛出
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      if (cancelToken != null && cancelToken.isCancelled) rethrow;

      firstTryError = e;
      LogService.w('[UpdateService] 首次下载尝试失败', e);

      // 删除可能存在的不完整文件
      await _deleteFileQuietly(savePath);
    }

    // 第二阶段：重新获取更新信息以刷新链接，进行最后一次尝试
    try {
      LogService.i('[UpdateService] 重新获取更新信息以刷新备用地址鉴权');
      final freshUpdateInfo = await _updateApi.checkForUpdate();

      // 如果应用更新被后端紧急撤回
      if (!freshUpdateInfo.hasUpdate) {
        throw const UpdateException('当前更新已被服务器撤回，请稍后再试');
      }

      String? urlToUse;

      if (primaryUrl != null && primaryUrl.isNotEmpty) {
        // 如果刚才失败的是主地址，这次优先尝试新的备用地址
        urlToUse = freshUpdateInfo.fallbackDownloadUrl;
        // 如果新备用地址为空，兜底试试新主地址
        if (urlToUse == null || urlToUse.isEmpty) {
          urlToUse = freshUpdateInfo.downloadUrl;
        }
      } else {
        // 如果刚才失败的直接就是备用地址，那依然尝试刷新后的新备用地址
        urlToUse = freshUpdateInfo.fallbackDownloadUrl;
      }

      // 极端兜底
      if (urlToUse == null || urlToUse.isEmpty) {
        urlToUse = fallbackUrl ?? primaryUrl;
      }

      if (urlToUse == null || urlToUse.isEmpty) {
        throw const UpdateException('无法获取有效的备用下载地址');
      }

      return await _updateApi.downloadUpdate(
        urlToUse,
        savePath,
        onProgress,
        cancelToken: cancelToken,
      );
    } catch (e2) {
      // 用户主动取消，不再包装成下载失败异常
      if (e2 is DioException && CancelToken.isCancel(e2)) rethrow;
      if (cancelToken != null && cancelToken.isCancelled) rethrow;

      LogService.e('[UpdateService] 刷新地址后下载依然失败', e2);
      throw UpdateException(
        '首次尝试失败: ${_getErrorMessageForReport(firstTryError)}\n重试也失败: ${_getErrorMessageForReport(e2)}',
      );
    }
  }

  /// 静默删除文件（忽略所有异常）
  Future<void> _deleteFileQuietly(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// 清除待安装标记
  Future<void> _clearPendingInstallMarkers() async {
    try {
      await StorageUtils.remove(_keyPendingInstallVersion);
      await StorageUtils.remove(_keyPendingInstallFromVersion);
    } catch (_) {}
  }

  /// 校验文件MD5，返回 null 表示无法读取文件（IO 错误）
  Future<bool?> _verifyFileMd5(String filePath, String expectedMd5) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString().toLowerCase() == expectedMd5.toLowerCase();
    } catch (e) {
      LogService.e('[UpdateService] MD5 校验读取文件失败', e);
      return null; // IO 错误，无法判断文件是否完整
    }
  }

  /// 安装更新
  Future<void> _installUpdate(String filePath) async {
    if (PlatformUtils.isAndroid) {
      await _installAndroidApk(filePath);
    } else if (PlatformUtils.isWindows) {
      await _installWindowsExe(filePath);
    } else if (PlatformUtils.isDesktopPlatform) {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  /// 安装 Windows EXE（静默模式，强制走 UAC 提权）
  ///
  /// 为什么必须显式提权：
  /// - BakaBox 主 exe 的 manifest 是 asInvoker（普通权限运行）
  /// - NSIS 安装器 manifest 是 requireAdministrator
  /// - 从普通权限进程直接 Process.start 一个 requireAdministrator 的 exe，
  ///   底层 CreateProcess 会返回 ERROR_ELEVATION_REQUIRED (740)
  /// - 之前依赖 cmd /c start 的 ShellExecute 隐式提权在部分环境下（企业 GPO、
  ///   某些 AV、精简版 Windows）会静默失败：既不弹 UAC 也没错误
  /// - PowerShell 的 Start-Process -Verb RunAs 底层是 ShellExecuteEx，
  ///   会显式触发 UAC 交互，可靠性高
  ///
  /// 流程：
  /// 1. PowerShell 显式触发 UAC，await 等用户交互结果
  /// 2. 用户点"是" → 提权安装器启动 → 关闭子窗口 → exit(0)
  /// 3. 用户点"否"/超时 → 抛清晰错误，子窗口保持完好
  /// 4. 兜底：如果 PowerShell 不可用（罕见），退回直接 Process.start
  Future<void> _installWindowsExe(String exePath) async {
    // 优先：PowerShell RunAs（可靠的 UAC 提权）
    final elevated = await _tryStartInstallerElevated(exePath);
    if (elevated) {
      await _finalizeExitForInstaller();
      return;
    }

    // PowerShell 路径失败：可能是用户拒绝 UAC，也可能是极端环境（无 PowerShell、
    // 被组策略禁用、超时等）。尝试直接 Process.start 作为兜底 —— 只有当
    // BakaBox 本身以管理员身份运行时才能成功。这样已提权用户不会被完全挡住。
    try {
      await Process.start(exePath, ['/S'], mode: ProcessStartMode.detached);
      await _finalizeExitForInstaller();
      return;
    } catch (e) {
      LogService.w('[UpdateService] 直接启动 installer 也失败: $e');
    }

    // 所有自动路径都失败：给用户一个明确的错误提示。
    // 不再尝试 launchUrl —— 它同样需要 UAC，用户很可能刚拒绝过。
    throw const UpdateException('管理员授权被取消或启动失败，请重试');
  }

  /// 通过 PowerShell 的 Start-Process -Verb RunAs 触发 UAC 提权启动安装器。
  ///
  /// 阻塞等待 UAC 交互结果：
  /// - 用户点"是" → 返回 true，安装器已 spawn 为独立提权进程
  /// - 用户点"否" → 返回 false
  /// - PowerShell 不可用/被禁用/超时 → 返回 false
  ///
  /// 关键：**不使用 detached 模式**，await PowerShell 的 exit code
  /// 来判断结果。这样如果用户拒绝 UAC，我们能立即知道并抛错，不会误关
  /// 用户的子窗口，也不会在桌面上留一个孤儿 UAC 弹窗（主窗口已关）。
  Future<bool> _tryStartInstallerElevated(String exePath) async {
    Process process;
    try {
      // 转义 exePath 中的单引号，防止破坏 PowerShell 单引号字符串语法
      // （getTemporaryDirectory 返回的路径通常不含单引号，但以防万一）
      final escaped = exePath.replaceAll("'", "''");
      // -Verb RunAs 触发 UAC
      // -WindowStyle Hidden 让安装器不弹自己的窗口
      // -ErrorAction Stop 让 UAC 拒绝的错误能被 catch 捕获
      // try/catch 让 UAC 拒绝或其他错误以退出码 1 结束
      final psCommand =
          "try { "
          "Start-Process -FilePath '$escaped' -ArgumentList '/S' "
          "-Verb RunAs -WindowStyle Hidden -ErrorAction Stop; "
          "exit 0 "
          "} catch { exit 1 }";

      process = await Process.start('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        psCommand,
      ]);
    } catch (e) {
      // PowerShell 本身启动失败（极端环境：Windows Nano Server、
      // 组策略禁止 PowerShell、系统损坏等）
      LogService.w('[UpdateService] PowerShell 启动失败: $e');
      return false;
    }

    // 等待 PowerShell 结束。UAC 交互期间会一直阻塞在这里。
    // 5 分钟兜底：极端情况下 UAC 弹窗被其他窗口遮挡/用户临时离开，
    // 避免我们无限期挂起
    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        LogService.w('[UpdateService] PowerShell RunAs 超时（5 分钟未响应）');
        process.kill();
        return -1;
      },
    );

    if (exitCode == 0) {
      LogService.i('[UpdateService] 安装器已通过 UAC 提权启动');
      return true;
    }
    LogService.w('[UpdateService] PowerShell 以退出码 $exitCode 结束（用户可能拒绝了 UAC）');
    return false;
  }

  /// 安装器已在独立进程启动后的收尾：关闭所有子窗口进程 → 等文件锁释放 → exit(0)。
  ///
  /// 背景：desktop_multi_window 的每个子窗口都是独立的 bakabox_app.exe 进程。
  /// 如果只 exit(0) 主进程，剩下的子窗口进程仍持有 exe/DLL 的文件锁，
  /// NSIS 静默模式 nsis7zU::Extract 无法覆盖被锁的文件且不会报错，
  /// 表现为「更新已完成但版本没变」——正是部分用户反馈的现象。
  ///
  /// 每一步都用 try/catch + 超时包裹，任何一步卡住或失败都不能阻断退出流程
  /// （NSIS 侧仍有兜底的杀进程循环，只是不那么可靠）。
  ///
  /// 只应在 Process.start 成功之后调用。若安装器启动失败就调用本方法，
  /// 会误关用户的子窗口。
  Future<void> _finalizeExitForInstaller() async {
    const closeTimeout = Duration(seconds: 2);

    try {
      // 关闭挤服/暖服/启动/连接等所有浮窗
      await FloatingWindowService().closeAllWindows().timeout(closeTimeout);
    } catch (e) {
      LogService.w('[UpdateService] closeAllWindows before exit failed: $e');
    }
    try {
      // 关闭热身/换图/更新日志/广播等所有通知窗口
      await NotificationWindowService().dismissAll().timeout(closeTimeout);
    } catch (e) {
      LogService.w('[UpdateService] dismissAll before exit failed: $e');
    }

    // 子窗口从收到 IPC 到进程真正退出、Windows 释放 DLL 句柄需要一点时间：
    // - windowManager.close() → 销毁 HWND → PostQuitMessage → 消息循环退出
    // - Flutter engine teardown → 进程退出
    // - Windows 内核延迟释放 DLL 引用计数
    // 经验值 1500ms 足以覆盖大部分场景，且不会让用户明显感知卡顿。
    await Future.delayed(const Duration(milliseconds: 1500));

    // exit(0) 是同步的且不返回。放在最后确保上面的清理都完成。
    exit(0);
  }

  /// 安装Android APK
  Future<void> _installAndroidApk(String apkPath) async {
    try {
      final file = File(apkPath);
      if (!await file.exists()) {
        throw UpdateException('APK 文件不存在: $apkPath');
      }

      // 使用 MethodChannel 调用原生安装
      const platform = MethodChannel('cc.aishia.bakabox/install');
      await platform.invokeMethod('installApk', {'path': apkPath});
    } catch (e) {
      if (e is UpdateException) rethrow;
      if (e is PlatformException) {
        throw UpdateException(e.message ?? '安装失败');
      }
      throw const UpdateException('无法安装APK，请检查安装权限');
    }
  }

  /// 获取错误信息用于上报
  ///
  /// 对于 AppException，返回 "ExceptionType: message" 格式
  /// 对于其他异常，返回 toString() 结果
  String _getErrorMessageForReport(Object e) {
    if (e is AppException) {
      return '${e.runtimeType}: ${e.message}';
    }
    return e.toString();
  }

  /// 上报更新结果（同步等待，确保上报完成）
  Future<void> _reportResult(
    AppUpdateInfo updateInfo,
    String status, {
    String? errorMessage,
  }) async {
    try {
      final request = UpdateReportRequest(
        platform: PlatformUtils.isDesktopPlatform ? 'desktop' : 'mobile',
        os: Platform.operatingSystem,
        fromVersion: updateInfo.currentVersion,
        toVersion: updateInfo.latestVersion,
        status: status,
        errorMessage: errorMessage,
      );
      await _enqueueReport(request);

      // 不阻塞主流程，后台静默刷新队列
      flushPendingReports().ignore();
    } catch (e) {
      // 上报入队或发送失败不影响主流程，静默处理
    }
  }

  /// 将上报请求加入本地持久化队列
  Future<void> _enqueueReport(UpdateReportRequest request) async {
    try {
      final pendingList = StorageUtils.getStringList(_keyPendingReports);
      pendingList.add(jsonEncode(request.toJson()));
      await StorageUtils.setStringList(_keyPendingReports, pendingList);
    } catch (e) {
      LogService.w('[UpdateService] 入队上报请求失败', e);
    }
  }

  bool _isFlushing = false;

  /// 尝试发送所有积压的上报请求，发送成功则移出队列
  Future<void> flushPendingReports() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      while (true) {
        final pendingList = StorageUtils.getStringList(_keyPendingReports);
        if (pendingList.isEmpty) break;

        final reportStr = pendingList.first;
        UpdateReportRequest request;
        try {
          request = UpdateReportRequest.fromJson(
            jsonDecode(reportStr) as Map<String, dynamic>,
          );
        } catch (e) {
          LogService.e('[UpdateService] 无效的上报数据，丢弃: $reportStr', e);
          final currentList = StorageUtils.getStringList(_keyPendingReports);
          if (currentList.isNotEmpty && currentList.first == reportStr) {
            currentList.removeAt(0);
            await StorageUtils.setStringList(_keyPendingReports, currentList);
          }
          continue; // 解析失败，直接抛弃并处理下一条
        }

        try {
          // 尝试发送，设置超时避免单个请求卡死整个队列
          await _updateApi
              .reportUpdateResult(request)
              .timeout(const Duration(seconds: 10));

          // 发送成功，重新读取列表并安全地移除已发送的项
          final currentList = StorageUtils.getStringList(_keyPendingReports);
          if (currentList.isNotEmpty && currentList.first == reportStr) {
            currentList.removeAt(0);
            await StorageUtils.setStringList(_keyPendingReports, currentList);
          }
        } catch (e) {
          // 发送失败（网络不通或超时等API异常），终止本次刷新，等待下次重试
          LogService.d('[UpdateService] 上报队列刷新暂停：发送失败');
          break;
        }
      }
    } finally {
      _isFlushing = false;
    }
  }
}
