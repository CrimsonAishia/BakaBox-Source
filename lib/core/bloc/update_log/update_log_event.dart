import 'package:equatable/equatable.dart';

abstract class UpdateLogEvent extends Equatable {
  const UpdateLogEvent();
  @override
  List<Object?> get props => [];
}

class UpdateLogFetch extends UpdateLogEvent {
  final String keyword;
  const UpdateLogFetch([this.keyword = '']);
  @override
  List<Object?> get props => [keyword];
}

class UpdateLogLoadMore extends UpdateLogEvent {}

class UpdateLogSearch extends UpdateLogEvent {
  final String keyword;
  const UpdateLogSearch(this.keyword);
  @override
  List<Object?> get props => [keyword];
}

class UpdateLogRefresh extends UpdateLogEvent {}

class UpdateLogClearError extends UpdateLogEvent {}

class UpdateLogReset extends UpdateLogEvent {}
