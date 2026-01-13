import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../../core/bloc/settings/settings_state.dart';
import '../../core/services/notification_window_service.dart';
import '../../core/utils/map_utils.dart';
import '../../core/utils/image_cache_manager.dart';
import '../theme/desktop_theme.dart';

/// 单个通知窗口状态通知器
class SingleNotificationStateNotifier extends ChangeNotifier {
  NotificationData _notification;
  int _position;
  double? _yOffset;
  final NotificationPositionType _notificationPosition;

  SingleNotificationStateNotifier(
    this._notification, 
    this._position, {
    double? yOffset,
    NotificationPositionType notificationPosition = NotificationPositionType.topRight,
  }) : _yOffset = yOffset,
       _notificationPosition = notificationPosition;

  NotificationData get notification => _notification;
  int get position => _position;
  double? get yOffset => _yOffset;
  NotificationPositionType get notificationPosition => _notificationPosition;

  void updateNotification(NotificationData notification) {
    _notification = notification;
    notifyListeners();
  }

  void updatePosition(int position, {double? yOffset}) {
    _position = position;
    _yOffset = yOffset;
    notifyListeners();
  }
}

/// 单个通知窗口应用入口
class SingleNotificationWindowApp extends StatelessWidget {
  final String windowId;
  final SingleNotificationStateNotifier stateNotifier;
  final WindowController? mainWindowController;
  final String notificationId;

  const SingleNotificationWindowApp({
    super.key,
    required this.windowId,
    required this.stateNotifier,
    this.mainWindowController,
    required this.notificationId,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakaBox 通知',
      debugShowCheckedModeBanner: false,
      theme: DesktopTheme.darkTheme,
      home: _SingleNotificationWindow(
        windowId: windowId,
        stateNotifier: stateNotifier,
        mainWindowController: mainWindowController,
        notificationId: notificationId,
      ),
    );
  }
}

class _SingleNotificationWindow extends StatefulWidget {
  final String windowId;
  final SingleNotificationStateNotifier stateNotifier;
  final WindowController? mainWindowController;
  final String notificationId;

  const _SingleNotificationWindow({
    required this.windowId,
    required this.stateNotifier,
    this.mainWindowController,
    required this.notificationId,
  });

  @override
  State<_SingleNotificationWindow> createState() =>
      _SingleNotificationWindowState();
}

class _SingleNotificationWindowState extends State<_SingleNotificationWindow>
    with SingleTickerProviderStateMixin {
  bool _initialized = false;

  // 窗口配置
  static const double _windowWidth = 300.0;
  static const double _normalCardHeight = 72.0;
  static const double _updateLogCardHeight = 120.0;
  static const double _topPadding = 40.0;

  // 动画
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // 倒计时
  int _countdownSeconds = 0;
  int _totalCountdownSeconds = 0;
  Timer? _countdownTimer;

  double get _windowHeight {
    final type = widget.stateNotifier.notification.type;
    if (type == NotificationType.updateLog) {
      return _updateLogCardHeight;
    }
    return _normalCardHeight;
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    widget.stateNotifier.addListener(_onStateChanged);
    _initWindow();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _slideController.dispose();
    widget.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (_initialized) {
      debugPrint(
          '[SingleNotificationWindow] State changed, position: ${widget.stateNotifier.position}');
      // 位置变化时更新窗口位置
      _updateWindowPosition();
    }
  }

  Future<void> _initWindow() async {
    try {
      await windowManager.waitUntilReady();

      final screenInfo = await windowManager.getPrimaryScreenSize();
      final screenWidth = screenInfo['screenWidth']!;
      final screenHeight = screenInfo['screenHeight']!;

      final size = Size(_windowWidth, _windowHeight);
      final position = _calculateWindowPosition(screenWidth, screenHeight);

      debugPrint('[SingleNotificationWindow] Init window at position ${widget.stateNotifier.position}, x=${position.dx}, y=${position.dy}');

      // 不传递 options，手动设置所有属性
      await windowManager.waitUntilReadyToShow(null, () async {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setSize(size);
        await windowManager.setPosition(position);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setBackgroundColor(Colors.transparent);
        if (Platform.isWindows) {
          await windowManager.setAsFrameless();
        }
        // 使用 showWithoutActivating 显示窗口但不获取焦点
        if (Platform.isWindows) {
          await windowManager.showWithoutActivating();
        } else {
          await windowManager.show();
          await windowManager.blur();
        }
      });

      if (mounted) {
        setState(() => _initialized = true);
        // 启动入场动画
        _slideController.forward();
        // 启动倒计时
        _startCountdown();
      }
    } catch (e) {
      debugPrint('[SingleNotificationWindow] Init error: $e');
    }
  }

  /// 根据通知位置设置计算窗口在屏幕上的位置
  Offset _calculateWindowPosition(double screenWidth, double screenHeight) {
    final notificationPosition = widget.stateNotifier.notificationPosition;
    final yOffset = widget.stateNotifier.yOffset ?? _topPadding;
    
    // 任务栏高度估算
    const taskbarHeight = 48.0;
    final availableHeight = screenHeight - taskbarHeight;
    final centerY = (availableHeight - _windowHeight) / 2;
    
    double x;
    double y;
    
    switch (notificationPosition) {
      case NotificationPositionType.topLeft:
        x = 0;
        y = yOffset;
        break;
      case NotificationPositionType.topCenter:
        x = (screenWidth - _windowWidth) / 2;
        y = yOffset;
        break;
      case NotificationPositionType.topRight:
        x = screenWidth - _windowWidth;
        y = yOffset;
        break;
      case NotificationPositionType.centerLeft:
        x = 0;
        y = centerY;
        break;
      case NotificationPositionType.center:
        x = (screenWidth - _windowWidth) / 2;
        y = centerY;
        break;
      case NotificationPositionType.centerRight:
        x = screenWidth - _windowWidth;
        y = centerY;
        break;
      case NotificationPositionType.bottomLeft:
        x = 0;
        y = screenHeight - _windowHeight - taskbarHeight - yOffset;
        break;
      case NotificationPositionType.bottomCenter:
        x = (screenWidth - _windowWidth) / 2;
        y = screenHeight - _windowHeight - taskbarHeight - yOffset;
        break;
      case NotificationPositionType.bottomRight:
        x = screenWidth - _windowWidth;
        y = screenHeight - _windowHeight - taskbarHeight - yOffset;
        break;
    }
    
    return Offset(x, y);
  }

  Future<void> _updateWindowPosition() async {
    if (!_initialized) return;
    try {
      final screenInfo = await windowManager.getPrimaryScreenSize();
      final screenWidth = screenInfo['screenWidth']!;
      final screenHeight = screenInfo['screenHeight']!;
      final position = _calculateWindowPosition(screenWidth, screenHeight);
      debugPrint(
          '[SingleNotificationWindow] Updating position to x=${position.dx}, y=${position.dy} (position=${widget.stateNotifier.position})');
      await windowManager.setPosition(position);
    } catch (e) {
      debugPrint('[SingleNotificationWindow] Update position error: $e');
    }
  }

  void _startCountdown() {
    final autoDismiss = widget.stateNotifier.notification.autoDismissSeconds;
    if (autoDismiss == null || autoDismiss <= 0) return;

    // 只在首次启动时初始化
    if (_totalCountdownSeconds == 0) {
      _totalCountdownSeconds = autoDismiss;
      _countdownSeconds = autoDismiss;
      if (mounted) setState(() {});
    }

    // 如果倒计时已结束，直接关闭
    if (_countdownSeconds <= 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _dismiss();
      });
      return;
    }

    // 如果定时器已存在，不重复创建
    if (_countdownTimer != null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        setState(() => _countdownSeconds = 0);
        timer.cancel();
        _countdownTimer = null;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _dismiss();
        });
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  void _pauseCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _resumeCountdown() {
    // 如果倒计时已结束，直接关闭
    if (_countdownSeconds <= 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _dismiss();
      });
      return;
    }

    // 如果定时器已存在，不重复创建
    if (_countdownTimer != null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        setState(() => _countdownSeconds = 0);
        timer.cancel();
        _countdownTimer = null;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _dismiss();
        });
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  Future<void> _dismiss() async {
    await _slideController.reverse();
    // 通过 IPC 通知主窗口此通知已关闭
    if (widget.mainWindowController != null) {
      try {
        await widget.mainWindowController!.invokeMethod(
            'notificationClosed', {'id': widget.notificationId});
        debugPrint('[SingleNotificationWindow] Notified main window of close');
      } catch (e) {
        debugPrint('[SingleNotificationWindow] Failed to notify main window: $e');
      }
    }
    // 关闭窗口
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: widget.stateNotifier,
        builder: (context, _) {
          return SlideTransition(
            position: _slideAnimation,
            child: _NotificationCard(
              notification: widget.stateNotifier.notification,
              onDismiss: _dismiss,
              countdownSeconds: _countdownSeconds,
              totalCountdownSeconds: _totalCountdownSeconds,
              onHover: (hovered) {
                if (hovered) {
                  _pauseCountdown();
                } else {
                  _resumeCountdown();
                }
              },
            ),
          );
        },
      ),
    );
  }
}

/// 通知卡片
class _NotificationCard extends StatefulWidget {
  final NotificationData notification;
  final VoidCallback onDismiss;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final ValueChanged<bool> onHover;

  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
    required this.onHover,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isHovered = false;
  bool _isDeleteHovered = false;

  static const double _width = 300.0;
  static const double _normalHeight = 72.0;
  static const double _updateLogHeight = 120.0;
  static const double _borderRadius = 8.0;
  static const double _borderWidth = 2.0;
  static const double _progressBarHeight = 3.0;
  static const double _deleteAreaWidth = 50.0;

  double get _height {
    if (widget.notification.type == NotificationType.updateLog) {
      return _updateLogHeight;
    }
    return _normalHeight;
  }

  bool get _hasProgressBar {
    return widget.totalCountdownSeconds > 0;
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final isWarmup = notification.type == NotificationType.warmup;
    final isMapChange = notification.type == NotificationType.mapChange;
    final isUpdateLog = notification.type == NotificationType.updateLog;

    final borderColor = isWarmup
        ? const Color(0xFFFF9800)
        : isMapChange
            ? const Color(0xFF4CAF50)
            : isUpdateLog
                ? const Color(0xFFF59E0B)
                : const Color(0xFF0080FF);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border.all(
            color: _isHovered ? borderColor.withValues(alpha: 1) : borderColor,
            width: _borderWidth,
          ),
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_borderRadius - _borderWidth),
          child: Stack(
            children: [
              // 主内容
              Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 地图背景
                        if (notification.mapName != null ||
                            notification.mapBackground != null)
                          Positioned.fill(
                              child: _buildMapBackground(notification)),
                        // 渐变遮罩
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  const Color(0xFF1E293B).withValues(alpha: 0.95),
                                  const Color(0xFF1E293B).withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 内容
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题行
                              Row(
                                children: [
                                  // 换图通知不显示标题，直接显示分类名+服务器名
                                  if (!isMapChange)
                                    Text(
                                      // 热身通知显示动态倒计时
                                      isWarmup && widget.countdownSeconds > 0
                                          ? '热身 ${widget.countdownSeconds}秒'
                                          : notification.title,
                                      style: TextStyle(
                                        color: borderColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (!isMapChange && notification.serverName != null)
                                    const SizedBox(width: 6),
                                  if (notification.serverName != null)
                                    Expanded(
                                      child: _ServerNameText(
                                        serverName: notification.serverName!,
                                        categoryName: notification.extraData?['categoryName'] as String?,
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // 消息
                              Expanded(
                                child: isUpdateLog
                                    ? _buildUpdateLogContent(notification)
                                    : _buildMessageWidget(
                                        notification, isWarmup, isMapChange),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 底部进度条
                  if (_hasProgressBar) _buildProgressBar(borderColor),
                ],
              ),
              // 删除按钮（右侧淡入）
              if (_isHovered)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: _hasProgressBar ? _progressBarHeight : 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isDeleteHovered = true),
                    onExit: (_) => setState(() => _isDeleteHovered = false),
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _deleteAreaWidth,
                        decoration: BoxDecoration(
                          color: _isDeleteHovered
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFEF4444),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
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

  Widget _buildMessageWidget(
      NotificationData notification, bool isWarmup, bool isMapChange) {
    final textStyle = TextStyle(
      color: isWarmup ? const Color(0xFFFFE082) : Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    // 卡片宽度300 - 左右padding各10 = 280
    const maxWidth = 280.0;

    return SizedBox(
      width: maxWidth,
      child: _MarqueeText(
        text: notification.message,
        style: textStyle,
        maxWidth: maxWidth,
      ),
    );
  }

  /// 构建更新日志内容 - 使用HTML解析和垂直跑马灯
  Widget _buildUpdateLogContent(NotificationData notification) {
    return _VerticalMarqueeHtml(
      htmlContent: notification.message,
    );
  }

  Widget _buildMapBackground(NotificationData notification) {
    final mapUrl = MapUtils.getMapImageUrl(
      notification.mapName,
      mapUrl: notification.mapBackground,
    );

    if (mapUrl.startsWith('http://') || mapUrl.startsWith('https://')) {
      final cacheKey = AppImageCacheManager.extractCacheKey(mapUrl);
      return CachedNetworkImage(
        imageUrl: mapUrl,
        cacheKey: cacheKey,
        cacheManager: AppImageCacheManager.instance,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(color: const Color(0xFF1E293B)),
        errorWidget: (context, url, error) =>
            Container(color: const Color(0xFF1E293B)),
      );
    }

    return Image.asset(
      mapUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: const Color(0xFF1E293B)),
    );
  }

  Widget _buildProgressBar(Color color) {
    final progress = widget.totalCountdownSeconds > 0
        ? widget.countdownSeconds / widget.totalCountdownSeconds
        : 0.0;

    return SizedBox(
      height: _progressBarHeight,
      child: Stack(
        children: [
          Container(color: Colors.white.withValues(alpha: 0.1)),
          TweenAnimationBuilder<double>(
            key: ValueKey(widget.countdownSeconds),
            tween: Tween(
              begin: (widget.countdownSeconds + 1) / widget.totalCountdownSeconds,
              end: progress,
            ),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.linear,
            builder: (context, value, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(color: color),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 服务器名称文本组件 - 支持分类名称高亮和超长滚动
class _ServerNameText extends StatefulWidget {
  final String serverName;
  final String? categoryName;

  const _ServerNameText({
    required this.serverName,
    this.categoryName,
  });

  @override
  State<_ServerNameText> createState() => _ServerNameTextState();
}

class _ServerNameTextState extends State<_ServerNameText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  double _scrollDistance = 0;
  final GlobalKey _textKey = GlobalKey();
  final GlobalKey _containerKey = GlobalKey();
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationUpdate);
    _animationController.removeStatusListener(_onAnimationStatus);
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndStartScroll() {
    if (!mounted || _animationStarted) return;

    // 延迟一帧确保布局完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _animationStarted) return;

      final textBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
      final containerBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
      
      if (textBox == null || containerBox == null) return;

      final textWidth = textBox.size.width;
      final containerWidth = containerBox.size.width;

      if (textWidth <= containerWidth) return;

      _scrollDistance = textWidth - containerWidth;
      _startScrollAnimation();
    });
  }

  void _startScrollAnimation() {
    if (!mounted || _scrollDistance <= 0 || _animationStarted) return;
    _animationStarted = true;

    final duration = Duration(milliseconds: (_scrollDistance * 30).toInt());
    _animationController.duration = duration;

    _animationController.addListener(_onAnimationUpdate);
    _animationController.addStatusListener(_onAnimationStatus);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _animationController.forward();
    });
  }

  void _onAnimationUpdate() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = (_animationController.value * _scrollDistance).clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetScroll);
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _scrollController.jumpTo(0);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _animationController.forward(from: 0);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryName = widget.categoryName;
    final hasCategory = categoryName != null && categoryName.isNotEmpty;

    return Row(
      children: [
        // 分类名固定显示，不滚动
        if (hasCategory)
          Text(
            '[$categoryName] ',
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        // 服务器名滚动
        Expanded(
          key: _containerKey,
          child: ClipRect(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                key: _textKey,
                widget.serverName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                softWrap: false,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// 跑马灯文本组件 - 当文本超出宽度时自动滚动
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double maxWidth;

  const _MarqueeText({
    required this.text,
    required this.style,
    required this.maxWidth,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  double _scrollDistance = 0;
  final GlobalKey _textKey = GlobalKey();
  // 额外滚动距离，补偿渲染误差
  static const double _extraScroll = 10.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndStartScroll() {
    // 等待布局完成后获取文本实际渲染宽度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final renderBox =
          _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final textWidth = renderBox.size.width;
      // 文本宽度不超过容器宽度，不需要滚动
      if (textWidth <= widget.maxWidth) return;

      // 滚动距离 = 文本宽度 - 容器宽度 + 额外补偿
      _scrollDistance = textWidth - widget.maxWidth + _extraScroll;
      _startScrollAnimation();
    });
  }

  void _startScrollAnimation() {
    if (!mounted || _scrollDistance <= 0) return;

    final duration = Duration(milliseconds: (_scrollDistance * 30).toInt());
    _animationController.duration = duration;

    // 监听动画值变化
    _animationController.addListener(_onAnimationUpdate);

    // 监听动画状态
    _animationController.addStatusListener(_onAnimationStatus);

    // 延迟1秒后开始滚动
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _animationController.forward();
    });
  }

  void _onAnimationUpdate() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_animationController.value * _scrollDistance);
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // 滚动完成后等待2秒再重置
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _scrollController.jumpTo(0);
        // 等待1秒后重新开始
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _animationController.forward(from: 0);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key: _textKey,
            widget.text,
            style: widget.style,
            softWrap: false,
            maxLines: 1,
          ),
          // 右侧留白，确保有足够空间滚动
          const SizedBox(width: _extraScroll),
        ],
      ),
    );
  }
}

/// 垂直跑马灯 HTML 组件 - 用于更新日志通知
class _VerticalMarqueeHtml extends StatefulWidget {
  final String htmlContent;

  const _VerticalMarqueeHtml({
    required this.htmlContent,
  });

  @override
  State<_VerticalMarqueeHtml> createState() => _VerticalMarqueeHtmlState();
}

class _VerticalMarqueeHtmlState extends State<_VerticalMarqueeHtml>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  double _scrollDistance = 0;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndStartScroll() {
    // 等待布局完成后获取内容高度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      _scrollDistance = maxScroll;
      _startScrollAnimation();
    });
  }

  void _startScrollAnimation() {
    if (!mounted || _scrollDistance <= 0) return;

    // 速度：每像素 50ms
    final duration = Duration(milliseconds: (_scrollDistance * 50).toInt());
    _animationController.duration = duration;

    _animationController.addListener(_onAnimationUpdate);
    _animationController.addStatusListener(_onAnimationStatus);

    // 延迟2秒后开始滚动
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _animationController.forward();
    });
  }

  void _onAnimationUpdate() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_animationController.value * _scrollDistance);
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // 滚动完成后等待3秒再重置
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _scrollController.jumpTo(0);
        // 等待2秒后重新开始
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _animationController.forward(from: 0);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        key: _contentKey,
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Html(
          data: widget.htmlContent,
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(12),
              lineHeight: const LineHeight(1.4),
              color: Colors.white,
            ),
            'p': Style(
              margin: Margins.only(bottom: 6),
            ),
            'ul': Style(
              margin: Margins.only(top: 4, bottom: 4),
              padding: HtmlPaddings.only(left: 16),
            ),
            'ol': Style(
              margin: Margins.only(top: 4, bottom: 4),
              padding: HtmlPaddings.only(left: 16),
            ),
            'li': Style(
              margin: Margins.only(bottom: 2),
              lineHeight: const LineHeight(1.3),
            ),
            'strong': Style(
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFBBF24),
            ),
            'h1': Style(
              fontSize: FontSize(14),
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFBBF24),
              margin: Margins.only(bottom: 6),
            ),
            'h2': Style(
              fontSize: FontSize(13),
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFBBF24),
              margin: Margins.only(bottom: 4),
            ),
            'h3': Style(
              fontSize: FontSize(12),
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFBBF24),
              margin: Margins.only(bottom: 4),
            ),
            'a': Style(
              color: const Color(0xFF60A5FA),
              textDecoration: TextDecoration.none,
            ),
          },
        ),
      ),
    );
  }
}
