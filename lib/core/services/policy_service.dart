import '../constants/policy_constants.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 协议管理服务
/// 
/// 负责管理用户对隐私政策和用户协议的同意状态
class PolicyService {
  static const String _keyAgreedVersion = 'policy_agreed_version';
  static const String _keyAgreedDate = 'policy_agreed_date';
  static const String _keyPrivacyAgreed = 'privacy_policy_agreed';
  static const String _keyTermsAgreed = 'terms_of_service_agreed';

  /// 检查用户是否需要重新同意协议
  /// 
  /// 返回 true 表示需要显示协议更新对话框
  Future<bool> needsReAgreement() async {
    try {
      // 获取用户上次同意的版本
      final agreedVersion = StorageUtils.getString(_keyAgreedVersion);
      
      // 如果从未同意过，需要同意
      if (agreedVersion == null) {
        return true;
      }
      
      // 比较版本号
      final currentVersion = PolicyConstants.version;
      if (agreedVersion != currentVersion) {
        // 版本不同，检查是否为重大变更
        if (PolicyConstants.requiresReAgreement) {
          LogService.i('[Policy] 协议已更新（$agreedVersion → $currentVersion），需要重新同意');
          return true;
        } else {
          // 非重大变更，自动更新版本号
          LogService.i('[Policy] 协议已更新（$agreedVersion → $currentVersion），自动接受');
          await _updateAgreedVersion();
          return false;
        }
      }
      
      return false;
    } catch (e) {
      LogService.e('[Policy] 检查协议状态失败', e);
      return true; // 出错时要求重新同意，确保安全
    }
  }

  /// 用户同意协议
  Future<void> agreeToPolicy() async {
    try {
      await StorageUtils.setString(_keyAgreedVersion, PolicyConstants.version);
      await StorageUtils.setString(_keyAgreedDate, DateTime.now().toIso8601String());
      await StorageUtils.setBool(_keyPrivacyAgreed, true);
      await StorageUtils.setBool(_keyTermsAgreed, true);
      
      LogService.i('[Policy] 用户已同意协议版本 ${PolicyConstants.version}');
    } catch (e) {
      LogService.e('[Policy] 保存协议同意状态失败', e);
      rethrow;
    }
  }

  /// 获取用户上次同意的版本
  Future<String?> getAgreedVersion() async {
    try {
      return StorageUtils.getString(_keyAgreedVersion);
    } catch (e) {
      LogService.e('[Policy] 获取协议版本失败', e);
      return null;
    }
  }

  /// 获取用户上次同意的日期
  Future<DateTime?> getAgreedDate() async {
    try {
      final dateStr = StorageUtils.getString(_keyAgreedDate);
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
      return null;
    } catch (e) {
      LogService.e('[Policy] 获取协议同意日期失败', e);
      return null;
    }
  }

  /// 检查是否已同意隐私政策
  Future<bool> hasAgreedToPrivacyPolicy() async {
    try {
      return StorageUtils.getBool(_keyPrivacyAgreed, defaultValue: false);
    } catch (e) {
      LogService.e('[Policy] 检查隐私政策同意状态失败', e);
      return false;
    }
  }

  /// 检查是否已同意用户协议
  Future<bool> hasAgreedToTerms() async {
    try {
      return StorageUtils.getBool(_keyTermsAgreed, defaultValue: false);
    } catch (e) {
      LogService.e('[Policy] 检查用户协议同意状态失败', e);
      return false;
    }
  }

  /// 清除协议同意状态（用于测试或重置）
  Future<void> clearAgreement() async {
    try {
      await StorageUtils.remove(_keyAgreedVersion);
      await StorageUtils.remove(_keyAgreedDate);
      await StorageUtils.remove(_keyPrivacyAgreed);
      await StorageUtils.remove(_keyTermsAgreed);
      
      LogService.i('[Policy] 已清除协议同意状态');
    } catch (e) {
      LogService.e('[Policy] 清除协议同意状态失败', e);
      rethrow;
    }
  }

  /// 内部方法：更新已同意的版本号（用于非重大变更）
  Future<void> _updateAgreedVersion() async {
    try {
      await StorageUtils.setString(_keyAgreedVersion, PolicyConstants.version);
      await StorageUtils.setString(_keyAgreedDate, DateTime.now().toIso8601String());
    } catch (e) {
      LogService.e('[Policy] 更新协议版本失败', e);
    }
  }

  /// 比较版本号（返回 -1: v1 < v2, 0: v1 == v2, 1: v1 > v2）
  int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }
    
    return 0;
  }
}
