import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

import '../utils/log_service.dart';

/// 广播通知服务 - 将大厅广播消息转为系统级通知
///
/// 使用 awesome_notifications 库创建系统级通知，
/// 在用户未授予通知权限时静默降级，不影响核心功能。
class BroadcastNotificationService {
  static final BroadcastNotificationService instance =
      BroadcastNotificationService._();

  BroadcastNotificationService._();

  final Random _random = Random();

  /// 初始化通知服务
  ///
  /// 创建 lobby_broadcast 通知渠道并请求通知权限。
  /// 所有操作均在 try-catch 中执行，失败时静默降级。
  Future<void> init() async {
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'lobby_broadcast',
            channelName: '大厅广播',
            channelDescription: 'BakaBox 大厅广播消息通知',
            defaultColor: const Color(0xFFF59E0B),
            importance: NotificationImportance.High,
          ),
        ],
      );

      LogService.i('广播通知服务初始化完成');
    } catch (e) {
      LogService.e('广播通知服务初始化失败', e);
    }
  }

  /// 显示广播通知
  ///
  /// 创建系统通知，标题为"BakaBox 大厅广播"，内容为发送者和消息内容。
  /// 权限未授予或创建失败时静默降级。
  Future<void> showBroadcastNotification({
    required String sender,
    required String content,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _random.nextInt(100000),
          channelKey: 'lobby_broadcast',
          title: 'BakaBox 大厅广播',
          body: '$sender: $content',
        ),
      );
    } catch (e) {
      LogService.e('创建广播通知失败', e);
    }
  }
}
