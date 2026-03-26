/// 版本工具类
///
/// 提供版本号比较功能
class VersionUtils {
  VersionUtils._();

  /// 比较两个版本号
  ///
  /// 返回值：
  /// - 正数：version1 > version2
  /// - 0：version1 == version2
  /// - 负数：version1 < version2
  ///
  /// 支持格式：
  /// - 1.0.0
  /// - 1.0.0-beta
  /// - 1.0.0+123
  static int compareVersion(String version1, String version2) {
    // 移除预发布标识和构建元数据
    final v1 = _normalizeVersion(version1);
    final v2 = _normalizeVersion(version2);

    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    final maxLength = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;
    while (parts1.length < maxLength) {
      parts1.add(0);
    }
    while (parts2.length < maxLength) {
      parts2.add(0);
    }

    // 逐位比较
    for (int i = 0; i < maxLength; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }

    return 0;
  }

  /// 标准化版本号（移除预发布标识和构建元数据）
  ///
  /// 例如：
  /// - 1.0.0-beta -> 1.0.0
  /// - 1.0.0+123 -> 1.0.0
  static String _normalizeVersion(String version) {
    // 移除 -beta, -alpha 等预发布标识
    if (version.contains('-')) {
      version = version.split('-').first;
    }
    // 移除 +123 等构建元数据
    if (version.contains('+')) {
      version = version.split('+').first;
    }
    return version.trim();
  }

  /// 检查版本是否低于最低支持版本
  ///
  /// 返回 true 表示当前版本过低，需要强制更新
  static bool isBelowMinVersion(String currentVersion, String minVersion) {
    return compareVersion(currentVersion, minVersion) < 0;
  }

  /// 检查是否有新版本
  static bool hasNewVersion(String currentVersion, String latestVersion) {
    return compareVersion(currentVersion, latestVersion) < 0;
  }
}
