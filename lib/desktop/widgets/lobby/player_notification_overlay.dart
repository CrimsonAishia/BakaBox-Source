import 'dart:async';
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

  /// 停留时间（动态变化）
  final Duration displayDuration;

  /// 是否被鼠标悬停
  final bool isHovered;

  /// 回调：当动画完成时通知父组件移除此通知
  final void Function(String id) onExpire;

  const _PlayerNotificationItem({
    required this.playerName,
    required this.type,
    this.targetMapName,
    this.sourceMapName,
    required this.notificationId,
    required this.displayDuration,
    required this.isHovered,
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
  Timer? _timer;

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

    _controller.forward();
    _startTimer(widget.displayDuration);
  }

  @override
  void didUpdateWidget(covariant _PlayerNotificationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 悬停状态发生改变
    if (widget.isHovered != oldWidget.isHovered) {
      if (widget.isHovered) {
        _timer?.cancel(); // 悬停时暂停计时
      } else {
        _startTimer(widget.displayDuration); // 移开时重新开始计时
      }
    } else if (!widget.isHovered &&
        widget.displayDuration < oldWidget.displayDuration) {
      // 只有在没被悬停时，才因为队列积压更新定时器
      _startTimer(widget.displayDuration);
    }
  }

  void _startTimer(Duration duration) {
    if (widget.isHovered) return; // 防御性判断
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (mounted && _controller.status != AnimationStatus.reverse) {
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
    _timer?.cancel();
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
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3), // 将外层的 padding 移到这里，使其一同缩放
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
      ),
    );
  }
}

/// 包装器类：为 _PlayerNotificationItem 提供 key
class _NotificationItemWrapper extends StatelessWidget {
  final dynamic notification;
  final int queueLength;
  final bool isHovered;
  final void Function(String id) onExpire;

  const _NotificationItemWrapper({
    super.key,
    required this.notification,
    required this.queueLength,
    required this.isHovered,
    required this.onExpire,
  });

  Duration get _displayDuration {
    if (queueLength > 15) return const Duration(milliseconds: 300);
    if (queueLength > 8) return const Duration(milliseconds: 600);
    if (queueLength > 5) return const Duration(milliseconds: 1000);
    return const Duration(milliseconds: 3000);
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerNotificationItem(
      playerName: notification.playerName as String,
      type: notification.type.index as int,
      targetMapName: notification.targetMapName as String?,
      sourceMapName: notification.sourceMapName as String?,
      notificationId: notification.id as String,
      displayDuration: _displayDuration,
      isHovered: isHovered,
      onExpire: onExpire,
    );
  }
}

/// 玩家通知覆盖层组件
/// CS2 风格：黑底白字，右上角队列显示
/// 机制：新的从顶部插入，旧的通知被推下去并淡出
/// 注意：此组件会被嵌入到 Positioned.fill 中，所以不需要 Positioned
class PlayerNotificationOverlay extends StatefulWidget {
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
  State<PlayerNotificationOverlay> createState() =>
      _PlayerNotificationOverlayState();
}

class _PlayerNotificationOverlayState extends State<PlayerNotificationOverlay> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    // 从屏幕顶部约 10% 的高度开始显示，贴着最右边
    final screenHeight = MediaQuery.of(context).size.height;
    final topOffset = screenHeight * 0.10;

    // 使用 Align 配合 alignment 来实现右上角定位（不依赖 Positioned）
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(top: topOffset, right: 0),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            // 渲染时限制最多可见 10 条，通过动态时长快速滚走积压条目
            children: widget.notifications.take(10).map((notification) {
              return Align(
                alignment: Alignment.centerRight,
                child: _NotificationItemWrapper(
                  key: ValueKey(notification.id),
                  notification: notification,
                  queueLength: widget.notifications.length,
                  isHovered: _isHovered,
                  onExpire: widget.onNotificationExpire,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
