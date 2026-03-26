import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/update_models.dart';
import '../../services/update_service.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import '../../utils/platform_utils.dart';
import 'update_event.dart';
import 'update_state.dart';

class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  final UpdateService _updateService = UpdateService();

  UpdateBloc() : super(const UpdateState()) {
    on<UpdateCheck>(_onCheck);
    on<UpdateAutoCheck>(_onAutoCheck);
    on<UpdateDownload>(_onDownload);
    on<UpdateInstall>(_onInstall);
    on<UpdateDownloadAndInstall>(_onDownloadAndInstall);
    on<UpdateOpenAppStore>(_onOpenAppStore);
    on<UpdateClearError>(_onClearError);
    on<UpdateCancel>(_onCancel);
    on<UpdateSkip>(_onSkip);
    on<UpdateReset>(_onReset);
  }

  Future<void> _onCheck(UpdateCheck event, Emitter<UpdateState> emit) async {
    if (state.status == UpdateStatus.checking) return;
    emit(state.copyWith(status: UpdateStatus.checking, clearError: true));
    try {
      final updateInfo = await _updateService.checkForUpdate();
      emit(
        state.copyWith(
          updateInfo: updateInfo,
          status: updateInfo.hasUpdate
              ? UpdateStatus.available
              : UpdateStatus.idle,
        ),
      );
    } catch (e) {
      LogService.e('检查更新失败', e);
      emit(
        state.copyWith(
          errorMessage: ErrorUtils.getErrorMessage(e, defaultMessage: '检查更新失败'),
          status: UpdateStatus.failed,
        ),
      );
    }
  }

  Future<void> _onAutoCheck(
    UpdateAutoCheck event,
    Emitter<UpdateState> emit,
  ) async {
    if (state.status == UpdateStatus.checking) return;
    emit(state.copyWith(status: UpdateStatus.checking, clearError: true));
    try {
      final updateInfo = await _updateService.autoCheckForUpdate();
      if (updateInfo != null) {
        emit(
          state.copyWith(
            updateInfo: updateInfo,
            status: UpdateStatus.available,
          ),
        );
      } else {
        emit(state.copyWith(status: UpdateStatus.idle));
      }
    } catch (e) {
      LogService.e('自动检查更新失败: $e', e);
      // 自动检查失败时静默处理，不影响用户体验
      // 但确保状态回到 idle，避免卡在 checking 状态
      emit(state.copyWith(status: UpdateStatus.idle, clearError: true));
    }
  }

  /// 仅下载
  Future<void> _onDownload(
    UpdateDownload event,
    Emitter<UpdateState> emit,
  ) async {
    if (state.updateInfo == null || !state.updateInfo!.hasUpdate) {
      emit(
        state.copyWith(
          errorMessage: 'No update available',
          status: UpdateStatus.failed,
        ),
      );
      return;
    }
    if (state.status == UpdateStatus.downloading) return;

    emit(state.copyWith(status: UpdateStatus.downloading, clearError: true));
    try {
      final filePath = await _updateService.downloadUpdate(state.updateInfo!, (
        progress,
      ) {
        emit(state.copyWith(downloadProgress: progress));
      });
      // 下载完成，等待用户确认安装
      emit(
        state.copyWith(
          status: UpdateStatus.downloaded,
          downloadedFilePath: filePath,
        ),
      );
    } catch (e) {
      LogService.e('下载更新失败', e);
      emit(
        state.copyWith(
          errorMessage: ErrorUtils.getErrorMessage(e, defaultMessage: '下载更新失败'),
          status: UpdateStatus.failed,
        ),
      );
    }
  }

  /// 安装已下载的更新
  Future<void> _onInstall(
    UpdateInstall event,
    Emitter<UpdateState> emit,
  ) async {
    if (state.downloadedFilePath == null) {
      emit(
        state.copyWith(
          errorMessage: 'No downloaded file',
          status: UpdateStatus.failed,
        ),
      );
      return;
    }
    if (state.status == UpdateStatus.installing ||
        state.status == UpdateStatus.preparing) {
      return;
    }

    // Windows 显示准备安装状态，倒计时 3 秒
    // Android 直接安装（系统会弹出确认界面）
    if (PlatformUtils.isWindows) {
      emit(state.copyWith(status: UpdateStatus.preparing, clearError: true));
      await Future.delayed(const Duration(seconds: 3));
    }

    // 开始安装
    emit(state.copyWith(status: UpdateStatus.installing));
    try {
      await _updateService.installUpdate(
        state.downloadedFilePath!,
        state.updateInfo,
      );
      // Windows 静默安装会自动关闭进程
      // Android 安装后显示完成状态
      if (!PlatformUtils.isWindows) {
        emit(state.copyWith(status: UpdateStatus.completed));
      }
    } catch (e) {
      LogService.e('安装更新失败', e);
      emit(
        state.copyWith(
          errorMessage: ErrorUtils.getErrorMessage(e, defaultMessage: '安装更新失败'),
          status: UpdateStatus.failed,
        ),
      );
    }
  }

  Future<void> _onDownloadAndInstall(
    UpdateDownloadAndInstall event,
    Emitter<UpdateState> emit,
  ) async {
    if (state.updateInfo == null || !state.updateInfo!.hasUpdate) {
      emit(
        state.copyWith(
          errorMessage: 'No update available',
          status: UpdateStatus.failed,
        ),
      );
      return;
    }
    if (state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing) {
      return;
    }

    // Windows 和 Android：先下载，等用户确认后再安装
    if (PlatformUtils.isWindows || PlatformUtils.isAndroid) {
      add(UpdateDownload());
      return;
    }

    emit(state.copyWith(status: UpdateStatus.downloading, clearError: true));
    try {
      await _updateService.downloadAndInstallUpdate(state.updateInfo!, (
        progress,
      ) {
        emit(state.copyWith(downloadProgress: progress));
      });
      // iOS 直接跳转商店，显示完成状态
      // 其他平台打开安装包后显示完成状态
      if (PlatformUtils.isIOS) {
        emit(state.copyWith(status: UpdateStatus.completed));
      } else {
        emit(state.copyWith(status: UpdateStatus.installing));
        emit(state.copyWith(status: UpdateStatus.completed));
      }
    } catch (e) {
      LogService.e('下载安装更新失败', e);
      emit(
        state.copyWith(
          errorMessage: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '下载安装更新失败',
          ),
          status: UpdateStatus.failed,
        ),
      );
    }
  }

  Future<void> _onOpenAppStore(
    UpdateOpenAppStore event,
    Emitter<UpdateState> emit,
  ) async {
    try {
      await _updateService.openAppStore(state.updateInfo);
    } catch (e) {
      LogService.e('打开应用商店失败', e);
      emit(
        state.copyWith(
          errorMessage: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '打开应用商店失败',
          ),
        ),
      );
    }
  }

  void _onClearError(UpdateClearError event, Emitter<UpdateState> emit) {
    emit(
      state.copyWith(
        clearError: true,
        status: state.status == UpdateStatus.failed
            ? UpdateStatus.idle
            : state.status,
      ),
    );
  }

  Future<void> _onCancel(UpdateCancel event, Emitter<UpdateState> emit) async {
    if (state.status == UpdateStatus.downloading) {
      // 上报取消下载
      if (state.updateInfo != null) {
        await _updateService.reportCancelled(state.updateInfo!);
      }
      emit(
        state.copyWith(status: UpdateStatus.cancelled, downloadProgress: null),
      );
    }
  }

  Future<void> _onSkip(UpdateSkip event, Emitter<UpdateState> emit) async {
    // 上报跳过更新
    if (state.updateInfo != null) {
      await _updateService.reportSkipped(state.updateInfo!);
    }
  }

  void _onReset(UpdateReset event, Emitter<UpdateState> emit) {
    emit(const UpdateState());
  }
}
