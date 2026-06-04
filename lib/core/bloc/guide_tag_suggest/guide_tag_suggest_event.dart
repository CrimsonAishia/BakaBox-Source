import 'package:equatable/equatable.dart';

abstract class GuideTagSuggestEvent extends Equatable {
  const GuideTagSuggestEvent();

  @override
  List<Object?> get props => [];
}

/// 根据关键词请求标签联想建议
class Suggest extends GuideTagSuggestEvent {
  final String keyword;

  const Suggest(this.keyword);

  @override
  List<Object?> get props => [keyword];
}

/// 重置建议列表（清空）
class Reset extends GuideTagSuggestEvent {
  const Reset();
}
