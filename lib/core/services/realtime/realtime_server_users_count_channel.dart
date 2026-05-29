import 'dart:async';

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
  int _refCount = 0;

  Map<String, ServerUsersCount> _latestSnapshot = const {};

  Stream<UsersCountUpdateEvent> get events => _controller.stream;

  Map<String, ServerUsersCount> get latestSnapshot =>
      Map.unmodifiable(_latestSnapshot);

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.serverUsersCount)
          .listen(_onEvent);
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
        LogService.d('[Realtime/UsersCount] 忽略事件: ${event.eventType}');
    }
  }

  void _onSnapshot(RealtimeChannelEvent event) {
    final list = <ServerUsersCount>[];
    for (final raw in event.snapshotItems) {
      final count = _parse(raw);
      if (count != null) list.add(count);
    }
    final indexed = <String, ServerUsersCount>{};
    for (final c in list) {
      indexed[c.serverAddress] = c;
    }
    _latestSnapshot = indexed;
    if (!_controller.isClosed) {
      _controller.add(
        UsersCountUpdateEvent(kind: UsersCountUpdateEventKind.snapshot, counts: list),
      );
    }
  }

  void _onUpdated(RealtimeChannelEvent event) {
    final count = _parse(event.data);
    if (count == null) return;
    final next = Map<String, ServerUsersCount>.from(_latestSnapshot);
    next[count.serverAddress] = count;
    _latestSnapshot = next;
    if (!_controller.isClosed) {
      _controller.add(
        UsersCountUpdateEvent(kind: UsersCountUpdateEventKind.updated, counts: [count]),
      );
    }
  }

  ServerUsersCount? _parse(Map<String, dynamic> raw) {
    final serverAddress = raw['serverAddress'] ?? raw['server_address'];
    if (serverAddress is! String || serverAddress.isEmpty) return null;
    return ServerUsersCount.fromJson(raw);
  }
}
