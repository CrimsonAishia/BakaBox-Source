import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/update_api.dart';
import '../models/update_models.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';

/// 更新异常
class UpdateException implements Exception {
  final String message;

  const UpdateException(this.message);

  @override
  String toString() => message;
}

class UpdateService {
  final UpdateApi _updateApi = UpdateApi();
  static const String _keyLastCheckTime = 'last_update_check_time';
  static const int _minCheckIntervalHours = 6;

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
      LogService.i('商店版本跳过自动更新检查');
      return null;
    }

    try {
      final shouldCheck = await _shouldCheckForUpdate();
      if (!shouldCheck) {
        LogService.i('跳过自动更新检查（未到检查间隔）');
        return null;
      }
      LogService.i('开始自动检查更新...');
      final updateInfo = await checkForUpdate();
      if (updateInfo.hasUpdate) {
        LogService.i('发现新版本: ${updateInfo.latestVersion}');
      } else {
        LogService.i('当前已是最新版本');
      }
      return updateInfo.hasUpdate ? updateInfo : null;
    } catch (e) {
      LogService.e('自动检查更新失败: $e', e);
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
        throw const UpdateException('文件校验失败，请重新下载');
      }
    }

    // 上报下载成功
    _reportResult(updateInfo, 'success');

    return downloadedFilePath;
  }

  /// 安装已下载的更新
  Future<void> installUpdate(String filePath, AppUpdateInfo? updateInfo) async {
    await _installUpdate(filePath);
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

    try {
      final directory = await getTemporaryDirectory();
      final fileName = _getFileNameFromUrl(updateInfo.downloadUrl!);
      final savePath = '${directory.path}/$fileName';

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
          throw const UpdateException('文件校验失败，请重新下载');
        }
      }

      // 上报下载成功
      _reportResult(updateInfo, 'success');

      // 安装更新
      await _installUpdate(downloadedFilePath);
    } catch (e) {
      // 上报下载失败
      _reportResult(updateInfo, 'download_failed', errorMessage: e.toString());
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
      LogService.e('MD5校验失败: $e', e);
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
  Future<void> _installWindowsExe(String exePath) async {
    try {
      LogService.i('准备 Windows 静默安装: $exePath');
      
      final result = await Process.start(
        exePath,
        ['/S'],
        mode: ProcessStartMode.detached,
      );
      LogService.i('Windows 静默安装已启动, PID: ${result.pid}');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      LogService.i('退出当前程序，等待安装完成...');
      exit(0);
    } catch (e) {
      LogService.e('Windows 静默安装失败: $e', e);
      final uri = Uri.file(exePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw const UpdateException('无法安装更新，请手动运行安装程序');
      }
    }
  }

  /// 安装Android APK
  Future<void> _installAndroidApk(String apkPath) async {
    try {
      LogService.i('安装 APK: $apkPath');
      
      final file = File(apkPath);
      if (!await file.exists()) {
        throw UpdateException('APK 文件不存在: $apkPath');
      }
      
      final fileSize = await file.length();
      LogService.i('APK 文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // 使用 MethodChannel 调用原生安装
      const platform = MethodChannel('cc.aishia.bakabox/install');
      final result = await platform.invokeMethod('installApk', {'path': apkPath});
      LogService.i('APK 安装结果: $result');
    } catch (e) {
      LogService.e('APK 安装失败: $e', e);
      if (e is UpdateException) rethrow;
      if (e is PlatformException) {
        throw UpdateException(e.message ?? '安装失败');
      }
      throw const UpdateException('无法安装APK，请检查安装权限');
    }
  }

  /// 上报更新结果
  void _reportResult(AppUpdateInfo updateInfo, String status, {String? errorMessage}) {
    try {
      _updateApi.reportUpdateResult(UpdateReportRequest(
        platform: PlatformUtils.isDesktopPlatform ? 'desktop' : 'mobile',
        os: Platform.operatingSystem,
        fromVersion: updateInfo.currentVersion,
        toVersion: updateInfo.latestVersion,
        status: status,
        errorMessage: errorMessage,
      ));
    } catch (_) {
      // 上报失败不影响主流程
    }
  }
}
