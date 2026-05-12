import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/lobby/lobby_bloc.dart';
import '../../core/models/lobby_models.dart';

/// 全局广播悬浮通知卡片
/// - 收到广播时卡片从右侧弹入，显示在右下角
/// - 卡片内最多同时显示 3 条广播，新的从底部滑入，超出时最旧的从顶部滑出
/// - 所有广播都关闭后卡片整体退场
class GlobalBroadcastBar extends StatefulWidget {
  const GlobalBroadcastBar({super.key});

  @override
  State<GlobalBroadcastBar> createState() => _GlobalBroadcastBarState();
}

class _GlobalBroadcastBarState extends State<GlobalBroadcastBar>
    with SingleTickerProviderStateMixin {
  /// 卡片整体入场/退场动画
  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;

  /// 当前显示的广播列表（最旧在前，最新在后）
  /// 注意：退出动画期间条目仍留在列表中，由 _leavingIds 标记
  final List<LobbyBroadcastMessage> _messages = [];

  /// 正在播放退出动画的消息 id
  final Set<String> _leavingIds = {};

  StreamSubscription<LobbyBroadcastMessage>? _sub;

  static const int _maxMessages = 3;
  static const Duration _itemLeaveDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInCubic,
    ));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
        reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeIn),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = context.read<LobbyBloc>().broadcastStream.listen(_onBroadcast);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cardController.dispose();
    super.dispose();
  }

  // 有效消息数（不含正在退出的）
  int get _activeCount => _messages.where((m) => !_leavingIds.contains(m.messageId)).length;

  void _onBroadcast(LobbyBroadcastMessage msg) {
    if (!mounted) return;

    // 卡片整体入场：仅当当前没有任何消息（包括正在退出的）时触发
    final shouldEnter = _messages.isEmpty;

    // 如果有效消息已满，驱逐最旧的一条（跳过已在退出的）
    if (_activeCount >= _maxMessages) {
      final oldest = _messages.firstWhere(
        (m) => !_leavingIds.contains(m.messageId),
        orElse: () => _messages.first,
      );
      _leavingIds.add(oldest.messageId);
      Future.delayed(_itemLeaveDuration, () {
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.messageId == oldest.messageId);
          _leavingIds.remove(oldest.messageId);
        });
      });
    }

    setState(() => _messages.add(msg));

    if (shouldEnter) {
      // 如果卡片正在退场中，从当前位置反向播放入场
      _cardController.forward();
    }
  }

  void _dismissMessage(String messageId) {
    if (!mounted || _leavingIds.contains(messageId)) return;
    setState(() => _leavingIds.add(messageId));

    Future.delayed(_itemLeaveDuration, () {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.messageId == messageId);
        _leavingIds.remove(messageId);
      });
      _checkAndDismissCard();
    });
  }

  void _dismissAll() {
    if (!mounted) return;
    // 整体退场，动画结束后清空
    _cardController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _leavingIds.clear();
      });
    });
  }

  void _checkAndDismissCard() {
    // 所有消息（含正在退出的）都已移除，整体退场
    if (_messages.isEmpty && mounted) {
      _cardController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 卡片动画结束且无消息时，完全从树中移除
    if (_messages.isEmpty && _cardController.isDismissed) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _cardSlide,
      child: FadeTransition(
        opacity: _cardFade,
        child: _BroadcastCard(
          messages: List.unmodifiable(_messages),
          leavingIds: Set.unmodifiable(_leavingIds),
          onDismissMessage: _dismissMessage,
          onDismissAll: _dismissAll,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BroadcastCard extends StatelessWidget {
  final List<LobbyBroadcastMessage> messages;
  final Set<String> leavingIds;
  final void Function(String messageId) onDismissMessage;
  final VoidCallback onDismissAll;

  static const double _cardWidth = 300.0;

  const _BroadcastCard({
    required this.messages,
    required this.leavingIds,
    required this.onDismissMessage,
    required this.onDismissAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildMessageList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF1E293B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2D3F55), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '全服广播',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Server Broadcast',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          _CloseButton(onTap: onDismissAll),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < messages.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFF2D3F55),
                indent: 12,
                endIndent: 12,
              ),
            _AnimatedMessageItem(
              key: ValueKey(messages[i].messageId),
              message: messages[i],
              isLeaving: leavingIds.contains(messages[i].messageId),
              // 最旧的条目（index 0）向上退出，其余向下退出
              leaveUpward: i == 0,
              onDismiss: () => onDismissMessage(messages[i].messageId),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// 单条广播消息，带独立的滑入/滑出动画
class _AnimatedMessageItem extends StatefulWidget {
  final LobbyBroadcastMessage message;
  final bool isLeaving;
  /// true = 向上退出（被新消息顶替的最旧条目），false = 向下退出（用户手动关闭）
  final bool leaveUpward;
  final VoidCallback onDismiss;

  const _AnimatedMessageItem({
    super.key,
    required this.message,
    required this.isLeaving,
    required this.leaveUpward,
    required this.onDismiss,
  });

  @override
  State<_AnimatedMessageItem> createState() => _AnimatedMessageItemState();
}

class _AnimatedMessageItemState extends State<_AnimatedMessageItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 入场：从底部滑入到原位
  static const Offset _enterFrom = Offset(0.0, 0.5);

  // 退出偏移：向上退出（被顶替）或向下退出（手动关闭）
  Offset get _leaveTo =>
      widget.leaveUpward ? const Offset(0.0, -0.4) : const Offset(0.0, 0.4);

  // 用两个独立 Animation 分别控制入场和退出的位移
  late Animation<Offset> _enterSlide;
  late Animation<Offset> _leaveSlide;
  late Animation<double> _fade;
  late Animation<double> _size;

  // 标记当前是否处于退出阶段
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rebuildAnimations();
    _ctrl.forward(from: 0);
  }

  void _rebuildAnimations() {
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // 入场：enterFrom → zero（正向播放）
    _enterSlide = Tween<Offset>(
      begin: _enterFrom,
      end: Offset.zero,
    ).animate(curved);

    // 退出：zero → leaveTo（正向播放，但我们用 reverse 触发，所以实际是 leaveTo→zero 反向）
    // 为了让退出时从 zero 滑向 leaveTo，我们直接正向播放一个新的 controller 值
    // 实现方式：退出时切换到 leaveSlide，并 forward 一个从 0→1 的新动画
    _leaveSlide = Tween<Offset>(
      begin: Offset.zero,
      end: _leaveTo,
    ).animate(curved);

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
        reverseCurve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _size = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(_AnimatedMessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLeaving && !oldWidget.isLeaving) {
      _isLeaving = true;
      _rebuildAnimations(); // 用最新的 leaveUpward 重建退出动画
      // 退出：从当前位置（应为 1.0）反向播放 size/fade，同时正向播放 leaveSlide
      // 用 reverse 统一驱动：leaveSlide begin=zero end=leaveTo，reverse 时 t: 1→0，
      // 即从 leaveTo→zero，方向反了。
      // 正确做法：退出时 forward 一个新的 controller，但我们只有一个 controller。
      // 最简单的解法：退出时直接 reverse()，leaveSlide 用 begin=leaveTo end=zero，
      // reverse 时 t: 1→0，即从 zero→leaveTo，正好是我们想要的。
      _leaveSlide = Tween<Offset>(
        begin: _leaveTo, // reverse 时：end(zero) → begin(leaveTo)，即 zero→leaveTo ✓
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 入场时用 enterSlide，退出时用 leaveSlide
    final slideAnim = _isLeaving ? _leaveSlide : _enterSlide;

    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: slideAnim,
          child: _MessageRow(
            message: widget.message,
            onDismiss: widget.onDismiss,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MessageRow extends StatefulWidget {
  final LobbyBroadcastMessage message;
  final VoidCallback onDismiss;

  const _MessageRow({required this.message, required this.onDismiss});

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  bool _dismissHovered = false;

  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;
  bool _userScrolling = false;
  bool _needsScroll = false;

  static const double _maxContentHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndStartScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) {
      setState(() => _needsScroll = true);
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(milliseconds: 1500), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (!mounted || _userScrolling || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final remaining = pos.maxScrollExtent - pos.pixels;
    if (remaining <= 1) {
      _pauseThenReturnToTop();
      return;
    }
    final ms = (remaining / 40 * 1000).round().clamp(800, 12000);
    _scrollController
        .animateTo(pos.maxScrollExtent,
            duration: Duration(milliseconds: ms), curve: Curves.linear)
        .then((_) {
      if (!mounted || !_scrollController.hasClients || _userScrolling) return;
      _pauseThenReturnToTop();
    });
  }

  void _pauseThenReturnToTop() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_scrollController.hasClients || _userScrolling) return;
      _scrollController.jumpTo(0);
      _autoScrollTimer = Timer(const Duration(seconds: 1), _scrollToBottom);
    });
  }

  void _onUserScrollStart() {
    _userScrolling = true;
    _autoScrollTimer?.cancel();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.pixels);
    }
  }

  void _onUserScrollEnd() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _userScrolling = false;
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            avatarUrl: widget.message.avatarUrl,
            nickname: widget.message.nickname,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.message.nickname,
                  style: const TextStyle(
                    color: Color(0xFFA5B4FC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification && n.dragDetails != null) {
                      _onUserScrollStart();
                    } else if (n is ScrollEndNotification) {
                      _onUserScrollEnd();
                    }
                    return false;
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: _maxContentHeight),
                    child: RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: _needsScroll,
                      thickness: 3,
                      radius: const Radius.circular(2),
                      thumbColor: const Color(0xFF6366F1),
                      trackVisibility: _needsScroll,
                      trackColor: Colors.white.withValues(alpha: 0.08),
                      trackBorderColor: Colors.transparent,
                      padding: const EdgeInsets.only(right: 1),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          widget.message.content,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          MouseRegion(
            onEnter: (_) => setState(() => _dismissHovered = true),
            onExit: (_) => setState(() => _dismissHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _dismissHovered ? 1.0 : 0.4,
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            color: _hovered ? Colors.white : Colors.white54,
            size: 13,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;

  const _Avatar({required this.avatarUrl, required this.nickname});

  @override
  Widget build(BuildContext context) {
    const double size = 36;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(size),
        ),
      );
    }
    return _fallback(size);
  }

  Widget _fallback(double size) {
    final initial =
        nickname.isNotEmpty ? nickname.characters.first.toUpperCase() : '?';
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    final color = colors[nickname.hashCode.abs() % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
