import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/bloc.dart';
import '../../../core/models/lobby_models.dart';
import 'chat_bubble_animation.dart';
import 'chat_panel.dart';
import 'unread_badge.dart';

class FloatingChatButton extends StatefulWidget {
  /// Initial offset from bottom-right corner of the parent Stack.
  final double initialBottom;
  final double initialRight;

  const FloatingChatButton({
    super.key,
    this.initialBottom = 50,
    this.initialRight = 50,
  });

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  final List<BubbleEntry> _bubbles = [];
  bool _isPanelOpen = false;

  static const double _buttonSize = 56.0;
  static const double _panelWidth = 320.0;
  static const double _panelHeight = 480.0;

  // Draggable position — stored as (left, top) in parent coordinates.
  double? _left;
  double? _top;
  bool _isDragging = false;
  bool _isDisposed = false;

  /// Accumulated drag distance to distinguish drag from tap.
  double _dragDistance = 0.0;

  /// Minimum pixels moved to count as a real drag (not an accidental micro-move).
  static const double _dragThreshold = 4.0;

  /// Cached parent size used when computing allowed angle range in _addBubble.
  Size? _lastParentSize;

  /// Track the last message ID we've seen to avoid duplicate bubbles.
  String? _lastSeenMessageId;
  bool _seeded = false;
  // Ignore bubbles for messages arriving within 2s of mount (initial load)
  late final DateTime _mountedAt;

  @override
  void initState() {
    super.initState();
    _mountedAt = DateTime.now();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hoverController.dispose();
    for (final entry in _bubbles) {
      entry.controller.dispose();
      entry.expireTimer.cancel();
    }
    _bubbles.clear();
    super.dispose();
  }

  /// Computes the allowed [angleMin, angleMax] range so that a bubble placed
  /// at [radius] from the button centre stays within [parentSize].
  ({double min, double max}) _allowedAngleRange(Size parentSize) {
    const radius = 56.0;
    // After rotation, the bounding box of the bubble is roughly its diagonal.
    // Original ~160×56, diagonal ≈ 170. Use 170 as the effective size.
    const bubbleSize = 170.0;
    const margin = 8.0;

    final btnLeft = _left ?? 0;
    final btnTop = _top ?? 0;
    final btnCx = btnLeft + _buttonSize / 2;
    final btnCy = btnTop + _buttonSize / 2;

    final spaceRight = parentSize.width - btnCx - margin;
    final spaceLeft = btnCx - margin;
    final spaceUp = btnCy - margin;
    final spaceDown = parentSize.height - btnCy - margin;

    const need = radius + bubbleSize / 2;

    final canRight = spaceRight >= need;
    final canLeft = spaceLeft >= need;
    final canUp = spaceUp >= need;
    final canDown = spaceDown >= need;

    final segments = <(double, double)>[];

    if (canRight && canUp) segments.add((0, pi / 2));
    if (canUp && canLeft) segments.add((pi / 2, pi));
    if (canLeft && canDown) segments.add((pi, 3 * pi / 2));
    if (canDown && canRight) segments.add((3 * pi / 2, 2 * pi));

    if (segments.isEmpty) {
      return (min: 0, max: 2 * pi);
    }

    segments.sort((a, b) => a.$1.compareTo(b.$1));

    final merged = <(double, double)>[segments.first];
    for (int i = 1; i < segments.length; i++) {
      final last = merged.last;
      final cur = segments[i];
      if ((cur.$1 - last.$2).abs() < 0.01) {
        merged[merged.length - 1] = (last.$1, cur.$2);
      } else {
        merged.add(cur);
      }
    }
    if (merged.length > 1 &&
        (merged.first.$1 - 0).abs() < 0.01 &&
        (merged.last.$2 - 2 * pi).abs() < 0.01) {
      final first = merged.removeAt(0);
      final last = merged.removeLast();
      merged.insert(0, (last.$1 - 2 * pi, first.$2));
    }

    (double, double) best = merged.first;
    for (final seg in merged) {
      if ((seg.$2 - seg.$1) > (best.$2 - best.$1)) best = seg;
    }

    return (min: best.$1, max: best.$2);
  }

  void _addBubble(LobbyMessage message) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_bubbles.length}';
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final seed = Random().nextDouble();
    final range = _allowedAngleRange(_lastParentSize ?? const Size(800, 600));
    final angle =
        generateBubbleAngle(seed, angleMin: range.min, angleMax: range.max);
    final text = truncateBubbleText(message.content);
    final senderName = truncateSenderName(message.displayName);

    final timer = Timer(const Duration(seconds: 4), () {
      _removeBubble(id);
    });

    final entry = BubbleEntry(
      id: id,
      text: text,
      senderName: senderName,
      angle: angle,
      controller: controller,
      expireTimer: timer,
    );

    controller.forward();
    setState(() => _bubbles.add(entry));
  }

  void _removeBubble(String id) {
    final index = _bubbles.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final entry = _bubbles[index];
    entry.expireTimer.cancel();

    entry.controller
        .animateTo(
      0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeIn,
    )
        .then((_) {
      if (_isDisposed) return;
      entry.controller.dispose();
      if (!mounted) return;
      setState(() => _bubbles.removeWhere((e) => e.id == id));
    });
  }

  void _onPanelClose() {
    setState(() => _isPanelOpen = false);
    context.read<FloatingChatCubit>().panelClosed();
  }

  /// Compute where the panel should be placed relative to the button.
  ({Offset offset, Alignment alignment}) _computePanelLayout(Size parentSize) {
    final btnLeft = _left ?? 0;
    final btnTop = _top ?? 0;
    final btnCenterX = btnLeft + _buttonSize / 2;
    final btnCenterY = btnTop + _buttonSize / 2;

    double panelLeft;
    final bool expandsLeft;
    if (btnCenterX > parentSize.width / 2) {
      panelLeft = btnLeft + _buttonSize - _panelWidth;
      expandsLeft = true;
    } else {
      panelLeft = btnLeft;
      expandsLeft = false;
    }

    double panelTop;
    final bool expandsUp;
    if (btnCenterY > parentSize.height / 2) {
      panelTop = btnTop + _buttonSize - _panelHeight;
      expandsUp = true;
    } else {
      panelTop = btnTop;
      expandsUp = false;
    }

    panelLeft = panelLeft.clamp(8.0, parentSize.width - _panelWidth - 8);
    panelTop = panelTop.clamp(8.0, parentSize.height - _panelHeight - 8);

    final alignment = Alignment(
      expandsLeft ? 1.0 : -1.0,
      expandsUp ? 1.0 : -1.0,
    );

    return (offset: Offset(panelLeft, panelTop), alignment: alignment);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FloatingChatCubit, FloatingChatState>(
      builder: (context, floatingState) {
        return BlocListener<LobbyBloc, LobbyState>(
          listenWhen: (previous, current) =>
              previous.messages.length != current.messages.length ||
              (previous.messages.isNotEmpty &&
                  current.messages.isNotEmpty &&
                  previous.messages.last.messageId !=
                      current.messages.last.messageId),
          listener: (context, lobbyState) {
            context
                .read<FloatingChatCubit>()
                .onMessagesChanged(lobbyState.messages);

            if (lobbyState.messages.isEmpty) return;

            final lastMsg = lobbyState.messages.lastWhere(
              (m) => !m.messageId.startsWith('local_'),
              orElse: () => lobbyState.messages.last,
            );

            final isNewId = lastMsg.messageId != _lastSeenMessageId;
            _lastSeenMessageId = lastMsg.messageId;

            if (!_seeded) {
              _seeded = true;
              return;
            }

            if (_isPanelOpen) return;
            if (lastMsg.messageId.startsWith('local_')) return;
            if (!isNewId) return;

            // Suppress bubbles during the initial load grace period (3s)
            if (DateTime.now().difference(_mountedAt) <
                const Duration(seconds: 3)) {
              return;
            }

            _addBubble(lastMsg);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final parentSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              _left ??= parentSize.width - _buttonSize - widget.initialRight;
              _top ??= parentSize.height - _buttonSize - widget.initialBottom;
              _lastParentSize = parentSize;

              return _buildContent(context, floatingState, parentSize);
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    FloatingChatState floatingState,
    Size parentSize,
  ) {
    final lobbyState = context.watch<LobbyBloc>().state;
    final isDisconnected =
        lobbyState.connectionStatus != LobbyConnectionStatus.connected;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bubble animation layer
        if (!_isPanelOpen)
          Positioned(
            left: (_left ?? 0) +
                _buttonSize / 2 -
                ChatBubbleAnimation.halfContainer,
            top: (_top ?? 0) +
                _buttonSize / 2 -
                ChatBubbleAnimation.halfContainer,
            child: ChatBubbleAnimation(
              bubbles: _bubbles,
              buttonSize: const Size(_buttonSize, _buttonSize),
            ),
          ),
        // Panel (when open)
        if (_isPanelOpen)
          Builder(builder: (_) {
            final layout = _computePanelLayout(parentSize);
            return Positioned(
              left: layout.offset.dx,
              top: layout.offset.dy,
              child: ChatPanel(
                key: const ValueKey('panel'),
                onClose: _onPanelClose,
                expandOrigin: layout.alignment,
              ),
            );
          }),
        // Draggable button — always rendered, hidden behind panel via opacity
        Positioned(
          left: _left ?? 0,
          top: _top ?? 0,
          child: IgnorePointer(
            ignoring: _isPanelOpen,
            child: AnimatedOpacity(
              opacity: _isPanelOpen ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: _buildDraggableButton(
                floatingState: floatingState,
                isDisconnected: isDisconnected,
                parentSize: parentSize,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableButton({
    required FloatingChatState floatingState,
    required bool isDisconnected,
    required Size parentSize,
  }) {
    final scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );

    return MouseRegion(
      cursor: _isDragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.click,
      onEnter: (_) {
        if (!_isDragging) _hoverController.forward();
      },
      onExit: (_) {
        if (!_isDragging) _hoverController.reverse();
      },
      child: GestureDetector(
        onPanStart: (_) {
          _dragDistance = 0.0;
          setState(() => _isDragging = true);
          _hoverController.reverse();
        },
        onPanUpdate: (details) {
          _dragDistance += details.delta.distance;
          setState(() {
            _left = ((_left ?? 0) + details.delta.dx)
                .clamp(0.0, parentSize.width - _buttonSize);
            _top = ((_top ?? 0) + details.delta.dy)
                .clamp(0.0, parentSize.height - _buttonSize);
          });
        },
        onPanEnd: (_) {
          final wasDrag = _dragDistance >= _dragThreshold;
          setState(() => _isDragging = false);

          // If the total drag distance was below threshold, treat as a tap
          if (!wasDrag) {
            setState(() => _isPanelOpen = true);
            context.read<FloatingChatCubit>().panelOpened();
          }
        },
        onTap: () {
          setState(() => _isPanelOpen = true);
          context.read<FloatingChatCubit>().panelOpened();
        },
        child: Tooltip(
          message: '点击打开 / 长按拖动',
          preferBelow: false,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _buttonSize,
                  height: _buttonSize,
                  decoration: BoxDecoration(
                    color: isDisconnected
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF0080FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDisconnected
                            ? const Color(0xFF6B7280).withValues(alpha: 0.3)
                            : const Color(0xFF0080FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isDisconnected
                        ? Icons.chat_bubble_outline
                        : Icons.chat_bubble,
                    color: isDisconnected
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.white,
                    size: 24,
                  ),
                ),
                if (!isDisconnected)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: UnreadBadge(count: floatingState.unreadCount),
                  ),
                if (isDisconnected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
