import 'dart:async';

import '../../models/realtime_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// 公告频道事件类型（业务层）
enum AnnouncementChannelEventKind {
  created,
  updated,
  statusChanged,
  stickyChanged,
  deleted,
}

/// 公告频道事件
class AnnouncementChannelEvent {
  final AnnouncementChannelEventKind kind;
  final int id;
  final Map<String, dynamic>? raw;

  const AnnouncementChannelEvent({
    required this.kind,
    required this.id,
    this.raw,
  });
}

/// 公告频道 (`announcements`) 适配器
///
/// 把 [RealtimeService] 通用频道事件解析成业务层友好的 [AnnouncementChannelEvent]。
class RealtimeAnnouncementChannel {
  RealtimeAnnouncementChannel._internal();

  static final RealtimeAnnouncementChannel _instance =
      RealtimeAnnouncementChannel._internal();

  factory RealtimeAnnouncementChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<AnnouncementChannelEvent> _controller =
      StreamController<AnnouncementChannelEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;
  int _refCount = 0;

  Stream<AnnouncementChannelEvent> get events => _controller.stream;

  /// 订阅频道（引用计数）
  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.announcements)
          .listen(_onEvent);
      _service.subscribe(RealtimeChannels.announcements);
    }
  }

  /// 取消订阅
  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.announcements);
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _onEvent(RealtimeChannelEvent event) {
    final kind = _kindFromEventType(event.eventType);
    if (kind == null) {
      LogService.d('[Realtime/Announcement] 忽略未知事件类型: ${event.eventType}');
      return;
    }

    final id = (event.data['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) {
      LogService.d('[Realtime/Announcement] 缺失 id 字段: ${event.data}');
      return;
    }

    if (!_controller.isClosed) {
      _controller.add(
        AnnouncementChannelEvent(kind: kind, id: id, raw: event.data),
      );
    }
  }

  AnnouncementChannelEventKind? _kindFromEventType(String eventType) {
    switch (eventType) {
      case RealtimeEventTypes.announcementCreated:
        return AnnouncementChannelEventKind.created;
      case RealtimeEventTypes.announcementUpdated:
        return AnnouncementChannelEventKind.updated;
      case RealtimeEventTypes.announcementStatusChanged:
        return AnnouncementChannelEventKind.statusChanged;
      case RealtimeEventTypes.announcementStickyChanged:
        return AnnouncementChannelEventKind.stickyChanged;
      case RealtimeEventTypes.announcementDeleted:
        return AnnouncementChannelEventKind.deleted;
      default:
        return null;
    }
  }
}
