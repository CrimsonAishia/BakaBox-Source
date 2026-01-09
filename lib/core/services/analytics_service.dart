import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/api.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';

/// 应用统计服务
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;
  
  AnalyticsService._internal();

  /// 应用启动时间，在 main() 中设置
  DateTime? _appStartTime;
  
  /// 是否已上报启动统计
  bool _startupReported = false;

  /// 设置应用启动时间（在 main() 中调用）
  void setStartTime(DateTime time) {
    _appStartTime = time;
  }

  /// 上报启动统计（在首页首帧渲染完成后调用）
  Future<void> reportStartupIfNeeded() async {
    if (_startupReported || _appStartTime == null) return;
    _startupReported = true;
    await recordAppStartup(_appStartTime!);
  }

  Future<void> recordAppStartup(DateTime startTime) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final arch = _getDeviceArchitecture();
      final platform = PlatformUtils.platformName;
      
      final data = {
        'event_type': 'app_startup',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'client_id': 'bakabox_${platform}_${arch}_${packageInfo.version}',
        
        'app_version': packageInfo.version,
        'build_date': packageInfo.buildNumber,
        'build_platform': '$platform/$arch',
        
        'os_platform': platform,
        'os_arch': arch,
        'os_version': Platform.operatingSystemVersion,
        
        'startup_time_ms': DateTime.now().difference(startTime).inMilliseconds,
      };
      
      await Api.post('/steam/app/startup/stats', body: data);
      LogService.d('启动统计已发送');
    } catch (e) {
      LogService.d('发送启动统计失败: $e');
    }
  }

  String _getDeviceArchitecture() {
    try {
      // 桌面平台可以通过 dart:ffi 或环境变量获取架构
      if (PlatformUtils.isWindows) {
        // Dart 运行时信息包含架构
        final version = Platform.version;
        if (version.contains('x64') || version.contains('x86_64') || version.contains('amd64')) {
          return 'x86_64';
        }
        if (version.contains('arm64') || version.contains('aarch64')) {
          return 'arm64';
        }
        if (version.contains('x86') || version.contains('ia32')) {
          return 'x86';
        }
        return 'x86_64'; // Windows 默认 x86_64
      }
      
      // iOS 设备
      if (PlatformUtils.isIOS) {
        return 'arm64'; // 所有现代 iOS 设备都是 arm64
      }
      
      // Android 设备
      if (PlatformUtils.isAndroid) {
        final version = Platform.version;
        if (version.contains('arm64') || version.contains('aarch64')) return 'arm64';
        if (version.contains('arm')) return 'arm';
        if (version.contains('x86_64')) return 'x86_64';
        if (version.contains('x86')) return 'x86';
        return 'arm64'; // Android 默认 arm64
      }
      
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }
}
