/// 应用更新信息
class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? downloadUrl;
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
    required this.fileSize,
    this.fileMd5,
    required this.publishDate,
    this.isForced = false,
    this.minSupportVersion,
  });

  /// 从后端响应解析
  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String currentVersion) {
    final hasUpdate = json['hasUpdate'] as bool? ?? false;
    if (!hasUpdate) {
      return AppUpdateInfo.noUpdate(currentVersion);
    }
    
    final updateInfo = json['updateInfo'] as Map<String, dynamic>?;
    if (updateInfo == null) {
      return AppUpdateInfo.noUpdate(currentVersion);
    }

    return AppUpdateInfo(
      hasUpdate: true,
      currentVersion: currentVersion,
      latestVersion: updateInfo['version'] as String? ?? '',
      releaseNotes: updateInfo['releaseNotes'] as String? ?? '',
      downloadUrl: updateInfo['downloadUrl'] as String?,
      fileSize: updateInfo['fileSize'] as int? ?? 0,
      fileMd5: updateInfo['fileMd5'] as String?,
      publishDate: DateTime.tryParse(updateInfo['publishDate'] as String? ?? '') ?? DateTime.now(),
      isForced: updateInfo['isForced'] as bool? ?? false,
      minSupportVersion: updateInfo['minSupportVersion'] as String?,
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

  String get formattedPublishDate => '${publishDate.year}年${publishDate.month}月${publishDate.day}日';
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
enum UpdateStatus { idle, checking, available, downloading, downloaded, preparing, installing, completed, failed, cancelled }

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
