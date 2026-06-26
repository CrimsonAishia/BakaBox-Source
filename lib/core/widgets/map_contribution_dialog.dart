import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_portal/flutter_portal.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/map_contribution/map_contribution_bloc.dart';
import '../bloc/map_contribution/map_contribution_event.dart';
import '../bloc/map_contribution/map_contribution_state.dart';
import '../bloc/map_tag/map_tag_bloc.dart';
import '../bloc/map_tag/map_tag_event.dart';
import '../bloc/map_tag/map_tag_state.dart';
import '../api/map_tag_api.dart';
import '../constants/credit_constants.dart';
import '../models/map_contribution_models.dart';
import '../models/map_tag_models.dart';
import '../models/report_models.dart';
import '../utils/contribution_validation_utils.dart';
import '../utils/log_service.dart';

import '../utils/toast_utils.dart';
import '../services/file_upload_service.dart';
import '../services/image_url_service.dart';
import '../services/token_service.dart';
import 'disk_cached_image.dart';
import 'tag_color_picker.dart';
import 'common_report_dialog.dart';
import '../../desktop/widgets/login_dialog.dart';
import '../constants/app_colors.dart';

part 'map_contribution/contribution_image_widgets.dart';
part 'map_contribution/map_tag_chip.dart';
part 'map_contribution/tag_voters_dialogs.dart';
part 'map_contribution/tooltip_shape_border.dart';

/// 地图贡献对话框
class MapContributionDialog extends StatefulWidget {
  final String mapName;
  final String? mapLabel;
  final bool isDifficultySeparated;
  final String? serverAddress;

  const MapContributionDialog({
    super.key,
    required this.mapName,
    this.mapLabel,
    this.isDifficultySeparated = false,
    this.serverAddress,
  });

  /// 显示地图贡献对话框
  static Future<void> show(
    BuildContext context, {
    required String mapName,
    String? mapLabel,
    bool isDifficultySeparated = false,
    String? serverAddress,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => MapContributionBloc()),
          BlocProvider(create: (context) => MapTagBloc()),
        ],
        child: MapContributionDialog(
          mapName: mapName,
          mapLabel: mapLabel,
          isDifficultySeparated: isDifficultySeparated,
          serverAddress: serverAddress,
        ),
      ),
    );
  }

  @override
  State<MapContributionDialog> createState() => _MapContributionDialogState();
}

class _MapContributionDialogState extends State<MapContributionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _scrollController = ScrollController();

  // 图片上传状态
  File? _selectedImage;
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;

  // 滚动指示器状态
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  // 标签搜索
  final _tagSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _nameController.addListener(_onNameChanged);
    _scrollController.addListener(_updateScrollIndicators);
    _tagSearchController.addListener(_onTagSearchChanged);

    // 初始加载名称贡献列表
    _loadContributions(ContributionType.name);

    // 刷新用户积分（确保积分数据是最新的）
    _refreshUserCredits();
  }

  /// 刷新用户积分
  void _refreshUserCredits() {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated) {
      context.read<AuthBloc>().add(const AuthRefreshRequested());
    }
  }

  /// 处理标签投票（暴露给外部组件）
  void handleTagVote(MapTag tag, String voteType) {
    _handleTagVote(tag, voteType);
  }

  /// 显示编辑标签对话框（暴露给外部组件）
  void showEditTagDialog(MapTag tag) {
    _showEditTagDialog(tag);
  }

  /// 显示删除标签对话框（暴露给外部组件）
  void showDeleteTagDialog(MapTag tag) {
    _showDeleteTagDialog(tag);
  }

  /// 显示标签投票用户对话框（暴露给外部组件）
  void showTagVotersDialog(String mapName, MapTag tag) {
    _showTagVotersDialog(mapName, tag);
  }

  /// 处理撤销变更申请（先弹确认对话框，暴露给外部组件）
  void handleCancelChangeRequest(MapTag tag) {
    if (!_checkLogin()) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(MdiIcons.alertCircleOutline, color: AppColors.amber500),
            const SizedBox(width: 12),
            Text(
              '撤销变更申请',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
          ],
        ),
        content: Text(
          '确定要撤销标签 "${tag.name}" 的变更申请吗？撤销后可重新发起申请。',
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.gray700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<MapTagBloc>().add(
                CancelTagChangeRequest(tagId: tag.id),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认撤销'),
          ),
        ],
      ),
    );
  }

  void _onNameChanged() {
    setState(() {});
  }

  void _onTagSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocusNode.dispose();
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    _tagSearchController.removeListener(_onTagSearchChanged);
    _tagSearchController.dispose();

    // 清理 File 引用，释放文件句柄
    _selectedImage = null;

    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index == 0) {
      _loadContributions(ContributionType.name);
    } else if (index == 1) {
      _loadContributions(ContributionType.background);
    } else if (index == 2) {
      _loadTagData();
    }
    // 重置滚动状态
    setState(() {
      _canScrollUp = false;
      _canScrollDown = false;
    });
  }

  void _loadTagData() {
    context.read<MapTagBloc>().add(const LoadTagList());

    if (widget.serverAddress == null) {
      context.read<MapTagBloc>().add(LoadMapServers(mapName: widget.mapName));
    }

    context.read<MapTagBloc>().add(
      LoadMapTagList(
        mapName: widget.mapName,
        serverAddress: widget.serverAddress,
      ),
    );

    // 只有登录用户才加载个人标签（pending/rejected 状态）
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated) {
      context.read<MapTagBloc>().add(const LoadUserTags());
    }
  }

  void _loadContributions(ContributionType type) {
    if (type == ContributionType.name) {
      context.read<MapContributionBloc>().add(
        LoadNameContributions(mapName: widget.mapName),
      );
    } else {
      context.read<MapContributionBloc>().add(
        LoadBackgroundContributions(mapName: widget.mapName),
      );
    }
  }

  ContributionType get _currentType => _tabController.index == 0
      ? ContributionType.name
      : ContributionType.background;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.gray800;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 680,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            _buildHeader(textColor, isDark),
            _buildTabBar(isDark),
            Expanded(child: _buildContent(isDark)),
            _buildSubmitArea(isDark),
          ],
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(Color textColor, bool isDark) {
    final secondaryTextColor = isDark ? Colors.white54 : AppColors.gray500;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.pencilOutline, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '修改地图信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                // 地图原名（可复制）
                Tooltip(
                  message: '点击复制',
                  child: InkWell(
                    onTap: () => _copyMapName(),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MdiIcons.contentCopy,
                            size: 12,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.mapName,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: secondaryTextColor),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  /// 复制地图原名到剪贴板
  void _copyMapName() {
    Clipboard.setData(ClipboardData(text: widget.mapName));
    ToastUtils.showSuccess(context, '已复制: ${widget.mapName}');
  }

  /// 构建 Tab 栏
  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? Colors.white54 : AppColors.gray500,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2,
        tabs: const [
          Tab(text: '中文名称'),
          Tab(text: '背景图片'),
          Tab(text: '标签'),
        ],
      ),
    );
  }

  /// 构建说明提示
  Widget _buildHintBanner(bool isDark) {
    final isNameTab = _currentType == ContributionType.name;
    final hintText = isNameTab
        ? '票数最高的名称将作为该地图的中文名显示，1分钟左右生效'
        : '票数最高的图片将作为该地图的背景显示，1分钟左右生效';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.informationOutline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hintText,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(bool isDark) {
    return BlocConsumer<MapContributionBloc, MapContributionState>(
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
          context.read<MapContributionBloc>().add(
            const ClearContributionError(),
          );
        }
        if (state.submitSuccess) {
          ToastUtils.showSuccess(context, '提交成功');
        }
        if (state.deleteSuccess) {
          ToastUtils.showSuccess(context, '删除成功');
        }
      },
      builder: (context, state) {
        // 标签 Tab
        if (_tabController.index == 2) {
          return _buildTagContent(isDark);
        }

        final isNameTab = _currentType == ContributionType.name;
        final isLoading = isNameTab
            ? state.isLoadingNames
            : state.isLoadingBackgrounds;
        final isEmpty = isNameTab
            ? state.isNamesEmpty
            : state.isBackgroundsEmpty;
        final contributions = isNameTab
            ? state.nameContributions
            : state.backgroundContributions;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        // 延迟检查滚动状态
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateScrollIndicators();
        });

        return Column(
          children: [
            _buildHintBanner(isDark),
            Expanded(
              child: isEmpty
                  ? _buildEmptyState(isDark)
                  : Stack(
                      children: [
                        _buildContributionList(contributions, isDark),
                        // 顶部滚动指示器
                        if (_canScrollUp)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _buildScrollIndicator(
                              isTop: true,
                              isDark: isDark,
                            ),
                          ),
                        // 底部滚动指示器
                        if (_canScrollDown)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildScrollIndicator(
                              isTop: false,
                              isDark: isDark,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 构建标签 Tab 内容
  Widget _buildTagContent(bool isDark) {
    return BlocConsumer<MapTagBloc, MapTagState>(
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
          context.read<MapTagBloc>().add(const ClearTagError());
        }
        if (state.submitSuccess) {
          ToastUtils.showSuccess(context, '提交成功，等待审核');
          context.read<MapTagBloc>().add(const RefreshUserTags());
        }
        if (state.deleteSuccess) {
          ToastUtils.showSuccess(context, '删除成功');
        }
        if (state.cancelSuccess) {
          ToastUtils.showSuccess(context, '已撤销变更申请');
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        return Column(
          children: [
            // 难度独立提示横幅
            if (widget.isDifficultySeparated)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber500.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.amber500.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      MdiIcons.informationOutline,
                      size: 18,
                      color: AppColors.amber500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '由于该模式采用按难度分服的机制，当前的地图投票仅反映本服务器所属的标签',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 服务器版本筛选（单独一行）
            _buildServerFilter(state, isDark),
            // 搜索栏
            _buildTagSearchBar(state, isDark),
            // 标签列表与浮动面板
            Expanded(
              child: Stack(
                children: [
                  _buildTagList(state, isDark),
                  Positioned(
                    bottom: 0,
                    right: 16,
                    child: _buildVotedTagsPanel(state, isDark),
                  ),
                ],
              ),
            ),
            // 提交区域
            _buildTagSubmitArea(state, isDark),
          ],
        );
      },
    );
  }

  /// 构建已投票标签浮动面板
  Widget _buildVotedTagsPanel(MapTagState state, bool isDark) {
    // 获取有票数的标签（任何人投过票的标签）
    // 这里我们将全局标签和用户标签去重后，再筛选
    final seen = <int>{};
    final allUniqueTags = [
      ...state.userTags,
      ...state.tagList,
    ].where((t) => seen.add(t.id)).toList();
    final votedTags = allUniqueTags
        .where((t) => (state.getMapTagVoteByTagId(t.id)?.voteCount ?? 0) > 0)
        .toList();

    // 按票数排序
    votedTags.sort((a, b) {
      final av = state.getMapTagVoteByTagId(a.id)?.voteCount ?? 0;
      final bv = state.getMapTagVoteByTagId(b.id)?.voteCount ?? 0;
      return bv.compareTo(av);
    });

    return _VotedTagsFloatingPanel(
      votedTags: votedTags,
      state: state,
      isDark: isDark,
      mapName: widget.mapName,
    );
  }

  /// 构建服务器筛选
  Widget _buildServerFilter(MapTagState state, bool isDark) {
    if (state.mapServers.isEmpty) return const SizedBox.shrink();

    final effectiveAddress =
        state.mapServers.any((s) => s.serverAddress == state.serverAddress)
        ? state.serverAddress
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Icon(
            MdiIcons.serverNetwork,
            size: 16,
            color: isDark ? Colors.white54 : AppColors.gray500,
          ),
          const SizedBox(width: 8),
          Text(
            '分服服务器特定版本：',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.gray500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: effectiveAddress,
                  isExpanded: true,
                  icon: Icon(
                    MdiIcons.chevronDown,
                    size: 16,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                  dropdownColor: isDark ? AppColors.slate800 : Colors.white,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('默认'),
                    ),
                    ...state.mapServers.map((server) {
                      return DropdownMenuItem<String?>(
                        value: server.serverAddress,
                        child: Text(server.serverName),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    context.read<MapTagBloc>().add(
                      ChangeServerAddress(serverAddress: newValue),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签搜索栏
  Widget _buildTagSearchBar(MapTagState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _tagSearchController,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : AppColors.gray800,
        ),
        decoration: InputDecoration(
          hintText: '搜索标签...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : AppColors.gray400,
          ),
          prefixIcon: Icon(
            MdiIcons.magnify,
            size: 18,
            color: isDark ? Colors.white38 : AppColors.gray400,
          ),
          suffixIcon: _tagSearchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    MdiIcons.close,
                    size: 16,
                    color: isDark ? Colors.white38 : AppColors.gray400,
                  ),
                  onPressed: () {
                    _tagSearchController.clear();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey[100],
        ),
      ),
    );
  }

  /// 构建标签列表
  Widget _buildTagList(MapTagState state, bool isDark) {
    final query = _tagSearchController.text.trim().toLowerCase();

    // 获取后端用户 ID
    final currentUserId = TokenService.instance.userInfo?.id;

    // 分离出用户自己在全局标签中的已通过标签
    // 未登录时 currentUserId 为 null，不应匹配任何标签
    final userGlobalTags = currentUserId != null
        ? state.tagList
              .where((t) => t.contributor?.userId == currentUserId)
              .toList()
        : <MapTag>[];
    final otherGlobalTags = currentUserId != null
        ? state.tagList
              .where((t) => t.contributor?.userId != currentUserId)
              .toList()
        : state.tagList;

    // 合并用户的审核中/被拒绝标签与已通过标签，并按 id 去重
    final seen = <int>{};
    List<MapTag> allUserTags = [
      ...state.userTags,
      ...userGlobalTags,
    ].where((t) => seen.add(t.id)).toList();

    // 根据搜索关键词过滤标签（不区分大小写）
    List<MapTag> filteredUserTags = allUserTags;
    List<MapTag> filteredTagList = otherGlobalTags;
    if (query.isNotEmpty) {
      filteredUserTags = allUserTags
          .where((t) => t.name.toLowerCase().contains(query))
          .toList();
      filteredTagList = otherGlobalTags
          .where((t) => t.name.toLowerCase().contains(query))
          .toList();
    }

    // 按票数（净值）降序排序，有票的排在前面
    int byVoteCountDesc(MapTag a, MapTag b) {
      final av = state.getMapTagVoteByTagId(a.id)?.voteCount ?? 0;
      final bv = state.getMapTagVoteByTagId(b.id)?.voteCount ?? 0;
      return bv.compareTo(av);
    }

    filteredTagList.sort(byVoteCountDesc);

    final difficultyTags = filteredTagList
        .where(
          (t) => t.isDifficulty == true && t.difficultyType == 'difficulty',
        )
        .toList();
    final tierTags = filteredTagList
        .where((t) => t.isDifficulty == true && t.difficultyType == 'tier')
        .toList();
    final otherTags = filteredTagList
        .where(
          (t) =>
              !(t.isDifficulty == true &&
                  (t.difficultyType == 'difficulty' ||
                      t.difficultyType == 'tier')),
        )
        .toList();

    final hasNoTags =
        filteredUserTags.isEmpty &&
        filteredTagList.isEmpty &&
        !state.isLoadingTagList &&
        !state.isLoadingUserTags;

    if (hasNoTags) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.tagOutline,
              size: 64,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty ? '没有找到匹配的标签' : '暂无标签',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty ? '试试其他关键词吧' : '成为第一个贡献者吧！',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white38
                    : AppColors.gray500.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户标签区块（审核中 + 已拒绝），无数据且非加载中时隐藏
          if (filteredUserTags.isNotEmpty || state.isLoadingUserTags)
            _buildTagSection(
              title: '我的标签',
              tags: filteredUserTags,
              isLoading: state.isLoadingUserTags,
              isDark: isDark,
              state: state,
              isUserSection: true,
              mapName: widget.mapName,
            ),
          // 全局标签区块：按类别拆分
          if (state.isLoadingTagList)
            _buildTagSection(
              title: '全局标签',
              tags: const [],
              isLoading: true,
              isDark: isDark,
              state: state,
              isUserSection: false,
              mapName: widget.mapName,
            )
          else if (filteredTagList.isEmpty)
            _buildTagSection(
              title: '其他标签',
              tags: const [],
              isLoading: false,
              isDark: isDark,
              state: state,
              isUserSection: false,
              mapName: widget.mapName,
            )
          else ...[
            if (difficultyTags.isNotEmpty)
              _buildTagSection(
                title: '难度标签',
                tags: difficultyTags,
                isLoading: false,
                isDark: isDark,
                state: state,
                isUserSection: false,
                mapName: widget.mapName,
              ),
            if (tierTags.isNotEmpty)
              _buildTagSection(
                title: 'Tier 标签',
                tags: tierTags,
                isLoading: false,
                isDark: isDark,
                state: state,
                isUserSection: false,
                mapName: widget.mapName,
              ),
            if (otherTags.isNotEmpty)
              _buildTagSection(
                title: '其他标签',
                tags: otherTags,
                isLoading: false,
                isDark: isDark,
                state: state,
                isUserSection: false,
                mapName: widget.mapName,
              ),
          ],
        ],
      ),
    );
  }

  /// 构建标签分区
  Widget _buildTagSection({
    required String title,
    required List<MapTag> tags,
    required bool isLoading,
    required bool isDark,
    required MapTagState state,
    required bool isUserSection,
    required String mapName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.gray800,
            ),
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '暂无',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : AppColors.gray400,
              ),
            ),
          )
        else
          _TagGrid(
            tags: tags,
            state: state,
            isDark: isDark,
            isUserSection: isUserSection,
            mapName: mapName,
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 处理标签投票
  void _handleTagVote(MapTag tag, String voteType) {
    if (!_checkLogin()) return;
    context.read<MapTagBloc>().add(
      ToggleTagVote(tagId: tag.id, voteType: voteType),
    );
  }

  /// 显示编辑标签对话框
  void _showEditTagDialog(MapTag tag) {
    if (!_checkLogin()) return;
    final controller = TextEditingController(text: tag.name);
    final reasonController = TextEditingController();
    String? selectedColor = tag.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapTagBloc = context.read<MapTagBloc>();
    final isApproved = tag.isApproved;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.slate800 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '修改标签',
            style: TextStyle(color: isDark ? Colors.white : AppColors.gray800),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 50,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                  decoration: InputDecoration(
                    labelText: '标签名称',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.gray500,
                    ),
                    hintText: '输入标签名称',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : AppColors.gray500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 颜色选择
                Text(
                  '标签颜色',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildEditTagColorPicker(
                  selectedColor,
                  isDark,
                  (color) => setDialogState(() => selectedColor = color),
                ),
                if (isApproved) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLength: 100,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.gray800,
                    ),
                    decoration: InputDecoration(
                      labelText: '变更理由',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white54 : AppColors.gray500,
                      ),
                      hintText: '请输入申请变更的理由',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : AppColors.gray500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '取消',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isEmpty) {
                  ToastUtils.showError(dialogContext, '标签名称不能为空');
                  return;
                }
                final reason = reasonController.text.trim();
                if (isApproved && reason.isEmpty) {
                  ToastUtils.showError(dialogContext, '变更理由不能为空');
                  return;
                }
                Navigator.of(dialogContext).pop();
                mapTagBloc.add(
                  UpdateTag(
                    tagId: tag.id,
                    name: newName,
                    color: selectedColor,
                    editReason: isApproved ? reason : null,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑标签时的颜色选择器
  Widget _buildEditTagColorPicker(
    String? selectedColor,
    bool isDark,
    void Function(String?) onColorChanged,
  ) {
    return TagColorPicker(
      selectedColor: selectedColor,
      onColorChanged: onColorChanged,
      enabled: true,
    );
  }

  /// 显示删除标签确认对话框
  void _showDeleteTagDialog(MapTag tag) {
    if (!_checkLogin()) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapTagBloc = context.read<MapTagBloc>();
    final reasonController = TextEditingController();
    final isApproved = tag.isApproved;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(MdiIcons.alertCircleOutline, color: AppColors.red500),
            const SizedBox(width: 12),
            Text(
              '确认删除',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除标签 "${tag.name}" 吗？删除后无法恢复。',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
            if (isApproved) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 100,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
                decoration: InputDecoration(
                  labelText: '删除理由',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                  hintText: '请输入申请删除的理由',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : AppColors.gray500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (isApproved && reason.isEmpty) {
                ToastUtils.showError(dialogContext, '删除理由不能为空');
                return;
              }
              Navigator.of(dialogContext).pop();
              mapTagBloc.add(
                DeleteTag(
                  tagId: tag.id,
                  editReason: isApproved ? reason : null,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示标签投票用户对话框
  void _showTagVotersDialog(String mapName, MapTag tag) {
    final currentServerAddress =
        context.read<MapTagBloc>().state.serverAddress ?? widget.serverAddress;
    showDialog(
      context: context,
      builder: (dialogContext) => _TagVotersDialog(
        mapName: mapName,
        tag: tag,
        isDifficultySeparated: widget.isDifficultySeparated,
        serverAddress: currentServerAddress,
      ),
    );
  }

  /// 显示地图所有标签投票记录对话框
  void _showMapAllVotersDialog() {
    final currentServerAddress =
        context.read<MapTagBloc>().state.serverAddress ?? widget.serverAddress;
    showDialog(
      context: context,
      builder: (dialogContext) => _MapAllVotersDialog(
        mapName: widget.mapName,
        mapLabel: widget.mapLabel,
        isDifficultySeparated: widget.isDifficultySeparated,
        serverAddress: currentServerAddress,
      ),
    );
  }

  /// 构建标签提交区域
  Widget _buildTagSubmitArea(MapTagState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // 添加标签按钮
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: state.isSubmitting ? null : _showAddTagDialog,
                icon: Icon(MdiIcons.tagPlusOutline, size: 18),
                label: const Text(
                  '添加标签',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: const Color(
                    0xFF0080FF,
                  ).withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 查看全部投票记录按钮
          SizedBox(
            height: 44,
            child: Tooltip(
              message: '查看该地图所有标签的投票记录',
              child: ElevatedButton.icon(
                onPressed: () => _showMapAllVotersDialog(),
                icon: Icon(MdiIcons.accountGroupOutline, size: 18),
                label: const Text(
                  '投票记录',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加标签对话框
  void _showAddTagDialog() {
    if (!_checkLogin()) return;
    final controller = TextEditingController();
    String? selectedColor;
    bool autoVote = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapTagBloc = context.read<MapTagBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.slate800 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '添加标签',
            style: TextStyle(color: isDark ? Colors.white : AppColors.gray800),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 50,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                  decoration: InputDecoration(
                    labelText: '标签名称',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.gray500,
                    ),
                    hintText: '输入标签名称',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : AppColors.gray500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 颜色选择
                Text(
                  '标签颜色',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                ),
                const SizedBox(height: 8),
                TagColorPicker(
                  selectedColor: selectedColor,
                  onColorChanged: (color) =>
                      setDialogState(() => selectedColor = color),
                ),
                const SizedBox(height: 16),
                // 审核通过自动投票选项
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: autoVote,
                        onChanged: (value) =>
                            setDialogState(() => autoVote = value ?? false),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => autoVote = !autoVote),
                        child: Text(
                          '审核通过自动为该地图投票',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '取消',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ToastUtils.showError(dialogContext, '标签名称不能为空');
                  return;
                }
                Navigator.of(dialogContext).pop();
                mapTagBloc.add(
                  SubmitTag(
                    name: name,
                    color: selectedColor,
                    autoVote: autoVote,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(bool isDark) {
    final secondaryTextColor = isDark ? Colors.white54 : AppColors.gray500;
    final isNameTab = _currentType == ContributionType.name;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNameTab ? MdiIcons.textBoxPlusOutline : MdiIcons.imagePlusOutline,
            size: 64,
            color: secondaryTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isNameTab ? '暂无中文名称贡献' : '暂无背景图片贡献',
            style: TextStyle(fontSize: 16, color: secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            '成为第一个贡献者吧！',
            style: TextStyle(
              fontSize: 14,
              color: secondaryTextColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建贡献列表
  Widget _buildContributionList(
    List<MapContribution> contributions,
    bool isDark,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contributions.length,
      itemBuilder: (context, index) {
        final contribution = contributions[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey('${contribution.id}_$index'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + index * 80),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + 0.2 * value,
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            );
          },
          child: _buildContributionItem(contribution, index, isDark),
        );
      },
    );
  }

  /// 构建滚动指示器
  Widget _buildScrollIndicator({required bool isTop, required bool isDark}) {
    final bgColor = isDark ? AppColors.slate800 : Colors.white;
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.9),
              bgColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 2 : 0, bottom: isTop ? 0 : 2),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: isDark ? Colors.white54 : AppColors.gray500,
          size: 24,
        ),
      ),
    );
  }

  /// 构建贡献项
  Widget _buildContributionItem(
    MapContribution contribution,
    int index,
    bool isDark,
  ) {
    final isNameType = contribution.type == ContributionType.name;
    final isFirst = index == 0;
    final showAuditStatusBar = !contribution.isApproved;
    final canEdit =
        contribution.isOwner &&
        (contribution.isRejected || contribution.isPending);

    // 确定边框颜色
    final Color borderColor;
    if (showAuditStatusBar) {
      // 有审核状态：使用状态颜色
      borderColor = contribution.isPending
          ? AppColors.amber500.withValues(alpha: 0.4)
          : AppColors.red500.withValues(alpha: 0.4);
    } else if (isFirst) {
      // 第一名：蓝色高亮
      borderColor = AppColors.primary.withValues(alpha: 0.5);
    } else {
      // 普通状态：灰色边框
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08);
    }

    // 根据审核状态确定文字颜色（审核状态下使用白色以提高对比度）
    final Color textColor;
    final Color secondaryTextColor;
    if (showAuditStatusBar) {
      // 审核状态：使用白色/深色以提高对比度
      textColor = isDark ? Colors.white : AppColors.gray800;
      secondaryTextColor = isDark
          ? Colors.white.withValues(alpha: 0.9)
          : AppColors.gray700;
    } else {
      // 正常状态：使用原有颜色
      textColor = isDark ? Colors.white : AppColors.gray800;
      secondaryTextColor = isDark ? Colors.white54 : AppColors.gray500;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 审核状态条（顶部）
        if (showAuditStatusBar)
          _buildAuditStatusBar(contribution, isDark, canEdit),
        // 贡献项主体
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.fromLTRB(
            16,
            showAuditStatusBar ? 0 : 4, // 有状态条时顶部不留间距
            16,
            4,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFirst
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.only(
              topLeft: showAuditStatusBar
                  ? Radius.zero
                  : const Radius.circular(10),
              topRight: showAuditStatusBar
                  ? Radius.zero
                  : const Radius.circular(10),
              bottomLeft: const Radius.circular(10),
              bottomRight: const Radius.circular(10),
            ),
            // 统一边框：有状态条时只加左右下边框，否则加完整边框
            border: showAuditStatusBar
                ? Border(
                    left: BorderSide(color: borderColor, width: 1),
                    right: BorderSide(color: borderColor, width: 1),
                    bottom: BorderSide(color: borderColor, width: 1),
                  )
                : Border.all(color: borderColor, width: isFirst ? 1.5 : 1),
            boxShadow: isFirst
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 排名标识
              _buildRankBadge(index, isDark),
              const SizedBox(width: 12),
              // 主要内容：贡献内容
              Expanded(
                child: isNameType
                    ? Tooltip(
                        message: contribution.content,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          contribution.content,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isFirst
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _buildImagePreview(
                          contribution.backgroundImageRef ??
                              contribution.content,
                          isDark,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // 右侧信息区域：贡献者信息
              _buildContributorInfo(contribution, secondaryTextColor),
              const SizedBox(width: 12),
              // 投票按钮
              _buildVoteButton(contribution, isDark),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建审核状态条（顶部）
  Widget _buildAuditStatusBar(
    MapContribution contribution,
    bool isDark,
    bool canEdit,
  ) {
    final isPending = contribution.isPending;
    final statusColor = isPending ? AppColors.amber500 : AppColors.red500;
    final statusIcon = isPending
        ? MdiIcons.clockOutline
        : MdiIcons.alertCircleOutline;
    final statusText = isPending ? '审核中' : '审核失败';
    final statusMessage = isPending
        ? '等待管理员审核'
        : (contribution.auditRemark.isNotEmpty
              ? contribution.auditRemark
              : '未通过审核');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Tooltip(
              message: statusMessage,
              waitDuration: const Duration(milliseconds: 500),
              child: Text(
                '- $statusMessage',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.gray700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (canEdit) ...[
            // 修改按钮
            Tooltip(
              message: '修改后重新提交审核',
              child: Material(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => _showEditDialog(contribution),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MdiIcons.pencilOutline,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '修改',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 删除按钮
            Tooltip(
              message: '删除',
              child: Material(
                color: AppColors.red500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => _showDeleteConfirmDialog(contribution),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MdiIcons.deleteOutline,
                          size: 14,
                          color: AppColors.red500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '删除',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建贡献者信息
  Widget _buildContributorInfo(
    MapContribution contribution,
    Color secondaryTextColor,
  ) {
    // 系统数据显示"系统"标识
    if (contribution.isSystem) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(MdiIcons.steam, size: 16, color: secondaryTextColor),
          const SizedBox(width: 4),
          Text(
            'Steam',
            style: TextStyle(fontSize: 11, color: secondaryTextColor),
          ),
        ],
      );
    }

    // 用户贡献显示头像和用户名
    final contributor = contribution.contributor;
    if (contributor == null) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildContributorAvatar(contributor, size: 36),
          const SizedBox(width: 4),
          Flexible(
            child: Tooltip(
              message: contributor.username,
              waitDuration: const Duration(milliseconds: 500),
              child: Text(
                contributor.username,
                style: TextStyle(fontSize: 11, color: secondaryTextColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示编辑对话框
  void _showEditDialog(MapContribution contribution) {
    final isNameType = contribution.type == ContributionType.name;

    if (isNameType) {
      _showEditNameDialog(contribution);
    } else {
      _showEditBackgroundDialog(contribution);
    }
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(MapContribution contribution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNameType = contribution.type == ContributionType.name;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              MdiIcons.alertCircleOutline,
              color: AppColors.red500,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              '确认删除',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除这个贡献吗？',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            // 内容预览区域
            if (isNameType)
              // 名称贡献：显示文字
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      MdiIcons.textBoxOutline,
                      size: 16,
                      color: isDark ? Colors.white54 : AppColors.gray500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contribution.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.gray800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              // 背景贡献：显示图片预览
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _ContributionImage(
                  imageRef:
                      contribution.backgroundImageRef ?? contribution.content,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '删除后无法恢复',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.red500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _handleDelete(contribution);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 处理删除操作
  void _handleDelete(MapContribution contribution) {
    final isNameType = contribution.type == ContributionType.name;

    if (isNameType) {
      context.read<MapContributionBloc>().add(
        DeleteNameContribution(id: contribution.id),
      );
    } else {
      context.read<MapContributionBloc>().add(
        DeleteBackgroundContribution(id: contribution.id),
      );
    }
  }

  /// 显示编辑名称对话框
  void _showEditNameDialog(MapContribution contribution) {
    final controller = TextEditingController(text: contribution.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                '修改名称贡献',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
              ),
              const SizedBox(height: 20),
              // 拒绝原因提示
              if (contribution.auditRemark.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.red500.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        MdiIcons.alertCircleOutline,
                        size: 16,
                        color: AppColors.red500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '拒绝原因: ${contribution.auditRemark}',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 输入框
              TextField(
                controller: controller,
                maxLength: 50,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
                decoration: InputDecoration(
                  labelText: '地图中文名称',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : AppColors.gray500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final newName = controller.text.trim();
                      if (newName.isEmpty) {
                        ToastUtils.showError(context, '名称不能为空');
                        return;
                      }
                      if (newName == contribution.content) {
                        ToastUtils.showError(context, '名称未修改');
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      context.read<MapContributionBloc>().add(
                        UpdateNameContribution(
                          id: contribution.id,
                          name: newName,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('提交'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示编辑背景对话框
  void _showEditBackgroundDialog(MapContribution contribution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    File? selectedImage;
    bool isHovered = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.slate800 : Colors.white,
          title: Text(
            '修改背景贡献',
            style: TextStyle(color: isDark ? Colors.white : AppColors.gray800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contribution.auditRemark.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.red500.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        MdiIcons.alertCircleOutline,
                        size: 16,
                        color: AppColors.red500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '拒绝原因: ${contribution.auditRemark}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.gray700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 图片选择区域（带 hover 效果）
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setDialogState(() => isHovered = true),
                onExit: (_) => setDialogState(() => isHovered = false),
                child: GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
                    );
                    if (!context.mounted) return;
                    if (result != null && result.files.single.path != null) {
                      final file = File(result.files.single.path!);
                      final validation =
                          ContributionValidationUtils.validateBackgroundImage(
                            file,
                          );
                      if (!validation.isValid) {
                        if (!context.mounted) return;
                        ToastUtils.showError(context, validation.errorMessage!);
                        return;
                      }
                      setDialogState(() => selectedImage = file);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 280,
                    height: 160,
                    decoration: BoxDecoration(
                      color: isHovered
                          ? (isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08))
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHovered
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : (isDark ? Colors.white24 : Colors.black12),
                        width: isHovered ? 2 : 1,
                      ),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: isHovered ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  MdiIcons.imagePlusOutline,
                                  size: 40,
                                  color: isHovered
                                      ? AppColors.primary
                                      : (isDark
                                            ? Colors.white38
                                            : Colors.black26),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '点击选择新图片',
                                style: TextStyle(
                                  color: isHovered
                                      ? AppColors.primary
                                      : (isDark
                                            ? Colors.white54
                                            : AppColors.gray500),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '取消',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedImage == null
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await _uploadAndUpdateBackground(
                        contribution.id,
                        selectedImage!,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(
                  0xFF0080FF,
                ).withValues(alpha: 0.5),
              ),
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  /// 上传并更新背景贡献
  Future<void> _uploadAndUpdateBackground(
    int contributionId,
    File imageFile,
  ) async {
    // 显示上传进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在上传图片...'),
          ],
        ),
      ),
    );

    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadToImageBed(
        imageFile,
        categoryName: 'map_backgrounds',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭进度对话框

      context.read<MapContributionBloc>().add(
        UpdateBackgroundContribution(id: contributionId, fileId: result.fileId),
      );
    } catch (e) {
      LogService.e('上传背景图片失败', e);
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭进度对话框
      ToastUtils.showError(context, '上传失败，请稍后重试');
    }
  }

  /// 构建排名标识
  Widget _buildRankBadge(int index, bool isDark) {
    Color badgeColor;
    IconData? icon;

    if (index == 0) {
      badgeColor = const Color(0xFFFFD700); // 金色皇冠
      icon = MdiIcons.crown;
    } else if (index == 1) {
      badgeColor = const Color(0xFFC0C0C0); // 银色
    } else if (index == 2) {
      badgeColor = const Color(0xFFCD7F32); // 铜色
    } else {
      badgeColor = isDark ? Colors.white38 : AppColors.gray400;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: index == 0
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFFFFD700), const Color(0xFFFFA500)],
              )
            : null,
        color: index == 0 ? null : badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: index == 0
            ? null
            : Border.all(color: badgeColor.withValues(alpha: 0.4)),
        boxShadow: index == 0
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, size: 16, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
      ),
    );
  }

  /// 构建贡献者头像
  Widget _buildContributorAvatar(
    ContributorInfo contributor, {
    double size = 36,
  }) {
    final avatarUrl = contributor.avatar;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        color: AppColors.primary.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? DiskCachedImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              placeholder: _buildDefaultAvatar(contributor.username, size),
              errorWidget: _buildDefaultAvatar(contributor.username, size),
            )
          : _buildDefaultAvatar(contributor.username, size),
    );
  }

  /// 构建默认头像
  Widget _buildDefaultAvatar(String username, [double size = 36]) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final fontSize = size * 0.45;
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// 构建图片预览
  Widget _buildImagePreview(String imageUrl, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _HoverScaleWidget(
        child: GestureDetector(
          onTap: () => _showFullImage(imageUrl),
          child: Container(
            height: 80,
            width: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ContributionImage(imageRef: imageUrl),
                // Hover 遮罩
                Positioned.fill(
                  child: _HoverOverlay(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: const Center(
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示完整图片
  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: _ContributionImage(
                imageRef: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建投票按钮组（赞成/反对）
  /// 系统数据（isSystem=true）不可投票
  /// 未审核通过的贡献不可投票
  Widget _buildVoteButton(MapContribution contribution, bool isDark) {
    final upCount = contribution.upCount;
    final downCount = contribution.downCount;
    final voteType = contribution.voteType;
    final isOwner = contribution.isOwner;
    final isSystem = contribution.isSystem;
    final isApproved = contribution.isApproved;
    final secondaryColor = isDark ? Colors.white70 : AppColors.gray500;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    // 系统数据或未审核通过的贡献：显示禁用状态的投票按钮
    final isDisabled = isSystem || !isApproved;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 赞成按钮
        _buildSingleVoteButton(
          icon: voteType == VoteType.up
              ? MdiIcons.thumbUp
              : MdiIcons.thumbUpOutline,
          isActive: voteType == VoteType.up,
          count: upCount,
          onTap: isDisabled
              ? null
              : () => _handleVote(contribution, VoteType.up),
          isDark: isDark,
          bgColor: bgColor,
          secondaryColor: secondaryColor,
          disabled: isDisabled,
        ),
        const SizedBox(width: 8),
        // 反对按钮（自己的贡献或禁用状态不能踩）
        _buildSingleVoteButton(
          icon: voteType == VoteType.down
              ? MdiIcons.thumbDown
              : MdiIcons.thumbDownOutline,
          isActive: voteType == VoteType.down,
          count: downCount,
          onTap: (isOwner || isDisabled)
              ? null
              : () => _handleVote(contribution, VoteType.down),
          isDark: isDark,
          bgColor: bgColor,
          secondaryColor: secondaryColor,
          isDownVote: true,
          disabled: isOwner || isDisabled,
        ),
      ],
    );
  }

  /// 构建单个投票按钮
  Widget _buildSingleVoteButton({
    required IconData icon,
    required bool isActive,
    required int count,
    required VoidCallback? onTap,
    required bool isDark,
    required Color bgColor,
    required Color secondaryColor,
    bool isDownVote = false,
    bool disabled = false,
  }) {
    final activeColor = isDownVote ? AppColors.red500 : AppColors.primary;

    // 确定图标和文字颜色
    final Color contentColor;
    if (isActive) {
      // 激活状态：始终使用白色（无论是否禁用）
      contentColor = Colors.white;
    } else if (disabled) {
      // 未激活且禁用：使用半透明灰色
      contentColor = secondaryColor.withValues(alpha: 0.3);
    } else {
      // 未激活且可用：使用正常灰色
      contentColor = secondaryColor;
    }

    return Material(
      color: isActive ? activeColor : bgColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: contentColor),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建提交区域
  Widget _buildSubmitArea(bool isDark) {
    // 标签 Tab 不使用这个提交区域
    if (_tabController.index == 2) {
      return const SizedBox.shrink();
    }

    final inputBgColor = isDark ? AppColors.slate700 : AppColors.slate100;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final isNameTab = _currentType == ContributionType.name;

    return BlocBuilder<MapContributionBloc, MapContributionState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isNameTab)
                _buildNameInput(
                  inputBgColor,
                  textColor,
                  borderColor,
                  state.isSubmitting,
                )
              else
                _buildImageInput(inputBgColor, isDark, state.isSubmitting),
              const SizedBox(height: 12),
              _buildSubmitButton(state.isSubmitting),
            ],
          ),
        );
      },
    );
  }

  /// 构建名称输入框（带实时验证）
  Widget _buildNameInput(
    Color inputBgColor,
    Color textColor,
    Color borderColor,
    bool isSubmitting,
  ) {
    // 实时验证
    final validationError = ContributionValidationUtils.validateNameRealtime(
      _nameController.text,
    );
    final hasError = validationError != null;
    final errorColor = AppColors.red500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          enabled: !isSubmitting,
          style: TextStyle(color: textColor),
          maxLength: ContributionValidationUtils.maxNameLength,
          decoration: InputDecoration(
            hintText: '输入地图中文名称',
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
            filled: true,
            fillColor: hasError
                ? errorColor.withValues(alpha: 0.05)
                : inputBgColor,
            counterText: '',
            prefixIcon: Icon(
              MdiIcons.textBoxOutline,
              color: hasError ? errorColor : textColor.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? errorColor : borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? errorColor : borderColor,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? errorColor : AppColors.primary,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (_) => _handleSubmit(),
        ),
        // 错误提示
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(MdiIcons.alertCircleOutline, size: 14, color: errorColor),
                const SizedBox(width: 4),
                Text(
                  validationError,
                  style: TextStyle(fontSize: 12, color: errorColor),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 构建图片输入区域
  Widget _buildImageInput(Color inputBgColor, bool isDark, bool isSubmitting) {
    final textColor = isDark ? Colors.white70 : AppColors.gray500;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: inputBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: _selectedImage != null
          ? _buildSelectedImagePreview(isDark)
          : InkWell(
              onTap: isSubmitting || _isUploadingImage ? null : _pickImage,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(MdiIcons.imagePlusOutline, size: 24, color: textColor),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '点击选择背景图片',
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'JPG、PNG、WebP、GIF，最大 5MB',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// 构建已选择图片预览
  Widget _buildSelectedImagePreview(bool isDark) {
    return Stack(
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_selectedImage!, height: 72, fit: BoxFit.cover),
          ),
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '上传中 ${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
              onPressed: () => setState(() => _selectedImage = null),
              splashRadius: 16,
            ),
          ),
      ],
    );
  }

  /// 构建提交按钮
  Widget _buildSubmitButton(bool isSubmitting) {
    final isNameTab = _currentType == ContributionType.name;
    final canSubmit = isNameTab
        ? _nameController.text.trim().isNotEmpty
        : _selectedImage != null;

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: (isSubmitting || _isUploadingImage || !canSubmit)
            ? null
            : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: const Color(
            0xFF0080FF,
          ).withValues(alpha: 0.5),
        ),
        child: isSubmitting || _isUploadingImage
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '提交',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }


  /// 检查登录状态
  bool _checkLogin() {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      _showLoginPrompt();
      return false;
    }
    return true;
  }

  /// 检查积分是否足够
  bool _checkCredits() {
    final authState = context.read<AuthBloc>().state;
    final userInfo = authState.userInfo;
    if (userInfo == null) return false;

    final credits = int.tryParse(userInfo.credits ?? '0') ?? 0;
    if (credits < CreditConstants.minCredits) {
      _showCreditsPrompt(credits);
      return false;
    }
    return true;
  }

  /// 显示积分不足提示
  void _showCreditsPrompt(int currentCredits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(CreditConstants.insufficientCreditsTitle),
        content: Text(
          CreditConstants.getMapContributionCreditsMessage(
            CreditConstants.minCredits,
            currentCredits,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 显示登录提示
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('请先登录论坛账户后再进行此操作'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              LoginDialog.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  /// 处理投票
  void _handleVote(MapContribution contribution, VoteType voteType) {
    if (!_checkLogin()) return;

    context.read<MapContributionBloc>().add(
      ToggleVote(contribution.id, voteType),
    );
  }

  /// 选择图片
  Future<void> _pickImage() async {
    if (!_checkLogin()) return;
    if (!_checkCredits()) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // 验证图片
        final validation = ContributionValidationUtils.validateBackgroundImage(
          file,
        );
        if (!validation.isValid) {
          if (mounted) {
            ToastUtils.showError(context, validation.errorMessage!);
          }
          return;
        }

        if (!mounted) return;
        setState(() => _selectedImage = file);
      }
    } catch (e) {
      LogService.e('选择图片失败', e);
      if (mounted) {
        ToastUtils.showError(context, '选择图片失败');
      }
    }
  }

  /// 处理提交
  Future<void> _handleSubmit() async {
    if (!_checkLogin()) return;
    if (!_checkCredits()) return;

    final isNameTab = _currentType == ContributionType.name;

    if (isNameTab) {
      await _submitName();
    } else {
      await _submitImage();
    }
  }

  /// 提交名称贡献
  Future<void> _submitName() async {
    final name = _nameController.text.trim();

    // 验证名称
    final validation = ContributionValidationUtils.validateName(name);
    if (!validation.isValid) {
      ToastUtils.showError(context, validation.errorMessage!);
      return;
    }

    context.read<MapContributionBloc>().add(
      SubmitNameContribution(mapName: widget.mapName, name: name),
    );

    // 清空输入
    _nameController.clear();
  }

  /// 提交图片贡献
  Future<void> _submitImage() async {
    if (_selectedImage == null) {
      ToastUtils.showError(context, '请先选择图片');
      return;
    }

    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0.0;
    });

    try {
      // 上传图片
      final uploadService = FileUploadService();
      final result = await uploadService.uploadToImageBed(
        _selectedImage!,
        categoryName: 'map_backgrounds',
      );

      if (!mounted) return;

      // 提交贡献（使用 fileId）
      context.read<MapContributionBloc>().add(
        SubmitBackgroundContribution(
          mapName: widget.mapName,
          fileId: result.fileId,
        ),
      );

      // 清空状态
      setState(() {
        _selectedImage = null;
        _isUploadingImage = false;
        _uploadProgress = 0.0;
      });
    } catch (e) {
      LogService.e('上传图片失败', e);
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadProgress = 0.0;
        });
        ToastUtils.showError(context, '上传失败，请稍后重试');
      }
    }
  }
}

/// 底部悬浮的已投票标签面板
class _VotedTagsFloatingPanel extends StatefulWidget {
  final List<MapTag> votedTags;
  final MapTagState state;
  final bool isDark;
  final String mapName;

  const _VotedTagsFloatingPanel({
    required this.votedTags,
    required this.state,
    required this.isDark,
    required this.mapName,
  });

  @override
  State<_VotedTagsFloatingPanel> createState() =>
      _VotedTagsFloatingPanelState();
}

class _VotedTagsFloatingPanelState extends State<_VotedTagsFloatingPanel> {
  bool _isExpanded = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.slate700 : Colors.white;
    final borderColor = widget.isDark ? Colors.white24 : Colors.black12;
    final textColor = widget.isDark ? Colors.white : AppColors.gray800;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.5)
                : borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.25 : 0.15),
              blurRadius: _isHovered ? 16 : 10,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: _isExpanded ? 480 : null,
                child: InkWell(
                  onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    borderRadius: _isExpanded
                        ? const BorderRadius.vertical(top: Radius.circular(12))
                        : BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                MdiIcons.checkCircleOutline,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '已投票(${widget.votedTags.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              _isExpanded
                                  ? MdiIcons.chevronDown
                                  : MdiIcons.chevronUp,
                              size: 20,
                              color: widget.isDark
                                  ? Colors.white54
                                  : AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isExpanded)
                    Container(
                      width: 480,
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        shrinkWrap: true,
                        children: [
                          _TagGrid(
                            tags: widget.votedTags,
                            state: widget.state,
                            isDark: widget.isDark,
                            isUserSection: false,
                            mapName: widget.mapName,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
  }
}
