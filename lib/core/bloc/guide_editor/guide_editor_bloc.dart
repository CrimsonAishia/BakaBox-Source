import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../api/api.dart';
import '../../api/guide_api.dart';
import '../../models/guide_models.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import '../guide_categories/guide_categories_state.dart';
import 'guide_editor_event.dart';
import 'guide_editor_state.dart';

/// 攻略编辑器 Bloc
///
/// 职责：
/// - 管理草稿编辑状态
/// - 防抖 3s 本地保存 + 30s 周期云端保存
/// - 409 冲突处理
/// - 发布前校验（category 必选、与 GuideCategoriesBloc 可用列表对比）
/// - canPublish 计算：categoriesBloc 为 success 且 validateErrors 为空
class GuideEditorBloc extends Bloc<GuideEditorEvent, GuideEditorState> {
  final GuideApi _guideApi = GuideApi();

  /// 外部注入的分类状态获取回调
  ///
  /// 编辑器 Bloc 不直接持有 GuideCategoriesBloc 引用，通过回调解耦依赖。
  final CategoriesStatus Function() getCategoriesStatus;
  final List<GuideCategoryDef> Function() getCategoriesItems;

  /// 内容防抖计时器（3 秒后触发本地保存）
  Timer? _contentDebounceTimer;

  /// 云端周期保存计时器（30 秒）
  Timer? _remoteSaveTimer;

  /// 用于标记是否有待保存的本地变更（自上次云端保存后）
  bool _hasPendingRemoteChanges = false;

  /// 防抖时长：内容变更后 3 秒本地保存
  static const Duration _contentDebounceDuration = Duration(seconds: 3);

  /// 周期云端保存间隔：30 秒
  static const Duration _remoteSaveInterval = Duration(seconds: 30);

  /// 正文图片数量上限（与编辑器 UI 的 maxImages 保持一致）
  static const int maxImages = 100;

  GuideEditorBloc({
    required this.getCategoriesStatus,
    required this.getCategoriesItems,
  }) : super(const GuideEditorState()) {
    on<InitFromDraft>(_onInitFromDraft);
    on<InitFromServer>(_onInitFromServer);
    on<UpdateTitle>(_onUpdateTitle);
    on<UpdateCover>(_onUpdateCover);
    on<UpdateSummary>(_onUpdateSummary);
    on<UpdateContent>(_onUpdateContent);
    on<UpdateCategory>(_onUpdateCategory);
    on<UpdateTags>(_onUpdateTags);
    on<UpdateMap>(_onUpdateMap);
    on<InsertBilibiliEmbed>(_onInsertBilibiliEmbed);
    on<SaveDraftRequested>(_onSaveDraftRequested);
    on<PublishRequested>(_onPublishRequested);
    on<LeaveRequested>(_onLeaveRequested);
    on<ResolveDraftConflict>(_onResolveDraftConflict);
  }

  // ─── 辅助方法 ─────────────────────────────────────────────────────────────

  String _getErrorMessage(Object e) {
    if (e is ApiException) return e.message;
    return ErrorUtils.getErrorMessage(e);
  }

  /// 计算 canPublish：分类接口成功 且 validateErrors 为空
  bool _computeCanPublish(List<EditorValidateError> errors) {
    return getCategoriesStatus() == CategoriesStatus.success &&
        errors.isEmpty;
  }

  /// 启动 30s 周期云端保存定时器
  void _startRemoteSaveTimer() {
    _remoteSaveTimer?.cancel();
    _remoteSaveTimer = Timer.periodic(_remoteSaveInterval, (_) {
      if (_hasPendingRemoteChanges && !isClosed) {
        add(const SaveDraftRequested(manual: false));
      }
    });
  }

  /// 更新草稿字段并 emit
  void _emitDraftUpdate(Emitter<GuideEditorState> emit, GuideDraft newDraft) {
    _hasPendingRemoteChanges = true;
    // 首次内容变更时启动周期保存定时器
    if (_remoteSaveTimer == null || !_remoteSaveTimer!.isActive) {
      _startRemoteSaveTimer();
    }
    final errors = _validateDraft(newDraft);
    emit(state.copyWith(
      draft: newDraft,
      validateErrors: errors,
      canPublish: _computeCanPublish(errors),
      dirty: true,
      clearError: true,
    ));
  }

  /// 执行发布前校验
  List<EditorValidateError> _validateDraft(GuideDraft? draft, {int? contentPlainTextLength}) {
    if (draft == null) return [EditorValidateError.titleRequired];

    final errors = <EditorValidateError>[];

    // 标题必填（2-60 字）
    final title = draft.title ?? '';
    if (title.length < 2 || title.length > 60) {
      errors.add(EditorValidateError.titleRequired);
    }

    // 分类必选
    if (draft.category == null || draft.category!.isEmpty) {
      errors.add(EditorValidateError.categoryRequired);
    } else {
      // 校验分类 code 是否在可用列表中
      final availableCodes =
          getCategoriesItems().map((c) => c.code).toSet();
      if (availableCodes.isNotEmpty &&
          !availableCodes.contains(draft.category)) {
        errors.add(EditorValidateError.categoryInvalid);
      }
    }

    // 正文 plainText ≥ 50 字
    // 优先使用编辑器直接传入的字数，回退到自行解析
    final textLength = contentPlainTextLength ?? state.contentPlainTextLength;
    if (textLength < 50) {
      errors.add(EditorValidateError.contentTooShort);
    }

    // 标签 ≤ 5
    if (draft.tags.length > 5) {
      errors.add(EditorValidateError.tagsTooMany);
    }

    // 图片 ≤ maxImages（从 content 中提取图片节点数）
    final content = draft.content ?? '';
    if (_countImages(content) > maxImages) {
      errors.add(EditorValidateError.imagesTooMany);
    }

    // B 站视频 ≤ 5
    if (draft.videoEmbeds.length > 5) {
      errors.add(EditorValidateError.videosTooMany);
    }

    return errors;
  }

  /// 统计 content 中的 resizableImage 嵌入节点数量
  ///
  /// 优先解析 Delta JSON 精确计数，解码失败时回退正则匹配。
  int _countImages(String content) {
    if (content.isEmpty) return 0;

      // 解析 Delta JSON，精确统计 resizableImage 节点；失败则 fallback 到正则
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        int count = 0;
        for (final op in decoded) {
          if (op is Map &&
              op['insert'] is Map &&
              (op['insert'] as Map).containsKey('resizableImage')) {
            count++;
          }
        }
        return count;
      }
    } catch (_) {
      // Delta JSON 解码失败，回退到正则匹配
    }
    return RegExp(r'"resizableImage"').allMatches(content).length;
  }

  /// 从正文 Delta JSON 中提取纯文本前 100 字作为摘要
  String? _extractSummaryFromContent(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final op in decoded) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert'] as String);
            if (buffer.length >= 100) break;
          }
        }
        final text = buffer.toString().trim().replaceAll(RegExp(r'\n+'), ' ');
        if (text.isEmpty) return null;
        return text.length > 100 ? '${text.substring(0, 100)}...' : text;
      }
    } catch (_) {}
    // 非 Delta JSON，直接截取
    final plain = content.replaceAll(RegExp(r'[{}\[\]":]'), ' ').trim();
    if (plain.isEmpty) return null;
    return plain.length > 100 ? '${plain.substring(0, 100)}...' : plain;
  }

  /// 计算正文 Delta JSON 的纯文本字数
  int _calcContentPlainTextLength(String? content) {
    if (content == null || content.isEmpty) return 0;
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final op in decoded) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert'] as String);
          }
        }
        return buffer.toString().trim().length;
      }
    } catch (_) {}
    return 0;
  }

  // ─── 事件处理 ─────────────────────────────────────────────────────────────

  Future<void> _onInitFromDraft(
    InitFromDraft event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draftId = event.draftId;

    // 有 draftId → 从服务端恢复已有草稿
    if (draftId != null) {
      emit(state.copyWith(phase: EditorPhase.saving, clearError: true));

      try {
        final remoteDraft = await _guideApi.getDraftDetail(draftId);
        if (remoteDraft != null) {
          final plainTextLen = _calcContentPlainTextLength(remoteDraft.content);
          final errors = _validateDraft(remoteDraft, contentPlainTextLength: plainTextLen);
          emit(state.copyWith(
            phase: EditorPhase.idle,
            draft: remoteDraft,
            lastSavedAt: remoteDraft.updatedAt ?? DateTime.now(),
            validateErrors: errors,
            canPublish: _computeCanPublish(errors),
            contentPlainTextLength: plainTextLen,
            clearRemoteDraft: true,
            clearError: true,
          ));
          _startRemoteSaveTimer();
          return;
        }
      } catch (e) {
        // 获取失败时降级为创建新草稿
        LogService.e('获取草稿详情失败，创建新草稿', e);
      }
    }

    // 无 draftId 或获取失败 → 创建新草稿
    final newDraftId = draftId ?? const Uuid().v4();
    final draft = GuideDraft(
      draftId: newDraftId,
      version: 1,
    );

    emit(state.copyWith(
      phase: EditorPhase.idle,
      draft: draft,
      validateErrors: _validateDraft(draft),
      canPublish: false,
      clearError: true,
      clearRemoteDraft: true,
    ));

    // 新建空草稿时不启动定时器，等首次内容变更再启动
  }

  Future<void> _onInitFromServer(
    InitFromServer event,
    Emitter<GuideEditorState> emit,
  ) async {
    if (event.guideId == null) {
      // 无 guideId 等同于新建
      add(const InitFromDraft());
      return;
    }

    emit(state.copyWith(phase: EditorPhase.saving, clearError: true));

    try {
      final guide = await _guideApi.getGuideDetail(event.guideId!);
      if (guide == null) {
        emit(state.copyWith(
          phase: EditorPhase.error,
          error: '攻略不存在',
        ));
        return;
      }

      // 将 Guide 转为 GuideDraft 用于编辑
      final draft = GuideDraft(
        draftId: const Uuid().v4(),
        guideId: guide.id,
        title: guide.title,
        coverUrl: guide.coverUrl,
        category: guide.category,
        tags: guide.tags,
        mapName: guide.mapName,
        summary: guide.summary,
        content: guide.content,
        videoEmbeds: guide.videoEmbeds,
        version: guide.version,
        updatedAt: guide.updatedAt,
      );

      final plainTextLen = _calcContentPlainTextLength(draft.content);
      final errorsWithContent = _validateDraft(draft, contentPlainTextLength: plainTextLen);
      emit(state.copyWith(
        phase: EditorPhase.idle,
        draft: draft,
        lastSavedAt: guide.updatedAt,
        validateErrors: errorsWithContent,
        canPublish: _computeCanPublish(errorsWithContent),
        contentPlainTextLength: plainTextLen,
        clearRemoteDraft: true,
        originalGuideStatus: guide.status,
        originalRejectReason: guide.rejectReason,
      ));

      _startRemoteSaveTimer();
    } catch (e) {
      emit(state.copyWith(
        phase: EditorPhase.error,
        error: _getErrorMessage(e),
      ));
      LogService.e('从服务端初始化编辑器失败', e);
    }
  }

  Future<void> _onUpdateTitle(
    UpdateTitle event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: event.title,
      coverUrl: draft.coverUrl,
      category: draft.category,
      tags: draft.tags,
      mapName: draft.mapName,
      summary: draft.summary,
      content: draft.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onUpdateCover(
    UpdateCover event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: event.coverUrl,
      category: draft.category,
      tags: draft.tags,
      mapName: draft.mapName,
      summary: draft.summary,
      content: draft.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onUpdateSummary(
    UpdateSummary event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: draft.coverUrl,
      category: draft.category,
      tags: draft.tags,
      mapName: draft.mapName,
      summary: event.summary,
      content: draft.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onUpdateContent(
    UpdateContent event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: draft.coverUrl,
      category: draft.category,
      tags: draft.tags,
      mapName: draft.mapName,
      summary: draft.summary,
      content: event.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );

    _hasPendingRemoteChanges = true;
    if (_remoteSaveTimer == null || !_remoteSaveTimer!.isActive) {
      _startRemoteSaveTimer();
    }
    final errors = _validateDraft(newDraft, contentPlainTextLength: event.plainTextLength);
    emit(state.copyWith(
      draft: newDraft,
      validateErrors: errors,
      canPublish: _computeCanPublish(errors),
      dirty: true,
      contentPlainTextLength: event.plainTextLength,
      clearError: true,
    ));

    // 防抖 3s 后自动触发本地保存
    _contentDebounceTimer?.cancel();
    _contentDebounceTimer = Timer(_contentDebounceDuration, () {
      if (!isClosed) {
        add(const SaveDraftRequested(manual: false));
      }
    });
  }

  Future<void> _onUpdateCategory(
    UpdateCategory event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: draft.coverUrl,
      category: event.code,
      tags: draft.tags,
      mapName: draft.mapName,
      summary: draft.summary,
      content: draft.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onUpdateTags(
    UpdateTags event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: draft.coverUrl,
      category: draft.category,
      tags: event.tags,
      mapName: draft.mapName,
      summary: draft.summary,
      content: draft.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onUpdateMap(
    UpdateMap event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: draft.coverUrl,
      category: draft.category,
      tags: draft.tags,
      mapName: event.mapInfo?.mapName,
      summary: draft.summary,
      content: draft.content,
      videoEmbeds: draft.videoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onInsertBilibiliEmbed(
    InsertBilibiliEmbed event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    final newVideoEmbeds = [...draft.videoEmbeds, event.videoEmbed];
    final newDraft = GuideDraft(
      draftId: draft.draftId,
      guideId: draft.guideId,
      title: draft.title,
      coverUrl: draft.coverUrl,
      category: draft.category,
      tags: draft.tags,
      mapName: draft.mapName,
      summary: draft.summary,
      content: draft.content,
      videoEmbeds: newVideoEmbeds,
      version: draft.version,
      updatedAt: draft.updatedAt,
    );
    _emitDraftUpdate(emit, newDraft);
  }

  Future<void> _onSaveDraftRequested(
    SaveDraftRequested event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    // 如果已在冲突或发布中，跳过保存
    if (state.phase == EditorPhase.conflict ||
        state.phase == EditorPhase.publishing ||
        state.phase == EditorPhase.submitted) {
      return;
    }

    // 草稿没有实质内容时不触发云端保存（避免生成大量空草稿）
    final hasContent = (draft.title?.isNotEmpty ?? false) ||
        (draft.content?.isNotEmpty ?? false) ||
        (draft.coverUrl?.isNotEmpty ?? false) ||
        (draft.summary?.isNotEmpty ?? false);
    if (!hasContent) {
      _hasPendingRemoteChanges = false;
      return;
    }

    emit(state.copyWith(phase: EditorPhase.savingRemote, clearError: true));

    try {
      final response = await _guideApi.saveDraft(draft);

      if (response is DraftSaveSuccess) {
        // 保存成功 → 更新 version 和 lastSavedAt
        final updatedDraft = GuideDraft(
          draftId: response.draftId,
          guideId: draft.guideId,
          title: draft.title,
          coverUrl: draft.coverUrl,
          category: draft.category,
          tags: draft.tags,
          mapName: draft.mapName,
          summary: draft.summary,
          content: draft.content,
          videoEmbeds: draft.videoEmbeds,
          version: response.version,
          updatedAt: response.updatedAt ?? DateTime.now(),
        );

        _hasPendingRemoteChanges = false;
        emit(state.copyWith(
          phase: EditorPhase.idle,
          draft: updatedDraft,
          lastSavedAt: DateTime.now(),
          dirty: false,
        ));
      } else if (response is DraftSaveConflict) {
        // 409 冲突 → 进入 conflict 状态
        emit(state.copyWith(
          phase: EditorPhase.conflict,
          remoteDraft: response.remote,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        phase: EditorPhase.error,
        error: _getErrorMessage(e),
      ));
      LogService.e('保存草稿失败', e);
    }
  }

  Future<void> _onPublishRequested(
    PublishRequested event,
    Emitter<GuideEditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null) return;

    // 执行完整校验
    final errors = _validateDraft(draft);

    // 额外校验：分类接口是否成功
    if (getCategoriesStatus() != CategoriesStatus.success) {
      emit(state.copyWith(
        validateErrors: [...errors, EditorValidateError.categoryRequired],
        canPublish: false,
        error: '分类加载失败，无法发布',
      ));
      return;
    }

    if (errors.isNotEmpty) {
      emit(state.copyWith(
        validateErrors: errors,
        canPublish: false,
      ));
      return;
    }

    // 校验通过，开始发布
    emit(state.copyWith(
      phase: EditorPhase.publishing,
      validateErrors: const [],
      clearError: true,
    ));

    // 如果 summary 为空，自动从正文提取前 100 字
    final effectiveSummary = (draft.summary?.trim().isNotEmpty ?? false)
        ? draft.summary
        : _extractSummaryFromContent(draft.content);

    try {
      // 先创建或更新攻略
      if (draft.guideId != null && draft.guideId! > 0) {
        // 编辑已有攻略
        await _guideApi.updateGuide(
          draft.guideId!,
          UpdateGuideRequest(
            title: draft.title,
            summary: effectiveSummary,
            coverUrl: draft.coverUrl,
            category: draft.category,
            tags: draft.tags,
            mapName: draft.mapName,
            content: draft.content,
            videoEmbeds:
                draft.videoEmbeds.map((e) => e.toJson()).toList(),
          ),
        );
        await _guideApi.publishGuide(draft.guideId!);
      } else {
        // 新建攻略并发布
        final guide = await _guideApi.createGuide(
          CreateGuideRequest(
            title: draft.title ?? '',
            summary: effectiveSummary,
            coverUrl: draft.coverUrl,
            category: draft.category,
            tags: draft.tags,
            mapName: draft.mapName,
            content: draft.content,
            videoEmbeds:
                draft.videoEmbeds.map((e) => e.toJson()).toList(),
          ),
        );
        if (guide == null) {
          emit(state.copyWith(
            phase: EditorPhase.error,
            error: '创建攻略失败，请重试',
          ));
          return;
        }
        await _guideApi.publishGuide(guide.id);
      }

      _hasPendingRemoteChanges = false;
      _contentDebounceTimer?.cancel();
      _remoteSaveTimer?.cancel();

      // 发布成功后删除对应草稿
      try {
        await _guideApi.deleteDraft(draft.draftId);
      } catch (_) {
        // 草稿删除失败不影响发布结果
      }

      emit(state.copyWith(
        phase: EditorPhase.submitted,
        dirty: false,
        lastSavedAt: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(
        phase: EditorPhase.error,
        error: _getErrorMessage(e),
      ));
      LogService.e('发布攻略失败', e);
    }
  }

  Future<void> _onLeaveRequested(
    LeaveRequested event,
    Emitter<GuideEditorState> emit,
  ) async {
    // 如果有待保存内容，UI 层应拦截并弹对话框
    // Bloc 本身不做阻止，只提供 hasUnsavedChanges 给 UI 判断
  }

  Future<void> _onResolveDraftConflict(
    ResolveDraftConflict event,
    Emitter<GuideEditorState> emit,
  ) async {
    if (event.useRemote) {
      // 使用云端版本覆盖本地
      final remoteDraft = state.remoteDraft;
      if (remoteDraft == null) return;

      final errors = _validateDraft(remoteDraft);
      emit(state.copyWith(
        phase: EditorPhase.idle,
        draft: remoteDraft,
        lastSavedAt: DateTime.now(),
        validateErrors: errors,
        canPublish: _computeCanPublish(errors),
        clearRemoteDraft: true,
        clearError: true,
        dirty: false,
      ));
      _hasPendingRemoteChanges = false;
    } else {
      // 保留本地版本，以远端 version 强制覆盖云端
      final draft = state.draft;
      final remoteDraft = state.remoteDraft;
      if (draft == null || remoteDraft == null) return;

      // 使用远端的 version 重新提交
      final forceDraft = GuideDraft(
        draftId: draft.draftId,
        guideId: draft.guideId,
        title: draft.title,
        coverUrl: draft.coverUrl,
        category: draft.category,
        tags: draft.tags,
        mapName: draft.mapName,
        summary: draft.summary,
        content: draft.content,
        videoEmbeds: draft.videoEmbeds,
        version: remoteDraft.version,
        updatedAt: draft.updatedAt,
      );

      emit(state.copyWith(
        phase: EditorPhase.idle,
        draft: forceDraft,
        clearRemoteDraft: true,
        clearError: true,
      ));

      _hasPendingRemoteChanges = true;
      // 立即触发一次云端保存
      add(const SaveDraftRequested(manual: true));
    }
  }

  // ─── 生命周期 ─────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _contentDebounceTimer?.cancel();
    _remoteSaveTimer?.cancel();
    return super.close();
  }
}
