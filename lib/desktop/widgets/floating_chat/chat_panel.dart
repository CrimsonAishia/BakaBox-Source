import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';
import '../lobby/lobby_broadcast_dialog.dart';

/// 浮动聊天面板，从 56×56 圆形展开为 320×480 矩形
class ChatPanel extends StatefulWidget {
  final VoidCallback onClose;

  /// The corner where the button sits relative to the panel.
  /// Controls which corner the expand/collapse animation originates from.
  final Alignment expandOrigin;

  const ChatPanel({
    super.key,
    required this.onClose,
    this.expandOrigin = Alignment.bottomRight,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const double _expandedWidth = 320.0;
  static const double _expandedHeight = 480.0;

  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MM-dd HH:mm');

  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scrollToBottom();
      }
    });
    _expandController.forward();
  }

  @override
  void dispose() {
    _expandController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _closePanel() {
    _expandController
        .animateTo(
      0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInCubic,
    )
        .then((_) {
      widget.onClose();
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<LobbyBloc>().add(LobbyChatSubmitted(text));
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// Remove local optimistic messages when a server-confirmed duplicate exists.
  ///
  /// Uses a time-bucket approach with ±1 bucket tolerance to handle boundary
  /// cases where local and server messages land in adjacent 5s windows.
  List<LobbyMessage> _deduplicateMessages(List<LobbyMessage> raw) {
    final serverKeys = <String>{};
    for (final msg in raw) {
      if (!msg.messageId.startsWith('local_')) {
        final bucket = msg.timestamp.millisecondsSinceEpoch ~/ 5000;
        serverKeys.add('${msg.userId}|${msg.content}|$bucket');
        serverKeys.add('${msg.userId}|${msg.content}|${bucket - 1}');
        serverKeys.add('${msg.userId}|${msg.content}|${bucket + 1}');
      }
    }

    return raw.where((msg) {
      if (!msg.messageId.startsWith('local_')) return true;
      final bucket = msg.timestamp.millisecondsSinceEpoch ~/ 5000;
      final key = '${msg.userId}|${msg.content}|$bucket';
      return !serverKeys.contains(key);
    }).toList();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay =
        DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (messageDay == today) {
      return _timeFormat.format(timestamp);
    }
    return _dateTimeFormat.format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = context.watch<LobbyBloc>().state;
    final isConnected =
        lobbyState.connectionStatus == LobbyConnectionStatus.connected;
    final isAnonymous = lobbyState.selfUser?.isAnonymous ?? true;
    final messages = _deduplicateMessages(lobbyState.messages);

    // Auto-scroll when new messages arrive
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    return AnimatedBuilder(
      animation: _expandController,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_expandController.value);
        final borderRadius = 28.0 + (12.0 - 28.0) * t;

        return SizedBox(
          width: _expandedWidth,
          height: _expandedHeight,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: _RevealClip(
                  progress: t,
                  origin: widget.expandOrigin,
                  child: Container(
                    color: const Color(0xFF1A1A2E),
                    child: Column(
                      children: [
                        _buildHeader(lobbyState),
                        Expanded(child: _buildMessageList(messages)),
                        if (!isConnected) _buildDisconnectedBanner(),
                        _buildInputRow(
                          isConnected: isConnected,
                          isAnonymous: isAnonymous,
                          lobbyState: lobbyState,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 广播弹窗叠加层
              if (lobbyState.isBroadcastDialogOpen)
                const Positioned.fill(child: LobbyBroadcastDialog(compact: true)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(LobbyState lobbyState) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble, color: Color(0xFF0080FF), size: 16),
          const SizedBox(width: 8),
          const Text(
            '大厅聊天',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _HoverIconButton(
            onTap: _closePanel,
            icon: Icons.close,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<LobbyMessage> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          '暂无消息',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final message = messages[index];
        if (message.type == LobbyMessageType.broadcast) {
          return _BroadcastMessageWidget(
            message: message,
            formatTime: _formatTime,
          );
        }
        return _buildRegularMessage(message);
      },
    );
  }

  Widget _buildRegularMessage(LobbyMessage message) {
    final isSystem = message.type == LobbyMessageType.system;
    final isAnonymous = message.isAnonymous;

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
                  ? const Color(0xFFFFB74D)
                  : (isAnonymous
                      ? const Color(0xFFB0BEC5)
                      : const Color(0xFF81D4FA)),
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
  }

  Widget _buildDisconnectedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: Colors.orange.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFFFB74D), size: 14),
          const SizedBox(width: 6),
          Text(
            '聊天服务未连接',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required bool isConnected,
    required bool isAnonymous,
    required LobbyState lobbyState,
  }) {
    final canType = isConnected && !isAnonymous;
    final cooldown = lobbyState.broadcastCooldownSeconds;
    final canBroadcast = !isAnonymous && isConnected && cooldown <= 0;

    // Anonymous users see a tappable prompt instead of a disabled text field
    if (isConnected && isAnonymous) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              // TODO: navigate to login if needed
            },
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '登录后即可参与聊天',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final hintText = !isConnected ? '聊天服务未连接' : '输入消息';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: isConnected,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLength: 50,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF0080FF), width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                onSubmitted: canType ? (_) => _sendMessage() : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _BroadcastButton(
            cooldown: cooldown,
            canBroadcast: canBroadcast,
            isAnonymous: isAnonymous,
            onTap: canBroadcast
                ? () => context
                    .read<LobbyBloc>()
                    .add(const LobbyBroadcastDialogToggled())
                : null,
          ),
          const SizedBox(width: 8),
          _SendButton(
            enabled: canType,
            onTap: _sendMessage,
          ),
        ],
      ),
    );
  }
}


/// 广播消息特殊样式 — uses a static gradient instead of infinite animation
/// to avoid unnecessary GPU usage for historical broadcast messages.
class _BroadcastMessageWidget extends StatelessWidget {
  final LobbyMessage message;
  final String Function(DateTime) formatTime;

  const _BroadcastMessageWidget({
    required this.message,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF4C1D95),
            Color(0xFF7C3AED),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.campaign,
            color: Color(0xFFFBBF24),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${message.displayName}: ',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: message.content,
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
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
  }
}

// ---------------------------------------------------------------------------
// _HoverIconButton — icon button with hover highlight
// ---------------------------------------------------------------------------

class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({
    required this.onTap,
    required this.icon,
    required this.size,
  });

  final VoidCallback onTap;
  final IconData icon;
  final double size;

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            color: _hovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SendButton — send button with hover effect
// ---------------------------------------------------------------------------

class _SendButton extends StatefulWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF0080FF);
    final disabledColor = Colors.white.withValues(alpha: 0.1);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.enabled
                ? (_hovered
                    ? Color.lerp(baseColor, Colors.white, 0.15)!
                    : baseColor)
                : disabledColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.send,
            color: widget.enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            size: 16,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BroadcastButton — broadcast button styled like _SendButton
// ---------------------------------------------------------------------------

class _BroadcastButton extends StatefulWidget {
  const _BroadcastButton({
    required this.cooldown,
    required this.canBroadcast,
    required this.isAnonymous,
    required this.onTap,
  });

  final int cooldown;
  final bool canBroadcast;
  final bool isAnonymous;
  final VoidCallback? onTap;

  @override
  State<_BroadcastButton> createState() => _BroadcastButtonState();
}

class _BroadcastButtonState extends State<_BroadcastButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFFF59E0B);
    final disabledColor = Colors.white.withValues(alpha: 0.1);

    final tooltipMsg = widget.isAnonymous
        ? '登录后可使用广播'
        : widget.cooldown > 0
            ? '冷却中 (${widget.cooldown}s)'
            : '全服广播';

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      child: MouseRegion(
        cursor: widget.canBroadcast
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.canBroadcast
                      ? (_hovered
                          ? Color.lerp(baseColor, Colors.white, 0.15)!
                          : baseColor)
                      : disabledColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.campaign,
                  color: widget.canBroadcast
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  size: 18,
                ),
              ),
              // 冷却 badge
              if (widget.cooldown > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.cooldown}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RevealClip — clips content to reveal from a specific corner
// ---------------------------------------------------------------------------

class _RevealClip extends StatelessWidget {
  const _RevealClip({
    required this.progress,
    required this.origin,
    required this.child,
  });

  final double progress;
  final Alignment origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: _RevealClipper(progress: progress, origin: origin),
      child: child,
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper({required this.progress, required this.origin});

  final double progress;
  final Alignment origin;

  static const double _collapsed = 56.0;

  @override
  Rect getClip(Size size) {
    final w = _collapsed + (size.width - _collapsed) * progress;
    final h = _collapsed + (size.height - _collapsed) * progress;

    final isRight = origin.x > 0;
    final isBottom = origin.y > 0;

    final left = isRight ? size.width - w : 0.0;
    final top = isBottom ? size.height - h : 0.0;

    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.origin != origin;
}
