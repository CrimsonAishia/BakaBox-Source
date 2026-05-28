import 'dart:async';

import '../../models/realtime_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// 单条服务器换图条目
///
/// 对应 `server.map.runtime` 频道 `changed` / `snapshot.items[*]` 负载
class ServerMapRuntimeEntry {
  /// 服务器地址（domain:port 或 ip:port）
  final String serverAddress;

  /// 当前地图名
  final String mapName;

  /// 上一张地图（snapshot 不带）
  final String? oldMapName;

  /// 最大玩家数（可选）
  final int? maxPlayers;

  /// 主机名（可选）
  final String? hostName;

  /// 历史记录 ID（可选）
  final int? historyId;

  /// 换图时间（秒），可选
  final int? changedAt;

  const ServerMapRuntimeEntry({
    required this.serverAddress,
    required this.mapName,
    this.oldMapName,
    this.maxPlayers,
    this.hostName,
    this.historyId,
    this.changedAt,
  });

  factory ServerMapRuntimeEntry.fromJson(Map<String, dynamic> json) {
    return ServerMapRuntimeEntry(
      serverAddress: (json['serverAddress'] as String?) ?? '',
      mapName: (json['mapName'] as String?) ?? '',
      oldMapName: json['oldMapName'] as String?,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt(),
      hostName: json['hostname'] as String?,
      historyId: (json['historyId'] as num?)?.toInt(),
      changedAt: (json['changedAt'] as num?)?.toInt(),
    );
  }

  bool get isValid => serverAddress.isNotEmpty && mapName.isNotEmpty;
}

/// 服务器换图事件类型
enum ServerMapRuntimeEventKind { snapshot, changed }

/// 服务器换图事件
class ServerMapRuntimeEvent {
  final ServerMapRuntimeEventKind kind;

  /// snapshot 事件携带全量列表，changed 事件只有一个元素
  final List<ServerMapRuntimeEntry> entries;

  const ServerMapRuntimeEvent({required this.kind, required this.entries});
}

/// `server.map.runtime` 频道适配器
class RealtimeServerMapRuntimeChannel {
  RealtimeServerMapRuntimeChannel._internal();

  static final RealtimeServerMapRuntimeChannel _instance =
      RealtimeServerMapRuntimeChannel._internal();

  factory RealtimeServerMapRuntimeChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<ServerMapRuntimeEvent> _controller =
      StreamController<ServerMapRuntimeEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;
  int _refCount = 0;

  /// 最近一次 snapshot 缓存（订阅前已发生的事件可以取到最新状态）
  Map<String, ServerMapRuntimeEntry> _latestSnapshot = const {};

  /// 事件流
  Stream<ServerMapRuntimeEvent> get events => _controller.stream;

  /// 最近一次 snapshot 数据，按 serverAddress 索引
  Map<String, ServerMapRuntimeEntry> get latestSnapshot =>
      Map.unmodifiable(_latestSnapshot);

  /// 根据地址获取最近一次的换图条目
  ServerMapRuntimeEntry? snapshotFor(String serverAddress) =>
      _latestSnapshot[serverAddress];

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.serverMapRuntime)
          .listen(_onEvent);
      _service.subscribe(RealtimeChannels.serverMapRuntime);
    }
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.serverMapRuntime);
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
      case RealtimeEventTypes.changed:
        _onChanged(event);
        break;
      default:
        LogService.d('[Realtime/MapRuntime] 忽略事件: ${event.eventType}');
    }
  }

  void _onSnapshot(RealtimeChannelEvent event) {
    final items = event.snapshotItems
        .map(ServerMapRuntimeEntry.fromJson)
        .where((e) => e.isValid)
        .toList(growable: false);
    final indexed = <String, ServerMapRuntimeEntry>{};
    for (final entry in items) {
      indexed[entry.serverAddress] = entry;
    }
    _latestSnapshot = indexed;
    if (!_controller.isClosed) {
      _controller.add(
        ServerMapRuntimeEvent(
          kind: ServerMapRuntimeEventKind.snapshot,
          entries: items,
        ),
      );
    }
  }

  void _onChanged(RealtimeChannelEvent event) {
    final entry = ServerMapRuntimeEntry.fromJson(event.data);
    if (!entry.isValid) return;
    final next = Map<String, ServerMapRuntimeEntry>.from(_latestSnapshot);
    next[entry.serverAddress] = entry;
    _latestSnapshot = next;
    if (!_controller.isClosed) {
      _controller.add(
        ServerMapRuntimeEvent(
          kind: ServerMapRuntimeEventKind.changed,
          entries: [entry],
        ),
      );
    }
  }
}
