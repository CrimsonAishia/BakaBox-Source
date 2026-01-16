import 'package:equatable/equatable.dart';
import '../../models/feature_status_models.dart';

abstract class FeatureStatusEvent extends Equatable {
  const FeatureStatusEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化并加载所有功能状态
class FeatureStatusLoad extends FeatureStatusEvent {}

/// 刷新所有功能状态
class FeatureStatusRefresh extends FeatureStatusEvent {}

/// 刷新单个功能状态
class FeatureStatusRefreshSingle extends FeatureStatusEvent {
  final FeatureType feature;

  const FeatureStatusRefreshSingle(this.feature);

  @override
  List<Object?> get props => [feature];
}

/// 启动定时刷新
class FeatureStatusStartPeriodicRefresh extends FeatureStatusEvent {}

/// 停止定时刷新
class FeatureStatusStopPeriodicRefresh extends FeatureStatusEvent {}
