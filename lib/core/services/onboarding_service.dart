import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_service.dart';

/// 引导服务 - 管理首次启动引导状态
class OnboardingService {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyOnboardingVersion = 'onboarding_version';
  
  /// 当前引导版本，升级此值可强制用户重新完成引导
  static const int currentOnboardingVersion = 1;

  /// 检查是否需要显示引导
  Future<bool> shouldShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_keyOnboardingCompleted) ?? false;
      final version = prefs.getInt(_keyOnboardingVersion) ?? 0;
      
      // 未完成或版本过旧都需要显示引导
      if (!completed || version < currentOnboardingVersion) {
        LogService.d('[OnboardingService] 需要显示引导: completed=$completed, version=$version');
        return true;
      }
      
      return false;
    } catch (e) {
      LogService.e('[OnboardingService] 检查引导状态失败', e);
      return false;
    }
  }

  /// 标记引导已完成
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, true);
      await prefs.setInt(_keyOnboardingVersion, currentOnboardingVersion);
      LogService.i('[OnboardingService] 引导已完成');
    } catch (e) {
      LogService.e('[OnboardingService] 保存引导状态失败', e);
    }
  }

  /// 跳过引导
  Future<void> skipOnboarding() async {
    await completeOnboarding();
    LogService.i('[OnboardingService] 用户跳过引导');
  }

  /// 重置引导状态（用于测试）
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyOnboardingCompleted);
      await prefs.remove(_keyOnboardingVersion);
      LogService.i('[OnboardingService] 引导状态已重置');
    } catch (e) {
      LogService.e('[OnboardingService] 重置引导状态失败', e);
    }
  }
}
