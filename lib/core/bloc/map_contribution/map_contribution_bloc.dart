import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/api.dart';
import '../../api/map_contribution_api.dart';
import '../../models/map_contribution_models.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'map_contribution_event.dart';
import 'map_contribution_state.dart';

/// 地图贡献 Bloc
/// 
/// 分别管理名称贡献和背景贡献两个独立列表
/// 支持加载、提交、投票操作
/// 贡献一旦提交无法删除（Requirements 6.1, 6.2）
class MapContributionBloc
    extends Bloc<MapContributionEvent, MapContributionState> {
  final MapContributionApi _api = MapContributionApi();

  MapContributionBloc() : super(const MapContributionState()) {
    on<LoadNameContributions>(_onLoadNameContributions);
    on<LoadBackgroundContributions>(_onLoadBackgroundContributions);
    on<LoadAllContributions>(_onLoadAllContributions);
    on<SubmitNameContribution>(_onSubmitNameContribution);
    on<SubmitBackgroundContribution>(_onSubmitBackgroundContribution);
    on<UpdateNameContribution>(_onUpdateNameContribution);
    on<UpdateBackgroundContribution>(_onUpdateBackgroundContribution);
    on<ToggleVote>(_onToggleVote);
    on<RefreshNameContributions>(_onRefreshNameContributions);
    on<RefreshBackgroundContributions>(_onRefreshBackgroundContributions);
    on<ClearContributionError>(_onClearError);
    on<ResetContributionState>(_onReset);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  /// 对贡献列表排序：按票数降序，相同票数按时间升序
  /// Requirements 4.1, 4.3
  List<MapContribution> _sortContributions(List<MapContribution> contributions) {
    final sorted = List<MapContribution>.from(contributions);
    sorted.sort((a, b) {
      final voteCompare = b.voteCount.compareTo(a.voteCount);
      if (voteCompare != 0) return voteCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  /// 加载名称贡献列表
  /// Requirements 1.1, 5.1
  Future<void> _onLoadNameContributions(
    LoadNameContributions event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingNames: true,
      clearError: true,
      currentMapName: event.mapName,
    ));

    try {
      final contributions = await _api.getNameContributions(event.mapName);
      emit(state.copyWith(
        nameContributions: _sortContributions(contributions),
        isLoadingNames: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoadingNames: false));
      LogService.e('加载名称贡献列表失败', e);
    }
  }

  /// 加载背景贡献列表
  /// Requirements 2.1, 5.1
  Future<void> _onLoadBackgroundContributions(
    LoadBackgroundContributions event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingBackgrounds: true,
      clearError: true,
      currentMapName: event.mapName,
    ));

    try {
      final contributions = await _api.getBackgroundContributions(event.mapName);
      emit(state.copyWith(
        backgroundContributions: _sortContributions(contributions),
        isLoadingBackgrounds: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoadingBackgrounds: false));
      LogService.e('加载背景贡献列表失败', e);
    }
  }

  /// 加载所有贡献（名称和背景）
  Future<void> _onLoadAllContributions(
    LoadAllContributions event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingNames: true,
      isLoadingBackgrounds: true,
      clearError: true,
      currentMapName: event.mapName,
    ));

    try {
      final nameContributions = await _api.getNameContributions(event.mapName);
      final backgroundContributions = await _api.getBackgroundContributions(event.mapName);
      
      emit(state.copyWith(
        nameContributions: _sortContributions(nameContributions),
        backgroundContributions: _sortContributions(backgroundContributions),
        isLoadingNames: false,
        isLoadingBackgrounds: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: _getErrorMessage(e),
        isLoadingNames: false,
        isLoadingBackgrounds: false,
      ));
      LogService.e('加载贡献列表失败', e);
    }
  }

  /// 提交名称贡献
  /// Requirements 1.1, 1.2, 1.3, 1.4
  Future<void> _onSubmitNameContribution(
    SubmitNameContribution event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final contribution = await _api.submitNameContribution(
        event.mapName,
        event.name,
      );
      if (contribution != null) {
        final updatedList = [...state.nameContributions, contribution];
        emit(state.copyWith(
          nameContributions: _sortContributions(updatedList),
          isSubmitting: false,
          submitSuccess: true,
        ));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('提交名称贡献失败', e);
    }
  }

  /// 提交背景贡献
  /// Requirements 2.1, 2.2, 2.3, 2.4
  Future<void> _onSubmitBackgroundContribution(
    SubmitBackgroundContribution event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final contribution = await _api.submitBackgroundContribution(
        event.mapName,
        event.fileId,
      );
      if (contribution != null) {
        final updatedList = [...state.backgroundContributions, contribution];
        emit(state.copyWith(
          backgroundContributions: _sortContributions(updatedList),
          isSubmitting: false,
          submitSuccess: true,
        ));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('提交背景贡献失败', e);
    }
  }

  /// 更新名称贡献（仅审核失败的可修改）
  Future<void> _onUpdateNameContribution(
    UpdateNameContribution event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final contribution = await _api.updateNameContribution(event.id, event.name);
      if (contribution != null) {
        // 更新列表中的贡献
        final updatedList = state.nameContributions.map((c) {
          if (c.id == event.id) return contribution;
          return c;
        }).toList();
        emit(state.copyWith(
          nameContributions: _sortContributions(updatedList),
          isSubmitting: false,
          submitSuccess: true,
        ));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('更新名称贡献失败', e);
    }
  }

  /// 更新背景贡献（仅审核失败的可修改）
  Future<void> _onUpdateBackgroundContribution(
    UpdateBackgroundContribution event,
    Emitter<MapContributionState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final contribution = await _api.updateBackgroundContribution(event.id, event.fileId);
      if (contribution != null) {
        // 更新列表中的贡献
        final updatedList = state.backgroundContributions.map((c) {
          if (c.id == event.id) return contribution;
          return c;
        }).toList();
        emit(state.copyWith(
          backgroundContributions: _sortContributions(updatedList),
          isSubmitting: false,
          submitSuccess: true,
        ));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('更新背景贡献失败', e);
    }
  }

  /// 投票/取消投票
  /// Requirements 3.1, 3.2, 3.3, 3.4
  Future<void> _onToggleVote(
    ToggleVote event,
    Emitter<MapContributionState> emit,
  ) async {
    try {
      final response = await _api.toggleVote(event.contributionId, event.voteType);
      if (response != null && response.success) {
        // 更新名称贡献列表中的投票状态
        final updatedNames = state.nameContributions.map((c) {
          if (c.id == event.contributionId) {
            return c.copyWith(
              voteCount: response.newVoteCount,
              upCount: response.upCount,
              downCount: response.downCount,
              hasVoted: response.hasVoted,
              voteType: response.voteType,
              clearVoteType: response.voteType == null,
            );
          }
          return c;
        }).toList();

        // 更新背景贡献列表中的投票状态
        final updatedBackgrounds = state.backgroundContributions.map((c) {
          if (c.id == event.contributionId) {
            return c.copyWith(
              voteCount: response.newVoteCount,
              upCount: response.upCount,
              downCount: response.downCount,
              hasVoted: response.hasVoted,
              voteType: response.voteType,
              clearVoteType: response.voteType == null,
            );
          }
          return c;
        }).toList();

        emit(state.copyWith(
          nameContributions: _sortContributions(updatedNames),
          backgroundContributions: _sortContributions(updatedBackgrounds),
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e)));
      LogService.e('投票操作失败', e);
    }
  }

  /// 刷新名称贡献列表
  Future<void> _onRefreshNameContributions(
    RefreshNameContributions event,
    Emitter<MapContributionState> emit,
  ) async {
    if (state.currentMapName != null) {
      add(LoadNameContributions(mapName: state.currentMapName!));
    }
  }

  /// 刷新背景贡献列表
  Future<void> _onRefreshBackgroundContributions(
    RefreshBackgroundContributions event,
    Emitter<MapContributionState> emit,
  ) async {
    if (state.currentMapName != null) {
      add(LoadBackgroundContributions(mapName: state.currentMapName!));
    }
  }

  /// 清除错误
  void _onClearError(
    ClearContributionError event,
    Emitter<MapContributionState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  /// 重置状态
  void _onReset(
    ResetContributionState event,
    Emitter<MapContributionState> emit,
  ) {
    emit(const MapContributionState());
  }
}
