import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';

/// 大厅聊天输入覆盖层
class LobbyChatOverlay extends StatefulWidget {
  final LobbyState state;
  final TextEditingController controller;
  final FocusNode focusNode;

  const LobbyChatOverlay({
    super.key,
    required this.state,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<LobbyChatOverlay> createState() => _LobbyChatOverlayState();
}

class _LobbyChatOverlayState extends State<LobbyChatOverlay> {
  /// 上一次同步时的 chatDraft 值，用于检测外部变化
  String? _lastSyncedDraft;

  @override
  void initState() {
    super.initState();
    _lastSyncedDraft = widget.state.chatDraft;
    widget.controller.text = widget.state.chatDraft;
  }

  @override
  void didUpdateWidget(LobbyChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 chatDraft 在外部被更新（如 chat.reject 恢复草稿）且与 controller 文本不一致时，同步到 controller
    // 不覆盖用户正在编辑的内容：只有当 controller 文本和当前 chatDraft 相同时才同步
    // 这样可以避免覆盖用户正在输入的内容
    if (widget.state.chatDraft != _lastSyncedDraft) {
      final controllerText = widget.controller.text;
      // 只有当 controller 内容与旧草稿一致（用户没有编辑）或为空时才同步
      if (controllerText == _lastSyncedDraft || controllerText.isEmpty) {
        widget.controller.text = widget.state.chatDraft;
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.state.chatDraft.length,
        );
      }
      _lastSyncedDraft = widget.state.chatDraft;
    }
  }

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MM-dd HH:mm');

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDay == today) {
      return _timeFormat.format(timestamp);
    }
    return _dateTimeFormat.format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final recentMessages = widget.state.messages.reversed.take(50).toList(growable: false);
    final isChatActive = widget.state.isChatActive;

    return SizedBox(
      width: 360,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 360,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isChatActive
              ? Colors.black.withValues(
                  alpha: (widget.state.chatOpacity + 0.18).clamp(0.0, 0.8),
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isChatActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isChatActive ? '大厅聊天（Enter 发送 / Esc 退出）' : '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            // 聊天消息列表
            SizedBox(
              height: 128,
              child: ListView.separated(
                reverse: true,
                // 聊天激活时启用滚动，禁用时阻止滚动传递
                primary: isChatActive,
                physics: isChatActive
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: recentMessages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final message = recentMessages[index];
                  final isSystem = message.type == LobbyMessageType.system;
                  final isBroadcast = message.type == LobbyMessageType.broadcast;
                  final isAnonymous = message.isAnonymous;

                  // 广播消息特殊样式：黄色加粗内容 + 动态底纹
                  if (isBroadcast) {
                    return _BroadcastMessageWidget(
                      message: message,
                      formatTime: _formatTime,
                    );
                  }

                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '[${_formatTime(message.timestamp)}] ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        TextSpan(
                          text: '${message.displayName}: ',
                          style: TextStyle(
                            color: isSystem
                                ? const Color(0xFFFFB74D) // 系统消息：橙色
                                : (isAnonymous
                                    ? const Color(0xFFB0BEC5) // 匿名用户：灰蓝色
                                    : const Color(0xFF81D4FA)), // 登录用户：浅蓝色
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: message.content,
                          style: TextStyle(
                            color: isSystem
                                ? Colors.white.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (isChatActive) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 50,
                    readOnly: widget.state.selfUser?.isAnonymous ?? false,
                    enabled: widget.state.chatCooldownSeconds <= 0,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: widget.state.selfUser?.isAnonymous ?? false
                          ? '登录后即可参与聊天'
                          : widget.state.chatCooldownSeconds > 0
                              ? '${widget.state.chatCooldownSeconds}秒后可发送'
                              : '输入消息',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    onChanged: (value) =>
                        context.read<LobbyBloc>().add(LobbyChatInputChanged(value)),
                    onSubmitted: (_) =>
                        context.read<LobbyBloc>().add(const LobbyChatSubmitted()),
                  ),
                  // 冷却动画覆盖层
                  if (widget.state.chatCooldownSeconds > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: Center(
                              child: _CooldownIndicator(seconds: widget.state.chatCooldownSeconds),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ] else
              GestureDetector(
                onTap: () {
                  // 点击"按 Enter 开始聊天"时打开聊天
                  context.read<LobbyBloc>().add(const LobbyChatModeChanged(true));
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '按 Enter 开始聊天',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 冷却倒计时动画组件
class _CooldownIndicator extends StatelessWidget {
  final int seconds;

  const _CooldownIndicator({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: Duration(seconds: seconds),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 圆形进度
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2.5,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
              ),
            ),
            // 倒计时数字
            Text(
              '$seconds',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 广播消息特殊样式组件：黄色加粗内容 + 动态渐变底纹
class _BroadcastMessageWidget extends StatefulWidget {
  final LobbyMessage message;
  final String Function(DateTime) formatTime;

  const _BroadcastMessageWidget({
    required this.message,
    required this.formatTime,
  });

  @override
  State<_BroadcastMessageWidget> createState() => _BroadcastMessageWidgetState();
}

class _BroadcastMessageWidgetState extends State<_BroadcastMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offsetValue = _controller.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                // 动态底纹：从深紫色到浅紫色再到深紫色
                Color.lerp(const Color(0xFF4C1D95), const Color(0xFF7C3AED),
                    0.5 + 0.5 * offsetValue)!,
                Color.lerp(const Color(0xFF7C3AED), const Color(0xFF4C1D95),
                    offsetValue)!,
              ],
              stops: const [0.0, 1.0],
            ),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF7C3AED),
                const Color(0xFFFBBF24),
                offsetValue,
              )!.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.campaign,
                color: Color.lerp(
                  const Color(0xFF7C3AED),
                  const Color(0xFFFBBF24),
                  offsetValue,
                ),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${widget.message.displayName}: ',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24), // 黄色
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: widget.message.content,
                        style: const TextStyle(
                          color: Color(0xFFFBBF24), // 黄色
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
