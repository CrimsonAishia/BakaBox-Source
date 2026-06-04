import 'package:equatable/equatable.dart';

abstract class GuideDetailEvent extends Equatable {
  const GuideDetailEvent();
  @override
  List<Object?> get props => [];
}

/// 加载攻略详情
class LoadGuide extends GuideDetailEvent {
  final int id;
  const LoadGuide(this.id);
  @override
  List<Object?> get props => [id];
}

/// 切换点赞（乐观更新）
class ToggleLike extends GuideDetailEvent {
  const ToggleLike();
}

/// 切换收藏（乐观更新）
class ToggleFavorite extends GuideDetailEvent {
  const ToggleFavorite();
}

/// 上报浏览（fire-and-forget）
class ReportView extends GuideDetailEvent {
  const ReportView();
}

/// 分享
class Share extends GuideDetailEvent {
  final String? channel;
  const Share({this.channel});
  @override
  List<Object?> get props => [channel];
}
