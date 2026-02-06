import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/update_api.dart';
import '../exceptions/app_exception.dart';
import '../models/update_models.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';
import '../utils/log_service.dart';

/// 更新异常
class UpdateException implements AppException {
  @override
  final String message;

  const UpdateException(this.message);
}

class UpdateService {
  final UpdateApi _updateApi = UpdateApi();
  static const String _keyLastCheckTime = 'last_update_check_time';
  static const String _keyPendingInstallVersion = 'pending_install_version';
  static const String _keyPendingInstallFromVersion = 'pending_install_from_version';
  static const int _minCheckIntervalHours = 6;

  /// 检查并上报安装成功（应用启动时调用）
  /// 
  /// 原理：
  /// 1. 安装前记录待安装版本号
  /// 2. 新版本启动时检测版本号变化
  /// 3. 如果匹配，说明安装成功，上报统计
  Future<void> checkAndReportInstallSuccess() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 获取待安装版本号
      final pendingVersion = StorageUtils.getString(_keyPendingInstallVersion);
      final fromVersion = StorageUtils.getString(_keyPendingInstallFromVersion);
      
      if (pendingVersion != null && pendingVersion == currentVersion) {
        // 版本匹配，说明安装成功
        // 上报安装成功
        await _updateApi.reportUpdateResult(UpdateReportRequest(
          platform: PlatformUtils.isDesktopPlatform ? 'desktop' : 'mobile',
          os: Platform.operatingSystem,
          fromVersion: fromVersion ?? 'unknown',
          toVersion: currentVersion,
          status: 'install_success',
          errorMessage: null,
        ));
        
        // 清除待安装标记
        await StorageUtils.remove(_keyPendingInstallVersion);
        await StorageUtils.remove(_keyPendingInstallFromVersion);
      }
    } catch (e) {
      // 失败不影响应用启动，静默处理
    }
  }

  /// 检查更新
  Future<AppUpdateInfo> checkForUpdate() async {
    // 商店版本不支持手动更新
    if (PlatformUtils.isInstalledFromStore) {
      throw const UpdateException('商店版本由 Microsoft Store 自动更新');
    }

    try {
      final updateInfo = await _updateApi.checkForUpdate();
      await _updateLastCheckTime();
      return updateInfo;
    } catch (e) {
      rethrow;
    }
  }

  /// 自动检查更新（带间隔限制）
  Future<AppUpdateInfo?> autoCheckForUpdate() async {
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
    if (updateInfo.downloadUrl == null) {
      throw const UpdateException('下载地址不可用');
    }

    final directory = await getTemporaryDirectory();
    final fileName = _getFileNameFromUrl(updateInfo.downloadUrl!);
    final savePath = '${directory.path}/$fileName';

    try {
      // 下载文件
      final downloadedFilePath = await _updateApi.downloadUpdate(
        updateInfo.downloadUrl!,
        savePath,
        onProgress,
      );

      // 校验文件MD5
      if (updateInfo.fileMd5 != null) {
        final isValid = await _verifyFileMd5(downloadedFilePath, updateInfo.fileMd5!);
        if (!isValid) {
          try {
            await File(downloadedFilePath).delete();
          } catch (_) {}
          throw const UpdateException('文件完整性校验失败\n下载的文件可能已损坏，请重新下载');
        }
      }

      // 上报下载成功
      await _reportResult(updateInfo, 'download_success');

      return downloadedFilePath;
    } catch (e) {
      // 上报下载失败
      await _reportResult(updateInfo, 'download_failed', errorMessage: _getErrorMessageForReport(e));
      rethrow;
    }
  }

  /// 安装已下载的更新
  Future<void> installUpdate(String filePath, AppUpdateInfo? updateInfo) async {
    try {
      // 记录待安装版本号（用于下次启动时检测安装成功）
      if (updateInfo != null) {
        await StorageUtils.setString(_keyPendingInstallVersion, updateInfo.latestVersion);
        await StorageUtils.setString(_keyPendingInstallFromVersion, updateInfo.currentVersion);
      }
      
      // 在安装前上报（Windows 会立即退出，必须提前上报）
      if (updateInfo != null) {
        await _reportResult(updateInfo, 'install_started');
      }
      await _installUpdate(filePath);
    } catch (e) {
      // 上报安装启动失败
      if (updateInfo != null) {
        await _reportResult(updateInfo, 'install_failed', errorMessage: _getErrorMessageForReport(e));
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
      if (updateInfo.downloadUrl != null) {
        final uri = Uri.parse(updateInfo.downloadUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return;
    }

    if (updateInfo.downloadUrl == null) {
      throw const UpdateException('下载地址不可用');
    }

    final directory = await getTemporaryDirectory();
    final fileName = _getFileNameFromUrl(updateInfo.downloadUrl!);
    final savePath = '${directory.path}/$fileName';

    String? downloadedFilePath;
    bool downloadSucceeded = false;
    
    try {
      // 下载文件
      downloadedFilePath = await _updateApi.downloadUpdate(
        updateInfo.downloadUrl!,
        savePath,
        onProgress,
      );

      // 校验文件MD5
      if (updateInfo.fileMd5 != null) {
        final isValid = await _verifyFileMd5(downloadedFilePath, updateInfo.fileMd5!);
        if (!isValid) {
          try {
            await File(downloadedFilePath).delete();
          } catch (_) {}
          throw const UpdateException('文件完整性校验失败\n下载的文件可能已损坏，请重新下载');
        }
      }

      // 上报下载成功
      await _reportResult(updateInfo, 'download_success');
      downloadSucceeded = true;

      // 记录待安装版本号（用于下次启动时检测安装成功）
      await StorageUtils.setString(_keyPendingInstallVersion, updateInfo.latestVersion);
      await StorageUtils.setString(_keyPendingInstallFromVersion, updateInfo.currentVersion);

      // 安装更新
      // 在安装前上报（Windows 会立即退出，必须提前上报）
      await _reportResult(updateInfo, 'install_started');
      await _installUpdate(downloadedFilePath);
    } catch (e) {
      // 判断是下载失败还是安装失败
      if (!downloadSucceeded) {
        // 下载阶段失败
        await _reportResult(updateInfo, 'download_failed', errorMessage: _getErrorMessageForReport(e));
      } else {
        // 安装阶段失败
        await _reportResult(updateInfo, 'install_failed', errorMessage: _getErrorMessageForReport(e));
      }
      
      if (e is UpdateException) rethrow;
      throw const UpdateException('下载安装失败，请检查网络后重试');
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
    await StorageUtils.setInt(_keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);
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

  /// 校验文件MD5
  Future<bool> _verifyFileMd5(String filePath, String expectedMd5) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString().toLowerCase() == expectedMd5.toLowerCase();
    } catch (e) {
      return false;
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

  /// 安装 Windows EXE（静默模式）
  /// 
  /// 直接启动安装程序，NSIS 脚本会等待本程序退出后再继续安装
  Future<void> _installWindowsExe(String exePath) async {
    try {
      await Process.start(
        exePath,
        ['/S'],
        mode: ProcessStartMode.detached,
      );
      
      // 立即退出，安装程序会等待本进程退出
      exit(0);
    } catch (e) {
      LogService.e('启动安装程序失败', e);
      
      // 备用方案：通过 cmd 启动
      try {
        await Process.start(
          'cmd',
          ['/c', 'start', '', exePath, '/S'],
          mode: ProcessStartMode.detached,
          runInShell: true,
        );
        exit(0);
      } catch (e2) {
        LogService.e('cmd 方式启动也失败', e2);
        
        // 最后尝试直接打开（非静默）
        final uri = Uri.file(exePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          exit(0);
        } else {
          throw const UpdateException('无法启动安装程序，请手动运行');
        }
      }
    }
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
  Future<void> _reportResult(AppUpdateInfo updateInfo, String status, {String? errorMessage}) async {
    try {
      await _updateApi.reportUpdateResult(UpdateReportRequest(
        platform: PlatformUtils.isDesktopPlatform ? 'desktop' : 'mobile',
        os: Platform.operatingSystem,
        fromVersion: updateInfo.currentVersion,
        toVersion: updateInfo.latestVersion,
        status: status,
        errorMessage: errorMessage,
      ));
    } catch (e) {
      // 上报失败不影响主流程，静默处理
    }
  }
}
