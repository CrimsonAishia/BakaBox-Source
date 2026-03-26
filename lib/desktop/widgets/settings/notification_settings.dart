import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/bloc/settings/settings_bloc.dart';
import '../../../core/bloc/settings/settings_event.dart';
import '../../../core/bloc/settings/settings_state.dart';
import '../../../core/utils/log_service.dart';
import '../notification_position_editor.dart';
import 'settings_group_title.dart';
import 'settings_item.dart';

/// 通知设置组件
class NotificationSettings extends StatelessWidget {
  final SettingsState settingsState;

  const NotificationSettings({super.key, required this.settingsState});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: '窗口位置设置',
          hasGlow: true,
          icon: MdiIcons.monitorScreenshot,
        ),
        AppSettingItem(
          title: '窗口位置',
          description: '拖动窗口调整位置，点击预览按钮在屏幕上显示实际占用区域',
          value: _NotificationPositionEditorWrapper(
            settingsState: settingsState,
          ),
          action: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 位置编辑器包装组件
class _NotificationPositionEditorWrapper extends StatefulWidget {
  final SettingsState settingsState;

  const _NotificationPositionEditorWrapper({required this.settingsState});

  @override
  State<_NotificationPositionEditorWrapper> createState() =>
      _NotificationPositionEditorWrapperState();
}

class _NotificationPositionEditorWrapperState
    extends State<_NotificationPositionEditorWrapper> {
  String? _notificationPreviewWindowId;
  String? _floatingPreviewWindowId;
  Timer? _notificationAutoCloseTimer;
  Timer? _floatingAutoCloseTimer;

  // 通知窗口尺寸（与 notification_window_service.dart 一致）
  static const double _notificationWidth = 300.0;
  static const double _notificationCardHeight = 72.0;
  static const double _notificationSpacing = 8.0;
  static const int _maxNotifications = 5;
  // 通知区域总高度 = 5张卡片 + 4个间距
  static const double _notificationTopPadding =
      5.0; // 与 notification_window_service.dart 一致
  static const double _notificationTotalHeight =
      _notificationCardHeight * _maxNotifications +
      _notificationSpacing * (_maxNotifications - 1);

  // 浮窗尺寸（与 floating_window_service.dart 一致）
  static const double _floatingWidth = 280.0;
  static const double _floatingHeight = 160.0;
  static const double _floatingPadding = 20.0; // 浮窗边距

  static const double _taskbarHeight = 48.0;

  @override
  void dispose() {
    _notificationAutoCloseTimer?.cancel();
    _floatingAutoCloseTimer?.cancel();
    _closeAllPreviews();
    super.dispose();
  }

  Future<void> _closeAllPreviews() async {
    if (_notificationPreviewWindowId != null) {
      await _closePreviewWindow(_notificationPreviewWindowId!);
      _notificationPreviewWindowId = null;
    }
    if (_floatingPreviewWindowId != null) {
      await _closePreviewWindow(_floatingPreviewWindowId!);
      _floatingPreviewWindowId = null;
    }
  }

  Future<void> _closePreviewWindow(String windowId) async {
    try {
      final controller = WindowController.fromWindowId(windowId);
      await controller.invokeMethod('window_close');
    } catch (e) {
      LogService.d('[PositionPreview] Window may already be closed: $e');
    }
  }

  Future<void> _showNotificationPreview() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    // 关闭已有的预览窗口
    if (_notificationPreviewWindowId != null) {
      _notificationAutoCloseTimer?.cancel();
      await _closePreviewWindow(_notificationPreviewWindowId!);
      _notificationPreviewWindowId = null;
      setState(() {});
      return;
    }

    // 获取屏幕尺寸（使用 window_manager）
    final screenInfo = await windowManager.getPrimaryScreenSize();
    final screenWidth = screenInfo['screenWidth']!;
    final screenHeight = screenInfo['screenHeight']!;

    final position = _calculateNotificationPosition(
      widget.settingsState.notificationPosition,
      screenWidth,
      screenHeight,
    );

    try {
      // 创建预览窗口
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({
            'windowType': 'position_preview',
            'previewType': 'notification',
            'width': _notificationWidth,
            'height': _notificationTotalHeight,
            'label': '通知区域',
            'sublabel': '最多 $_maxNotifications 条通知',
            'x': position.dx,
            'y': position.dy,
          }),
        ),
      );

      _notificationPreviewWindowId = controller.windowId;
      setState(() {});

      // 5秒后自动关闭
      _notificationAutoCloseTimer?.cancel();
      _notificationAutoCloseTimer = Timer(const Duration(seconds: 5), () async {
        if (_notificationPreviewWindowId != null) {
          await _closePreviewWindow(_notificationPreviewWindowId!);
          _notificationPreviewWindowId = null;
          if (mounted) setState(() {});
        }
      });
    } catch (e) {
      LogService.e('[PositionPreview] Create notification preview failed', e);
    }
  }

  Future<void> _showFloatingPreview() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    if (_floatingPreviewWindowId != null) {
      _floatingAutoCloseTimer?.cancel();
      await _closePreviewWindow(_floatingPreviewWindowId!);
      _floatingPreviewWindowId = null;
      setState(() {});
      return;
    }

    // 获取屏幕尺寸（使用 window_manager）
    final screenInfo = await windowManager.getPrimaryScreenSize();
    final screenWidth = screenInfo['screenWidth']!;
    final screenHeight = screenInfo['screenHeight']!;

    final position = _calculateFloatingPosition(
      widget.settingsState.floatingWindowPosition,
      screenWidth,
      screenHeight,
    );

    try {
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({
            'windowType': 'position_preview',
            'previewType': 'floating',
            'width': _floatingWidth,
            'height': _floatingHeight,
            'label': '浮窗区域',
            'sublabel': '挤服/连接状态',
            'x': position.dx,
            'y': position.dy,
          }),
        ),
      );

      _floatingPreviewWindowId = controller.windowId;
      setState(() {});

      // 5秒后自动关闭
      _floatingAutoCloseTimer?.cancel();
      _floatingAutoCloseTimer = Timer(const Duration(seconds: 5), () async {
        if (_floatingPreviewWindowId != null) {
          await _closePreviewWindow(_floatingPreviewWindowId!);
          _floatingPreviewWindowId = null;
          if (mounted) setState(() {});
        }
      });
    } catch (e) {
      LogService.e('[PositionPreview] Create floating preview failed', e);
    }
  }

  /// 计算通知窗口位置（贴边，无边距）
  Offset _calculateNotificationPosition(
    NotificationPositionType position,
    double screenWidth,
    double screenHeight,
  ) {
    final availableHeight = screenHeight - _taskbarHeight;
    final centerY = (availableHeight - _notificationTotalHeight) / 2;

    switch (position) {
      case NotificationPositionType.topLeft:
        return Offset(0, _notificationTopPadding);
      case NotificationPositionType.topCenter:
        return Offset(
          (screenWidth - _notificationWidth) / 2,
          _notificationTopPadding,
        );
      case NotificationPositionType.topRight:
        return Offset(
          screenWidth - _notificationWidth,
          _notificationTopPadding,
        );
      case NotificationPositionType.centerLeft:
        return Offset(0, centerY);
      case NotificationPositionType.center:
        return Offset((screenWidth - _notificationWidth) / 2, centerY);
      case NotificationPositionType.centerRight:
        return Offset(screenWidth - _notificationWidth, centerY);
      case NotificationPositionType.bottomLeft:
        return Offset(
          0,
          availableHeight - _notificationTotalHeight - _notificationTopPadding,
        );
      case NotificationPositionType.bottomCenter:
        return Offset(
          (screenWidth - _notificationWidth) / 2,
          availableHeight - _notificationTotalHeight - _notificationTopPadding,
        );
      case NotificationPositionType.bottomRight:
        return Offset(
          screenWidth - _notificationWidth,
          availableHeight - _notificationTotalHeight - _notificationTopPadding,
        );
    }
  }

  /// 计算浮窗位置（有边距）
  Offset _calculateFloatingPosition(
    NotificationPositionType position,
    double screenWidth,
    double screenHeight,
  ) {
    final availableHeight = screenHeight - _taskbarHeight;
    final centerY = (availableHeight - _floatingHeight) / 2;

    switch (position) {
      case NotificationPositionType.topLeft:
        return Offset(_floatingPadding, _floatingPadding);
      case NotificationPositionType.topCenter:
        return Offset((screenWidth - _floatingWidth) / 2, _floatingPadding);
      case NotificationPositionType.topRight:
        return Offset(
          screenWidth - _floatingWidth - _floatingPadding,
          _floatingPadding,
        );
      case NotificationPositionType.centerLeft:
        return Offset(_floatingPadding, centerY);
      case NotificationPositionType.center:
        return Offset((screenWidth - _floatingWidth) / 2, centerY);
      case NotificationPositionType.centerRight:
        return Offset(screenWidth - _floatingWidth - _floatingPadding, centerY);
      case NotificationPositionType.bottomLeft:
        return Offset(
          _floatingPadding,
          availableHeight - _floatingHeight - _floatingPadding,
        );
      case NotificationPositionType.bottomCenter:
        return Offset(
          (screenWidth - _floatingWidth) / 2,
          availableHeight - _floatingHeight - _floatingPadding,
        );
      case NotificationPositionType.bottomRight:
        return Offset(
          screenWidth - _floatingWidth - _floatingPadding,
          availableHeight - _floatingHeight - _floatingPadding,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NotificationPositionEditor(
          initialNotificationPosition: _convertToEditorPosition(
            widget.settingsState.notificationPosition,
          ),
          initialFloatingPosition: _convertToEditorPosition(
            widget.settingsState.floatingWindowPosition,
          ),
          onNotificationPositionChanged: (position) {
            final statePosition = _convertToStatePosition(position);
            context.read<SettingsBloc>().add(
              SettingsSetNotificationPosition(statePosition),
            );
            // 如果预览窗口打开，移动到新位置
            _updateNotificationPreviewPosition(statePosition);
          },
          onFloatingPositionChanged: (position) {
            final statePosition = _convertToStatePosition(position);
            context.read<SettingsBloc>().add(
              SettingsSetFloatingWindowPosition(statePosition),
            );
            // 如果预览窗口打开，移动到新位置
            _updateFloatingPreviewPosition(statePosition);
          },
          onNotificationPreview: _showNotificationPreview,
          onFloatingPreview: _showFloatingPreview,
          isNotificationPreviewActive: _notificationPreviewWindowId != null,
          isFloatingPreviewActive: _floatingPreviewWindowId != null,
        ),
      ],
    );
  }

  /// 更新通知预览窗口位置
  Future<void> _updateNotificationPreviewPosition(
    NotificationPositionType position,
  ) async {
    if (_notificationPreviewWindowId == null) return;

    try {
      final screenInfo = await windowManager.getPrimaryScreenSize();
      final screenWidth = screenInfo['screenWidth']!;
      final screenHeight = screenInfo['screenHeight']!;

      final newPosition = _calculateNotificationPosition(
        position,
        screenWidth,
        screenHeight,
      );

      final controller = WindowController.fromWindowId(
        _notificationPreviewWindowId!,
      );
      await controller.invokeMethod('updatePosition', {
        'x': newPosition.dx,
        'y': newPosition.dy,
      });
    } catch (e) {
      LogService.d('[PositionPreview] Update notification position failed: $e');
    }
  }

  /// 更新浮窗预览窗口位置
  Future<void> _updateFloatingPreviewPosition(
    NotificationPositionType position,
  ) async {
    if (_floatingPreviewWindowId == null) return;

    try {
      final screenInfo = await windowManager.getPrimaryScreenSize();
      final screenWidth = screenInfo['screenWidth']!;
      final screenHeight = screenInfo['screenHeight']!;

      final newPosition = _calculateFloatingPosition(
        position,
        screenWidth,
        screenHeight,
      );

      final controller = WindowController.fromWindowId(
        _floatingPreviewWindowId!,
      );
      await controller.invokeMethod('updatePosition', {
        'x': newPosition.dx,
        'y': newPosition.dy,
      });
    } catch (e) {
      LogService.d('[PositionPreview] Update floating position failed: $e');
    }
  }

  WindowPositionType _convertToEditorPosition(
    NotificationPositionType position,
  ) {
    switch (position) {
      case NotificationPositionType.topLeft:
        return WindowPositionType.topLeft;
      case NotificationPositionType.topCenter:
        return WindowPositionType.topCenter;
      case NotificationPositionType.topRight:
        return WindowPositionType.topRight;
      case NotificationPositionType.centerLeft:
        return WindowPositionType.centerLeft;
      case NotificationPositionType.center:
        return WindowPositionType.center;
      case NotificationPositionType.centerRight:
        return WindowPositionType.centerRight;
      case NotificationPositionType.bottomLeft:
        return WindowPositionType.bottomLeft;
      case NotificationPositionType.bottomCenter:
        return WindowPositionType.bottomCenter;
      case NotificationPositionType.bottomRight:
        return WindowPositionType.bottomRight;
    }
  }

  NotificationPositionType _convertToStatePosition(
    WindowPositionType position,
  ) {
    switch (position) {
      case WindowPositionType.topLeft:
        return NotificationPositionType.topLeft;
      case WindowPositionType.topCenter:
        return NotificationPositionType.topCenter;
      case WindowPositionType.topRight:
        return NotificationPositionType.topRight;
      case WindowPositionType.centerLeft:
        return NotificationPositionType.centerLeft;
      case WindowPositionType.center:
        return NotificationPositionType.center;
      case WindowPositionType.centerRight:
        return NotificationPositionType.centerRight;
      case WindowPositionType.bottomLeft:
        return NotificationPositionType.bottomLeft;
      case WindowPositionType.bottomCenter:
        return NotificationPositionType.bottomCenter;
      case WindowPositionType.bottomRight:
        return NotificationPositionType.bottomRight;
    }
  }
}
