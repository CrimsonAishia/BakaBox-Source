import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../api/guide_api.dart';
import '../../utils/log_service.dart';
import 'guide_tag_suggest_event.dart';
import 'guide_tag_suggest_state.dart';

/// Suggest 事件的 debounce 时长
const _suggestDebounceDuration = Duration(milliseconds: 300);

/// debounce transformer：对 Suggest 事件做 300ms 防抖 + switchMap
EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
}

/// 标签联想 Bloc（短生命周期）
///
/// `Suggest(keyword)` → 调用后端 `suggestTags` 接口获取匹配的标签列表。
/// 内置 300ms 防抖，避免输入过程中频繁请求。
class GuideTagSuggestBloc
    extends Bloc<GuideTagSuggestEvent, GuideTagSuggestState> {
  final GuideApi _guideApi = GuideApi();

  GuideTagSuggestBloc() : super(const GuideTagSuggestState()) {
    on<Suggest>(_onSuggest, transformer: _debounce(_suggestDebounceDuration));
    on<Reset>(_onReset);
  }

  Future<void> _onSuggest(
    Suggest event,
    Emitter<GuideTagSuggestState> emit,
  ) async {
    final keyword = event.keyword.trim();
    if (keyword.isEmpty) {
      emit(state.copyWith(suggestions: []));
      return;
    }

    try {
      final suggestions = await _guideApi.suggestTags(keyword);
      emit(state.copyWith(suggestions: suggestions));
    } catch (e) {
      // 标签建议失败不阻塞用户操作，静默降级为空列表
      LogService.e('标签联想失败', e);
      emit(state.copyWith(suggestions: []));
    }
  }

  void _onReset(Reset event, Emitter<GuideTagSuggestState> emit) {
    emit(state.copyWith(suggestions: []));
  }
}
