import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/map_contribution/map_contribution_bloc.dart';
import '../bloc/map_contribution/map_contribution_event.dart';
import '../bloc/map_contribution/map_contribution_state.dart';
import '../models/map_contribution_models.dart';
import '../utils/contribution_validation_utils.dart';
import '../utils/log_service.dart';
import '../utils/toast_utils.dart';
import '../utils/image_cache_manager.dart';
import '../services/file_upload_service.dart';
import '../services/image_url_service.dart';
import '../../desktop/widgets/login_dialog.dart';

/// 地图贡献对话框
/// 
/// 显示地图贡献列表、提交表单、投票功能
/// 使用 Tab 分隔名称贡献和背景贡献两个独立列表
/// 贡献一旦提交无法删除（Requirements 6.1, 6.2）
/// Requirements: 1.1, 2.1, 3.1, 4.2, 5.1, 5.2, 5.3, 6.1, 6.2
class MapContributionDialog extends StatefulWidget {
  final String mapName;
  final String? mapLabel;

  const MapContributionDialog({
    super.key,
    required this.mapName,
    this.mapLabel,
  });

  /// 显示地图贡献对话框
  static Future<void> show(
    BuildContext context, {
    required String mapName,
    String? mapLabel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BlocProvider(
        create: (context) => MapContributionBloc(),
        child: MapContributionDialog(
          mapName: mapName,
          mapLabel: mapLabel,
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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _nameController.addListener(_onNameChanged);
    _scrollController.addListener(_updateScrollIndicators);
    
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

  void _onNameChanged() {
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
    final type = _tabController.index == 0
        ? ContributionType.name
        : ContributionType.background;
    _loadContributions(type);
    // 重置滚动状态
    setState(() {
      _canScrollUp = false;
      _canScrollDown = false;
    });
  }

  void _loadContributions(ContributionType type) {
    if (type == ContributionType.name) {
      context.read<MapContributionBloc>().add(LoadNameContributions(
        mapName: widget.mapName,
      ));
    } else {
      context.read<MapContributionBloc>().add(LoadBackgroundContributions(
        mapName: widget.mapName,
      ));
    }
  }

  ContributionType get _currentType =>
      _tabController.index == 0 ? ContributionType.name : ContributionType.background;


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        height: 600,
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
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.pencilOutline, color: const Color(0xFF0080FF), size: 24),
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
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF0080FF),
        unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF0080FF),
        indicatorWeight: 2,
        tabs: const [
          Tab(text: '中文名称'),
          Tab(text: '背景图片'),
        ],
      ),
    );
  }

  /// 构建说明提示
  Widget _buildHintBanner(bool isDark) {
    final isNameTab = _currentType == ContributionType.name;
    final hintText = isNameTab
        ? '票数最高的名称将作为该地图的中文名显示，1小时内生效'
        : '票数最高的图片将作为该地图的背景显示，1小时内生效';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0080FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF0080FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.informationOutline,
            size: 16,
            color: const Color(0xFF0080FF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hintText,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
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
          context.read<MapContributionBloc>().add(const ClearContributionError());
        }
        if (state.submitSuccess) {
          ToastUtils.showSuccess(context, '提交成功');
        }
      },
      builder: (context, state) {
        final isNameTab = _currentType == ContributionType.name;
        final isLoading = isNameTab ? state.isLoadingNames : state.isLoadingBackgrounds;
        final isEmpty = isNameTab ? state.isNamesEmpty : state.isBackgroundsEmpty;
        final contributions = isNameTab ? state.nameContributions : state.backgroundContributions;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
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
                            child: _buildScrollIndicator(isTop: true, isDark: isDark),
                          ),
                        // 底部滚动指示器
                        if (_canScrollDown)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildScrollIndicator(isTop: false, isDark: isDark),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }


  /// 构建空状态
  /// Requirements: 5.3
  Widget _buildEmptyState(bool isDark) {
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6B7280);
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
            style: TextStyle(
              fontSize: 16,
              color: secondaryTextColor,
            ),
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
  /// Requirements: 5.1
  Widget _buildContributionList(List<MapContribution> contributions, bool isDark) {
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
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: _buildContributionItem(contribution, index, isDark),
        );
      },
    );
  }

  /// 构建滚动指示器
  Widget _buildScrollIndicator({required bool isTop, required bool isDark}) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
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
          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
          size: 24,
        ),
      ),
    );
  }


  /// 构建贡献项
  /// Requirements: 4.2, 5.2, 6.2, 6.3
  Widget _buildContributionItem(MapContribution contribution, int index, bool isDark) {
    final isNameType = contribution.type == ContributionType.name;
    final isFirst = index == 0;
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6B7280);
    // 只有自己的、被拒绝的贡献才能编辑
    final canEdit = contribution.isOwner && contribution.isRejected;
    // 是否需要显示审核相关信息
    final showAuditInfo = !contribution.isApproved;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFirst
            ? const Color(0xFF0080FF).withValues(alpha: 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(10),
        border: isFirst
            ? Border.all(color: const Color(0xFF0080FF).withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.15),
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
                        fontWeight: isFirst ? FontWeight.w600 : FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _buildImagePreview(
                        contribution.backgroundImageRef ?? contribution.content, isDark),
                  ),
          ),
          const SizedBox(width: 12),
          // 右侧信息区域
          // 有审核信息时：两行布局（审核状态+编辑 / 贡献者信息）
          // 无审核信息时：单行布局（仅贡献者信息）
          if (showAuditInfo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：审核状态和编辑按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAuditStatusBadge(contribution, isDark),
                    if (canEdit) ...[
                      const SizedBox(width: 6),
                      _buildEditButton(contribution, isDark),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // 第二行：贡献者信息（水平居中）
                _buildContributorInfo(contribution, secondaryTextColor),
              ],
            )
          else
            // 无审核信息时：单行贡献者信息
            _buildContributorInfo(contribution, secondaryTextColor),
          const SizedBox(width: 12),
          // 投票按钮
          _buildVoteButton(contribution, isDark),
        ],
      ),
    );
  }

  /// 构建贡献者信息
  Widget _buildContributorInfo(MapContribution contribution, Color secondaryTextColor) {
    // 系统数据显示"系统"标识
    if (contribution.isSystem) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.steam,
            size: 16,
            color: secondaryTextColor,
          ),
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
      constraints: const BoxConstraints(maxWidth: 100),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildContributorAvatar(contributor, size: 18),
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

  /// 构建审核状态标识
  Widget _buildAuditStatusBadge(MapContribution contribution, bool isDark) {
    final isPending = contribution.isPending;
    final color = isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final text = isPending ? '待审核' : '已拒绝';
    
    return Tooltip(
      message: contribution.isRejected && contribution.auditRemark.isNotEmpty
          ? '拒绝原因: ${contribution.auditRemark}'
          : text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  /// 构建编辑按钮
  Widget _buildEditButton(MapContribution contribution, bool isDark) {
    return Tooltip(
      message: '修改后重新提交审核',
      child: Material(
        color: const Color(0xFF0080FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => _showEditDialog(contribution),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(
              MdiIcons.pencilOutline,
              size: 16,
              color: const Color(0xFF0080FF),
            ),
          ),
        ),
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

  /// 显示编辑名称对话框
  void _showEditNameDialog(MapContribution contribution) {
    final controller = TextEditingController(text: contribution.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          '修改名称贡献',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contribution.auditRemark.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      MdiIcons.alertCircleOutline,
                      size: 16,
                      color: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '拒绝原因: ${contribution.auditRemark}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              maxLength: 50,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              decoration: InputDecoration(
                labelText: '地图中文名称',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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
                  borderSide: const BorderSide(color: Color(0xFF0080FF)),
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
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ),
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
              context.read<MapContributionBloc>().add(UpdateNameContribution(
                id: contribution.id,
                name: newName,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0080FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('提交'),
          ),
        ],
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
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            '修改背景贡献',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contribution.auditRemark.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        MdiIcons.alertCircleOutline,
                        size: 16,
                        color: const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '拒绝原因: ${contribution.auditRemark}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
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
                    if (result != null && result.files.single.path != null) {
                      final file = File(result.files.single.path!);
                      final validation = ContributionValidationUtils.validateBackgroundImage(file);
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
                          ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08))
                          : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHovered
                            ? const Color(0xFF0080FF).withValues(alpha: 0.5)
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
                                      ? const Color(0xFF0080FF)
                                      : (isDark ? Colors.white38 : Colors.black26),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '点击选择新图片',
                                style: TextStyle(
                                  color: isHovered
                                      ? const Color(0xFF0080FF)
                                      : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
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
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedImage == null
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await _uploadAndUpdateBackground(contribution.id, selectedImage!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF0080FF).withValues(alpha: 0.5),
              ),
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  /// 上传并更新背景贡献
  Future<void> _uploadAndUpdateBackground(int contributionId, File imageFile) async {
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

      context.read<MapContributionBloc>().add(UpdateBackgroundContribution(
        id: contributionId,
        fileId: result.fileId,
      ));
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
      badgeColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
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
                colors: [
                  const Color(0xFFFFD700),
                  const Color(0xFFFFA500),
                ],
              )
            : null,
        color: index == 0 ? null : badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: index == 0 ? null : Border.all(color: badgeColor.withValues(alpha: 0.4)),
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
  /// Requirements: 4.2, 5.2
  Widget _buildContributorAvatar(ContributorInfo contributor, {double size = 36}) {
    final avatarUrl = contributor.avatar;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        color: const Color(0xFF0080FF).withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              cacheKey: AppImageCacheManager.extractCacheKey(avatarUrl),
              cacheManager: AppImageCacheManager.instance,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildDefaultAvatar(contributor.username, size),
              errorWidget: (context, url, error) => _buildDefaultAvatar(contributor.username, size),
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
          color: const Color(0xFF0080FF),
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
            height: 56,
            width: 100,
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
              child: _ContributionImage(imageRef: imageUrl, fit: BoxFit.contain),
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
  /// Requirements: 3.1, 4.2, 5.2
  /// 系统数据（isSystem=true）不可投票
  Widget _buildVoteButton(MapContribution contribution, bool isDark) {
    final upCount = contribution.upCount;
    final downCount = contribution.downCount;
    final voteType = contribution.voteType;
    final isOwner = contribution.isOwner;
    final isSystem = contribution.isSystem;
    final secondaryColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    // 系统数据只显示票数，不显示投票按钮
    if (isSystem) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.thumbUp,
              size: 14,
              color: secondaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              '$upCount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secondaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              MdiIcons.thumbDown,
              size: 14,
              color: secondaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              '$downCount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 赞成按钮
        _buildSingleVoteButton(
          icon: voteType == VoteType.up ? MdiIcons.thumbUp : MdiIcons.thumbUpOutline,
          isActive: voteType == VoteType.up,
          count: upCount,
          onTap: () => _handleVote(contribution, VoteType.up),
          isDark: isDark,
          bgColor: bgColor,
          secondaryColor: secondaryColor,
        ),
        const SizedBox(width: 8),
        // 反对按钮（自己的贡献不能踩）
        _buildSingleVoteButton(
          icon: voteType == VoteType.down ? MdiIcons.thumbDown : MdiIcons.thumbDownOutline,
          isActive: voteType == VoteType.down,
          count: downCount,
          onTap: isOwner ? null : () => _handleVote(contribution, VoteType.down),
          isDark: isDark,
          bgColor: bgColor,
          secondaryColor: secondaryColor,
          isDownVote: true,
          disabled: isOwner,
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
    final activeColor = isDownVote ? const Color(0xFFEF4444) : const Color(0xFF0080FF);
    
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
              Icon(
                icon,
                size: 16,
                color: disabled
                    ? secondaryColor.withValues(alpha: 0.3)
                    : (isActive ? Colors.white : secondaryColor),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? secondaryColor.withValues(alpha: 0.3)
                      : (isActive ? Colors.white : secondaryColor),
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
    final inputBgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
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
                _buildNameInput(inputBgColor, textColor, borderColor, state.isSubmitting)
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
  Widget _buildNameInput(Color inputBgColor, Color textColor, Color borderColor, bool isSubmitting) {
    // 实时验证
    final validationError = ContributionValidationUtils.validateNameRealtime(_nameController.text);
    final hasError = validationError != null;
    final errorColor = const Color(0xFFEF4444);

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
            fillColor: hasError ? errorColor.withValues(alpha: 0.05) : inputBgColor,
            counterText: '',
            prefixIcon: Icon(
              MdiIcons.textBoxOutline,
              color: hasError ? errorColor : textColor.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: hasError ? errorColor : borderColor),
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
                color: hasError ? errorColor : const Color(0xFF0080FF),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    final textColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: inputBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
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
                    Icon(
                      MdiIcons.imagePlusOutline,
                      size: 24,
                      color: textColor,
                    ),
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
                          style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11),
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
            child: Image.file(
              _selectedImage!,
              height: 72,
              fit: BoxFit.cover,
            ),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
        onPressed: (isSubmitting || _isUploadingImage || !canSubmit) ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0080FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          disabledBackgroundColor: const Color(0xFF0080FF).withValues(alpha: 0.5),
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

  // ========== 事件处理 ==========

  /// 贡献所需的最低积分
  static const int _minCreditsRequired = 500;

  /// 检查登录状态
  /// Requirements: 1.1, 2.1, 3.1
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
    if (credits < _minCreditsRequired) {
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
        title: const Text('积分不足'),
        content: Text('贡献功能需要 $_minCreditsRequired 论坛积分，您当前积分为 $currentCredits'),
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
        content: const Text('请先绑定论坛账户后再进行此操作'),
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
              backgroundColor: const Color(0xFF0080FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('去绑定'),
          ),
        ],
      ),
    );
  }


  /// 处理投票
  /// Requirements: 3.1, 3.2, 3.3, 3.4
  void _handleVote(MapContribution contribution, VoteType voteType) {
    if (!_checkLogin()) return;
    
    context.read<MapContributionBloc>().add(ToggleVote(contribution.id, voteType));
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
        final validation = ContributionValidationUtils.validateBackgroundImage(file);
        if (!validation.isValid) {
          if (mounted) {
            ToastUtils.showError(context, validation.errorMessage!);
          }
          return;
        }

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
  /// Requirements: 1.2, 1.3, 1.4
  Future<void> _submitName() async {
    final name = _nameController.text.trim();
    
    // 验证名称
    final validation = ContributionValidationUtils.validateName(name);
    if (!validation.isValid) {
      ToastUtils.showError(context, validation.errorMessage!);
      return;
    }

    context.read<MapContributionBloc>().add(SubmitNameContribution(
      mapName: widget.mapName,
      name: name,
    ));

    // 清空输入
    _nameController.clear();
  }

  /// 提交图片贡献
  /// Requirements: 2.2, 2.3, 2.4
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
      context.read<MapContributionBloc>().add(SubmitBackgroundContribution(
        mapName: widget.mapName,
        fileId: result.fileId,
      ));

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


/// Hover 缩放效果组件
class _HoverScaleWidget extends StatefulWidget {
  final Widget child;

  const _HoverScaleWidget({
    required this.child,
  });

  @override
  State<_HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<_HoverScaleWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}

/// Hover 遮罩组件
class _HoverOverlay extends StatefulWidget {
  final Widget child;

  const _HoverOverlay({required this.child});

  @override
  State<_HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends State<_HoverOverlay> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: _isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}

/// 贡献图片组件
/// 
/// 支持 fileId 引用格式（file:xxx）和普通 URL
/// 自动获取签名 URL 并缓存
class _ContributionImage extends StatefulWidget {
  final String imageRef;
  final BoxFit fit;

  const _ContributionImage({
    required this.imageRef,
    this.fit = BoxFit.cover,
  });

  @override
  State<_ContributionImage> createState() => _ContributionImageState();
}

class _ContributionImageState extends State<_ContributionImage> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(_ContributionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageRef != widget.imageRef) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final url = await ImageUrlService.instance.getSignedUrl(widget.imageRef);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.d('加载签名URL失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _signedUrl == null) {
      return Center(
        child: Icon(
          MdiIcons.imageOff,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: _signedUrl!,
      // 使用 imageRef（file:xxx 格式）作为缓存 key，避免签名 URL 变化导致重复下载
      cacheKey: widget.imageRef,
      cacheManager: AppImageCacheManager.instance,
      fit: widget.fit,
      placeholder: (context, url) => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          MdiIcons.imageOff,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }
}
