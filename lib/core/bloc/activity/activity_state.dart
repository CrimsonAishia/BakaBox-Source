import 'package:equatable/equatable.dart';
import '../../models/activity_model.dart';

enum ActivityStatus { initial, loading, success, failure }

class ActivityState extends Equatable {
  final ActivityStatus status;
  final List<ActivityModel> activities;
  final String? error;
  final DateTime? lastFetched;

  const ActivityState({
    this.status = ActivityStatus.initial,
    this.activities = const [],
    this.error,
    this.lastFetched,
  });

  ActivityState copyWith({
    ActivityStatus? status,
    List<ActivityModel>? activities,
    String? error,
    DateTime? lastFetched,
  }) {
    return ActivityState(
      status: status ?? this.status,
      activities: activities ?? this.activities,
      error: error ?? this.error,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  @override
  List<Object?> get props => [status, activities, error, lastFetched];
}
