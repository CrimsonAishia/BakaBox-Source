import 'package:equatable/equatable.dart';
import '../../models/feature_status_models.dart';

enum FeatureStatusLoadState { initial, loading, loaded, error }

class FeatureStatusState extends Equatable {
  final FeatureStatusLoadState loadState;
  final AllFeatureStatus status;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const FeatureStatusState({
    this.loadState = FeatureStatusLoadState.initial,
    this.status = const AllFeatureStatus(),
    this.errorMessage,
    this.lastUpdated,
  });

  /// 是否正在加载
  bool get isLoading => loadState == FeatureStatusLoadState.loading;

  /// 是否已加载
  bool get isLoaded => loadState == FeatureStatusLoadState.loaded;

  /// 按键绑定功能是否启用
  bool get isKeyConfigEnabled => status.keyConfig.enabled;

  /// Issue 反馈功能是否启用
  bool get isIssueEnabled => status.issue.enabled;

  /// 地图贡献功能是否启用
  bool get isMapContributionEnabled => status.mapContribution.enabled;

  /// 获取功能禁用提示信息
  String getDisabledMessage(FeatureType feature) {
    final featureStatus = status.getStatus(feature);
    return featureStatus.message.isNotEmpty ? featureStatus.message : '该功能暂未开放';
  }

  /// 检查缓存是否过期（5分钟）
  bool get isCacheExpired {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!).inMinutes >= 5;
  }

  FeatureStatusState copyWith({
    FeatureStatusLoadState? loadState,
    AllFeatureStatus? status,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return FeatureStatusState(
      loadState: loadState ?? this.loadState,
      status: status ?? this.status,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [loadState, status, errorMessage, lastUpdated];
}
