import 'dart:async';

import '../../models/realtime_models.dart';
import '../../utils/log_service.dart';
import '../realtime_service.dart';

/// 创意工坊更新日志频道事件
class WorkshopChangelogEvent {
  /// Steam 创意工坊 Item ID
  final int workshopItemId;

  /// 更新时间（Unix 时间戳，秒）
  final int updateTime;

  /// 更新内容
  final String content;

  const WorkshopChangelogEvent({
    required this.workshopItemId,
    required this.updateTime,
    required this.content,
  });
}

/// 创意工坊更新日志频道 (`workshop.changelog`) 适配器
///
/// 把 [RealtimeService] 通用频道事件解析成业务层友好的 [WorkshopChangelogEvent]。
class RealtimeWorkshopChangelogChannel {
  RealtimeWorkshopChangelogChannel._internal();

  static final RealtimeWorkshopChangelogChannel _instance =
      RealtimeWorkshopChangelogChannel._internal();

  factory RealtimeWorkshopChangelogChannel() => _instance;

  final RealtimeService _service = RealtimeService();
  final StreamController<WorkshopChangelogEvent> _controller =
      StreamController<WorkshopChangelogEvent>.broadcast();
  StreamSubscription<RealtimeChannelEvent>? _subscription;
  int _refCount = 0;

  Stream<WorkshopChangelogEvent> get events => _controller.stream;

  /// 订阅频道（引用计数）
  void subscribe() {
    _refCount += 1;
    if (_refCount == 1) {
      _subscription ??= _service
          .events(RealtimeChannels.workshopChangelog)
          .listen(_onEvent);
      _service.subscribe(RealtimeChannels.workshopChangelog);
    }
  }

  /// 取消订阅
  void unsubscribe() {
    if (_refCount <= 0) return;
    _refCount -= 1;
    if (_refCount == 0) {
      _service.unsubscribe(RealtimeChannels.workshopChangelog);
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _onEvent(RealtimeChannelEvent event) {
    if (event.eventType != RealtimeEventTypes.workshopChangelogNew) {
      LogService.d('[Realtime/WorkshopChangelog] 忽略未知事件类型: ${event.eventType}');
      return;
    }

    final workshopItemId = (event.data['workshopItemId'] as num?)?.toInt() ?? 0;
    final updateTime = (event.data['updateTime'] as num?)?.toInt() ?? 0;
    final content = (event.data['content'] as String?) ?? '';

    if (workshopItemId <= 0) {
      LogService.d(
        '[Realtime/WorkshopChangelog] 缺失 workshopItemId: ${event.data}',
      );
      return;
    }

    if (!_controller.isClosed) {
      _controller.add(
        WorkshopChangelogEvent(
          workshopItemId: workshopItemId,
          updateTime: updateTime,
          content: content,
        ),
      );
    }
  }
}
