import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/bloc/guide_categories/guide_categories_bloc.dart';
import '../../../core/bloc/guide_editor/guide_editor_bloc.dart';
import '../../../core/bloc/guide_editor/guide_editor_event.dart';
import '../../../core/bloc/guide_editor/guide_editor_state.dart';
import '../../../core/bloc/guide_tag_suggest/guide_tag_suggest_bloc.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/models/map_contribution_models.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/desktop_navigator.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/guide/guide_status_banner.dart';
import '../../../core/widgets/guide/guide_tokens.dart';
import '../../screens/community_guide_screen.dart';
import '../guide_editor/guide_editor_content.dart';
import '../guide_editor/guide_editor_header.dart';
import '../guide_editor/guide_editor_sidebar.dart';
import 'community_guide/community_guide_theme.dart';

/// 攻略编辑器视图
///
/// 职责：
/// - 接入 [GuideEditorBloc] + [GuideTagSuggestBloc]，生命周期与本 widget 绑定
/// - 窗口关闭拦截：实现 [WindowListener]，未保存时弹「保存草稿 / 放弃 / 取消」
/// - 草稿冲突：弹「使用云端 / 保留本地」二选对话框 → emit [ResolveDraftConflict]
/// - 校验失败：sidebar 校验清单标红 + Toast 提示
/// - 发布成功：跳转「我的中心 → 已发布」并上报 `guide_publish_*` 埋点
class GuideEditorView extends StatefulWidget {
  /// 编辑已有攻略的 ID；null 表示新建流程
  final int? guideId;

  /// 从指定草稿 ID 恢复；null 时自动新建草稿
  final String? draftId;

  /// 新建时预填的关联地图名称
  final String? prefillMapName;

  const GuideEditorView({
    super.key,
    this.guideId,
    this.draftId,
    this.prefillMapName,
  });

  @override
  State<GuideEditorView> createState() => GuideEditorViewState();
}

class GuideEditorViewState extends State<GuideEditorView> with WindowListener {
  late final GuideEditorBloc _editorBloc;
  late final GuideTagSuggestBloc _tagSuggestBloc;

  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);

    final categoriesBloc = context.read<GuideCategoriesBloc>();
    _editorBloc = GuideEditorBloc(
      getCategoriesStatus: () => categoriesBloc.state.status,
      getCategoriesItems: () => categoriesBloc.state.items,
    );
    _tagSuggestBloc = GuideTagSuggestBloc();

    if (widget.guideId != null) {
      _editorBloc.add(InitFromServer(guideId: widget.guideId));
    } else {
      _editorBloc.add(InitFromDraft(draftId: widget.draftId));
    }

    // fire-and-forget：上报编辑器打开埋点
    _reportAnalytics('guide_publish_start', {
      'guideId': widget.guideId,
      'isEdit': widget.guideId != null,
      'prefillMapName': widget.prefillMapName,
    });

    // 预填地图：等 Bloc 初始化微任务完成后再写入，避免被 init 覆盖
    if (widget.prefillMapName != null) {
      Future.microtask(() {
        if (mounted) {
          _editorBloc.add(
            UpdateMap(
              MapInfo(
                mapName: widget.prefillMapName!,
                mapLabel: widget.prefillMapName!,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _editorBloc.close();
    _tagSuggestBloc.close();
    super.dispose();
  }

  // ─── WindowListener：拦截窗口关闭 ─────────────────────────────────────────

  @override
  void onWindowClose() async {
    if (_editorBloc.state.hasUnsavedChanges) {
      final action = await _showLeaveDialog();
      switch (action) {
        case _LeaveAction.saveDraft:
          _editorBloc.add(const SaveDraftRequested(manual: true));
          // 等待草稿保存请求处理后再销毁窗口
          await Future.delayed(const Duration(milliseconds: 500));
          await windowManager.destroy();
        case _LeaveAction.discard:
          await windowManager.destroy();
        case _LeaveAction.cancel:
        case null:
          break; // 用户取消，保留窗口
      }
    } else {
      await windowManager.destroy();
    }
  }

  // ─── 公共方法（供 CommunityGuideScreen 调用） ─────────────────────────────────

  /// 检查是否有未保存的更改
  bool get hasUnsavedChanges => _editorBloc.state.hasUnsavedChanges;

  /// 请求保存草稿
  void saveDraft() {
    _editorBloc.add(const SaveDraftRequested(manual: true));
  }

  // ─── 离开拦截对话框 ───────────────────────────────────────────────────────

  Future<_LeaveAction?> _showLeaveDialog() async {
    if (!mounted) return null;

    return showDialog<_LeaveAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('未保存的更改'),
          content: const Text('当前编辑器有未保存的内容，你想怎么做？'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GuideTokens.radius16),
          ),
          backgroundColor: GuideTokens.dialogBg(dialogContext),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveAction.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveAction.discard),
              style: TextButton.styleFrom(
                foregroundColor: GuideTokens.statusRejected,
              ),
              child: const Text('放弃'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveAction.saveDraft),
              child: const Text('保存草稿'),
            ),
          ],
        );
      },
    );
  }

  // ─── 草稿冲突对话框 ─────────────────────────────────────────────────────────

  Future<void> _showDraftConflictDialog() async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('草稿版本冲突'),
          content: const Text('云端有更新版本的草稿。请选择要保留的版本：'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GuideTokens.radius16),
          ),
          backgroundColor: GuideTokens.dialogBg(dialogContext),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('保留本地'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('使用云端'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      _editorBloc.add(ResolveDraftConflict(useRemote: result));
    }
  }

  // ─── 埋点 ─────────────────────────────────────────────────────────────────

  void _reportAnalytics(String event, Map<String, dynamic> params) {
    // fire-and-forget
    AnalyticsService.instance.trackEvent(event, params);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  //
  // 不再在此处包裹 PopScope：外层 [CommunityGuideScreen] 已经为编辑器视图注册了
  // 统一的 PopScope（含「未保存」提示 + `_previousView` 回退逻辑），重复包裹会
  // 导致同一次返回触发两个对话框，并且总是跳到列表而非用户来源页（如「我的」）。
  //
  // 头部返回按钮直接通过 findAncestorStateOfType 找到 CommunityGuideScreenState，
  // 调用 canLeaveCurrentView() + goBack()，绕过 Navigator.maybePop() 以避免
  // 冒泡到 DesktopHomeScreen 的 PopScope 触发退出弹窗。
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<GuideEditorBloc>.value(value: _editorBloc),
        BlocProvider<GuideTagSuggestBloc>.value(value: _tagSuggestBloc),
      ],
      child: _EditorBody(
        guideId: widget.guideId,
        onBack: () async {
          // 通过祖先 State 触发离开检查，避免直接 Navigator.maybePop()
          // 冒泡到 DesktopHomeScreen 的 PopScope 弹出「退出程序」对话框。
          final guideScreen = context
              .findAncestorStateOfType<CommunityGuideScreenState>();
          if (guideScreen != null) {
            final canLeave = await guideScreen.canLeaveCurrentView();
            if (canLeave) {
              guideScreen.goBack();
            }
          }
        },
        onPublishSuccess: () => _onPublishSuccess(),
        onConflict: () => _showDraftConflictDialog(),
        reportAnalytics: _reportAnalytics,
      ),
    );
  }

  void _onPublishSuccess() {
    // fire-and-forget：上报发布成功埋点
    _reportAnalytics('guide_publish_success', {
      'guideId': widget.guideId,
      'isEdit': widget.guideId != null,
    });

    if (mounted) {
      final msg = widget.guideId != null ? '修改成功，等待审核' : '发布成功，等待审核';
      ToastUtils.showSuccess(context, msg);
    }

    // 发布成功后跳转「我的中心」。
    // 标记 fromPublish，让「我的中心」（若仍挂载）刷新当前列表，同步后端最新数据
    // （草稿被删、已发布攻略内容 / 状态更新等），避免显示旧标题 / 摘要 / 状态。
    final navigator = DesktopNavigatorProvider.of(context);
    navigator?.openMine(fromPublish: true);
  }
}

/// 编辑器主体内容（独立 widget 以获取 BlocProvider 上下文）
class _EditorBody extends StatelessWidget {
  final int? guideId;
  final Future<void> Function() onBack;
  final VoidCallback onPublishSuccess;
  final VoidCallback onConflict;
  final void Function(String event, Map<String, dynamic> params)
  reportAnalytics;

  const _EditorBody({
    this.guideId,
    required this.onBack,
    required this.onPublishSuccess,
    required this.onConflict,
    required this.reportAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<GuideEditorBloc, GuideEditorState>(
      listener: (context, state) {
        // 草稿冲突
        if (state.phase == EditorPhase.conflict) {
          onConflict();
        }

        // 发布成功
        if (state.phase == EditorPhase.submitted) {
          onPublishSuccess();
        }

        // 发布失败
        if (state.phase == EditorPhase.error && state.error != null) {
          final prefix = guideId != null ? '修改失败：' : '发布失败：';
          ToastUtils.showError(context, '$prefix${state.error!}');
          reportAnalytics('guide_publish_fail', {'error': state.error});
        }
      },
      listenWhen: (prev, curr) => prev.phase != curr.phase,
      child: Scaffold(
        backgroundColor: CommunityGuideColors.of(context).scaffoldBg,
        body: Column(
          children: [
            // 返回 + 标题 + 保存状态文本；右上角不放按钮，避免被窗口控件遮挡
            GuideEditorHeader(onBack: () => onBack(), guideId: guideId),

            // 编辑模式状态 Banner（已发布 / 已驳回时显示）
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _EditorStatusBanner(),
            ),

            // 左 Sidebar（卡片，宽 280）+ 右编辑区（直接坐在页面底色上）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GuideEditorSidebar(),
                    const Expanded(child: GuideEditorContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 编辑模式下的状态 Banner
///
/// - 已发布攻略编辑时：显示 amber 提示「重新提交后需再次审核」
/// - 驳回攻略编辑时：显示 [GuideStatusBanner]，含驳回原因折叠展开 + 「修改后重新提交」入口
class _EditorStatusBanner extends StatelessWidget {
  const _EditorStatusBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuideEditorBloc, GuideEditorState>(
      buildWhen: (prev, curr) =>
          prev.originalGuideStatus != curr.originalGuideStatus ||
          prev.originalRejectReason != curr.originalRejectReason,
      builder: (context, state) {
        final status = state.originalGuideStatus;

        // 新建或状态为空时不显示
        if (status == null) return const SizedBox.shrink();

        if (status == GuideStatus.published) {
          return _PublishedEditBanner();
        }

        if (status == GuideStatus.rejected) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              GuideTokens.space16,
              GuideTokens.space12,
              GuideTokens.space16,
              0,
            ),
            child: GuideStatusBanner(
              status: GuideStatus.rejected,
              rejectReason: state.originalRejectReason,
              // 「修改后重新提交」触发发布流程
              onEditTap: () {
                context.read<GuideEditorBloc>().add(const PublishRequested());
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// 已发布攻略编辑时的强提示 Banner
class _PublishedEditBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: GuideTokens.space16,
        vertical: GuideTokens.space12,
      ),
      decoration: BoxDecoration(
        color: GuideTokens.statusPending.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: GuideTokens.statusPending.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: GuideTokens.statusPending,
          ),
          const SizedBox(width: GuideTokens.space8),
          Text(
            '重新提交后需再次审核',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: GuideTokens.statusPending,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 离开编辑器时的用户操作
enum _LeaveAction {
  /// 先保存草稿再离开
  saveDraft,

  /// 放弃更改直接离开
  discard,

  /// 取消，留在编辑器
  cancel,
}
