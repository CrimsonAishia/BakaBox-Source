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
import '../../../core/services/broadcast_notification_service.dart';
import '../../../core/services/notification_window_service.dart';
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
        const SizedBox(height: 30),
        SettingsGroupTitle(
          title: '广播通知方式',
          hasGlow: true,
          icon: MdiIcons.bullhorn,
        ),
        SettingsItem(
          label: '收到广播时的通知方式',
          description: '收到全服广播时，右下角浮动卡片始终显示。此处控制是否额外弹出独立通知窗口或系统通知。',
          control: _BroadcastNotificationTypeSelector(
            settingsState: settingsState,
          ),
          alignTop: true,
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

/// 广播通知方式选择器（参考窗口设置 Wrap chip 风格）
class _BroadcastNotificationTypeSelector extends StatelessWidget {
  final SettingsState settingsState;

  const _BroadcastNotificationTypeSelector({required this.settingsState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = settingsState.broadcastNotificationType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: BroadcastNotificationType.values.map((type) {
            final isSelected = current == type;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                context.read<SettingsBloc>().add(
                  SettingsSetBroadcastNotificationType(type),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0080FF).withValues(alpha: 0.15),
                            const Color(0xFF00D4FF).withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF9FAFB)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0080FF)
                        : (isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFE5E7EB)),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF0080FF,
                            ).withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForType(type),
                      size: 18,
                      color: isSelected
                          ? const Color(0xFF0080FF)
                          : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF0080FF)
                            : (isDark ? Colors.white : const Color(0xFF374151)),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(
                        MdiIcons.checkCircle,
                        size: 16,
                        color: const Color(0xFF0080FF),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            current.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (current != BroadcastNotificationType.disabled)
          _BroadcastNotificationTestButton(settingsState: settingsState),
      ],
    );
  }

  IconData _iconForType(BroadcastNotificationType type) {
    switch (type) {
      case BroadcastNotificationType.software:
        return MdiIcons.bellOutline;
      case BroadcastNotificationType.system:
        return MdiIcons.microsoftWindows;
      case BroadcastNotificationType.disabled:
        return MdiIcons.bellOffOutline;
    }
  }
}

/// 广播通知测试按钮
class _BroadcastNotificationTestButton extends StatefulWidget {
  final SettingsState settingsState;

  const _BroadcastNotificationTestButton({required this.settingsState});

  @override
  State<_BroadcastNotificationTestButton> createState() =>
      _BroadcastNotificationTestButtonState();
}

class _BroadcastNotificationTestButtonState
    extends State<_BroadcastNotificationTestButton> {
  bool _isSending = false;

  Future<void> _sendTest() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final type = widget.settingsState.broadcastNotificationType;
      if (type == BroadcastNotificationType.disabled) return;
      if (type == BroadcastNotificationType.system) {
        await BroadcastNotificationService.instance.showBroadcastNotification(
          sender: 'BakaBox',
          content: '这是一条系统通知测试消息',
        );
      } else {
        NotificationWindowService().showBroadcastNotification(
          nickname: 'BakaBox',
          content: '这是一条软件通知测试消息',
        );
      }
    } catch (e) {
      LogService.e('[NotificationTest] 测试通知发送失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通知发送失败，请检查系统通知权限'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // 短暂禁用按钮防止连点
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
        opacity: _isSending ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: OutlinedButton.icon(
          onPressed: _isSending ? null : _sendTest,
          icon: _isSending
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white54 : const Color(0xFF6366F1),
                  ),
                )
              : const Icon(Icons.notifications_active_outlined, size: 16),
          label: Text(_isSending ? '已发送' : '发送测试通知'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : const Color(0xFF6366F1),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFF6366F1).withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
