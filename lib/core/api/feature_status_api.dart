import '../models/feature_status_models.dart';
import '../utils/log_service.dart';
import 'api.dart';

/// 功能状态 API 服务
class FeatureStatusApi {
  /// 获取单个功能状态
  Future<FeatureStatus> getFeatureStatus(FeatureType feature) async {
    try {
      LogService.d('获取功能状态: ${feature.displayName}');

      final result = await Api.get<FeatureStatus>(
        '/api/stub${feature.apiPath}/status',
        fromJson: (json) =>
            FeatureStatus.fromJson(json as Map<String, dynamic>),
      );

      return result ?? FeatureStatus.defaultDisabled;
    } catch (e) {
      LogService.e('获取功能状态失败: ${feature.displayName}', e);
      // API 失败时默认禁用，避免服务端出问题时用户访问异常功能
      return FeatureStatus.defaultDisabled;
    }
  }

  /// 批量获取所有功能状态
  Future<AllFeatureStatus> getAllFeatureStatus() async {
    try {
      LogService.d('批量获取所有功能状态');

      // 并行请求所有功能状态
      final results = await Future.wait([
        getFeatureStatus(FeatureType.keyConfig),
        getFeatureStatus(FeatureType.issue),
        getFeatureStatus(FeatureType.mapContribution),
      ]);

      return AllFeatureStatus(
        keyConfig: results[0],
        issue: results[1],
        mapContribution: results[2],
      );
    } catch (e) {
      LogService.e('批量获取功能状态失败', e);
      // 失败时返回默认全部禁用
      return AllFeatureStatus.allDisabled;
    }
  }
}
