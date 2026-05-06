import 'package:equatable/equatable.dart';
import '../../models/server_stats_models.dart';

class ServerStatsState extends Equatable {
  final bool isLoading;
  final String? error;
  final ServerStatsResponse? stats;
  final DateTime? lastFetched;

  const ServerStatsState({this.isLoading = false, this.error, this.stats, this.lastFetched});

  ServerStatsState copyWith({
    bool? isLoading,
    String? error,
    ServerStatsResponse? stats,
    DateTime? lastFetched,
  }) {
    return ServerStatsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, stats, lastFetched];
}
