import 'dart:async';

import '../../models/realtime_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// 地图信息变更事件
class MapInfoChangedEvent {
  /// 地图名（小写）
  final String mapName;

  /// 触发原因：`""` / `contribution` / `admin` / `sync`
  final String reason;

  const MapInfoChangedEvent({required this.mapName, required this.reason});
}

/// `map.info` 频道适配器
class RealtimeMapInfoChannel {
  RealtimeMapInfoChannel._internal();

  static final RealtimeMapInfoChannel _instance =
      RealtimeMapInfoChannel._internal();

  factory RealtimeMapInfoChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<MapInfoChangedEvent> _controller =
      StreamController<MapInfoChangedEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;
  int _refCount = 0;

  Stream<MapInfoChangedEvent> get events => _controller.stream;

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.mapInfo)
          .listen(_onEvent);
      _service.subscribe(RealtimeChannels.mapInfo);
    }
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.mapInfo);
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _onEvent(RealtimeChannelEvent event) {
    if (event.eventType != RealtimeEventTypes.changed) {
      LogService.d('[Realtime/MapInfo] 忽略事件: ${event.eventType}');
      return;
    }
    final mapName = (event.data['mapName'] as String?)?.toLowerCase().trim();
    if (mapName == null || mapName.isEmpty) return;
    final reason = (event.data['reason'] as String?) ?? '';
    if (!_controller.isClosed) {
      _controller.add(MapInfoChangedEvent(mapName: mapName, reason: reason));
    }
  }
}
