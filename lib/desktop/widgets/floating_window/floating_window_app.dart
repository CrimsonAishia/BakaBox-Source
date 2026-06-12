import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/services/floating_window_service.dart';
import '../../../core/utils/fullscreen_detector.dart';
import '../../theme/desktop_theme.dart';
import 'floating_window_shell.dart';
import 'floating_window_state.dart';
import '../../../core/constants/app_colors.dart';

/// 状态更新回调类型
typedef StateUpdateCallback = void Function(Map<dynamic, dynamic> args);

/// 浮窗状态通知器 - 单一状态源
///
/// 重构后的状态管理器，确保：
/// 1. 状态只有一个权威来源
/// 2. 初始化只执行一次
/// 3. 终态保护（成功/失败后不会被覆盖）
/// 4. 启动状态保护（启动中不会被非启动状态覆盖）
class FloatingWindowStateNotifier extends ChangeNotifier {
  FloatingWindowState _state = const FloatingWindowState();
  bool _initialized = false;
  int? _autoDismissSeconds;

  /// 当前状态
  FloatingWindowState get state => _state;

  /// 是否已初始化
  bool get initialized => _initialized;

  /// 自动关闭倒计时秒数（如果有更新）
  int? get autoDismissSeconds => _autoDismissSeconds;

  /// 兼容旧代码的 lastUpdate getter
  Map<dynamic, dynamic>? get lastUpdate => null;

  /// 初始化状态（仅执行一次）
  void initialize(FloatingWindowState initialState) {
    if (_initialized) {
      debugPrint('[FloatingWindowStateNotifier] Already initialized, ignoring');
      return;
    }
    _state = initialState;
    _initialized = true;
    debugPrint(
      '[FloatingWindowStateNotifier] Initialized with state: ${_state.state}',
    );
    notifyListeners();
  }

  /// 更新状态（来自 IPC）
  void updateState(Map<dynamic, dynamic> args) {
    final newStateStr = args['state'] as String?;

    debugPrint(
      '[FloatingWindowStateNotifier] updateState called: newState=$newStateStr, currentState=${_state.state}',
    );

    // 检查是否有 autoDismissSeconds 更新
    if (args.containsKey('autoDismissSeconds')) {
      _autoDismissSeconds = args['autoDismissSeconds'] as int?;
      debugPrint(
        '[FloatingWindowStateNotifier] autoDismissSeconds updated: $_autoDismissSeconds',
      );
    }

    // 如果当前是终态，检查是否允许转换
    if (_state.isTerminal && newStateStr != null) {
      final newState = FloatingWindowState.fromMap({'state': newStateStr});
      // 允许从终态转换到活跃状态（挤服、连接、加载、启动）
      if (newState.isQueueing ||
          newState.isConnecting ||
          newState.isLoading ||
          newState.isLaunching) {
        debugPrint(
          '[FloatingWindowStateNotifier] Allowing transition from terminal to active state: $newStateStr',
        );
        // 继续处理
      } else {
        debugPrint(
          '[FloatingWindowStateNotifier] Ignoring update while in terminal state: ${_state.state}',
        );
        return;
      }
    }

    // 如果当前是启动状态，只接受特定状态转换
    if (_state.isLaunching && newStateStr != null) {
      final newState = FloatingWindowState.fromMap({'state': newStateStr});
      // 允许转换到成功、失败、挤服状态
      if (newState.isPaused &&
          !newState.isSuccess &&
          !newState.isFailed &&
          !newState.isQueueing) {
        debugPrint(
          '[FloatingWindowStateNotifier] Ignoring paused update while in launching state: $newStateStr',
        );
        return;
      }
    }

    final hasMapNameKey = args.containsKey('mapName');
    final hasMapNameCnKey = args.containsKey('mapNameCn');
    final hasMapBackgroundKey = args.containsKey('mapBackground');

    _state = FloatingWindowState(
      state: newStateStr ?? _state.state,
      message: args['message'] as String? ?? _state.message,
      subtitle: args['subtitle'] as String? ?? _state.subtitle,
      currentPlayers: args['currentPlayers'] as int? ?? _state.currentPlayers,
      targetPlayers: args['targetPlayers'] as int? ?? _state.targetPlayers,
      threadStatuses:
          (args['threadStatuses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          _state.threadStatuses,
      mapName: hasMapNameKey ? args['mapName'] as String? : _state.mapName,
      mapNameCn: hasMapNameCnKey
          ? args['mapNameCn'] as String?
          : _state.mapNameCn,
      mapBackground: hasMapBackgroundKey
          ? args['mapBackground'] as String?
          : _state.mapBackground,
    );

    debugPrint(
      '[FloatingWindowStateNotifier] State updated: ${_state.state} - ${_state.message}',
    );
    notifyListeners();
  }

  /// 看门狗强制超时（兜底）
  ///
  /// 浮窗是纯粹由宿主进程通过 IPC 驱动的"视图"，本身没有连接/加载的时序权威。
  /// 正常情况下宿主一定会在有限时间内推送终态（成功/失败/服务器满）或持续推送
  /// 进度更新。但若宿主进程崩溃、IPC 通道断开、观察流程的 completer 异常未完成，
  /// 或收到未知 state 字符串，浮窗会永远停在非终态而不关闭。
  ///
  /// 该方法由浮窗自身的看门狗在"长时间收不到宿主任何更新"时调用，把状态切到
  /// `timeout` 终态，从而复用既有的倒计时关闭链路统一收尾——不依赖宿主。
  ///
  /// 已是终态时不打扰（终态自有倒计时负责关闭）。
  void forceTimeout(String message) {
    if (_state.isTerminal) return;
    _state = _state.copyWith(state: 'timeout', message: message);
    debugPrint('[FloatingWindowStateNotifier] Forced timeout (watchdog): $message');
    notifyListeners();
  }
}

/// 通用浮窗应用入口
class FloatingWindowApp extends StatelessWidget {
  final FloatingWindowConfig config;
  final String windowId;
  final FloatingWindowStateNotifier stateNotifier;

  const FloatingWindowApp({
    super.key,
    required this.config,
    required this.windowId,
    required this.stateNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.title ?? 'BakaBox',
      debugShowCheckedModeBanner: false,
      theme: DesktopTheme.darkTheme,
      home: _FloatingWindowInitializer(
        config: config,
        windowId: windowId,
        stateNotifier: stateNotifier,
      ),
    );
  }
}

/// 浮窗初始化器 - 在 widget 树中初始化 windowManager
class _FloatingWindowInitializer extends StatefulWidget {
  final FloatingWindowConfig config;
  final String windowId;
  final FloatingWindowStateNotifier stateNotifier;

  const _FloatingWindowInitializer({
    required this.config,
    required this.windowId,
    required this.stateNotifier,
  });

  @override
  State<_FloatingWindowInitializer> createState() =>
      _FloatingWindowInitializerState();
}

class _FloatingWindowInitializerState
    extends State<_FloatingWindowInitializer> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWindow();
  }

  Future<void> _initWindow() async {
    try {
      // 等待窗口就绪事件
      await windowManager.waitUntilReady();

      final size = widget.config.windowSize;

      // 获取屏幕尺寸
      // 注意：fork 的 window_manager 在 Windows 端这样设计：
      //   - getPrimaryScreenSize: 返回 GetSystemMetrics 的【物理像素】
      //   - setPosition / setSize: C++ 端把传入值乘以 devicePixelRatio
      //     ⇒ Dart 这一侧期望传入【逻辑像素】
      // 两个 API 的坐标系不一致，必须把屏幕物理像素手动除以 DPR 才能给 setPosition 用，
      // 否则在高 DPI 屏（如 200% 缩放）下会把窗口扔到屏幕外。
      final screenInfo = await windowManager.getPrimaryScreenSize();
      final dpr =
          PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
      final screenWidth = screenInfo['screenWidth']! / dpr;
      final workAreaHeight = screenInfo['workAreaHeight']! / dpr;
      final workAreaY = screenInfo['workAreaY']! / dpr;

      // 从设置中读取浮窗位置
      final position = await _calculateFloatingPosition(
        screenWidth,
        workAreaHeight,
        workAreaY,
        size,
      );

      await windowManager.waitUntilReadyToShow(null, () async {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setSize(size);
        await windowManager.setPosition(position);
        await windowManager.setMinimumSize(
          Size(size.width - 60, size.height - 60),
        );
        await windowManager.setMaximumSize(
          Size(size.width + 100, size.height + 100),
        );
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setBackgroundColor(Colors.transparent);
        if (Platform.isWindows) {
          await windowManager.setAsFrameless();
          // 边界：若创建瞬间已处于 D3D 独占全屏（游戏中），show 会抢前台导致
          // 游戏掉帧/最小化。此时只设置好窗口属性但不显示，交给启动器的
          // 全屏轮询定时器在退出全屏后再 show。
          if (FullscreenDetector.instance.canCreateWindow()) {
            // 浮窗不抢焦点
            await windowManager.showWithoutActivating();
          } else {
            debugPrint(
              '[FloatingWindow] D3D fullscreen detected at init, defer show',
            );
          }
        } else {
          await windowManager.show();
        }
      });

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e, stack) {
      debugPrint('[FloatingWindow] Init error: $e\n$stack');
      if (mounted) {
        setState(() => _error = '初始化失败，请重试');
      }
    }
  }

  /// 计算浮窗位置（从配置中读取）
  Future<Offset> _calculateFloatingPosition(
    double screenWidth,
    double workAreaHeight,
    double workAreaY,
    Size windowSize,
  ) async {
    try {
      // 从 config.extra 中读取浮窗位置设置
      final positionIndex =
          widget.config.extra?['floatingWindowPosition'] as int? ?? 8; // 默认右下角
      final position = NotificationPositionType.values[positionIndex];

      const padding = 20.0;
      final availableHeight = workAreaHeight;
      final centerY = workAreaY + (availableHeight - windowSize.height) / 2;

      Offset calculatedPosition;

      switch (position) {
        case NotificationPositionType.topLeft:
          calculatedPosition = Offset(padding, workAreaY + padding);
          break;
        case NotificationPositionType.topCenter:
          calculatedPosition = Offset(
            (screenWidth - windowSize.width) / 2,
            workAreaY + padding,
          );
          break;
        case NotificationPositionType.topRight:
          calculatedPosition = Offset(
            screenWidth - windowSize.width - padding,
            workAreaY + padding,
          );
          break;
        case NotificationPositionType.centerLeft:
          calculatedPosition = Offset(padding, centerY);
          break;
        case NotificationPositionType.center:
          calculatedPosition = Offset(
            (screenWidth - windowSize.width) / 2,
            centerY,
          );
          break;
        case NotificationPositionType.centerRight:
          calculatedPosition = Offset(
            screenWidth - windowSize.width - padding,
            centerY,
          );
          break;
        case NotificationPositionType.bottomLeft:
          calculatedPosition = Offset(
            padding,
            workAreaY + availableHeight - windowSize.height - padding,
          );
          break;
        case NotificationPositionType.bottomCenter:
          calculatedPosition = Offset(
            (screenWidth - windowSize.width) / 2,
            workAreaY + availableHeight - windowSize.height - padding,
          );
          break;
        case NotificationPositionType.bottomRight:
          calculatedPosition = Offset(
            screenWidth - windowSize.width - padding,
            workAreaY + availableHeight - windowSize.height - padding,
          );
          break;
      }

      return calculatedPosition;
    } catch (e) {
      debugPrint(
        '[FloatingWindow] Failed to read position setting, using default: $e',
      );
      // 默认右下角
      const padding = 20.0;
      return Offset(
        screenWidth - windowSize.width - padding,
        workAreaY + workAreaHeight - windowSize.height - padding,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.slate800,
        body: Center(
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.slate800,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return FloatingWindowShell(
      config: widget.config,
      windowId: widget.windowId,
      stateNotifier: widget.stateNotifier,
    );
  }
}
