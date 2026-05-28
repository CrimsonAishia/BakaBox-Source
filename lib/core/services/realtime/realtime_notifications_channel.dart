import 'dart:async';

import '../../models/notification_models.dart';
import '../../models/realtime_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// `notifications` 频道适配器（用户级，需登录）
class RealtimeNotificationsChannel {
  RealtimeNotificationsChannel._internal();

  static final RealtimeNotificationsChannel _instance =
      RealtimeNotificationsChannel._internal();

  factory RealtimeNotificationsChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<NotificationItem> _newItemController =
      StreamController<NotificationItem>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;
  int _refCount = 0;

  /// 新消息流（`new` 事件）
  Stream<NotificationItem> get newItemStream => _newItemController.stream;

  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.notifications)
          .listen(_onEvent);
      _service.subscribe(RealtimeChannels.notifications);
    }
  }

  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.notifications);
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _onEvent(RealtimeChannelEvent event) {
    if (event.eventType != RealtimeEventTypes.created) {
      LogService.d('[Realtime/Notifications] 忽略事件: ${event.eventType}');
      return;
    }
    final json = _normalize(event.data);
    try {
      final item = NotificationItem.fromJson(json);
      if (!_newItemController.isClosed) {
        _newItemController.add(item);
      }
    } catch (e) {
      LogService.w('[Realtime/Notifications] 解析失败: $e');
    }
  }

  /// 服务端时间戳是毫秒数字，模型期望字符串日期，做一次归一化
  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final created = map['createdAt'];
    if (created is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(created.toInt());
      map['createdAt'] = dt.toIso8601String();
    }
    final read = map['readAt'];
    if (read is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(read.toInt());
      map['readAt'] = dt.toIso8601String();
    }
    return map;
  }
}
