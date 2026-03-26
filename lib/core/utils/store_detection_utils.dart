import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'platform_utils.dart';

/// 商店检测工具类
///
/// 提供多种方法检测应用是否从 Microsoft Store 安装
/// 参考：Electron、VS Code、Microsoft Teams 等成熟应用的做法
class StoreDetectionUtils {
  StoreDetectionUtils._();

  static bool? _cachedResult;

  /// 检测是否从 Microsoft Store 安装
  ///
  /// 使用多重检测策略，确保准确性：
  /// 1. 检查可执行文件路径（WindowsApps 目录）
  /// 2. 检查包名格式（MSIX 特有格式）
  /// 3. 检查环境变量（MSIX 容器标识）
  /// 4. 检查注册表（可选，需要额外权限）
  static Future<bool> isInstalledFromStore() async {
    // 使用缓存结果（安装来源不会改变）
    if (_cachedResult != null) {
      return _cachedResult!;
    }

    if (!PlatformUtils.isWindows) {
      _cachedResult = false;
      return false;
    }

    try {
      // 方法 1: 检查可执行文件路径（最可靠）
      final pathCheck = _checkExecutablePath();
      if (pathCheck) {
        _cachedResult = true;
        return true;
      }

      // 方法 2: 检查包名格式
      final packageCheck = await _checkPackageName();
      if (packageCheck) {
        _cachedResult = true;
        return true;
      }

      // 方法 3: 检查环境变量
      final envCheck = _checkEnvironmentVariables();
      if (envCheck) {
        _cachedResult = true;
        return true;
      }

      // 所有检测都未通过，判定为非商店版本
      _cachedResult = false;
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('商店检测失败: $e');
      }
      _cachedResult = false;
      return false;
    }
  }

  /// 同步版本（使用缓存结果）
  ///
  /// 注意：首次调用前应先调用异步版本初始化
  static bool isInstalledFromStoreSync() {
    if (_cachedResult != null) {
      return _cachedResult!;
    }

    // 未初始化时使用快速检测
    if (!PlatformUtils.isWindows) {
      return false;
    }

    return _checkExecutablePath();
  }

  /// 方法 1: 检查可执行文件路径
  ///
  /// MSIX 应用固定安装在：
  /// C:\Program Files\WindowsApps\{PublisherName}.{AppName}_{Version}_{Architecture}__{PublisherId}\
  ///
  /// 这是最可靠的检测方法，几乎不会误判
  static bool _checkExecutablePath() {
    try {
      final exePath = Platform.resolvedExecutable.toLowerCase();

      // 检查是否包含 windowsapps 目录
      if (exePath.contains('windowsapps')) {
        return true;
      }

      // 检查是否包含典型的 MSIX 路径特征
      // 例如：C:\Program Files\WindowsApps\Aishia.BakaBox_1.0.0.0_x64__xxxxx
      if (exePath.contains(r'program files\windowsapps')) {
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('路径检测失败: $e');
      }
      return false;
    }
  }

  /// 方法 2: 检查包名格式
  ///
  /// MSIX 应用的包名格式：PublisherName.AppName
  /// 例如：Aishia.BakaBox
  ///
  /// 传统 EXE 应用通常使用简单的名称
  static Future<bool> _checkPackageName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;

      // MSIX 包名通常包含点号分隔的发布者和应用名
      // 例如：Aishia.BakaBox
      if (packageName.contains('.') &&
          !packageName.startsWith('com.') &&
          !packageName.startsWith('org.')) {
        // 排除 Android 风格的包名（com.xxx, org.xxx）
        // MSIX 包名格式：PublisherName.AppName
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('包名检测失败: $e');
      }
      return false;
    }
  }

  /// 方法 3: 检查环境变量
  ///
  /// MSIX 应用运行在容器中，会设置特定的环境变量
  /// 参考：https://docs.microsoft.com/windows/msix/detect-package-identity
  static bool _checkEnvironmentVariables() {
    try {
      // 检查 MSIX 容器相关的环境变量
      final env = Platform.environment;

      // PkgInstallFolder: MSIX 包安装目录
      if (env.containsKey('PkgInstallFolder')) {
        return true;
      }

      // APPX_PROCESS: MSIX 进程标识
      if (env.containsKey('APPX_PROCESS')) {
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('环境变量检测失败: $e');
      }
      return false;
    }
  }

  /// 获取安装来源描述
  static Future<String> getInstallationSource() async {
    final isStore = await isInstalledFromStore();
    if (isStore) {
      return 'Microsoft Store';
    } else {
      return 'Direct Download';
    }
  }

  /// 获取详细的检测信息（用于调试）
  static Future<Map<String, dynamic>> getDetectionDetails() async {
    if (!PlatformUtils.isWindows) {
      return {'platform': 'non-windows', 'isStore': false};
    }

    final pathCheck = _checkExecutablePath();
    final packageCheck = await _checkPackageName();
    final envCheck = _checkEnvironmentVariables();
    final finalResult = await isInstalledFromStore();

    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}

    return {
      'isStore': finalResult,
      'checks': {
        'executablePath': pathCheck,
        'packageName': packageCheck,
        'environment': envCheck,
      },
      'details': {
        'executablePath': Platform.resolvedExecutable,
        'packageName': packageInfo?.packageName,
        'environment': {
          'PkgInstallFolder': Platform.environment['PkgInstallFolder'],
          'APPX_PROCESS': Platform.environment['APPX_PROCESS'],
        },
      },
    };
  }
}
