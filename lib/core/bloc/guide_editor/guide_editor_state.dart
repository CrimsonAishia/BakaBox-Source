import 'package:equatable/equatable.dart';

import '../../models/guide_models.dart';

/// 编辑器阶段
enum EditorPhase {
  /// 空闲（正常编辑中）
  idle,

  /// 正在保存本地草稿
  saving,

  /// 正在保存至云端
  savingRemote,

  /// 云端草稿版本冲突
  conflict,

  /// 正在发布
  publishing,

  /// 已提交发布（成功）
  submitted,

  /// 出错
  error,
}

/// 校验错误枚举
enum EditorValidateError {
  /// 标题为空或不合法（2-60 字）
  titleRequired,

  /// 摘要为空
  summaryRequired,

  /// 分类未选择
  categoryRequired,

  /// 分类 code 不在可用列表中
  categoryInvalid,

  /// 正文 plainText 不足 50 字
  contentTooShort,

  /// 标签超过 5 个
  tagsTooMany,

  /// 图片超过 100 张
  imagesTooMany,

  /// B 站视频超过 5 个
  videosTooMany,
}

class GuideEditorState extends Equatable {
  final EditorPhase phase;
  final GuideDraft? draft;
  final DateTime? lastSavedAt;

  /// 冲突时的远端草稿
  final GuideDraft? remoteDraft;
  final List<EditorValidateError> validateErrors;

  /// canPublish = (categoriesBlocStatus == success) && validateErrors.isEmpty
  final bool canPublish;
  final String? error;

  /// 自上次成功保存后是否有新的内容变更
  final bool dirty;

  /// 正文纯文本字数（由编辑器直接传入，避免 Bloc 重新解析 Delta）
  final int contentPlainTextLength;

  /// 编辑模式下，原始攻略的状态（用于显示编辑模式 Banner）
  /// - published：显示「重新提交后需再次审核」
  /// - rejected：显示驳回 StatusBanner + 驳回理由
  final GuideStatus? originalGuideStatus;

  /// 编辑模式下，原始攻略的驳回理由（rejected 时使用）
  final String? originalRejectReason;

  const GuideEditorState({
    this.phase = EditorPhase.idle,
    this.draft,
    this.lastSavedAt,
    this.remoteDraft,
    this.validateErrors = const [],
    this.canPublish = false,
    this.dirty = false,
    this.contentPlainTextLength = 0,
    this.error,
    this.originalGuideStatus,
    this.originalRejectReason,
  });

  /// 是否有未保存的改动（用于 Host 的 canLeaveCurrentView 检查）
  bool get hasUnsavedChanges {
    if (draft == null) return false;

    // 判断是否有实质内容（标题、正文、封面、摘要任一非空）
    final hasContent =
        (draft!.title?.isNotEmpty ?? false) ||
        (draft!.content?.isNotEmpty ?? false) ||
        (draft!.coverUrl?.isNotEmpty ?? false) ||
        (draft!.summary?.isNotEmpty ?? false);

    // 无实质内容 → 不需要保存，直接放行
    if (!hasContent) return false;

    // 如果从未保存过，有内容就算未保存
    if (lastSavedAt == null) return true;

    // 已保存过：通过 dirty 标记判断保存后是否有新变更
    return dirty;
  }

  GuideEditorState copyWith({
    EditorPhase? phase,
    GuideDraft? draft,
    DateTime? lastSavedAt,
    bool clearLastSavedAt = false,
    GuideDraft? remoteDraft,
    bool clearRemoteDraft = false,
    List<EditorValidateError>? validateErrors,
    bool? canPublish,
    bool? dirty,
    int? contentPlainTextLength,
    String? error,
    bool clearError = false,
    GuideStatus? originalGuideStatus,
    String? originalRejectReason,
    bool clearOriginalGuideInfo = false,
  }) {
    return GuideEditorState(
      phase: phase ?? this.phase,
      draft: draft ?? this.draft,
      lastSavedAt: clearLastSavedAt ? null : (lastSavedAt ?? this.lastSavedAt),
      remoteDraft: clearRemoteDraft ? null : (remoteDraft ?? this.remoteDraft),
      validateErrors: validateErrors ?? this.validateErrors,
      canPublish: canPublish ?? this.canPublish,
      dirty: dirty ?? this.dirty,
      contentPlainTextLength:
          contentPlainTextLength ?? this.contentPlainTextLength,
      error: clearError ? null : (error ?? this.error),
      originalGuideStatus: clearOriginalGuideInfo
          ? null
          : (originalGuideStatus ?? this.originalGuideStatus),
      originalRejectReason: clearOriginalGuideInfo
          ? null
          : (originalRejectReason ?? this.originalRejectReason),
    );
  }

  @override
  List<Object?> get props => [
    phase,
    draft,
    lastSavedAt,
    remoteDraft,
    validateErrors,
    canPublish,
    dirty,
    contentPlainTextLength,
    error,
    originalGuideStatus,
    originalRejectReason,
  ];
}
