import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/core.dart';

/// 全局底部广播通知栏
/// 收到广播消息时从底部滑入，30秒后自动消失；新消息直接顶替旧消息
class GlobalBroadcastBar extends StatefulWidget {
  const GlobalBroadcastBar({super.key});

  @override
  State<GlobalBroadcastBar> createState() => _GlobalBroadcastBarState();
}

class _GlobalBroadcastBarState extends State<GlobalBroadcastBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  String? _nickname;
  String? _content;
  Timer? _hideTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 30;

  // 用最后一条已处理的 broadcast 消息 ID 来追踪，避免 length 比较的竞态问题
  String? _lastHandledMessageId;

  // 标记是否正在执行 dismiss 的 reverse 动画，防止 reverse 完成后覆盖新消息
  bool _isDismissing = false;

  static const int _displaySeconds = 30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showBroadcast(String nickname, String content) {
    // 取消所有旧定时器
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    // 标记不再处于 dismiss 流程
    _isDismissing = false;

    setState(() {
      _nickname = nickname;
      _content = content;
      _remainingSeconds = _displaySeconds;
    });

    // 无论当前动画状态，直接从头播放入场动画（顶替效果）
    _controller.forward(from: 0);

    // 30秒后自动消失
    _hideTimer = Timer(const Duration(seconds: _displaySeconds), _dismiss);

    // 每秒倒计时
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _remainingSeconds - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds = next);
      }
    });
  }

  void _dismiss() {
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _isDismissing = true;

    _controller.reverse().then((_) {
      // 只有仍处于 dismiss 流程时才清空内容，防止新消息被覆盖
      if (mounted && _isDismissing) {
        setState(() {
          _nickname = null;
          _content = null;
          _isDismissing = false;
        });
      }
    });
  }

  // 标记下一次 messages 变化是否来自快照（loading → ready 的那次）
  bool _suppressNextBroadcast = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LobbyBloc, LobbyState>(
      listenWhen: (prev, curr) {
        // 检测快照加载完成（loading → ready），标记下一次 messages 变化需要静默
        if (prev.pageStatus == LobbyPageStatus.loading &&
            curr.pageStatus == LobbyPageStatus.ready) {
          _suppressNextBroadcast = true;
        }
        return curr.messages != prev.messages;
      },
      listener: (context, state) {
        // 找最新的一条 broadcast
        LobbyMessage? latestBroadcast;
        for (int i = state.messages.length - 1; i >= 0; i--) {
          if (state.messages[i].type == LobbyMessageType.broadcast) {
            latestBroadcast = state.messages[i];
            break;
          }
        }

        // 快照带来的这次 messages 变化，无论有没有广播都要消费掉 suppress 标记
        final suppress = _suppressNextBroadcast;
        _suppressNextBroadcast = false;

        if (latestBroadcast == null) return;
        if (latestBroadcast.messageId == _lastHandledMessageId) return;

        _lastHandledMessageId = latestBroadcast.messageId;

        // 快照带来的历史广播，只标记不弹出
        if (suppress) return;

        _showBroadcast(latestBroadcast.nickname, latestBroadcast.content);
      },
      child: _nickname == null
          ? const SizedBox.shrink()
          : SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _BroadcastBarContent(
                  nickname: _nickname!,
                  content: _content!,
                  remainingSeconds: _remainingSeconds,
                  totalSeconds: _displaySeconds,
                  onClose: _dismiss,
                ),
              ),
            ),
    );
  }
}

class _BroadcastBarContent extends StatefulWidget {
  final String nickname;
  final String content;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onClose;

  const _BroadcastBarContent({
    required this.nickname,
    required this.content,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onClose,
  });

  @override
  State<_BroadcastBarContent> createState() => _BroadcastBarContentState();
}

class _BroadcastBarContentState extends State<_BroadcastBarContent> {
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    final progress =
        (widget.remainingSeconds / widget.totalSeconds).clamp(0.0, 1.0);
    // 进度条颜色：剩余多时白色，快到期时橙红色，与顶部紫色边框区分
    final barColor = Color.lerp(
      const Color(0xFFEF4444),
      const Color(0xFFE2E8F0),
      progress,
    )!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        border: const Border(
          top: BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 倒计时进度条（直接用 progress，无需 TweenAnimationBuilder）
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
          // 主内容行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
            child: Row(
              children: [
                // 广播图标 + 标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        '全服广播',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // 发送者
                Text(
                  widget.nickname,
                  style: const TextStyle(
                    color: Color(0xFFA5B4FC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(width: 1, height: 12, color: Colors.white24),
                const SizedBox(width: 6),
                // 内容
                Expanded(
                  child: Text(
                    widget.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // 倒计时秒数（颜色随进度变化）
                Text(
                  '${widget.remainingSeconds}s',
                  style: TextStyle(
                    color: barColor.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                // 关闭按钮（带 hover 效果）
                MouseRegion(
                  onEnter: (_) => setState(() => _closeHovered = true),
                  onExit: (_) => setState(() => _closeHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _closeHovered
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _closeHovered
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: _closeHovered ? Colors.white : Colors.white54,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
