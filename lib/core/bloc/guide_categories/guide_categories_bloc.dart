import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api.dart';
import '../../api/guide_api.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import 'guide_categories_event.dart';
import 'guide_categories_state.dart';

/// 攻略分类全局 Bloc
///
/// 30 分钟内存缓存；接口失败 emit failure，不填充任何写死本地分类。
/// 列表页 / 编辑器 / 我的中心通过 BlocProvider.value 共享。
class GuideCategoriesBloc
    extends Bloc<GuideCategoriesEvent, GuideCategoriesState> {
  final GuideApi _guideApi = GuideApi();

  /// 缓存有效期：30 分钟
  static const Duration _cacheDuration = Duration(minutes: 30);

  GuideCategoriesBloc() : super(const GuideCategoriesState()) {
    on<LoadCategories>(_onLoadCategories);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<GuideCategoriesState> emit,
  ) async {
    // 缓存检查：30 分钟内且非强制刷新，跳过
    if (!event.force && _isCacheValid()) {
      return;
    }

    // 防止重复请求：已在加载中且非强制刷新，跳过
    if (!event.force && state.status == CategoriesStatus.loading) {
      return;
    }

    emit(state.copyWith(status: CategoriesStatus.loading, clearError: true));

    try {
      final categories = await _guideApi.getCategories();
      emit(state.copyWith(
        status: CategoriesStatus.success,
        items: categories,
        lastFetchedAt: DateTime.now(),
      ));
    } catch (e) {
      final errorMessage = e is ApiException
          ? e.message
          : ErrorUtils.getErrorMessage(e);
      emit(state.copyWith(
        status: CategoriesStatus.failure,
        error: errorMessage,
      ));
      LogService.e('获取攻略分类失败', e);
    }
  }

  /// 判断缓存是否仍有效（30 分钟内）
  bool _isCacheValid() {
    final lastFetched = state.lastFetchedAt;
    if (lastFetched == null) return false;
    return DateTime.now().difference(lastFetched) < _cacheDuration;
  }
}
