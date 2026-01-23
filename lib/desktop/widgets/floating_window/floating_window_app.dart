import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/services/floating_window_service.dart';
import '../../../core/utils/storage_utils.dart';
import '../../theme/desktop_theme.dart';
import 'floating_window_shell.dart';
import 'floating_window_state.dart';

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
    debugPrint('[FloatingWindowStateNotifier] Initialized with state: ${_state.state}');
    notifyListeners();
  }

  /// 更新状态（来自 IPC）
  void updateState(Map<dynamic, dynamic> args) {
    final newStateStr = args['state'] as String?;
    
    debugPrint('[FloatingWindowStateNotifier] updateState called: newState=$newStateStr, currentState=${_state.state}');
    
    // 检查是否有 autoDismissSeconds 更新
    if (args.containsKey('autoDismissSeconds')) {
      _autoDismissSeconds = args['autoDismissSeconds'] as int?;
      debugPrint('[FloatingWindowStateNotifier] autoDismissSeconds updated: $_autoDismissSeconds');
    }
    
    // 如果当前是终态，检查是否允许转换
    if (_state.isTerminal && newStateStr != null) {
      final newState = FloatingWindowState.fromMap({'state': newStateStr});
      // 允许从终态转换到活跃状态（挤服、连接、加载、启动）
      if (newState.isQueueing || newState.isConnecting || newState.isLoading || newState.isLaunching) {
        debugPrint('[FloatingWindowStateNotifier] Allowing transition from terminal to active state: $newStateStr');
        // 继续处理
      } else {
        debugPrint('[FloatingWindowStateNotifier] Ignoring update while in terminal state: ${_state.state}');
        return;
      }
    }
    
    // 如果当前是启动状态，只接受特定状态转换
    if (_state.isLaunching && newStateStr != null) {
      final newState = FloatingWindowState.fromMap({'state': newStateStr});
      // 允许转换到成功、失败、挤服状态
      if (newState.isPaused && !newState.isSuccess && !newState.isFailed && !newState.isQueueing) {
        debugPrint('[FloatingWindowStateNotifier] Ignoring paused update while in launching state: $newStateStr');
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
      threadStatuses: (args['threadStatuses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? _state.threadStatuses,
      mapName: hasMapNameKey ? args['mapName'] as String? : _state.mapName,
      mapNameCn: hasMapNameCnKey ? args['mapNameCn'] as String? : _state.mapNameCn,
      mapBackground: hasMapBackgroundKey ? args['mapBackground'] as String? : _state.mapBackground,
    );
    
    debugPrint('[FloatingWindowStateNotifier] State updated: ${_state.state} - ${_state.message}');
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
      debugPrint('[FloatingWindow] Starting initialization...');

      // 等待窗口就绪事件
      await windowManager.waitUntilReady();

      // windowManager 已在 main.dart 中初始化
      debugPrint('[FloatingWindow] windowManager ready');

      final size = widget.config.windowSize;

      // 获取屏幕尺寸
      final screenInfo = await windowManager.getPrimaryScreenSize();
      final screenWidth = screenInfo['screenWidth']!;
      final workAreaHeight = screenInfo['workAreaHeight']!;
      final workAreaY = screenInfo['workAreaY']!;
      
      // 从设置中读取浮窗位置
      final position = await _calculateFloatingPosition(
        screenWidth,
        workAreaHeight,
        workAreaY,
        size,
      );

      final windowOptions = WindowOptions(
        size: size,
        center: false,
        backgroundColor: Colors.transparent,
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
        alwaysOnTop: true,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPosition(position);
        await windowManager.setMinimumSize(
            Size(size.width - 60, size.height - 60));
        await windowManager.setMaximumSize(
            Size(size.width + 100, size.height + 100));
        if (Platform.isWindows) {
          await windowManager.setAsFrameless();
        }
        await windowManager.show();
        await windowManager.focus();
      });

      debugPrint('[FloatingWindow] Window setup complete at position: $position');

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

  /// 计算浮窗位置（从设置中读取）
  Future<Offset> _calculateFloatingPosition(
    double screenWidth,
    double workAreaHeight,
    double workAreaY,
    Size windowSize,
  ) async {
    try {
      // 从存储中读取浮窗位置设置
      final positionIndex = StorageUtils.getInt('floating_window_position') ?? 8; // 默认右下角
      final position = NotificationPositionType.values[positionIndex];
      
      const padding = 20.0;
      final availableHeight = workAreaHeight;
      final centerY = workAreaY + (availableHeight - windowSize.height) / 2;
      
      switch (position) {
        case NotificationPositionType.topLeft:
          return Offset(padding, workAreaY + padding);
        case NotificationPositionType.topCenter:
          return Offset((screenWidth - windowSize.width) / 2, workAreaY + padding);
        case NotificationPositionType.topRight:
          return Offset(screenWidth - windowSize.width - padding, workAreaY + padding);
        case NotificationPositionType.centerLeft:
          return Offset(padding, centerY);
        case NotificationPositionType.center:
          return Offset((screenWidth - windowSize.width) / 2, centerY);
        case NotificationPositionType.centerRight:
          return Offset(screenWidth - windowSize.width - padding, centerY);
        case NotificationPositionType.bottomLeft:
          return Offset(padding, workAreaY + availableHeight - windowSize.height - padding);
        case NotificationPositionType.bottomCenter:
          return Offset((screenWidth - windowSize.width) / 2, workAreaY + availableHeight - windowSize.height - padding);
        case NotificationPositionType.bottomRight:
          return Offset(screenWidth - windowSize.width - padding, workAreaY + availableHeight - windowSize.height - padding);
      }
    } catch (e) {
      debugPrint('[FloatingWindow] Failed to read position setting, using default: $e');
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
        backgroundColor: const Color(0xFF1E293B),
        body: Center(
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E293B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0080FF)),
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
