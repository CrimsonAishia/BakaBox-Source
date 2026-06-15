import 'dart:async';
import 'dart:collection';

import '../../models/realtime_models.dart';
import '../../models/server_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

enum UsersCountUpdateEventKind { snapshot, updated }

class UsersCountUpdateEvent {
  final UsersCountUpdateEventKind kind;
  final List<ServerUsersCount> counts;

  const UsersCountUpdateEvent({required this.kind, required this.counts});
}

class RealtimeServerUsersCountChannel {
  RealtimeServerUsersCountChannel._internal();

  static final RealtimeServerUsersCountChannel _instance =
      RealtimeServerUsersCountChannel._internal();

  factory RealtimeServerUsersCountChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<UsersCountUpdateEvent> _controller =
      StreamController<UsersCountUpdateEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;

  /// 对账信号订阅：连接保持期间服务端可能丢掉某条 updated（含「归零」），
  /// 本地会残留旧的挤服/暖服人数。监听对账信号强制重拉 snapshot 纠正。
  StreamSubscription<void>? _reconcileSubscription;
  int _refCount = 0;

  /// 最近一次 snapshot（按地址索引）。直接就地更新，对外只暴露不可变视图，
  /// 避免每条 updated 都全量复制整张 map（高频频道下是 GC 热点）。
  final Map<String, ServerUsersCount> _latestSnapshot = {};
  late final Map<String, ServerUsersCount> _latestSnapshotView =
      UnmodifiableMapView(_latestSnapshot);

  /// 同一 event-loop turn 内合并多条 updated，turn 末尾一次性下发，
  /// 降低下游（Bloc/UI）的重建频率。
  final Map<String, ServerUsersCount> _pendingUpdates = {};
  bool _flushScheduled = false;

  Stream<UsersCountUpdateEvent> get events => _controller.stream;

  Map<String, ServerUsersCount> get latestSnapshot => _latestSnapshotView;

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.serverUsersCount)
          .listen(_onEvent);
      _reconcileSubscription ??= _service.reconcileStream.listen((_) {
        _service.requestResnapshot(RealtimeChannels.serverUsersCount);
      });
      _service.subscribe(RealtimeChannels.serverUsersCount);
    }
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.serverUsersCount);
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
      default:
        LogService.d('[Realtime/UsersCount] 忽略事件: ${event.eventType}');
    }
  }

  void _onSnapshot(RealtimeChannelEvent event) {
    final list = <ServerUsersCount>[];
    for (final raw in event.snapshotItems) {
      final count = _parse(raw);
      if (count != null) list.add(count);
    }
    // snapshot 是全量真相：丢弃在途的增量合并，直接重建缓存
    _pendingUpdates.clear();
    _flushScheduled = false;
    _latestSnapshot
      ..clear()
      ..addEntries(list.map((c) => MapEntry(c.serverAddress, c)));
    if (!_controller.isClosed) {
      _controller.add(
        UsersCountUpdateEvent(
          kind: UsersCountUpdateEventKind.snapshot,
          counts: list,
        ),
      );
    }
  }

  void _onUpdated(RealtimeChannelEvent event) {
    final count = _parse(event.data);
    if (count == null) return;
    // 就地更新缓存（O(1)），下游事件合并到 turn 末尾统一下发
    _latestSnapshot[count.serverAddress] = count;
    _pendingUpdates[count.serverAddress] = count;
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
    final counts = _pendingUpdates.values.toList(growable: false);
    _pendingUpdates.clear();
    if (!_controller.isClosed) {
      _controller.add(
        UsersCountUpdateEvent(
          kind: UsersCountUpdateEventKind.updated,
          counts: counts,
        ),
      );
    }
  }

  ServerUsersCount? _parse(Map<String, dynamic> raw) {
    final serverAddress = raw['serverAddress'] ?? raw['server_address'];
    if (serverAddress is! String || serverAddress.isEmpty) return null;
    return ServerUsersCount.fromJson(raw);
  }
}
