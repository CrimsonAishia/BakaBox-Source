import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/guide_list/guide_list_bloc.dart';
import '../../core/bloc/guide_list/guide_list_event.dart';
import '../widgets/guide/community_guide/community_guide.dart';
import '../widgets/guide/guide_detail_view.dart';
import '../widgets/guide/guide_editor_view.dart';
import '../widgets/guide/guide_mine_view.dart';

/// 攻略模块内部视图枚举（list=列表、editor=编辑器、mine=我的中心）
enum _GuideView { list, editor, mine }

/// 攻略模块顶层容器，管理 list / editor / mine 三个子视图的切换。
///
/// 采用 setState 内部路由（不依赖 go_router），通过 [CommunityGuideScreenState]
/// 暴露公共方法，由 `DesktopHomeScreen` 通过 [GlobalKey] 驱动跨模块跳转。
///
/// 详情以内嵌弹窗（Stack 上层）呈现，不占用路由栈；
/// 子视图 UI 拆分到 `lib/desktop/widgets/guide/` 各子目录下。
class CommunityGuideScreen extends StatefulWidget {
  const CommunityGuideScreen({super.key});

  @override
  State<CommunityGuideScreen> createState() => CommunityGuideScreenState();
}

class CommunityGuideScreenState extends State<CommunityGuideScreen> {
  _GuideView _view = _GuideView.list;

  // 各子视图参数
  int? _editorGuideId;
  String? _editorDraftId;
  String? _editorPrefillMapName;
  String? _filterMapName;
  int? _mineInitialTab;

  /// 当前打开的详情 ID；null 表示弹窗关闭
  int? _detailId;

  /// 导航历史，用于 PopScope 回退到上一个视图
  _GuideView? _previousView;

  /// 「我的中心」是否曾被打开过。
  ///
  /// 用于决定是否把它放进 IndexedStack 渲染——只在第一次进入后才挂载，
  /// 之后即使去了编辑器再回来，也保留 mine 视图的 tab / 滚动 / 数据状态，
  /// 避免每次回来都被重置回默认 tab。
  bool _mineMounted = false;

  /// 「我的中心」widget 的 key 版本号。
  ///
  /// 大多数情况下我们希望复用挂载着的 GuideMineView 实例（保留 tab 状态）。
  /// 但当外部显式传入 [initialTab] 时（例如「从地图详情跳到我的收藏」），
  /// 需要让 mine 重新初始化以应用新的初始 tab。这时把版本号自增，等价于
  /// 给子树换一个 key，强制重建 GuideMineView。
  int _mineKeyVersion = 0;

  /// 编辑器 State 的引用键，用于调用 hasUnsavedChanges / saveDraft
  final _editorKey = GlobalKey<GuideEditorViewState>();

  /// 攻略列表 Bloc，生命周期与本 Screen 绑定
  late final GuideListBloc _guideListBloc;

  @override
  void initState() {
    super.initState();
    _guideListBloc = GuideListBloc();
    // 初次构建时 _filterMapName 必为 null（外部通过 showList(mapName:) 注入），
    // 所以这里直接拉首屏即可。带 mapName 的进入由 showList 内部分支去 add filter。
    _guideListBloc.add(const LoadGuides(reset: true));
  }

  @override
  void dispose() {
    _guideListBloc.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 公共方法（由 DesktopNavigator 通过 GlobalKey 调用）
  // ---------------------------------------------------------------------------

  /// 切换到攻略列表视图，可按地图名筛选
  void showList({String? mapName}) {
    setState(() {
      _previousView = null;
      _view = _GuideView.list;
      _filterMapName = mapName;
      // 切换主视图时，必然不再属于先前详情上下文，关闭遗留的详情弹窗
      _detailId = null;
    });
    final currentFilter = _guideListBloc.state.filter;
    if (currentFilter.mapName != mapName) {
      _guideListBloc.add(
        ChangeFilter(
          currentFilter.copyWith(
            mapName: mapName,
            clearMapName: mapName == null,
          ),
        ),
      );
    }
  }

  /// 以内嵌弹窗形式打开攻略详情（占内容区 90% 宽高）
  void showDetail(int id) {
    setState(() {
      _detailId = id;
    });
  }

  /// 关闭详情弹窗
  void closeDetail() {
    setState(() {
      _detailId = null;
    });
  }

  /// 切换到编辑器视图
  ///
  /// [guideId] 非空时为编辑已有攻略；[draftId] 非空时从草稿恢复；
  /// [prefillMapName] 用于新建时预填关联地图。
  void showEditor({int? guideId, String? draftId, String? prefillMapName}) {
    setState(() {
      _previousView = _view;
      _view = _GuideView.editor;
      _editorGuideId = guideId;
      _editorDraftId = draftId;
      _editorPrefillMapName = prefillMapName;
      // 切换主视图时关闭遗留的详情弹窗，避免悬浮于编辑器之上
      _detailId = null;
    });
  }

  /// 切换到「我的中心」视图，[initialTab] 指定默认选中的 Tab 索引
  ///
  /// 注意：mine 视图首次进入后会一直保持挂载（IndexedStack），从编辑器返回时
  /// 不会重新构造，原有的 tab / 滚动位置 / 数据缓存都会被保留。只有显式传入
  /// [initialTab] 才会强制重建以应用新的初始 tab；不传则尊重用户上一次的选择。
  void showMine({int? initialTab}) {
    final mineWasMounted = _mineMounted;
    setState(() {
      // 当来源是编辑器（即从「发布成功」自动跳转过来）时，不要把 editor 记为
      // 上一视图，否则点击「我的中心」的返回会回到一个已经发布完成的编辑器，
      // 体验混乱。统一回退到列表更符合预期。
      _previousView = _view == _GuideView.editor ? null : _view;
      _view = _GuideView.mine;
      _mineMounted = true;
      // 仅在显式指定 initialTab，或者 mine 还没挂载过（首次进入）时更新它。
      // 这样从编辑器返回时不会冲掉用户当前所在的 tab。
      if (initialTab != null || !mineWasMounted) {
        _mineInitialTab = initialTab;
      }
      // 显式指定 initialTab 时强制重建 GuideMineView，让新 tab 生效。
      // 仅是「打开我的中心」（无 initialTab）时不要重建，保留用户当前位置。
      if (initialTab != null && mineWasMounted) {
        _mineKeyVersion++;
      }
      // 切换主视图时关闭遗留的详情弹窗，避免悬浮于「我的中心」之上
      _detailId = null;
    });
  }

  /// 检查当前视图是否可以安全离开。
  ///
  /// 编辑器有未保存更改时弹对话框，返回 true 表示用户确认离开。
  Future<bool> canLeaveCurrentView() async {
    if (_view != _GuideView.editor) return true;
    final editorState = _editorKey.currentState;
    if (editorState == null || !editorState.hasUnsavedChanges) return true;
    return _showUnsavedChangesDialog();
  }

  Future<bool> _showUnsavedChangesDialog() async {
    if (!mounted) return true;
    final result = await showDialog<_UnsavedAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('当前编辑器有未保存的内容，是否要离开？'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.discard),
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedAction.saveDraft),
            child: const Text('暂存草稿'),
          ),
        ],
      ),
    );

    switch (result) {
      case _UnsavedAction.saveDraft:
        _editorKey.currentState?.saveDraft();
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      case _UnsavedAction.discard:
        return true;
      case _UnsavedAction.cancel:
      case null:
        return false;
    }
  }

  void _handlePopBack() {
    if (_view == _GuideView.list) return;
    final target = _previousView ?? _GuideView.list;
    setState(() {
      _previousView = (target == _GuideView.list) ? null : _GuideView.list;
      _view = target;
    });
  }

  /// 公共返回方法，供子视图的返回按钮直接调用。
  ///
  /// 不走 Navigator.maybePop()，避免冒泡触发 DesktopHomeScreen 的退出弹窗。
  void goBack() => _handlePopBack();

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _guideListBloc,
      child: PopScope(
        canPop: _view == _GuideView.list && _detailId == null,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          // 详情弹窗打开时优先关闭弹窗，不回退视图
          if (_detailId != null) {
            closeDetail();
            return;
          }
          if (_view == _GuideView.editor) {
            final canLeave = await canLeaveCurrentView();
            if (!canLeave) return;
          }
          _handlePopBack();
        },
        child: Stack(
          children: [
            Positioned.fill(child: _buildCurrentView()),

            // 详情弹窗（内容区内嵌，占 90% 宽高）
            if (_detailId != null) _buildDetailOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailOverlay(BuildContext context) {
    final colors = CommunityGuideColors.of(context);

    return Positioned.fill(
      child: GestureDetector(
        onTap: closeDetail,
        child: Container(
          color: colors.scrim,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // 阻止点击内容区域穿透到遮罩层关闭弹窗
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth * 0.9;
                    final height = constraints.maxHeight * 0.92;
                    return Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: colors.detailOverlayBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            // 用 detailId 作为 key，切换 ID 时强制重建子树，
                            // 避免老的 GuideDetailBloc 残留旧 id 的状态。
                            child: GuideDetailView(
                              key: ValueKey(_detailId),
                              id: _detailId!,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child:
                                CommunityGuideCloseButton(onTap: closeDetail),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    // list / mine 用 IndexedStack 保持挂载，避免 mine 在「进入编辑器 → 返回」后
    // 被重建，从而丢失 tab、筛选、滚动位置和已加载的列表数据。
    //
    // mine 在第一次进入前不需要构造（_mineMounted=false），首次 showMine()
    // 之后会一直保持。编辑器作为浮层叠加于 list/mine 之上：进入时挂载，离开
    // 时卸载销毁 GuideEditorBloc，符合每次都从头开始一段新编辑会话的预期。
    final stackIndex = _view == _GuideView.mine && _mineMounted ? 1 : 0;

    return Stack(
      children: [
        Positioned.fill(
          child: IndexedStack(
            index: stackIndex,
            children: [
              CommunityGuideListView(
                mapName: _filterMapName,
                onViewDetail: showDetail,
                onOpenMine: () => showMine(),
              ),
              if (_mineMounted)
                GuideMineView(
                  key: ValueKey('guide_mine_v$_mineKeyVersion'),
                  initialTab: _mineInitialTab,
                  onEditDraft: (draftId) => showEditor(draftId: draftId),
                  onEditGuide: (guideId) => showEditor(guideId: guideId),
                  onCreateGuide: () => showEditor(),
                  onViewDetail: showDetail,
                  // 保留进入「我的」之前列表所用的地图筛选；之前没筛选时回到全列表
                  onBack: () => showList(mapName: _filterMapName),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),

        // 编辑器叠在 list/mine 之上：active 时显示，离开时整体卸载销毁。
        if (_view == _GuideView.editor)
          Positioned.fill(
            child: GuideEditorView(
              key: _editorKey,
              guideId: _editorGuideId,
              draftId: _editorDraftId,
              prefillMapName: _editorPrefillMapName,
            ),
          ),
      ],
    );
  }
}

/// 离开编辑器时的用户操作选择
enum _UnsavedAction {
  /// 暂存草稿后离开
  saveDraft,
  /// 放弃更改直接离开
  discard,
  /// 取消，留在编辑器
  cancel,
}
