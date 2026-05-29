import 'dart:async';

import '../../models/realtime_models.dart';
import '../../models/server_score.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// 比分事件类型
enum ScoreUpdateEventKind { snapshot, updated }

/// 比分事件
class ScoreUpdateEvent {
  final ScoreUpdateEventKind kind;

  /// snapshot 时为全量列表；updated 时只有一个元素
  final List<ServerScore> scores;

  const ScoreUpdateEvent({required this.kind, required this.scores});
}

/// `score.updates` 频道适配器
class RealtimeScoreUpdatesChannel {
  RealtimeScoreUpdatesChannel._internal();

  static final RealtimeScoreUpdatesChannel _instance =
      RealtimeScoreUpdatesChannel._internal();

  factory RealtimeScoreUpdatesChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<ScoreUpdateEvent> _controller =
      StreamController<ScoreUpdateEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;
  int _refCount = 0;

  /// 最近一次 snapshot（按地址索引）
  Map<String, ServerScore> _latestSnapshot = const {};

  Stream<ScoreUpdateEvent> get events => _controller.stream;

  Map<String, ServerScore> get latestSnapshot =>
      Map.unmodifiable(_latestSnapshot);

  ServerScore? scoreFor(String serverAddress) =>
      _latestSnapshot[serverAddress];

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.scoreUpdates)
          .listen(_onEvent);
      _service.subscribe(RealtimeChannels.scoreUpdates);
    }
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.scoreUpdates);
      _subscription?.cancel();
      _subscription = null;
      _latestSnapshot = const {};
    }
  }

  void _onEvent(RealtimeChannelEvent event) {
    switch (event.eventType) {
      case RealtimeEventTypes.snapshot:
        _onSnapshot(event);
        break;
      case RealtimeEventTypes.updated:
        _onUpdated(event);
        break;
      default:
        LogService.d('[Realtime/Score] 忽略事件: ${event.eventType}');
    }
  }

  void _onSnapshot(RealtimeChannelEvent event) {
    final list = <ServerScore>[];
    for (final raw in event.snapshotItems) {
      final score = _parseScore(raw);
      if (score != null) list.add(score);
    }
    final indexed = <String, ServerScore>{};
    for (final s in list) {
      indexed[s.serverAddress] = s;
    }
    _latestSnapshot = indexed;
    if (!_controller.isClosed) {
      _controller.add(
        ScoreUpdateEvent(kind: ScoreUpdateEventKind.snapshot, scores: list),
      );
    }
  }

  void _onUpdated(RealtimeChannelEvent event) {
    final score = _parseScore(event.data);
    if (score == null) return;
    final next = Map<String, ServerScore>.from(_latestSnapshot);
    next[score.serverAddress] = score;
    _latestSnapshot = next;
    if (!_controller.isClosed) {
      _controller.add(
        ScoreUpdateEvent(kind: ScoreUpdateEventKind.updated, scores: [score]),
      );
    }
  }

  /// 服务端字段是 camelCase（serverAddress / ctScore / mapName / sourceCount …），
  /// REST 接口返回的是 snake_case，模型按 snake_case 解析；这里做一次字段对齐。
  ServerScore? _parseScore(Map<String, dynamic> raw) {
    final serverAddress = raw['serverAddress'] ?? raw['server_address'];
    if (serverAddress is! String || serverAddress.isEmpty) return null;
    final mapped = <String, dynamic>{
      'server_address': serverAddress,
      'ct_score': raw['ctScore'] ?? raw['ct_score'],
      't_score': raw['tScore'] ?? raw['t_score'],
      'round': raw['round'],
      'map_name': raw['mapName'] ?? raw['map_name'],
      'confidence': raw['confidence'],
      'source_count': raw['sourceCount'] ?? raw['source_count'],
      'updated_at': raw['updatedAt'] ?? raw['updated_at'],
      'data_quality': raw['dataQuality'] ?? raw['data_quality'] ?? 'good',
    };
    try {
      return ServerScore.fromJson(mapped);
    } catch (e) {
      LogService.w('[Realtime/Score] 解析失败: $e');
      return null;
    }
  }
}
