import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;

import '../core/bootstrap/app_initializer.dart';
import '../core/utils/platform_utils.dart';
import '../desktop/windows/window_launcher.dart';
import '../mobile/app.dart';

Future<void> runPlatformAppImpl(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith(
    options: {
      'platforms': ['windows', 'linux', 'macos'],
    },
  );
  AppInitializer.recordStartTime();

  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 << 20;

  if (PlatformUtils.isDesktopPlatform) {
    await DesktopWindowLauncher.launch(args);
    return;
  }

  runApp(const MobileApp());
}
