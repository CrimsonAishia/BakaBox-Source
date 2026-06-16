import 'dart:io';

String getOperatingSystem() => Platform.operatingSystem;

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isWindows => Platform.isWindows;

/// 获取规范化后的操作系统版本字符串
///
/// 主要用途：修正 Windows 11 被识别为 Windows 10 的问题。
/// 由于 Microsoft 在 Windows 11 上保留了内部主版本号 `10.0`，
/// `Platform.operatingSystemVersion` 仍会返回 `"Windows 10 ..."`，
/// 因此通过 Build 号（>= 22000 为 Windows 11）做矫正。
String getOperatingSystemVersion() {
  final raw = Platform.operatingSystemVersion;
  if (Platform.isWindows) {
    return _normalizeWindowsVersion(raw);
  }
  return raw;
}

/// 获取简短的操作系统名称，例如：`Windows 11`、`Windows 10`、`macOS`、`Android`、`iOS`、`Linux`。
String getOperatingSystemShortName() {
  if (Platform.isWindows) {
    final build = _parseWindowsBuild(Platform.operatingSystemVersion);
    if (build != null && build >= 22000) return 'Windows 11';
    return 'Windows 10';
  }
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  return Platform.operatingSystem;
}

String _normalizeWindowsVersion(String raw) {
  final build = _parseWindowsBuild(raw);
  if (build == null) return raw;
  if (build >= 22000) {
    // 将 "Windows 10" 替换为 "Windows 11"，保留版本/Build 详细信息。
    return raw.replaceAll('Windows 10', 'Windows 11');
  }
  return raw;
}

int? _parseWindowsBuild(String raw) {
  final match = RegExp(r'Build\s+(\d+)', caseSensitive: false).firstMatch(raw);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
