import 'package:equatable/equatable.dart';
import '../../models/update_models.dart';

class UpdateState extends Equatable {
  final UpdateStatus status;
  final AppUpdateInfo? updateInfo;
  final DownloadProgress? downloadProgress;
  final String? errorMessage;
  final String? downloadedFilePath;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
    this.downloadProgress,
    this.errorMessage,
    this.downloadedFilePath,
  });

  bool get hasUpdate => updateInfo?.hasUpdate ?? false;
  bool get isChecking => status == UpdateStatus.checking;
  bool get isDownloading => status == UpdateStatus.downloading;
  bool get isInstalling => status == UpdateStatus.installing;

  UpdateState copyWith({
    UpdateStatus? status,
    AppUpdateInfo? updateInfo,
    DownloadProgress? downloadProgress,
    String? errorMessage,
    String? downloadedFilePath,
    bool clearError = false,
    bool clearProgress = false,
    bool clearDownloadedFilePath = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: clearProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
    );
  }

  @override
  List<Object?> get props => [
    status,
    updateInfo,
    downloadProgress,
    errorMessage,
    downloadedFilePath,
  ];
}
