import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'core/bootstrap/app_initializer.dart';
import 'core/utils/platform_utils.dart';
import 'desktop/windows/window_launcher.dart';
import 'mobile/app.dart';

/// 应用入口
/// 
/// 职责：
/// 1. 初始化 Flutter 绑定
/// 2. 记录启动时间
/// 3. 根据平台分发到对应的启动流程
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  AppInitializer.recordStartTime();
  
  // 限制 Flutter 内置图片缓存，减少内存占用
  // 图片已通过 DiskImageCacheService 缓存到磁盘，内存缓存可以设置较小
  PaintingBinding.instance.imageCache.maximumSize = 50; // 最多缓存 50 张图片
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 << 20; // 最多 30MB

  if (PlatformUtils.isDesktopPlatform) {
    await DesktopWindowLauncher.launch(args);
  } else {
    runApp(const MobileApp());
  }
}
