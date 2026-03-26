import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:window_manager/window_manager.dart';

/// 位置预览窗口配置
class PositionPreviewConfig {
  final String previewType; // 'notification' or 'floating'
  final double width;
  final double height;
  final String label;
  final String sublabel;
  final double x;
  final double y;

  const PositionPreviewConfig({
    required this.previewType,
    required this.width,
    required this.height,
    required this.label,
    required this.sublabel,
    required this.x,
    required this.y,
  });

  factory PositionPreviewConfig.fromArguments(String arguments) {
    if (arguments.isEmpty) {
      return const PositionPreviewConfig(
        previewType: 'notification',
        width: 300,
        height: 376,
        label: '预览',
        sublabel: '',
        x: 100,
        y: 100,
      );
    }
    try {
      final map = jsonDecode(arguments) as Map<String, dynamic>;
      return PositionPreviewConfig(
        previewType: map['previewType'] as String? ?? 'notification',
        width: (map['width'] as num?)?.toDouble() ?? 300,
        height: (map['height'] as num?)?.toDouble() ?? 376,
        label: map['label'] as String? ?? '预览',
        sublabel: map['sublabel'] as String? ?? '',
        x: (map['x'] as num?)?.toDouble() ?? 100,
        y: (map['y'] as num?)?.toDouble() ?? 100,
      );
    } catch (e) {
      return const PositionPreviewConfig(
        previewType: 'notification',
        width: 300,
        height: 376,
        label: '预览',
        sublabel: '',
        x: 100,
        y: 100,
      );
    }
  }

  /// 检查是否是位置预览窗口
  static bool isPositionPreviewWindow(String arguments) {
    if (arguments.isEmpty) return false;
    try {
      final map = jsonDecode(arguments) as Map<String, dynamic>;
      return map['windowType'] == 'position_preview';
    } catch (e) {
      return false;
    }
  }
}

/// 位置预览窗口 App
class PositionPreviewWindowApp extends StatefulWidget {
  final PositionPreviewConfig config;

  const PositionPreviewWindowApp({super.key, required this.config});

  @override
  State<PositionPreviewWindowApp> createState() =>
      _PositionPreviewWindowAppState();
}

class _PositionPreviewWindowAppState extends State<PositionPreviewWindowApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initWindow();
  }

  Future<void> _initWindow() async {
    try {
      // 等待 windowManager 准备就绪（参考 notification_window_app.dart）
      await windowManager.waitUntilReady();

      final size = Size(widget.config.width, widget.config.height);
      final position = Offset(widget.config.x, widget.config.y);

      debugPrint(
        '[PositionPreview] Init window at x=${position.dx}, y=${position.dy}, size=${size.width}x${size.height}',
      );

      // 使用 waitUntilReadyToShow 模式（参考 notification_window_app.dart）
      await windowManager.waitUntilReadyToShow(null, () async {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setSize(size);
        await windowManager.setPosition(position);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setResizable(false);
        await windowManager.setBackgroundColor(Colors.transparent);
        if (Platform.isWindows) {
          await windowManager.setAsFrameless();
        }
        // 显示窗口但不获取焦点
        if (Platform.isWindows) {
          await windowManager.showWithoutActivating();
        } else {
          await windowManager.show();
          await windowManager.blur();
        }
      });

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('[PositionPreview] Init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 窗口未初始化时显示空白
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: SizedBox.shrink(),
        ),
      );
    }

    final isNotification = widget.config.previewType == 'notification';
    final color = isNotification
        ? const Color(0xFF0080FF)
        : const Color(0xFFFF9800);
    final icon = isNotification ? MdiIcons.bellOutline : MdiIcons.gamepad;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GestureDetector(
        onTap: () async {
          await windowManager.close();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            width: widget.config.width,
            height: widget.config.height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: isNotification ? 48 : 32, color: color),
                SizedBox(height: isNotification ? 16 : 8),
                Text(
                  widget.config.label,
                  style: TextStyle(
                    fontSize: isNotification ? 20 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: isNotification ? 8 : 4),
                Text(
                  widget.config.sublabel,
                  style: TextStyle(
                    fontSize: isNotification ? 14 : 11,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(height: isNotification ? 12 : 6),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNotification ? 12 : 8,
                    vertical: isNotification ? 6 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.config.width.toInt()} × ${widget.config.height.toInt()} px',
                    style: TextStyle(
                      fontSize: isNotification ? 12 : 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: isNotification ? 20 : 8),
                Text(
                  '点击关闭',
                  style: TextStyle(
                    fontSize: isNotification ? 11 : 9,
                    color: color.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
