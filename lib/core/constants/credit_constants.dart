/// 积分相关常量配置
/// 
/// 集中管理所有与积分相关的限制和配置
class CreditConstants {
  /// 最低积分
  static const int minCredits = 100;
  
  /// 积分不足提示文案
  static const String insufficientCreditsTitle = '积分不足';
  
  /// 积分获取方式说明
  static const String creditsAcquisitionHint = '积分可通过论坛发帖、回复等方式获取';
  
  /// 获取发布配置所需积分的提示文案
  static String getPublishConfigCreditsMessage(int required) {
    return '发布配置需要 $required 论坛积分';
  }
  
  /// 获取地图贡献所需积分的提示文案
  static String getMapContributionCreditsMessage(int required, int current) {
    return '地图信息编辑需要 $required 论坛积分，您当前积分为 $current';
  }
  
  /// 获取当前积分显示文案
  static String getCurrentCreditsLabel() {
    return '您当前积分：';
  }
}
