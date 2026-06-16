import 'package:flutter/foundation.dart';

String getOperatingSystem() {
  if (kIsWeb) {
    return 'web';
  }
  throw UnsupportedError('Web environment does not expose dart:io Platform');
}

bool get isAndroid => false;
bool get isIOS => false;
bool get isWindows => false;

/// 获取规范化后的操作系统版本字符串（Web 平台无 dart:io）。
String getOperatingSystemVersion() {
  if (kIsWeb) return 'web';
  throw UnsupportedError('Web environment does not expose dart:io Platform');
}

/// 获取简短的操作系统名称（Web 平台无 dart:io）。
String getOperatingSystemShortName() {
  if (kIsWeb) return 'web';
  throw UnsupportedError('Web environment does not expose dart:io Platform');
}
