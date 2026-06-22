/// 应用更新信息
class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? downloadUrl;
  final String? fallbackDownloadUrl;
  final int fileSize;
  final String? fileMd5;
  final DateTime publishDate;
  final bool isForced;
  final String? minSupportVersion;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    this.downloadUrl,
    this.fallbackDownloadUrl,
    required this.fileSize,
    this.fileMd5,
    required this.publishDate,
    this.isForced = false,
    this.minSupportVersion,
  });

  /// 从后端响应解析
  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    final hasUpdate = json['hasUpdate'] as bool? ?? false;
    if (!hasUpdate) {
      return AppUpdateInfo.noUpdate(currentVersion);
    }

    final updateInfo = json['updateInfo'] as Map<String, dynamic>?;
    if (updateInfo == null) {
      return AppUpdateInfo.noUpdate(currentVersion);
    }

    final minSupportVersion = updateInfo['minSupportVersion'] as String?;
    final isForced = updateInfo['isForced'] as bool? ?? false;

    // 检查是否低于最低支持版本
    // 如果当前版本低于最低支持版本，则强制更新
    bool shouldForceUpdate = false;
    if (minSupportVersion != null && minSupportVersion.isNotEmpty) {
      try {
        shouldForceUpdate =
            _compareVersion(currentVersion, minSupportVersion) < 0;
      } catch (e) {
        // 版本比较失败时保守处理，不强制更新
        shouldForceUpdate = false;
      }
    }

    return AppUpdateInfo(
      hasUpdate: true,
      currentVersion: currentVersion,
      latestVersion: updateInfo['version'] as String? ?? '',
      releaseNotes: updateInfo['releaseNotes'] as String? ?? '',
      downloadUrl: updateInfo['downloadUrl'] as String?,
      fallbackDownloadUrl: updateInfo['fallbackDownloadUrl'] as String?,
      fileSize: updateInfo['fileSize'] as int? ?? 0,
      fileMd5: updateInfo['fileMd5'] as String?,
      publishDate:
          DateTime.tryParse(updateInfo['publishDate'] as String? ?? '') ??
          DateTime.now(),
      isForced: isForced || shouldForceUpdate, // 服务器强制 或 版本过低时强制
      minSupportVersion: minSupportVersion,
    );
  }

  /// 无更新
  factory AppUpdateInfo.noUpdate(String currentVersion) {
    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseNotes: '',
      fileSize: 0,
      publishDate: DateTime.now(),
    );
  }

  /// 比较版本号（包含 build 号）
  /// 返回值：< 0 表示 v1 < v2，0 表示相等，> 0 表示 v1 > v2
  static int _compareVersion(String v1, String v2) {
    final parts1 = _parseVersion(v1);
    final parts2 = _parseVersion(v2);

    // 逐位比较 major, minor, patch, build
    for (int i = 0; i < 4; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }

  /// 解析版本号为 [major, minor, patch, build]
  static List<int> _parseVersion(String version) {
    // 移除 "v" 或 "V" 前缀
    String normalized = version.trim();
    if (normalized.toLowerCase().startsWith('v')) {
      normalized = normalized.substring(1);
    }

    int buildNumber = 0;
    if (normalized.contains('+')) {
      final splitParts = normalized.split('+');
      normalized = splitParts.first;
      if (splitParts.length > 1) {
        buildNumber = int.tryParse(splitParts.last) ?? 0;
      }
    }

    // 移除预发布标识
    if (normalized.contains('-')) {
      normalized = normalized.split('-').first;
    }

    final parts = normalized
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }

    final result = parts.take(3).toList();
    result.add(buildNumber);
    return result;
  }

  String get formattedFileSize {
    if (fileSize == 0) return '未知';
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = fileSize.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String get formattedPublishDate =>
      '${publishDate.year}年${publishDate.month}月${publishDate.day}日';
}

/// 下载进度
class DownloadProgress {
  final int downloaded;
  final int total;
  final double progress;
  final String speed;

  const DownloadProgress({
    required this.downloaded,
    required this.total,
    required this.progress,
    required this.speed,
  });

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';
  String get formattedDownloaded => _formatBytes(downloaded);
  String get formattedTotal => _formatBytes(total);

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)}${units[unitIndex]}';
  }
}

/// 更新状态
enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  downloaded,
  preparing,
  installing,
  completed,
  failed,
  cancelled,
}

/// 更新上报请求
class UpdateReportRequest {
  final String platform;
  final String? os;
  final String fromVersion;
  final String toVersion;
  final String status;
  final String? errorMessage;

  const UpdateReportRequest({
    required this.platform,
    this.os,
    required this.fromVersion,
    required this.toVersion,
    required this.status,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'platform': platform,
    if (os != null) 'os': os,
    'fromVersion': fromVersion,
    'toVersion': toVersion,
    'status': status,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };
}
