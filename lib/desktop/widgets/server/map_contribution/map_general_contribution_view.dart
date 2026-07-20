import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../core/bloc/map_contribution/map_contribution_bloc.dart';
import '../../../../core/bloc/map_contribution/map_contribution_event.dart';
import '../../../../core/bloc/map_contribution/map_contribution_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/map_contribution_models.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../../../core/utils/contribution_validation_utils.dart';
import '../../../../core/utils/log_service.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/widgets/disk_cached_image.dart';
import '../../../../core/widgets/image_viewer_dialog.dart';
import 'contribution_auth_mixin.dart';
import 'contribution_image_widgets.dart';

class MapGeneralContributionView extends StatefulWidget {
  final String mapName;
  final ContributionType type;

  const MapGeneralContributionView({
    super.key,
    required this.mapName,
    required this.type,
  });

  @override
  State<MapGeneralContributionView> createState() =>
      _MapGeneralContributionViewState();
}

class _MapGeneralContributionViewState extends State<MapGeneralContributionView>
    with ContributionAuthMixin {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _canScrollUp = false;
  bool _canScrollDown = false;
  File? _selectedImage;
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _scrollController.addListener(_updateScrollIndicators);
    _loadContributions();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
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

  void _loadContributions() {
    context.read<MapContributionBloc>().add(
      widget.type == ContributionType.name
          ? LoadNameContributions(mapName: widget.mapName)
          : LoadBackgroundContributions(mapName: widget.mapName),
    );
  }

  void _handleVote(MapContribution contribution, String voteType) {
    if (!checkLogin()) return;
    context.read<MapContributionBloc>().add(
      ToggleVote(
        contribution.id,
        voteType == 'up' ? VoteType.up : VoteType.down,
      ),
    );
  }

  void _handleDelete(MapContribution contribution) {
    if (!checkLogin()) return;
    context.read<MapContributionBloc>().add(
      widget.type == ContributionType.name
          ? DeleteNameContribution(id: contribution.id)
          : DeleteBackgroundContribution(id: contribution.id),
    );
  }

  void _showDeleteConfirmDialog(MapContribution contribution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        content: Text(
          '确定要删除这条贡献吗？删除后无法恢复。',
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
              _handleDelete(contribution);
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

  void _showEditDialog(MapContribution contribution) {
    if (widget.type == ContributionType.name) {
      _showEditNameDialog(contribution);
    } else {
      _showEditBackgroundDialog(contribution);
    }
  }

  void _showEditNameDialog(MapContribution contribution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editController = TextEditingController(text: contribution.content);
    final mapContributionBloc = context.read<MapContributionBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.slate800 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '修改名称贡献',
          style: TextStyle(color: isDark ? Colors.white : AppColors.gray800),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLength: 50,
          style: TextStyle(color: isDark ? Colors.white : AppColors.gray800),
          decoration: InputDecoration(
            labelText: '新的中文名称',
            labelStyle: TextStyle(
              color: isDark ? Colors.white54 : AppColors.gray500,
            ),
            hintText: '输入地图的中文名称',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppColors.gray500,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              final newName = editController.text.trim();
              final validation = ContributionValidationUtils.validateName(
                newName,
              );
              if (!validation.isValid) {
                ToastUtils.showError(dialogContext, validation.errorMessage!);
                return;
              }
              Navigator.of(dialogContext).pop();
              mapContributionBloc.add(
                UpdateNameContribution(id: contribution.id, name: newName),
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
    );
  }

  void _showEditBackgroundDialog(MapContribution contribution) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    File? newSelectedImage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final blockBgColor = isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03);
          final borderColor = isDark ? Colors.white24 : Colors.black12;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.slate800 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              '修改背景图片',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前图片',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: blockBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: ContributionImage(
                        imageRef: contribution.content,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '新图片',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                        );
                        if (result != null &&
                            result.files.single.path != null) {
                          final file = File(result.files.single.path!);
                          final sizeInMb = file.lengthSync() / (1024 * 1024);
                          if (sizeInMb > 5) {
                            if (context.mounted) {
                              ToastUtils.showError(context, '图片大小不能超过 5MB');
                            }
                            return;
                          }
                          setDialogState(() {
                            newSelectedImage = file;
                          });
                        }
                      } catch (e) {
                        LogService.e('选择图片失败', e);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: blockBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: newSelectedImage != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.file(
                                    newSelectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => setDialogState(
                                        () => newSelectedImage = null,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  MdiIcons.imagePlus,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击选择新图片',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                    ),
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
                onPressed: newSelectedImage == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        _uploadAndUpdateBackground(
                          contribution.id,
                          newSelectedImage!,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('上传并提交'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _uploadAndUpdateBackground(
    int contributionId,
    File imageFile,
  ) async {
    final mapContributionBloc = context.read<MapContributionBloc>();
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadToImageBed(
        imageFile,
        categoryName: 'bakabox_map_backgrounds',
      );
      if (!mounted) return;
      mapContributionBloc.add(
        UpdateBackgroundContribution(id: contributionId, fileId: result.fileId),
      );
    } catch (e) {
      LogService.e('上传新图片失败', e);
      if (mounted) {
        ToastUtils.showError(context, '图片上传失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showFullImage(String imageRef) {
    ImageViewerDialog.show(context, imageUrls: [imageRef]);
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final sizeInMb = file.lengthSync() / (1024 * 1024);
        if (sizeInMb > 5) {
          if (mounted) {
            ToastUtils.showError(context, '图片大小不能超过 5MB');
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

  Future<void> _handleSubmit() async {
    if (!checkLogin()) return;
    if (!checkCredits()) return;

    if (widget.type == ContributionType.name) {
      final name = _nameController.text.trim();
      final validation = ContributionValidationUtils.validateName(name);
      if (!validation.isValid) {
        ToastUtils.showError(context, validation.errorMessage!);
        return;
      }
      context.read<MapContributionBloc>().add(
        SubmitNameContribution(mapName: widget.mapName, name: name),
      );
      _nameController.clear();
    } else {
      if (_selectedImage == null) {
        ToastUtils.showError(context, '请先选择图片');
        return;
      }
      setState(() {
        _isUploadingImage = true;
        _uploadProgress = 0.0;
      });
      try {
        final uploadService = FileUploadService();
        final result = await uploadService.uploadToImageBed(
          _selectedImage!,
          categoryName: 'bakabox_map_backgrounds',
        );
        if (!mounted) return;
        context.read<MapContributionBloc>().add(
          SubmitBackgroundContribution(
            mapName: widget.mapName,
            fileId: result.fileId,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<MapContributionBloc, MapContributionState>(
      listener: (context, state) {
        if (state.error != null) {
          ToastUtils.showError(context, state.error!);
          context.read<MapContributionBloc>().add(
            const ClearContributionError(),
          );
        }
        if (state.submitSuccess) {
          ToastUtils.showSuccess(context, '提交成功，感谢您的贡献！');
        }
        if (state.deleteSuccess) {
          ToastUtils.showSuccess(context, '删除成功');
        }
      },
      builder: (context, state) {
        final isLoading = widget.type == ContributionType.name
            ? state.isLoadingNames
            : state.isLoadingBackgrounds;
        final isEmpty = widget.type == ContributionType.name
            ? state.isNamesEmpty
            : state.isBackgroundsEmpty;
        final contributions = widget.type == ContributionType.name
            ? state.nameContributions
            : state.backgroundContributions;

        return Column(
          children: [
            _buildHintBanner(isDark),
            Expanded(
              child: Stack(
                children: [
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  else if (isEmpty)
                    _buildEmptyState(isDark)
                  else
                    _buildContributionList(contributions, isDark, state),
                  if (_canScrollUp && !isLoading && !isEmpty)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildScrollIndicator(isTop: true, isDark: isDark),
                    ),
                  if (_canScrollDown && !isLoading && !isEmpty)
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
            _buildSubmitArea(state, isDark),
          ],
        );
      },
    );
  }

  Widget _buildHintBanner(bool isDark) {
    final isNameTab = widget.type == ContributionType.name;
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

  Widget _buildEmptyState(bool isDark) {
    final secondaryTextColor = isDark ? Colors.white54 : AppColors.gray500;
    final isNameTab = widget.type == ContributionType.name;

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

  Widget _buildContributionList(
    List<MapContribution> contributions,
    bool isDark,
    MapContributionState state,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

    final sortedContributions = List<MapContribution>.from(contributions);
    sortedContributions.sort((a, b) {
      if (a.voteCount != b.voteCount) return b.voteCount.compareTo(a.voteCount);
      return b.createdAt.compareTo(a.createdAt);
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: sortedContributions.length,
      itemBuilder: (context, index) {
        return _buildContributionItem(
          sortedContributions[index],
          index,
          isDark,
          state,
        );
      },
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

  Widget _buildContributionItem(
    MapContribution contribution,
    int index,
    bool isDark,
    MapContributionState state,
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
                        child: _buildImagePreview(contribution.content, isDark),
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
          _buildContributorAvatar(contributor.avatar, size: 36),
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

  Widget _buildContributorAvatar(String? avatarUrl, {double size = 32}) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultAvatar(size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: DiskCachedImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: _buildDefaultAvatar(size),
        errorWidget: _buildDefaultAvatar(size),
      ),
    );
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: size * 0.6, color: AppColors.primary),
    );
  }

  Widget _buildImagePreview(String imageRef, bool isDark) {
    return InkWell(
      onTap: () => _showFullImage(imageRef),
      child: HoverScaleWidget(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 54, // 16:9比例 (54*16/9=96)
              width: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: ContributionImage(imageRef: imageRef, fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: HoverOverlay(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.zoom_in, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(MapContribution contribution, bool isDark) {
    if (contribution.isPending || contribution.isRejected) {
      return const SizedBox.shrink();
    }

    final hasUpvoted = contribution.voteType == VoteType.up;
    final hasDownvoted = contribution.voteType == VoteType.down;

    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSingleVoteButton(
            icon: hasUpvoted ? MdiIcons.thumbUp : MdiIcons.thumbUpOutline,
            count: contribution.upCount,
            isSelected: hasUpvoted,
            isDark: isDark,
            isUp: true,
            onTap: () => _handleVote(contribution, 'up'),
          ),
          Container(
            width: 1,
            height: 16,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          _buildSingleVoteButton(
            icon: hasDownvoted ? MdiIcons.thumbDown : MdiIcons.thumbDownOutline,
            count: contribution.downCount,
            isSelected: hasDownvoted,
            isDark: isDark,
            isUp: false,
            onTap: () => _handleVote(contribution, 'down'),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleVoteButton({
    required IconData icon,
    required int count,
    required bool isSelected,
    required bool isDark,
    required bool isUp,
    required VoidCallback onTap,
  }) {
    final defaultColor = isDark ? Colors.white70 : AppColors.gray500;
    final activeColor = isUp ? AppColors.green500 : AppColors.red500;
    final color = isSelected ? activeColor : defaultColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitArea(MapContributionState state, bool isDark) {
    final inputBgColor = isDark ? AppColors.slate700 : AppColors.slate100;
    final textColor = isDark ? Colors.white : AppColors.gray800;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final isNameTab = widget.type == ContributionType.name;

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
  }

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

  Widget _buildSubmitButton(bool isSubmitting) {
    final isNameTab = widget.type == ContributionType.name;
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
}
