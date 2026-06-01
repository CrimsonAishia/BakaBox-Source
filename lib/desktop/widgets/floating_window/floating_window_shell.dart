import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/services/floating_window_service.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'floating_progress_bar.dart';
import 'floating_window_app.dart';
import 'floating_window_body.dart';
import 'floating_window_colors.dart';

/// 浮窗外壳 - 布局 (280x240)
class FloatingWindowShell extends StatefulWidget {
  final FloatingWindowConfig config;
  final String windowId;
  final FloatingWindowStateNotifier stateNotifier;

  const FloatingWindowShell({
    super.key,
    required this.config,
    required this.windowId,
    required this.stateNotifier,
  });

  @override
  State<FloatingWindowShell> createState() => _FloatingWindowShellState();
}

class _FloatingWindowShellState extends State<FloatingWindowShell> {
  // 倒计时
  int _countdownSeconds = 0;
  int _totalCountdownSeconds = 5;
  Timer? _countdownTimer;
  Timer? _scheduleCloseTimer;
  bool _isCountdownActive = false;

  // 窗口关闭状态
  bool _isClosing = false;

  // 窗口收起状态
  bool _isMinimized = false;

  // 窗口尺寸
  static const double _expandedHeight = 160.0;
  static const double _minimizedHeight = 44.0;
  static const double _windowWidth = 280.0;

  // 倒计时配置
  static const int _successCountdown = 5;
  static const int _failureCountdown = 8;
  static const int _pausedCountdown = 3;

  @override
  void initState() {
    super.initState();

    // 监听状态变化
    widget.stateNotifier.addListener(_onStateChanged);

    // 检查初始状态
    if (widget.stateNotifier.state.isTerminal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown(widget.stateNotifier.state.isSuccess);
      });
    }
  }

  void _onStateChanged() {
    final state = widget.stateNotifier.state;

    // 检查是否有 autoDismissSeconds 更新
    final autoDismiss = widget.stateNotifier.autoDismissSeconds;

    // 如果从暂停/终态恢复到活跃状态，取消倒计时
    if (_isCountdownActive &&
        (state.isQueueing ||
            state.isLaunching ||
            state.isConnecting ||
            state.isLoading)) {
      _cancelCountdown();
      return;
    }

    // 进入终态时启动倒计时
    if (state.isTerminal && !_isCountdownActive) {
      _startCountdown(state.isSuccess, customSeconds: autoDismiss);
      return;
    }

    // 进入暂停状态时启动倒计时
    if (state.isPaused && !_isCountdownActive) {
      _startCountdown(false, isPaused: true, customSeconds: autoDismiss);
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _scheduleCloseTimer?.cancel();
    _isCountdownActive = false;
    _isClosing = false; // 重置关闭标志，允许新的倒计时
    if (mounted) setState(() {});
  }

  void _startCountdown(
    bool isSuccess, {
    bool isPaused = false,
    int? customSeconds,
  }) {
    _countdownTimer?.cancel();

    // 优先使用自定义秒数，否则使用默认值
    if (customSeconds != null && customSeconds > 0) {
      _totalCountdownSeconds = customSeconds;
    } else if (isPaused) {
      _totalCountdownSeconds = _pausedCountdown;
    } else {
      _totalCountdownSeconds = isSuccess
          ? _successCountdown
          : _failureCountdown;
    }

    _countdownSeconds = _totalCountdownSeconds;
    _isCountdownActive = true;

    debugPrint(
      '[FloatingWindowShell] Starting countdown: $_totalCountdownSeconds seconds (isPaused: $isPaused, customSeconds: $customSeconds)',
    );

    if (mounted) setState(() {});

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownSeconds <= 1) {
        // 最后一秒，等进度条动画完成后再关闭
        setState(() {
          _countdownSeconds = 0;
        });
        timer.cancel();
        // 延迟 1 秒让进度条动画完成，然后关闭窗口
        _scheduleWindowClose();
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  /// 调度窗口关闭（确保一定会关闭）
  void _scheduleWindowClose() {
    // 防止重复调度
    if (_isClosing) return;
    _isClosing = true;

    _scheduleCloseTimer?.cancel();
    _scheduleCloseTimer = Timer(const Duration(milliseconds: 1000), () {
      // 即使 mounted 为 false，也尝试关闭窗口
      _closeWindow();
    });
  }

  Future<void> _closeWindow() async {
    _countdownTimer?.cancel();
    _scheduleCloseTimer?.cancel();
    _isCountdownActive = false;

    debugPrint('[FloatingWindowShell] Closing window: ${widget.windowId}');

    // 先通知主窗口，窗口即将关闭
    await _notifyMainWindowClosed();

    // 尝试多种关闭方式，确保窗口一定关闭
    try {
      await windowManager.close();
      debugPrint('[FloatingWindowShell] Window closed via close()');
    } catch (e) {
      debugPrint('[FloatingWindowShell] close() failed: $e, trying destroy()');
      try {
        await windowManager.destroy();
        debugPrint('[FloatingWindowShell] Window closed via destroy()');
      } catch (e2) {
        debugPrint(
          '[FloatingWindowShell] destroy() also failed: $e2, trying hide()',
        );
        // 最后尝试隐藏窗口
        try {
          await windowManager.hide();
          // 隐藏后再尝试关闭
          await Future.delayed(const Duration(milliseconds: 100));
          await windowManager.close();
        } catch (e3) {
          debugPrint('[FloatingWindowShell] All close attempts failed: $e3');
        }
      }
    }
  }

  /// 通知主窗口，浮动窗口已关闭
  Future<void> _notifyMainWindowClosed() async {
    try {
      // 主窗口的 windowId 是 0（或空字符串，取决于版本）
      // desktop_multi_window 0.3.0 中主窗口 ID 是空字符串
      final mainController = WindowController.fromWindowId('');
      await mainController.invokeMethod('floatingWindowClosed', {
        'windowId': widget.windowId,
      });
      debugPrint('[FloatingWindowShell] Notified main window of closure');
    } catch (e) {
      debugPrint('[FloatingWindowShell] Failed to notify main window: $e');
      // 通知失败不影响窗口关闭
    }
  }

  /// 切换窗口收起/展开状态
  Future<void> _toggleMinimize() async {
    setState(() {
      _isMinimized = !_isMinimized;
    });

    // 调整窗口大小
    final newHeight = _isMinimized ? _minimizedHeight : _expandedHeight;
    await windowManager.setSize(Size(_windowWidth, newHeight));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scheduleCloseTimer?.cancel();
    widget.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.stateNotifier,
      builder: (context, child) {
        final state = widget.stateNotifier.state;
        final color = FloatingWindowColors.fromState(state);
        final hasMapBackground =
            state.mapBackground != null && state.mapBackground!.isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: _isMinimized ? _minimizedHeight : null,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // 地图背景（如果有，收起时隐藏）
                  if (hasMapBackground && !_isMinimized)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildMapBackground(state.mapBackground!),
                      ),
                    ),
                  // 背景遮罩（有地图背景时添加，收起时隐藏）
                  if (hasMapBackground && !_isMinimized)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF1E293B).withValues(alpha: 0.7),
                              const Color(0xFF1E293B).withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // 主内容
                  Column(
                    mainAxisSize: _isMinimized
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    children: [
                      // 标题栏
                      _buildHeader(color),
                      // 主体内容（收起时隐藏）
                      if (!_isMinimized) ...[
                        Expanded(
                          child: FloatingWindowBody(
                            state: state,
                            serverAddress: widget.config.serverAddress,
                            serverName: widget.config.title,
                          ),
                        ),
                        // 底部进度条
                        FloatingProgressBar(
                          state: state,
                          isCountdownActive: _isCountdownActive,
                          countdownSeconds: _countdownSeconds,
                          totalCountdownSeconds: _totalCountdownSeconds,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建地图背景
  Widget _buildMapBackground(String mapUrl) {
    if (mapUrl.startsWith('http://') || mapUrl.startsWith('https://')) {
      return DiskCachedImage(
        imageUrl: mapUrl,
        fit: BoxFit.cover,
        placeholder: Container(color: const Color(0xFF1E293B)),
        errorWidget: Container(color: const Color(0xFF1E293B)),
      );
    }
    return Image.asset(
      mapUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: const Color(0xFF1E293B)),
    );
  }

  Widget _buildHeader(Color color) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Row(
          children: [
            Icon(_getTypeIcon(), size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getTitle(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildMinimizeButton(),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (widget.config.type) {
      case FloatingWindowType.queue:
        return Icons.people_alt;
      case FloatingWindowType.warmup:
        return Icons.local_fire_department;
      case FloatingWindowType.launch:
        return Icons.rocket_launch;
      case FloatingWindowType.connect:
        return Icons.link;
      case FloatingWindowType.status:
        return Icons.info_outline;
    }
  }

  String _getTitle() {
    if (widget.config.title != null && widget.config.title!.isNotEmpty) {
      return widget.config.title!;
    }
    switch (widget.config.type) {
      case FloatingWindowType.queue:
        return 'Queue Status';
      case FloatingWindowType.warmup:
        return 'Warmup Status';
      case FloatingWindowType.launch:
        return 'Launch Game';
      case FloatingWindowType.connect:
        return 'Connecting';
      case FloatingWindowType.status:
        return 'Status';
    }
  }

  Widget _buildMinimizeButton() {
    return InkWell(
      onTap: _toggleMinimize,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _isMinimized ? Icons.expand_more : Icons.expand_less,
          color: Colors.white70,
          size: 14,
        ),
      ),
    );
  }
}
