import 'package:package_info_plus/package_info_plus.dart';
import '../utils/log_service.dart';

/// 应用信息服务
/// 
/// 提供应用版本等信息的统一访问入口。
/// 在应用启动时初始化一次，之后可同步访问。
class AppInfoService {
  AppInfoService._();
  
  static final AppInfoService _instance = AppInfoService._();
  static AppInfoService get instance => _instance;
  
  PackageInfo? _packageInfo;
  bool _initialized = false;
  
  /// 应用版本号（如 1.0.3）
  String get version => _packageInfo?.version ?? 'unknown';
  
  /// 构建号（如 1）
  String get buildNumber => _packageInfo?.buildNumber ?? '0';
  
  /// 完整版本字符串（如 1.0.3+1）
  String get fullVersion => '$version+$buildNumber';
  
  /// 应用名称
  String get appName => _packageInfo?.appName ?? 'BakaBox';
  
  /// 包名
  String get packageName => _packageInfo?.packageName ?? '';
  
  /// 是否已初始化
  bool get isInitialized => _initialized;
  
  /// 初始化服务（应用启动时调用一次）
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _initialized = true;
      LogService.d('[AppInfoService] 初始化完成: version=$version, build=$buildNumber');
    } catch (e) {
      LogService.e('[AppInfoService] 初始化失败', e);
      // 初始化失败时使用默认值，不阻塞应用启动
      _initialized = true;
    }
  }
}
