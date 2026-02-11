import 'package:equatable/equatable.dart';

abstract class UpdateLogEvent extends Equatable {
  const UpdateLogEvent();
  @override
  List<Object?> get props => [];
}

/// 获取日志（首次加载或搜索）
class UpdateLogFetch extends UpdateLogEvent {
  final String keyword;
  const UpdateLogFetch([this.keyword = '']);
  @override
  List<Object?> get props => [keyword];
}

/// 加载更多
class UpdateLogLoadMore extends UpdateLogEvent {}

/// 清除错误
class UpdateLogClearError extends UpdateLogEvent {}
