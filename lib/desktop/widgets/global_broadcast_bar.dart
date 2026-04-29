import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/lobby/lobby_bloc.dart';
import '../../core/models/lobby_models.dart';

/// 全局广播悬浮通知卡片
/// - 收到广播时从右侧滑入，显示在右下角
/// - 需用户手动关闭（点 ✕）
/// - 新消息到来时先滑出再滑入替换内容
/// - 内容过长自动滚动，用户拖动时暂停，停止拖动 2 秒后恢复
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

  LobbyBroadcastMessage? _current;

  /// 在 reverse 动画期间缓存下一条消息
  LobbyBroadcastMessage? _pending;

  /// 标记当前是否正在执行 reverse（dismiss 或换消息）
  /// 用于区分 _dismiss 和 _onBroadcast 的并发情况
  bool _isReversing = false;

  StreamSubscription<LobbyBroadcastMessage>? _broadcastSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // 延迟到第一帧后订阅，确保 context 已挂载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _broadcastSubscription =
          context.read<LobbyBloc>().broadcastStream.listen(_onBroadcast);
    });
  }

  @override
  void dispose() {
    _broadcastSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onBroadcast(LobbyBroadcastMessage msg) {
    if (!mounted) return;

    if (_current == null) {
      // 没有卡片：直接入场
      setState(() => _current = msg);
      _controller.forward(from: 0);
    } else if (_isReversing) {
      // 正在 reverse（换消息或关闭中）：更新 pending，reverse 完成后会用最新的
      _pending = msg;
    } else {
      // 有卡片且未在 reverse：先滑出再换内容
      _pending = msg;
      _isReversing = true;
      _controller.reverse().then((_) {
        if (!mounted) return;
        _isReversing = false;
        // 无论 _pending 是否被更新过，都取最新值
        setState(() {
          _current = _pending;
          _pending = null;
        });
        _controller.forward(from: 0);
      });
    }
  }

  void _dismiss() {
    if (!mounted || _isReversing) return;
    _isReversing = true;
    _controller.reverse().then((_) {
      if (!mounted) return;
      _isReversing = false;
      if (_pending != null) {
        // dismiss 期间来了新消息，直接显示
        setState(() {
          _current = _pending;
          _pending = null;
        });
        _controller.forward(from: 0);
      } else {
        setState(() {
          _current = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_current == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _BroadcastCard(
          key: ValueKey(_current!.messageId),
          message: _current!,
          onClose: _dismiss,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BroadcastCard extends StatefulWidget {
  final LobbyBroadcastMessage message;
  final VoidCallback onClose;

  const _BroadcastCard({
    super.key,
    required this.message,
    required this.onClose,
  });

  @override
  State<_BroadcastCard> createState() => _BroadcastCardState();
}

class _BroadcastCardState extends State<_BroadcastCard> {
  bool _closeHovered = false;

  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;
  bool _userScrolling = false;
  bool _needsScroll = false;

  static const double _cardWidth = 300.0;
  static const double _maxContentHeight = 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // 等布局完成后检测是否需要滚动
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    // 先 cancel timer，再 dispose controller，避免 timer 回调访问已 dispose 的 controller
    _scrollController.dispose();
    super.dispose();
  }

  // ── 滚动逻辑 ──────────────────────────────────────────────────────────────

  void _checkAndStartScroll() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) {
      setState(() => _needsScroll = true);
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    // 延迟 1.5 秒后开始第一轮，给用户时间先读开头
    _autoScrollTimer =
        Timer(const Duration(milliseconds: 1500), _scrollToBottom);
  }

  /// 一次性匀速滚到底部（约 40px/s），到底后停顿再跳回顶部循环
  void _scrollToBottom() {
    if (!mounted || _userScrolling) return;
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final remaining = pos.maxScrollExtent - pos.pixels;

    if (remaining <= 1) {
      // 已在底部（留 1px 容差），直接进入停顿逻辑
      _pauseThenReturnToTop();
      return;
    }

    final ms = (remaining / 40 * 1000).round().clamp(800, 12000);
    _scrollController
        .animateTo(
          pos.maxScrollExtent,
          duration: Duration(milliseconds: ms),
          curve: Curves.linear,
        )
        .then((_) {
          // 必须先检查 mounted 和 hasClients，animateTo 的 Future 在 dispose 后仍会 resolve
          if (!mounted || !_scrollController.hasClients) return;
          if (_userScrolling) return;
          _pauseThenReturnToTop();
        });
  }

  void _pauseThenReturnToTop() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_scrollController.hasClients) return;
      if (_userScrolling) return;
      _scrollController.jumpTo(0);
      _autoScrollTimer = Timer(const Duration(seconds: 1), _scrollToBottom);
    });
  }

  void _onUserScrollStart() {
    _userScrolling = true;
    _autoScrollTimer?.cancel();
    // 同时中断正在进行的 animateTo（通过 jumpTo 当前位置打断）
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
          _buildBody(),
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
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 14,
            ),
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
                  size: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 5),
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification &&
                        n.dragDetails != null) {
                      _onUserScrollStart();
                    } else if (n is ScrollEndNotification) {
                      _onUserScrollEnd();
                    }
                    return false;
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: _maxContentHeight,
                    ),
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
        ],
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
    const double size = 38;

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
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
