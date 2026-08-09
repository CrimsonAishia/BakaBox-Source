import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:fvp/fvp.dart' as fvp;
import '../core/bootstrap/app_initializer.dart';
import '../core/utils/platform_utils.dart';
import '../desktop/windows/window_launcher.dart';
import '../mobile/app.dart';

Future<void> runPlatformAppImpl(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 注入完整的 Mozilla 根证书库 (cacert.pem)
  // 解决部分 Windows 用户由于系统根证书库陈旧、或 Dart 未能触发自动下载
  // 导致的 CERTIFICATE_VERIFY_FAILED。
  // Mozilla CA Bundle 包含了 Let's Encrypt (ISRG Root X1), ZeroSSL (Sectigo),
  // GlobalSign 等几乎所有主流权威 CA 的根证书，后续更换证书供应商也完全兼容。
  try {
    final ByteData data = await rootBundle.load('assets/certs/cacert.pem');
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(),
    );
  } catch (e) {
    debugPrint('加载 Mozilla 根证书库失败: $e');
  }

  AppInitializer.recordStartTime();

  // 初始化前台服务通信端口（必须在 runApp 之前调用）
  if (!PlatformUtils.isDesktopPlatform) {
    FlutterForegroundTask.initCommunicationPort();
  }

  PaintingBinding.instance.imageCache.maximumSize = 30;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 10 << 20;

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
