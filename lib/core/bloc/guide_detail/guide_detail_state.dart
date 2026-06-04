import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';

/// 详情页加载状态
enum DetailStatus { loading, success, notFound, blocked, failure }

class GuideDetailState extends Equatable {
  final DetailStatus status;
  final Guide? guide;
  final String? error;

  /// 每次互动成功后递增，UI 层通过 BlocListener 监听变化
  /// 以通知 GuideListBloc 执行 RefreshGuide(id)
  final int lastInteractionId;

  const GuideDetailState({
    this.status = DetailStatus.loading,
    this.guide,
    this.error,
    this.lastInteractionId = 0,
  });

  GuideDetailState copyWith({
    DetailStatus? status,
    Guide? guide,
    bool clearGuide = false,
    String? error,
    bool clearError = false,
    int? lastInteractionId,
  }) {
    return GuideDetailState(
      status: status ?? this.status,
      guide: clearGuide ? null : (guide ?? this.guide),
      error: clearError ? null : (error ?? this.error),
      lastInteractionId: lastInteractionId ?? this.lastInteractionId,
    );
  }

  @override
  List<Object?> get props => [status, guide, error, lastInteractionId];
}
