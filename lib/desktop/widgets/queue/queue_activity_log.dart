import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/models/queue_user.dart';

/// 活动日志类型
enum QueueActivityType {
  /// 用户加入
  join,

  /// 用户离开
  leave,

  /// 用户成功进入服务器
  success,
}

/// 活动日志条目
class QueueActivityItem {
  final String id;
  final QueueActivityType type;
  final String userName;
  final bool isSelf;
  final DateTime timestamp;

  const QueueActivityItem({
    required this.id,
    required this.type,
    required this.userName,
    required this.isSelf,
    required this.timestamp,
  });

  factory QueueActivityItem.fromUser(QueueUser user, QueueActivityType type) {
    return QueueActivityItem(
      id: '${user.uniqueId}_${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      userName: user.nickname ?? (user.isAnonymous ? '未登录用户' : '用户'),
      isSelf: user.isSelf,
      timestamp: DateTime.now(),
    );
  }
}

/// 挤服活动日志组件
///
/// 显示用户加入、离开、成功进入服务器的消息
class QueueActivityLog extends StatefulWidget {
  /// 活动日志列表
  final List<QueueActivityItem> activities;

  /// 最大显示条数
  final int maxItems;

  /// 是否为暖服模式
  final bool isWarmup;

  const QueueActivityLog({
    super.key,
    required this.activities,
    this.maxItems = 50,
    this.isWarmup = false,
  });

  @override
  State<QueueActivityLog> createState() => _QueueActivityLogState();
}

class _QueueActivityLogState extends State<QueueActivityLog> {
  final ScrollController _scrollController = ScrollController();

  // 记录上次最后一条消息的 id，用于检测新消息
  String? _lastActivityId;

  @override
  void initState() {
    super.initState();
    _lastActivityId = widget.activities.lastOrNull?.id;
  }

  @override
  void didUpdateWidget(QueueActivityLog oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 列表为空时重置
    if (widget.activities.isEmpty) {
      _lastActivityId = null;
      return;
    }

    // 检测是否有新消息（通过比较最后一条消息的 id）
    final currentLastId = widget.activities.last.id;
    if (currentLastId != _lastActivityId) {
      _lastActivityId = currentLastId;
      _scrollToBottom();
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    // 使用 addPostFrameCallback 确保 ListView 已经更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 如果 ScrollController 还没有 attach（比如从空列表变为非空）
      // 需要再等一帧
      if (!_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
        return;
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 限制显示条数
    final displayActivities = widget.activities.length > widget.maxItems
        ? widget.activities.sublist(widget.activities.length - widget.maxItems)
        : widget.activities;

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
            : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  MdiIcons.messageTextOutline,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  '动态',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.activities.length} 条',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: displayActivities.isEmpty
                ? Center(
                    child: Text(
                      '暂无动态',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    itemCount: displayActivities.length,
                    itemBuilder: (context, index) {
                      return _ActivityItemWidget(
                        activity: displayActivities[index],
                        isDark: isDark,
                        isWarmup: widget.isWarmup,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItemWidget extends StatelessWidget {
  final QueueActivityItem activity;
  final bool isDark;
  final bool isWarmup;

  const _ActivityItemWidget({
    required this.activity, 
    required this.isDark,
    this.isWarmup = false,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = _getActivityInfo();
    final timeStr = _formatTime(activity.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: activity.isSelf ? '你' : activity.userName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: activity.isSelf
                          ? const Color(0xFF3B82F6)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  TextSpan(
                    text: ' $message',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              maxLines: null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  (IconData, Color, String) _getActivityInfo() {
    final actionName = isWarmup ? '暖服' : '挤服';
    switch (activity.type) {
      case QueueActivityType.join:
        return (MdiIcons.accountPlus, const Color(0xFF22C55E), '加入了$actionName');
      case QueueActivityType.leave:
        return (MdiIcons.accountMinus, const Color(0xFFF59E0B), '离开了$actionName');
      case QueueActivityType.success:
        return (MdiIcons.checkCircle, const Color(0xFF3B82F6), '成功进入服务器！');
    }
  }
}
