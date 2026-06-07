import 'dart:async';

import '../../api/server_api.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';
import 'realtime_map_info_channel.dart';

/// 监听 `map.info` 频道，收到变更事件时清除地图信息缓存并重新拉取，
/// 让 [ServerApi] 的内存 / 持久化缓存保持新鲜。
class RealtimeMapInfoInvalidator {
  RealtimeMapInfoInvalidator._internal();

  static final RealtimeMapInfoInvalidator _instance =
      RealtimeMapInfoInvalidator._internal();

  factory RealtimeMapInfoInvalidator() => _instance;

  final RealtimeMapInfoChannel _channel = RealtimeMapInfoChannel();
  final ServerApi _serverApi = ServerApi();

  StreamSubscription<MapInfoChangedEvent>? _subscription;
  StreamSubscription<void>? _reconnectedSubscription;
  bool _started = false;

  /// 启动监听（应用启动后调用一次）
  void start() {
    if (_started) return;
    _started = true;
    _channel.subscribe();
    _subscription = _channel.events.listen(_onChanged);
    // map.info 频道不回放断线期间的变更，重连后无法得知哪些地图变了，
    // 直接清空地图信息缓存，下次读取自动从 API 拉取最新数据
    _reconnectedSubscription = RealtimeService().reconnectedStream.listen((_) {
      LogService.d('[MapInfoInvalidator] 重连成功，清空地图信息缓存');
      _serverApi.clearMapInfoCache();
    });
    LogService.d('[MapInfoInvalidator] 已启动');
  }

  /// 停止监听
  void stop() {
    if (!_started) return;
    _started = false;
    _subscription?.cancel();
    _subscription = null;
    _reconnectedSubscription?.cancel();
    _reconnectedSubscription = null;
    _channel.unsubscribe();
  }

  Future<void> _onChanged(MapInfoChangedEvent event) async {
    final mapName = event.mapName;
    if (mapName.isEmpty) return;
    LogService.d(
      '[MapInfoInvalidator] map.info 变更: $mapName reason=${event.reason}',
    );
    // 清除缓存后强制刷新一次，让所有订阅者拿到新数据
    _serverApi.clearMapInfoCacheForMap(mapName);
    try {
      await _serverApi.refreshMapInfo(mapName);
    } catch (e) {
      LogService.w('[MapInfoInvalidator] 刷新地图信息失败: $mapName, $e');
    }
  }
}
