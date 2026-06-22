import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/api.dart';
import '../constants/api_constants.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';

/// 应用统计服务
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  /// 上报通用业务事件（fire-and-forget，不阻塞调用方）
  ///
  /// [event] 事件名称，如 `guide_list_view`
  /// [params] 事件附加参数
  void trackEvent(String event, [Map<String, dynamic>? params]) {
    // fire-and-forget：异步执行，不阻塞用户交互
    _doTrackEvent(event, params);
  }

  Future<void> _doTrackEvent(String event, Map<String, dynamic>? params) async {
    try {
      final data = <String, dynamic>{
        'event': event,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'platform': PlatformUtils.platformName,
        if (params != null) ...params,
      };

      await Api.post(ApiConstants.analyticsEventPath, body: data);
      LogService.d('埋点上报成功: $event $params');
    } catch (e) {
      // 埋点失败静默处理，不影响业务
      LogService.d('埋点上报失败: $event - $e');
    }
  }

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

      // 从编译时环境变量获取构建日期
      const buildDate = String.fromEnvironment(
        'BUILD_DATE',
        defaultValue: 'dev',
      );

      final data = {
        'event_type': 'app_startup',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'client_id': 'bakabox_${platform}_${arch}_${packageInfo.version}',

        'app_version': packageInfo.version,
        'build_date': buildDate,
        'build_platform': '$platform/$arch',

        'os_platform': platform,
        'os_arch': arch,
        'os_version': PlatformUtils.osVersion,

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
        if (version.contains('x64') ||
            version.contains('x86_64') ||
            version.contains('amd64')) {
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
        if (version.contains('arm64') || version.contains('aarch64')) {
          return 'arm64';
        }
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
