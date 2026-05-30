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
    this.initialBottom = 100,
    this.initialRight = 50,
  });

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;

  /// Controls the button opacity: 1.0 = fully visible, 0.0 = fully transparent.
  /// We clamp the actual displayed opacity between [_minOpacity] and 1.0.
  late AnimationController _opacityController;
  late Animation<double> _opacityAnimation;

  /// New-message notification animation: bounce + ripple.
  late AnimationController _notifyController;
  late Animation<double> _notifyScale;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  /// Connection state transition animation controller.
  late AnimationController _connectionController;
  late Animation<Color?> _buttonColorAnimation;
  late Animation<Color?> _shadowColorAnimation;
  late Animation<double> _connectionIconOpacity;

  /// Pulsing animation for connecting state.
  late AnimationController _connectingPulseController;

  /// Minimum opacity — button is always visible enough to locate.
  static const double _minOpacity = 0.35;

  /// Opacity when active (unread messages / recently interacted).
  static const double _maxOpacity = 1.0;

  /// How long to stay fully visible after a user interaction (tap/drag).
  static const Duration _activeHoldDuration = Duration(seconds: 10);

  /// How long the fade-out transition takes.
  static const Duration _fadeDuration = Duration(seconds: 3);

  /// Interval between periodic bounce animations when there are unread messages.
  static const Duration _bouncePeriod = Duration(seconds: 3);

  Timer? _activeHoldTimer;
  Timer? _bounceTimer;
  Timer? _connectingTimeoutTimer;
  bool _hasUnread = false;
  bool _isHovered = false;

  /// Track the current connection status for animation transitions.
  LobbyConnectionStatus _currentConnectionStatus =
      LobbyConnectionStatus.connecting;

  // Color constants for connection states.
  static const Color _disconnectedColor = Color(0xFF6B7280);
  static const Color _connectingColor = Color(0xFF38BDF8);
  static const Color _connectedColor = Color(0xFF0080FF);

  /// Prevent double-firing the notify animation from both _addBubble and
  /// the FloatingChatCubit unreadCount listener in the same frame.
  bool _notifyScheduledThisFrame = false;

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
  bool _didSyncInitialConnectionStatus = false;

  @override
  void initState() {
    super.initState();
    _mountedAt = DateTime.now();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Start fully visible, then fade to min after the hold duration.
    _opacityController = AnimationController(
      vsync: this,
      value: 1.0, // start fully visible
    );
    _opacityAnimation = Tween<double>(
      begin: _minOpacity,
      end: _maxOpacity,
    ).animate(_opacityController);

    // New-message notify animation (total ~700ms).
    _notifyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Bounce: 1.0 → 1.22 → 0.93 → 1.0 using a custom curve sequence.
    _notifyScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.22,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.22,
          end: 0.93,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.93,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_notifyController);
    // Ripple scale: button size → 2.4× over the full duration.
    _rippleScale = Tween<double>(begin: 1.0, end: 2.4).animate(
      CurvedAnimation(parent: _notifyController, curve: Curves.easeOut),
    );
    // Ripple opacity: fade from 0.55 → 0 in the second half.
    _rippleOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.55), weight: 20),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.55,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 80,
      ),
    ]).animate(_notifyController);

    // Connection state transition animation (color morph).
    _connectionController = AnimationController(
      vsync: this,
      value: 0.5, // start at connecting midpoint
      duration: const Duration(milliseconds: 600),
    );
    _buttonColorAnimation =
        ColorTween(begin: _disconnectedColor, end: _connectedColor).animate(
          CurvedAnimation(
            parent: _connectionController,
            curve: Curves.easeInOut,
          ),
        );
    _shadowColorAnimation =
        ColorTween(
          begin: _disconnectedColor.withValues(alpha: 0.3),
          end: _connectedColor.withValues(alpha: 0.3),
        ).animate(
          CurvedAnimation(
            parent: _connectionController,
            curve: Curves.easeInOut,
          ),
        );
    _connectionIconOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _connectionController, curve: Curves.easeInOut),
    );

    // Pulsing animation for connecting/reconnecting state.
    _connectingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Initial state is connecting, start pulsing immediately.
    _connectingPulseController.repeat(reverse: true);
    // Start timeout for initial connecting state.
    _connectingTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_isDisposed) return;
      if (_currentConnectionStatus == LobbyConnectionStatus.connecting ||
          _currentConnectionStatus == LobbyConnectionStatus.reconnecting) {
        _connectingPulseController.stop();
        _connectingPulseController.value = 0.0;
        _connectionController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeIn,
        );
        _currentConnectionStatus = LobbyConnectionStatus.disconnected;
        _updateOpacityForState(hasUnread: _hasUnread, isDisconnected: true);
        setState(() {});
      }
    });

    // Begin the initial fade-out after a short grace period (hold 3s first).
    _activeHoldTimer = Timer(_activeHoldDuration, _scheduleIdleFade);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSyncInitialConnectionStatus) {
      _didSyncInitialConnectionStatus = true;
      final status = context.read<LobbyBloc>().state.connectionStatus;
      // If already connected or in a non-initial state, sync immediately.
      // If still disconnected (startup default), keep the connecting appearance
      // since LobbyStarted will fire momentarily.
      if (status != LobbyConnectionStatus.disconnected) {
        _animateConnectionTransition(status);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeHoldTimer?.cancel();
    _bounceTimer?.cancel();
    _connectingTimeoutTimer?.cancel();
    _hoverController.dispose();
    _opacityController.dispose();
    _notifyController.dispose();
    _connectionController.dispose();
    _connectingPulseController.dispose();
    for (final entry in _bubbles) {
      entry.controller.dispose();
      entry.expireTimer.cancel();
    }
    _bubbles.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Opacity helpers
  // ---------------------------------------------------------------------------

  /// Immediately snap to full opacity and restart the idle-fade timer.
  void _activateOpacity() {
    _activeHoldTimer?.cancel();
    _opacityController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    _activeHoldTimer = Timer(_activeHoldDuration, _scheduleIdleFade);
  }

  /// Fade the button down to [_minOpacity] over [_fadeDuration].
  void _scheduleIdleFade() {
    if (_isDisposed) return;
    // Don't fade out while there are unread messages.
    if (_hasUnread) return;
    _opacityController.animateTo(
      0.0, // controller 0 → animation value = _minOpacity
      duration: _fadeDuration,
      curve: Curves.easeInOut,
    );
  }

  /// Start the periodic bounce timer for unread-message reminder.
  void _startBounceTimer() {
    _bounceTimer?.cancel();
    _bounceTimer = Timer.periodic(_bouncePeriod, (_) {
      if (_isDisposed || _isPanelOpen) return;
      _triggerNewMessageAnimation();
    });
  }

  /// Stop the periodic bounce timer.
  void _stopBounceTimer() {
    _bounceTimer?.cancel();
    _bounceTimer = null;
  }

  /// Animate the button appearance based on connection status transitions.
  void _animateConnectionTransition(LobbyConnectionStatus newStatus) {
    if (newStatus == _currentConnectionStatus) return;
    final oldStatus = _currentConnectionStatus;
    _currentConnectionStatus = newStatus;

    // Cancel any pending connecting timeout.
    _connectingTimeoutTimer?.cancel();
    _connectingTimeoutTimer = null;

    switch (newStatus) {
      case LobbyConnectionStatus.connected:
        // Stop pulsing, animate to connected color.
        _connectingPulseController.stop();
        _connectingPulseController.value = 0.0;
        // If coming from connecting/reconnecting, animate from midpoint.
        if (oldStatus == LobbyConnectionStatus.connecting ||
            oldStatus == LobbyConnectionStatus.reconnecting) {
          _connectionController.animateTo(
            1.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        } else {
          _connectionController.animateTo(
            1.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
        break;
      case LobbyConnectionStatus.connecting:
      case LobbyConnectionStatus.reconnecting:
        // Animate to midpoint color and start pulsing.
        _connectionController.animateTo(
          0.5,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
        _connectingPulseController.repeat(reverse: true);
        // If still connecting after 10s, fall back to disconnected appearance.
        _connectingTimeoutTimer = Timer(const Duration(seconds: 10), () {
          if (_isDisposed) return;
          if (_currentConnectionStatus == LobbyConnectionStatus.connecting ||
              _currentConnectionStatus == LobbyConnectionStatus.reconnecting) {
            _connectingPulseController.stop();
            _connectingPulseController.value = 0.0;
            _connectionController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeIn,
            );
            _currentConnectionStatus = LobbyConnectionStatus.disconnected;
            // Fade out the button since we're now in disconnected state.
            _updateOpacityForState(hasUnread: _hasUnread, isDisconnected: true);
            setState(() {});
          }
        });
        break;
      case LobbyConnectionStatus.disconnected:
      case LobbyConnectionStatus.failed:
        // Stop pulsing, animate back to disconnected color.
        _connectingPulseController.stop();
        _connectingPulseController.value = 0.0;
        _connectionController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
        );
        break;
    }
  }

  /// Called whenever the unread / connection state changes so we can decide
  /// whether to keep the button fully visible or let it fade.
  void _updateOpacityForState({
    required bool hasUnread,
    required bool isDisconnected,
  }) {
    _hasUnread = hasUnread;
    if (hasUnread) {
      // Always fully visible when there are unread messages — cancel idle fade.
      _activeHoldTimer?.cancel();
      _activeHoldTimer = null;
      _opacityController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _startBounceTimer();
    } else {
      _stopBounceTimer();
      // Only fade out when truly disconnected/failed (not connecting/reconnecting).
      final shouldFade =
          isDisconnected &&
          _currentConnectionStatus != LobbyConnectionStatus.connecting &&
          _currentConnectionStatus != LobbyConnectionStatus.reconnecting;
      if (shouldFade) {
        _activeHoldTimer?.cancel();
        _activeHoldTimer = null;
        _opacityController.animateTo(
          0.0,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      } else if (!isDisconnected) {
        // Just connected — briefly show fully visible then start idle timer.
        _activateOpacity();
      }
    }
  }

  /// Trigger the bounce + ripple animation when a new message arrives.
  /// Uses a microtask dedup flag to prevent double-firing when both
  /// [_addBubble] and the unreadCount BlocListener fire in the same frame.
  void _triggerNewMessageAnimation() {
    if (_isPanelOpen) return;
    if (_notifyScheduledThisFrame) return;
    _notifyScheduledThisFrame = true;
    // Reset flag after the current microtask queue drains.
    Future.microtask(() => _notifyScheduledThisFrame = false);
    _notifyController
      ..stop()
      ..forward(from: 0.0);
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
    final angle = generateBubbleAngle(
      seed,
      angleMin: range.min,
      angleMax: range.max,
    );
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
    _triggerNewMessageAnimation();
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
    _activateOpacity();
    // _updateOpacityForState will be called by the unreadCount listener after
    // panelClosed() emits. If unread count is still > 0 after that emit,
    // _startBounceTimer will be called there. No need to check here.
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
            context.read<FloatingChatCubit>().onMessagesChanged(
              lobbyState.messages,
            );

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
          child: BlocListener<FloatingChatCubit, FloatingChatState>(
            listenWhen: (previous, current) =>
                previous.unreadCount != current.unreadCount,
            listener: (context, chatState) {
              final lobbyState = context.read<LobbyBloc>().state;
              final isDisconnected =
                  lobbyState.connectionStatus !=
                  LobbyConnectionStatus.connected;
              _updateOpacityForState(
                hasUnread: chatState.unreadCount > 0,
                isDisconnected: isDisconnected,
              );
              // Trigger animation when a new unread message arrives.
              if (chatState.unreadCount > 0) {
                _triggerNewMessageAnimation();
              }
            },
            child: BlocListener<LobbyBloc, LobbyState>(
              listenWhen: (previous, current) =>
                  previous.connectionStatus != current.connectionStatus,
              listener: (context, lobbyState) {
                final chatState = context.read<FloatingChatCubit>().state;
                final isDisconnected =
                    lobbyState.connectionStatus !=
                    LobbyConnectionStatus.connected;
                _updateOpacityForState(
                  hasUnread: chatState.unreadCount > 0,
                  isDisconnected: isDisconnected,
                );
                // Animate the button color/icon based on connection state.
                _animateConnectionTransition(lobbyState.connectionStatus);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final parentSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  _left ??=
                      parentSize.width - _buttonSize - widget.initialRight;
                  _top ??=
                      parentSize.height - _buttonSize - widget.initialBottom;
                  _lastParentSize = parentSize;

                  return _buildContent(context, floatingState, parentSize);
                },
              ),
            ),
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
            left:
                (_left ?? 0) +
                _buttonSize / 2 -
                ChatBubbleAnimation.halfContainer,
            top:
                (_top ?? 0) +
                _buttonSize / 2 -
                ChatBubbleAnimation.halfContainer,
            child: ChatBubbleAnimation(
              bubbles: _bubbles,
              buttonSize: const Size(_buttonSize, _buttonSize),
            ),
          ),
        // Panel (when open)
        if (_isPanelOpen)
          Builder(
            builder: (_) {
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
            },
          ),
        // Draggable button — always rendered, hidden behind panel via opacity
        Positioned(
          left: _left ?? 0,
          top: _top ?? 0,
          child: IgnorePointer(
            ignoring: _isPanelOpen,
            child: AnimatedBuilder(
              animation: _opacityAnimation,
              builder: (context, child) {
                final opacity = _isPanelOpen
                    ? 0.0
                    : (_isHovered ? 1.0 : _opacityAnimation.value);
                return AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
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
    final scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    final isConnecting =
        _currentConnectionStatus == LobbyConnectionStatus.connecting ||
        _currentConnectionStatus == LobbyConnectionStatus.reconnecting;

    return MouseRegion(
      cursor: _isDragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.click,
      onEnter: (_) {
        if (!_isDragging) {
          _hoverController.forward();
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) {
        if (!_isDragging) {
          _hoverController.reverse();
          setState(() => _isHovered = false);
        }
      },
      child: GestureDetector(
        onPanStart: (_) {
          _dragDistance = 0.0;
          setState(() => _isDragging = true);
          _hoverController.reverse();
          _activateOpacity();
        },
        onPanUpdate: (details) {
          _dragDistance += details.delta.distance;
          setState(() {
            _left = ((_left ?? 0) + details.delta.dx).clamp(
              0.0,
              parentSize.width - _buttonSize,
            );
            _top = ((_top ?? 0) + details.delta.dy).clamp(
              0.0,
              parentSize.height - _buttonSize,
            );
          });
        },
        onPanEnd: (_) {
          final wasDrag = _dragDistance >= _dragThreshold;
          setState(() => _isDragging = false);

          // If the total drag distance was below threshold, treat as a tap
          if (!wasDrag) {
            _activateOpacity();
            setState(() => _isPanelOpen = true);
            context.read<FloatingChatCubit>().panelOpened();
          }
        },
        onTap: () {
          _activateOpacity();
          setState(() => _isPanelOpen = true);
          context.read<FloatingChatCubit>().panelOpened();
        },
        child: Tooltip(
          message: '点击打开 / 长按拖动',
          preferBelow: false,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: AnimatedBuilder(
              animation: _notifyController,
              builder: (context, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Ripple ring — only rendered while animation is running
                    if (_notifyController.isAnimating)
                      Positioned.fill(
                        child: Transform.scale(
                          scale: _rippleScale.value,
                          child: AnimatedBuilder(
                            animation: _buttonColorAnimation,
                            builder: (context, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        (_buttonColorAnimation.value ??
                                                _disconnectedColor)
                                            .withValues(
                                              alpha: _rippleOpacity.value,
                                            ),
                                    width: 2.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    // Button with bounce scale
                    Transform.scale(scale: _notifyScale.value, child: child),
                  ],
                );
              },
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _connectionController,
                  _connectingPulseController,
                ]),
                builder: (context, _) {
                  // Compute the current button color based on connection animation.
                  final baseColor =
                      _buttonColorAnimation.value ?? _disconnectedColor;
                  // Apply pulse effect during connecting state.
                  final pulseT = _connectingPulseController.value;
                  final buttonColor = isConnecting
                      ? Color.lerp(
                          baseColor,
                          baseColor.withValues(alpha: 0.6),
                          pulseT,
                        )!
                      : baseColor;
                  final shadowColor =
                      _shadowColorAnimation.value ??
                      _disconnectedColor.withValues(alpha: 0.3);
                  final iconOpacity = _connectionIconOpacity.value;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Connecting pulse ring
                      if (isConnecting)
                        Positioned.fill(
                          child: Transform.scale(
                            scale: 1.0 + pulseT * 0.3,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _connectingColor.withValues(
                                    alpha: 0.4 * (1 - pulseT),
                                  ),
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: _buttonSize,
                        height: _buttonSize,
                        decoration: BoxDecoration(
                          color: buttonColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _buildButtonIcon(
                            isDisconnected: isDisconnected,
                            isConnecting: isConnecting,
                            iconOpacity: iconOpacity,
                          ),
                        ),
                      ),
                      // Status indicator badge
                      if (!isDisconnected && !isConnecting)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: UnreadBadge(count: floatingState.unreadCount),
                        ),
                      if (isConnecting)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _buildConnectingBadge(),
                        ),
                      if (isDisconnected && !isConnecting)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _buildDisconnectedBadge(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonIcon({
    required bool isDisconnected,
    required bool isConnecting,
    required double iconOpacity,
  }) {
    if (isDisconnected) {
      return Icon(
        Icons.chat_bubble_outline,
        key: const ValueKey('disconnected'),
        color: Colors.white.withValues(alpha: iconOpacity),
        size: 24,
      );
    }
    return Icon(
      Icons.chat_bubble,
      key: const ValueKey('connected'),
      color: Colors.white.withValues(alpha: iconOpacity),
      size: 24,
    );
  }

  Widget _buildConnectingBadge() {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Color(0xFFF59E0B),
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(3),
        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
      ),
    );
  }

  Widget _buildDisconnectedBadge() {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close, color: Colors.white, size: 10),
    );
  }
}
