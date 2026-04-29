import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/map_tag_api.dart';
import '../../models/map_tag_models.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'map_tag_event.dart';
import 'map_tag_state.dart';

/// 地图标签 Bloc
class MapTagBloc extends Bloc<MapTagEvent, MapTagState> {
  final MapTagApi _api = MapTagApi();

  MapTagBloc() : super(const MapTagState()) {
    on<LoadTagList>(_onLoadTagList);
    on<LoadMapTagList>(_onLoadMapTagList);
    on<LoadUserTags>(_onLoadUserTags);
    on<ToggleTagVote>(_onToggleTagVote);
    on<SubmitTag>(_onSubmitTag);
    on<RefreshTagList>(_onRefreshTagList);
    on<RefreshMapTagList>(_onRefreshMapTagList);
    on<RefreshUserTags>(_onRefreshUserTags);
    on<UpdateTag>(_onUpdateTag);
    on<DeleteTag>(_onDeleteTag);
    on<CancelTagChangeRequest>(_onCancelTagChangeRequest);
    on<ClearTagError>(_onClearError);
  }

  /// 提取错误信息
  String _getErrorMessage(Object e) {
    return ErrorUtils.getErrorMessage(e);
  }

  /// 加载全局标签列表
  Future<void> _onLoadTagList(
    LoadTagList event,
    Emitter<MapTagState> emit,
  ) async {
    emit(state.copyWith(isLoadingTagList: true, clearError: true));

    try {
      final tags = await _api.getTagList();
      emit(state.copyWith(tagList: tags, isLoadingTagList: false));
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isLoadingTagList: false));
      LogService.e('加载全局标签列表失败', e);
    }
  }

  /// 加载地图的标签投票列表
  Future<void> _onLoadMapTagList(
    LoadMapTagList event,
    Emitter<MapTagState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingMapTagVotes: true,
        clearError: true,
        currentMapName: event.mapName,
      ),
    );

    try {
      final response = await _api.getMapTagList(event.mapName);
      if (response != null) {
        emit(
          state.copyWith(
            mapTagVotes: response.items,
            isLoadingMapTagVotes: false,
          ),
        );
      } else {
        emit(state.copyWith(isLoadingMapTagVotes: false));
      }
    } catch (e) {
      emit(
        state.copyWith(error: _getErrorMessage(e), isLoadingMapTagVotes: false),
      );
      LogService.e('加载地图标签投票列表失败', e);
    }
  }

  /// 加载用户自己的标签（只加载 pending + rejected）
  Future<void> _onLoadUserTags(
    LoadUserTags event,
    Emitter<MapTagState> emit,
  ) async {
    emit(state.copyWith(isLoadingUserTags: true, clearError: true));

    try {
      // 并行加载 pending 和 rejected 状态的标签，以及变更申请
      final results = await Future.wait([
        _api.getMyTags(auditStatus: 'pending'),
        _api.getMyTags(auditStatus: 'rejected'),
        _api.getMyTagChangeRequests(),
      ]);
      final pendingTags = results[0] as List<MapTag>;
      final rejectedTags = results[1] as List<MapTag>;
      final changeRequests = results[2] as List<MapTagChangeRequest>;
      // 合并并按创建时间降序排列
      final allUserTags = [...pendingTags, ...rejectedTags]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(state.copyWith(
        userTags: allUserTags,
        myChangeRequests: changeRequests,
        isLoadingUserTags: false,
      ));
    } catch (e) {
      emit(
        state.copyWith(error: _getErrorMessage(e), isLoadingUserTags: false),
      );
      LogService.e('加载用户标签列表失败', e);
    }
  }

  /// 投票/取消投票
  Future<void> _onToggleTagVote(
    ToggleTagVote event,
    Emitter<MapTagState> emit,
  ) async {
    if (state.currentMapName == null) return;

    emit(state.copyWith(isVoting: true));

    try {
      final response = await _api.voteTag(
        state.currentMapName!,
        event.tagId,
        voteType: event.voteType,
      );
      if (response != null && response.success) {
        // 更新地图标签投票列表
        final updatedVotes = List<MapTagVoteSimple>.from(state.mapTagVotes);
        final existingIndex = updatedVotes.indexWhere(
          (v) => v.tagId == event.tagId,
        );

        if (existingIndex >= 0) {
          updatedVotes[existingIndex] = response.mapTagVote;
        } else {
          updatedVotes.add(response.mapTagVote);
        }

        // 按投票数降序排列
        updatedVotes.sort((a, b) => b.voteCount.compareTo(a.voteCount));

        emit(state.copyWith(mapTagVotes: updatedVotes, isVoting: false));
      } else {
        emit(state.copyWith(isVoting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isVoting: false));
      LogService.e('投票操作失败', e);
    }
  }

  /// 更新标签
  Future<void> _onUpdateTag(UpdateTag event, Emitter<MapTagState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final success = await _api.updateTag(
        event.tagId,
        event.name,
        color: event.color,
        editReason: event.editReason,
      );
      if (success) {
        // 刷新用户标签列表
        add(const LoadUserTags());
        emit(state.copyWith(isSubmitting: false, submitSuccess: true));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('更新标签失败', e);
    }
  }

  Future<void> _onDeleteTag(DeleteTag event, Emitter<MapTagState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final success = await _api.deleteTag(event.tagId, editReason: event.editReason);
      if (success) {
        if (event.editReason != null && event.editReason!.isNotEmpty) {
          // 已通过标签走变更申请流程：刷新用户标签列表（含变更申请）以同步状态
          add(const LoadUserTags());
          emit(state.copyWith(isSubmitting: false, submitSuccess: true));
        } else {
          // 未通过标签直接删除：从用户标签列表和全局标签列表中移除
          final updatedUserTags = state.userTags
              .where((t) => t.id != event.tagId)
              .toList();
          final updatedTagList = state.tagList
              .where((t) => t.id != event.tagId)
              .toList();
          emit(
            state.copyWith(
              userTags: updatedUserTags,
              tagList: updatedTagList,
              isSubmitting: false,
              deleteSuccess: true,
            ),
          );
        }
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('删除标签失败', e);
    }
  }

  /// 撤销变更申请
  Future<void> _onCancelTagChangeRequest(CancelTagChangeRequest event, Emitter<MapTagState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final success = await _api.cancelTagChangeRequest(event.tagId);
      if (success) {
        // 刷新用户标签列表和全局标签列表（以便状态同步）
        add(const LoadUserTags());
        add(const LoadTagList());
        emit(state.copyWith(isSubmitting: false, cancelSuccess: true));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('撤销变更申请失败', e);
    }
  }

  /// 提交新标签
  Future<void> _onSubmitTag(SubmitTag event, Emitter<MapTagState> emit) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      // 仅当勾选"审核通过自动投票"时才传 mapName
      final mapName = event.autoVote ? state.currentMapName : null;
      final tag = await _api.submitTag(
        event.name,
        mapName: mapName,
        color: event.color,
      );
      if (tag != null) {
        // 将新标签添加到列表（但可能还在审核中，不显示在全局列表）
        emit(state.copyWith(isSubmitting: false, submitSuccess: true));
      } else {
        emit(state.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(state.copyWith(error: _getErrorMessage(e), isSubmitting: false));
      LogService.e('提交新标签失败', e);
    }
  }

  /// 刷新标签列表
  Future<void> _onRefreshTagList(
    RefreshTagList event,
    Emitter<MapTagState> emit,
  ) async {
    add(const LoadTagList());
  }

  /// 刷新地图标签投票列表
  Future<void> _onRefreshMapTagList(
    RefreshMapTagList event,
    Emitter<MapTagState> emit,
  ) async {
    if (state.currentMapName != null) {
      add(LoadMapTagList(mapName: state.currentMapName!));
    }
  }

  /// 刷新用户标签列表
  Future<void> _onRefreshUserTags(
    RefreshUserTags event,
    Emitter<MapTagState> emit,
  ) async {
    add(const LoadUserTags());
  }

  /// 清除错误
  void _onClearError(ClearTagError event, Emitter<MapTagState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
