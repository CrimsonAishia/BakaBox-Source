import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:fvp/fvp.dart' as fvp;

import '../core/bootstrap/app_initializer.dart';
import '../core/utils/platform_utils.dart';
import '../desktop/windows/window_launcher.dart';
import '../mobile/app.dart';

Future<void> runPlatformAppImpl(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppInitializer.recordStartTime();

  // 初始化前台服务通信端口（必须在 runApp 之前调用）
  if (!PlatformUtils.isDesktopPlatform) {
    FlutterForegroundTask.initCommunicationPort();
  }

  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 << 20;

  if (PlatformUtils.isDesktopPlatform) {
    fvp.registerWith(
      options: {
        'platforms': ['windows', 'linux', 'macos'],
      },
    );
    await DesktopWindowLauncher.launch(args);
    return;
  }

  runApp(const MobileApp());
}
