import 'package:equatable/equatable.dart';
import '../../models/server_stats_models.dart';

class ServerStatsState extends Equatable {
  final bool isLoading;
  final String? error;
  final ServerStatsResponse? stats;

  const ServerStatsState({
    this.isLoading = false,
    this.error,
    this.stats,
  });

  ServerStatsState copyWith({
    bool? isLoading,
    String? error,
    ServerStatsResponse? stats,
  }) {
    return ServerStatsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, stats];
}
