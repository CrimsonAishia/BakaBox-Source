import 'dart:async';
import 'dart:collection';

import '../../models/realtime_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

enum CategoryPlayersUpdateEventKind { snapshot, updated, syncing }

class CategoryPlayersUpdateEvent {
  final CategoryPlayersUpdateEventKind kind;
  final Map<String, int> counts;

  const CategoryPlayersUpdateEvent({required this.kind, required this.counts});
}

class RealtimeCategoryPlayersChannel {
  RealtimeCategoryPlayersChannel._internal();

  static final RealtimeCategoryPlayersChannel _instance =
      RealtimeCategoryPlayersChannel._internal();

  factory RealtimeCategoryPlayersChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<CategoryPlayersUpdateEvent> _controller =
      StreamController<CategoryPlayersUpdateEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;

  StreamSubscription<void>? _reconcileSubscription;
  int _refCount = 0;

  final Map<String, int> _latestSnapshot = {};
  late final Map<String, int> _latestSnapshotView = UnmodifiableMapView(
    _latestSnapshot,
  );

  Stream<CategoryPlayersUpdateEvent> get events => _controller.stream;

  Map<String, int> get latestSnapshot => _latestSnapshotView;

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.serverCategoryPlayers)
          .listen(_onEvent);
      _reconcileSubscription ??= _service.reconcileStream.listen((_) {
        _service.requestResnapshot(RealtimeChannels.serverCategoryPlayers);
      });
      _service.subscribe(RealtimeChannels.serverCategoryPlayers);
    }
  }

  void forceResnapshot() {
    _service.requestResnapshot(
      RealtimeChannels.serverCategoryPlayers,
      emitSyncing: true,
    );
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.serverCategoryPlayers);
      _subscription?.cancel();
      _subscription = null;
      _reconcileSubscription?.cancel();
      _reconcileSubscription = null;
      _latestSnapshot.clear();
    }
  }

  void _onEvent(RealtimeChannelEvent event) {
    switch (event.eventType) {
      case RealtimeEventTypes.snapshot:
        _onSnapshot(event);
        break;
      case RealtimeEventTypes.changed:
      case RealtimeEventTypes.updated:
        _onUpdated(event);
        break;
      case RealtimeEventTypes.syncing:
        _onSyncing();
        break;
      default:
        LogService.d('[Realtime/CategoryPlayers] 忽略事件: \${event.eventType}');
    }
  }

  void _onSyncing() {
    _latestSnapshot.clear();
    if (!_controller.isClosed) {
      _controller.add(
        const CategoryPlayersUpdateEvent(
          kind: CategoryPlayersUpdateEventKind.syncing,
          counts: {},
        ),
      );
    }
  }

  void _onSnapshot(RealtimeChannelEvent event) {
    final counts = _parseCounts(event);
    _latestSnapshot
      ..clear()
      ..addAll(counts);
    if (!_controller.isClosed) {
      _controller.add(
        CategoryPlayersUpdateEvent(
          kind: CategoryPlayersUpdateEventKind.snapshot,
          counts: Map.unmodifiable(_latestSnapshot),
        ),
      );
    }
  }

  void _onUpdated(RealtimeChannelEvent event) {
    final counts = _parseCounts(event);
    _latestSnapshot.addAll(counts);
    if (!_controller.isClosed) {
      _controller.add(
        CategoryPlayersUpdateEvent(
          kind: CategoryPlayersUpdateEventKind.updated,
          counts: Map.unmodifiable(counts),
        ),
      );
    }
  }

  Map<String, int> _parseCounts(RealtimeChannelEvent event) {
    final counts = <String, int>{};

    // Snapshot 返回一个包含 items 的数组，每个可能包含 'counts' 映射
    if (event.eventType == RealtimeEventTypes.snapshot) {
      for (final raw in event.snapshotItems) {
        if (raw['counts'] is Map) {
          final rawCounts = raw['counts'] as Map;
          rawCounts.forEach((key, value) {
            counts[key.toString()] = (value as num).toInt();
          });
        }
      }
    } else {
      // Updated 直接在 data 中返回 counts
      if (event.data['counts'] is Map) {
        final rawCounts = event.data['counts'] as Map;
        rawCounts.forEach((key, value) {
          counts[key.toString()] = (value as num).toInt();
        });
      }
    }
    return counts;
  }
}
