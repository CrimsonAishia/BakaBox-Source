import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/bloc/auth/auth_bloc.dart';
import '../../../../core/bloc/map_tag/map_tag_bloc.dart';
import '../../../../core/bloc/map_tag/map_tag_event.dart';
import '../../../../core/bloc/map_tag/map_tag_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/map_tag_models.dart';
import '../../../../core/utils/toast_utils.dart';
import 'contribution_auth_mixin.dart';
import 'map_tag_chip.dart';
import '../../../../core/widgets/tag_color_picker.dart';
import '../../../../core/services/token_service.dart';
import 'tag_voters_dialogs.dart';

class MapTagContributionView extends StatefulWidget {
  final String mapName;
  final String? mapLabel;
  final bool isDifficultySeparated;
  final String? serverAddress;

  const MapTagContributionView({
    super.key,
    required this.mapName,
    this.mapLabel,
    this.isDifficultySeparated = false,
    this.serverAddress,
  });

  @override
  State<MapTagContributionView> createState() => _MapTagContributionViewState();
}

class _MapTagContributionViewState extends State<MapTagContributionView>
    with ContributionAuthMixin {
  final _tagSearchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;
  int _selectedTagFilter = -1; // -1: 全部, -2: 我的标签, 0: 未分类, >0: 具体分类ID

  @override
  void initState() {
    super.initState();
    _tagSearchController.addListener(_onTagSearchChanged);
    _scrollController.addListener(_updateScrollIndicators);
    _loadTagData();
  }

  @override
  void dispose() {
    _tagSearchController.removeListener(_onTagSearchChanged);
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    _tagSearchController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
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

  void _onTagSearchChanged() {
    setState(() {});
  }

  void _loadTagData() {
    context.read<MapTagBloc>().add(const LoadCategories());
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

    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated) {
      context.read<MapTagBloc>().add(const LoadUserTags());
    }
  }

  void handleTagVote(MapTag tag, String voteType) {
    if (!checkLogin()) return;
    context.read<MapTagBloc>().add(
      ToggleTagVote(tagId: tag.id, voteType: voteType),
    );
  }

  void showEditTagDialog(MapTag tag) {
    if (!checkLogin()) return;
    final controller = TextEditingController(text: tag.name);
    final reasonController = TextEditingController();
    String? selectedColor = tag.color;
    List<int> selectedCategoryIds = tag.categoryIds != null
        ? List.from(tag.categoryIds!)
        : [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapTagBloc = context.read<MapTagBloc>();
    final categories = mapTagBloc.state.categories;
    final isApproved = tag.isApproved;
    final isRejected = tag.isRejected;
    final needsReason = isApproved || isRejected;
    final reasonLabel = isApproved ? '变更理由' : '重新申请理由';
    final reasonHint = isApproved ? '请输入申请变更的理由' : '请输入重新申请的理由';

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
                  enabled: true,
                ),
                const SizedBox(height: 16),
                if (categories.isNotEmpty) ...[
                  Text(
                    '所属分类',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategoryIds.contains(cat.id);
                      return FilterChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.gray700),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedCategoryIds.add(cat.id);
                            } else {
                              selectedCategoryIds.remove(cat.id);
                            }
                          });
                        },
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                ],
                if (needsReason) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLength: 50,
                    maxLines: 4,
                    minLines: 4,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.gray800,
                    ),
                    decoration: InputDecoration(
                      labelText: reasonLabel,
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white54 : AppColors.gray500,
                      ),
                      hintText: reasonHint,
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
                if (needsReason && reason.isEmpty) {
                  ToastUtils.showError(dialogContext, '$reasonLabel不能为空');
                  return;
                }
                Navigator.of(dialogContext).pop();
                mapTagBloc.add(
                  UpdateTag(
                    tagId: tag.id,
                    name: newName,
                    color: selectedColor,
                    categoryIds: selectedCategoryIds,
                    editReason: needsReason ? reason : null,
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

  void showDeleteTagDialog(MapTag tag) {
    if (!checkLogin()) return;
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
                maxLength: 50,
                maxLines: 4,
                minLines: 4,
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

  void handleCancelChangeRequest(MapTag tag) {
    if (!checkLogin()) return;
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

  void showTagVotersDialog(String mapName, MapTag tag) {
    final currentServerAddress =
        context.read<MapTagBloc>().state.serverAddress ?? widget.serverAddress;
    showDialog(
      context: context,
      builder: (dialogContext) => TagVotersDialog(
        mapName: mapName,
        tag: tag,
        isDifficultySeparated: widget.isDifficultySeparated,
        serverAddress: currentServerAddress,
      ),
    );
  }

  void _showMapAllVotersDialog() {
    final currentServerAddress =
        context.read<MapTagBloc>().state.serverAddress ?? widget.serverAddress;
    showDialog(
      context: context,
      builder: (dialogContext) => MapAllVotersDialog(
        mapName: widget.mapName,
        mapLabel: widget.mapLabel,
        isDifficultySeparated: widget.isDifficultySeparated,
        serverAddress: currentServerAddress,
      ),
    );
  }

  void _showAddTagDialog() {
    if (!checkLogin()) return;
    final controller = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedColor;
    List<int> selectedCategoryIds = [];
    bool autoVote = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapTagBloc = context.read<MapTagBloc>();
    final categories = mapTagBloc.state.categories;

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
                if (categories.isNotEmpty) ...[
                  Text(
                    '所属分类',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategoryIds.contains(cat.id);
                      return FilterChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.gray700),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedCategoryIds.add(cat.id);
                            } else {
                              selectedCategoryIds.remove(cat.id);
                            }
                          });
                        },
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: reasonController,
                  maxLength: 50,
                  maxLines: 4,
                  minLines: 4,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                  decoration: InputDecoration(
                    labelText: '申请理由',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.gray500,
                    ),
                    hintText: '请解释标签作用/意义',
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
                final reason = reasonController.text.trim();
                Navigator.of(dialogContext).pop();
                mapTagBloc.add(
                  SubmitTag(
                    name: name,
                    color: selectedColor,
                    autoVote: autoVote,
                    categoryIds: selectedCategoryIds.isNotEmpty
                        ? selectedCategoryIds
                        : null,
                    reason: reason.isNotEmpty ? reason : null,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            _buildServerFilter(state, isDark),
            _buildTagSearchBar(state, isDark),
            Expanded(
              child: Stack(
                children: [
                  _buildTagList(state, isDark),
                  if (_canScrollUp)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildScrollIndicator(isTop: true, isDark: isDark),
                    ),
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
                  Positioned(
                    bottom: 0,
                    right: 16,
                    child: _buildVotedTagsPanel(state, isDark),
                  ),
                ],
              ),
            ),
            _buildTagSubmitArea(state, isDark),
          ],
        );
      },
    );
  }

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

  Widget _buildTagSearchBar(MapTagState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _tagSearchController,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索标签...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : AppColors.gray400,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                prefixIcon: Icon(
                  MdiIcons.magnify,
                  size: 18,
                  color: isDark ? Colors.white38 : AppColors.gray400,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: _tagSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          MdiIcons.close,
                          size: 16,
                          color: isDark ? Colors.white38 : AppColors.gray400,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _tagSearchController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey[100],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(state, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(MapTagState state, bool isDark) {
    String currentText = '全部标签';
    if (_selectedTagFilter == -2) {
      currentText = '我的标签';
    } else if (_selectedTagFilter == 0) {
      currentText = '未分类';
    } else if (_selectedTagFilter > 0) {
      final cat = state.categories
          .where((c) => c.id == _selectedTagFilter)
          .firstOrNull;
      if (cat != null) currentText = cat.name;
    }

    final items = <DropdownMenuItem<int>>[
      DropdownMenuItem(
        value: -1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.all_inclusive,
              size: 16,
              color: _selectedTagFilter == -1
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              '全部标签',
              style: TextStyle(
                color: _selectedTagFilter == -1
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: -2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 16,
              color: _selectedTagFilter == -2
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              '我的标签',
              style: TextStyle(
                color: _selectedTagFilter == -2
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    ];

    for (final cat in state.categories) {
      items.add(
        DropdownMenuItem(
          value: cat.id,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 16,
                color: _selectedTagFilter == cat.id
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 8),
              Text(
                cat.name,
                style: TextStyle(
                  color: _selectedTagFilter == cat.id
                      ? AppColors.primary
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    }

    items.add(
      DropdownMenuItem(
        value: 0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.device_unknown_outlined,
              size: 16,
              color: _selectedTagFilter == 0
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              '未分类',
              style: TextStyle(
                color: _selectedTagFilter == 0
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ]
              : [Colors.white, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedTagFilter,
          isDense: true,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          dropdownColor: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 8,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedTagFilter = value;
              });
            }
          },
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Container(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentText,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          items: items,
        ),
      ),
    );
  }

  Widget _buildTagList(MapTagState state, bool isDark) {
    final query = _tagSearchController.text.trim().toLowerCase();
    final currentUserId = TokenService.instance.userInfo?.id;

    final seen = <int>{};
    final allTags = <MapTag>[
      ...state.userTags, // pending/rejected (always mine)
      ...state.tagList, // approved (global)
    ].where((t) => seen.add(t.id)).toList();

    var filtered = allTags
        .where((t) => query.isEmpty || t.name.toLowerCase().contains(query))
        .toList();

    if (_selectedTagFilter == -2) {
      filtered = filtered.where((t) {
        final isContributor =
            currentUserId != null && t.contributor?.userId == currentUserId;
        final isUserTag = state.userTags.any((ut) => ut.id == t.id);
        return isContributor || isUserTag;
      }).toList();
    } else if (_selectedTagFilter > 0) {
      filtered = filtered
          .where((t) => t.categoryIds?.contains(_selectedTagFilter) ?? false)
          .toList();
    } else if (_selectedTagFilter == 0) {
      filtered = filtered.where((t) {
        if (t.isDifficulty == true &&
            (t.difficultyType == 'difficulty' || t.difficultyType == 'tier')) {
          return false;
        }
        return t.categoryIds == null || t.categoryIds!.isEmpty;
      }).toList();
    }

    filtered.sort((a, b) {
      final av = state.getMapTagVoteByTagId(a.id)?.voteCount ?? 0;
      final bv = state.getMapTagVoteByTagId(b.id)?.voteCount ?? 0;
      return bv.compareTo(av);
    });

    final difficultyTags = filtered
        .where(
          (t) => t.isDifficulty == true && t.difficultyType == 'difficulty',
        )
        .toList();
    final tierTags = filtered
        .where((t) => t.isDifficulty == true && t.difficultyType == 'tier')
        .toList();
    final normalTags = filtered
        .where(
          (t) =>
              !(t.isDifficulty == true &&
                  (t.difficultyType == 'difficulty' ||
                      t.difficultyType == 'tier')),
        )
        .toList();

    final Map<int, List<MapTag>> tagsByCategory = {};
    for (final cat in state.categories) {
      tagsByCategory[cat.id] = [];
    }
    final List<MapTag> uncategorizedTags = [];

    for (final tag in normalTags) {
      if (tag.categoryIds != null && tag.categoryIds!.isNotEmpty) {
        bool placed = false;
        for (final cid in tag.categoryIds!) {
          if (tagsByCategory.containsKey(cid)) {
            tagsByCategory[cid]!.add(tag);
            placed = true;
          }
        }
        if (!placed) uncategorizedTags.add(tag);
      } else {
        uncategorizedTags.add(tag);
      }
    }

    final hasNoTags =
        filtered.isEmpty && !state.isLoadingTagList && !state.isLoadingUserTags;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

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
              query.isNotEmpty || _selectedTagFilter != -1
                  ? '没有找到匹配的标签'
                  : '暂无标签',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty || _selectedTagFilter != -1
                  ? '试试其他条件吧'
                  : '成为第一个贡献者吧！',
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            for (final cat in state.categories)
              if (tagsByCategory[cat.id]!.isNotEmpty)
                _buildTagSection(
                  title: cat.name,
                  tags: tagsByCategory[cat.id]!,
                  isLoading: false,
                  isDark: isDark,
                  state: state,
                  isUserSection: false,
                  mapName: widget.mapName,
                ),
            if (uncategorizedTags.isNotEmpty)
              _buildTagSection(
                title: '未分类标签',
                tags: uncategorizedTags,
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
          TagGrid(
            tags: tags,
            state: state,
            isDark: isDark,
            isUserSection: isUserSection,
            mapName: mapName,
            onVote: handleTagVote,
            onEdit: showEditTagDialog,
            onDelete: showDeleteTagDialog,
            onCancelChangeRequest: handleCancelChangeRequest,
            onShowVoters: (mapName, tag) => showTagVotersDialog(mapName, tag),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScrollIndicator({required bool isTop, required bool isDark}) {
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final iconColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.3,
    );
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.8),
              bgColor.withValues(alpha: 0),
            ],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(top: isTop ? 4 : 0, bottom: isTop ? 0 : 4),
          child: Icon(
            isTop
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildVotedTagsPanel(MapTagState state, bool isDark) {
    final seen = <int>{};
    final allUniqueTags = [
      ...state.userTags,
      ...state.tagList,
    ].where((t) => seen.add(t.id)).toList();
    final votedTags = allUniqueTags
        .where((t) => (state.getMapTagVoteByTagId(t.id)?.voteCount ?? 0) > 0)
        .toList();

    if (votedTags.isEmpty) return const SizedBox.shrink();

    votedTags.sort((a, b) {
      final av = state.getMapTagVoteByTagId(a.id)?.voteCount ?? 0;
      final bv = state.getMapTagVoteByTagId(b.id)?.voteCount ?? 0;
      return bv.compareTo(av);
    });

    return VotedTagsFloatingPanel(
      votedTags: votedTags,
      state: state,
      isDark: isDark,
      mapName: widget.mapName,
      onVote: handleTagVote,
      onEdit: showEditTagDialog,
      onDelete: showDeleteTagDialog,
      onCancelChangeRequest: handleCancelChangeRequest,
      onShowVoters: (mapName, tag) => showTagVotersDialog(mapName, tag),
    );
  }

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
}
