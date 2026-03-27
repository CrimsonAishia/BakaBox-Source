import 'package:flutter/material.dart';

import '../core/bootstrap/app_initializer.dart';
import '../web/app.dart';

Future<void> runPlatformAppImpl(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppInitializer.recordStartTime();

  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 << 20;

  runApp(const WebApp());
}
