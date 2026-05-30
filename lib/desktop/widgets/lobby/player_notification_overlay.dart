import 'package:flutter/material.dart';

/// 单个玩家通知项（CS2 风格：黑底白字）
class _PlayerNotificationItem extends StatefulWidget {
  /// 玩家显示名称
  final String playerName;

  /// 通知类型（0=join, 1=leave, 2=teleport, 3=teleportIn）
  final int type;

  /// 目标地图名称（teleport 类型使用）
  final String? targetMapName;

  /// 来源地图名称（teleportIn 类型使用）
  final String? sourceMapName;

  /// 通知ID
  final String notificationId;

  /// 回调：当动画完成时通知父组件移除此通知
  final void Function(String id) onExpire;

  const _PlayerNotificationItem({
    required this.playerName,
    required this.type,
    this.targetMapName,
    this.sourceMapName,
    required this.notificationId,
    required this.onExpire,
  });

  @override
  State<_PlayerNotificationItem> createState() =>
      _PlayerNotificationItemState();
}

class _PlayerNotificationItemState extends State<_PlayerNotificationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  /// CS2 风格配色
  /// 背景：半透明黑色（约60%）
  static const _backgroundColor = Color(0x99000000);

  /// 加入玩家：绿色
  static const _joinColor = Color(0xFF6BBF59);

  /// 离开玩家：橙色
  static const _leaveColor = Color(0xFFFFB74D);

  /// 传送玩家：浅蓝色
  static const _teleportColor = Color(0xFF64B5F6);

  /// 文字主色：白色
  static const _textColor = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // 3秒后开始淡出
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onExpire(widget.notificationId);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 获取类型对应的颜色
  Color get _typeColor {
    switch (widget.type) {
      case 0: // online
        return _joinColor;
      case 1: // offline
        return _leaveColor;
      case 2: // teleport
        return _teleportColor;
      case 3: // teleportIn
        return _teleportColor;
      default:
        return _textColor;
    }
  }

  /// 获取类型对应的符号
  String get _typeSymbol {
    switch (widget.type) {
      case 0: // online
        return '+';
      case 1: // offline
        return '-';
      case 2: // teleport
        return '>';
      case 3: // teleportIn
        return '<';
      default:
        return '';
    }
  }

  /// 获取动作文字
  String get _actionText {
    switch (widget.type) {
      case 0: // online
        return '上线了';
      case 1: // offline
        return '下线了';
      case 2: // teleport（传送离开）
        return '传送';
      case 3: // teleportIn（传送进入）
        return '传送过来';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 类型符号
            SizedBox(
              width: 14,
              child: Text(
                _typeSymbol,
                style: TextStyle(
                  color: _typeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 玩家名（带颜色）
            Flexible(
              child: Text(
                widget.playerName,
                style: TextStyle(
                  color: _typeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            // 动作文字（白色）
            Text(
              _actionText,
              style: const TextStyle(
                color: _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            // 传送目标（teleport 离开）
            if (widget.type == 2 && widget.targetMapName != null) ...[
              const SizedBox(width: 4),
              Text(
                '→ ${widget.targetMapName}',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            // 传送来源（teleportIn 进入）
            if (widget.type == 3 && widget.sourceMapName != null) ...[
              const SizedBox(width: 4),
              Text(
                '← ${widget.sourceMapName}',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 包装器类：为 _PlayerNotificationItem 提供 key
class _NotificationItemWrapper extends StatelessWidget {
  final dynamic notification;
  final void Function(String id) onExpire;

  const _NotificationItemWrapper({
    super.key,
    required this.notification,
    required this.onExpire,
  });

  @override
  Widget build(BuildContext context) {
    return _PlayerNotificationItem(
      playerName: notification.playerName as String,
      type: notification.type.index as int,
      targetMapName: notification.targetMapName as String?,
      sourceMapName: notification.sourceMapName as String?,
      notificationId: notification.id as String,
      onExpire: onExpire,
    );
  }
}

/// 玩家通知覆盖层组件
/// CS2 风格：黑底白字，右上角队列显示
/// 机制：新的从顶部插入，旧的通知被推下去并淡出
/// 注意：此组件会被嵌入到 Positioned.fill 中，所以不需要 Positioned
class PlayerNotificationOverlay extends StatelessWidget {
  /// 通知列表
  final List<dynamic> notifications;

  /// 回调：当通知过期时通知父组件
  final void Function(String id) onNotificationExpire;

  const PlayerNotificationOverlay({
    super.key,
    required this.notifications,
    required this.onNotificationExpire,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    // 只显示最新的5条通知
    final visibleNotifications = notifications.take(5).toList();

    // 从屏幕顶部约 20% 的高度开始显示，贴着最右边
    final screenHeight = MediaQuery.of(context).size.height;
    final topOffset = screenHeight * 0.10;

    // 使用 Align 配合 alignment 来实现右上角定位（不依赖 Positioned）
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(top: topOffset, right: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: visibleNotifications.map((notification) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _NotificationItemWrapper(
                key: ValueKey(notification.id),
                notification: notification,
                onExpire: onNotificationExpire,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
