import 'dart:async';
import 'dart:collection';

import '../../models/realtime_models.dart';
import '../../models/server_score.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// 比分事件类型
enum ScoreUpdateEventKind { snapshot, updated, syncing }

/// 比分事件
class ScoreUpdateEvent {
  final ScoreUpdateEventKind kind;

  /// snapshot 时为全量列表；updated 时为本轮合并的若干条
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

  /// 对账信号订阅：连接保持期间服务端可能丢掉某条 updated，本地比分会停留在旧值。
  StreamSubscription<void>? _reconcileSubscription;
  int _refCount = 0;

  /// 最近一次 snapshot（按地址索引），就地更新，对外只暴露不可变视图。
  final Map<String, ServerScore> _latestSnapshot = {};
  late final Map<String, ServerScore> _latestSnapshotView = UnmodifiableMapView(
    _latestSnapshot,
  );

  /// 同一 event-loop turn 内合并多条 updated，turn 末尾一次性下发。
  final Map<String, ServerScore> _pendingUpdates = {};
  bool _flushScheduled = false;

  Stream<ScoreUpdateEvent> get events => _controller.stream;

  Map<String, ServerScore> get latestSnapshot => _latestSnapshotView;

  ServerScore? scoreFor(String serverAddress) => _latestSnapshot[serverAddress];

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.scoreUpdates)
          .listen(_onEvent);
      _reconcileSubscription ??= _service.reconcileStream.listen((_) {
        _service.requestResnapshot(RealtimeChannels.scoreUpdates);
      });
      _service.subscribe(RealtimeChannels.scoreUpdates);
    }
  }

  /// 主动请求服务端重新下发一份全量 snapshot。
  ///
  /// 用于用户手动刷新：强制纠正本地可能停留的旧比分。频率限制由调用方负责。
  void forceResnapshot() {
    _service.requestResnapshot(
      RealtimeChannels.scoreUpdates,
      emitSyncing: true,
    );
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.scoreUpdates);
      _subscription?.cancel();
      _subscription = null;
      _reconcileSubscription?.cancel();
      _reconcileSubscription = null;
      _latestSnapshot.clear();
      _pendingUpdates.clear();
      _flushScheduled = false;
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
      case RealtimeEventTypes.syncing:
        _onSyncing();
        break;
      default:
        LogService.d('[Realtime/Score] 忽略事件: ${event.eventType}');
    }
  }

  void _onSyncing() {
    _latestSnapshot.clear();
    _pendingUpdates.clear();
    _flushScheduled = false;
    if (!_controller.isClosed) {
      _controller.add(
        const ScoreUpdateEvent(kind: ScoreUpdateEventKind.syncing, scores: []),
      );
    }
  }

  void _onSnapshot(RealtimeChannelEvent event) {
    final list = <ServerScore>[];
    for (final raw in event.snapshotItems) {
      final score = _parseScore(raw);
      if (score != null) list.add(score);
    }
    // snapshot 是全量真相：丢弃在途增量合并，直接重建缓存
    _pendingUpdates.clear();
    _flushScheduled = false;
    _latestSnapshot
      ..clear()
      ..addEntries(list.map((s) => MapEntry(s.serverAddress, s)));
    if (!_controller.isClosed) {
      _controller.add(
        ScoreUpdateEvent(kind: ScoreUpdateEventKind.snapshot, scores: list),
      );
    }
  }

  void _onUpdated(RealtimeChannelEvent event) {
    final score = _parseScore(event.data);
    if (score == null) return;
    _latestSnapshot[score.serverAddress] = score;
    _pendingUpdates[score.serverAddress] = score;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(_flushUpdates);
  }

  void _flushUpdates() {
    _flushScheduled = false;
    if (_pendingUpdates.isEmpty) return;
    final scores = _pendingUpdates.values.toList(growable: false);
    _pendingUpdates.clear();
    if (!_controller.isClosed) {
      _controller.add(
        ScoreUpdateEvent(kind: ScoreUpdateEventKind.updated, scores: scores),
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
