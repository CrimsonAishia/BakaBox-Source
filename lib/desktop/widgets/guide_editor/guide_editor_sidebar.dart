import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/guide_api.dart';
import '../../../core/api/map_contribution_api.dart';
import '../../../core/bloc/auth/auth_state.dart';
import '../../../core/bloc/auth/auth_bloc.dart';
import '../../../core/bloc/guide_categories/guide_categories_bloc.dart';
import '../../../core/bloc/guide_categories/guide_categories_event.dart';
import '../../../core/bloc/guide_categories/guide_categories_state.dart';
import '../../../core/bloc/guide_editor/guide_editor_bloc.dart';
import '../../../core/bloc/guide_editor/guide_editor_event.dart';
import '../../../core/bloc/guide_editor/guide_editor_state.dart';
import '../../../core/bloc/guide_tag_suggest/guide_tag_suggest_bloc.dart';
import '../../../core/bloc/guide_tag_suggest/guide_tag_suggest_event.dart';
import '../../../core/bloc/guide_tag_suggest/guide_tag_suggest_state.dart';
import '../../../core/models/guide_models.dart';
import '../../../core/models/map_contribution_models.dart';
import '../../../core/services/desktop_navigator.dart';
import '../../../core/services/file_upload_service.dart';
import '../../../core/services/image_url_service.dart';
import '../../../core/utils/file_validation_utils.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/widgets/guide/guide_compact_card.dart';
import '../../../core/widgets/guide/guide_map_picker_sheet.dart';
import '../../../core/widgets/map_background.dart';
import '../common_scroll_indicator.dart';
import '../guide/community_guide/community_guide_theme.dart';
import '../../../core/constants/app_colors.dart';

// ─── 视觉常量（参考原型）────────────────────────────────────────────────
///
/// 颜色相关字段为实例成员，通过 `_T.of(context)` 获取，自动适配亮/暗主题。
/// 圆角常量为静态字段，与主题无关。
class _T {
  // 卡片底色 / 字段底色
  final Color cardBg;
  final Color fieldBg;
  final Color fieldBgHover;
  final Color borderSoft;
  final Color borderHover;
  final Color accent;
  final Color accentHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color danger;
  final Color success;

  // 圆角（静态，与主题无关）
  static const double radiusCard = 14;
  static const double radiusField = 10;

  const _T._({
    required this.cardBg,
    required this.fieldBg,
    required this.fieldBgHover,
    required this.borderSoft,
    required this.borderHover,
    required this.accent,
    required this.accentHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.danger,
    required this.success,
  });

  factory _T.of(BuildContext context) {
    final colors = CommunityGuideColors.of(context);
    if (colors.isDark) {
      return const _T._(
        cardBg: Color(0xFF131B2C),
        fieldBg: Color(0xFF1F2A3D),
        fieldBgHover: Color(0xFF263247),
        borderSoft: Color(0x1FFFFFFF),
        borderHover: Color(0x40FFFFFF),
        accent: Color(0xFF2196F3),
        accentHover: Color(0xFF42A5F5),
        textPrimary: AppColors.slate100,
        textSecondary: AppColors.slate300,
        textMuted: AppColors.slate400,
        danger: AppColors.red500,
        success: AppColors.green500,
      );
    }
    return const _T._(
      cardBg: Colors.white,
      fieldBg: AppColors.slate50,
      fieldBgHover: AppColors.slate200,
      borderSoft: AppColors.gray200,
      borderHover: AppColors.slate300,
      accent: Color(0xFF2196F3),
      accentHover: Color(0xFF1976D2),
      textPrimary: AppColors.gray800,
      textSecondary: AppColors.gray700,
      textMuted: AppColors.gray500,
      danger: AppColors.red500,
      success: AppColors.green500,
    );
  }
}

/// 攻略编辑器左侧 Sidebar（卡片化 + 可滚动 + 顶/底渐隐指示器）
///
/// 风格参考原型：深蓝卡片 + 圆角 + 微描边 + 字段块比卡片略亮以保证对比度。
/// 底部固定 保存草稿 / 提交 操作。
class GuideEditorSidebar extends StatefulWidget {
  const GuideEditorSidebar({super.key});

  @override
  State<GuideEditorSidebar> createState() => _GuideEditorSidebarState();
}

class _GuideEditorSidebarState extends State<GuideEditorSidebar> {
  final ScrollController _scrollController = ScrollController();
  bool _showTopIndicator = false;
  bool _showBottomIndicator = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicators());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateIndicators() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canScroll = pos.maxScrollExtent > 0;
    final showTop = canScroll && pos.pixels > 4;
    final showBottom = canScroll && pos.pixels < pos.maxScrollExtent - 4;
    if (showTop != _showTopIndicator || showBottom != _showBottomIndicator) {
      setState(() {
        _showTopIndicator = showTop;
        _showBottomIndicator = showBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return SizedBox(
      width: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_T.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(_T.radiusCard),
            border: Border.all(color: colors.borderSoft),
          ),
          child: BlocBuilder<GuideEditorBloc, GuideEditorState>(
            builder: (context, editorState) {
              return Column(
                children: [
                  Expanded(child: _buildScrollableForm(editorState)),
                  Container(height: 1, color: colors.borderSoft),
                  _FooterActions(state: editorState),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableForm(GuideEditorState editorState) {
    final colors = _T.of(context);
    return Stack(
      children: [
        ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(
              colors.accent.withValues(alpha: 0.6),
            ),
            thickness: WidgetStateProperty.all(4),
            radius: const Radius.circular(2),
            crossAxisMargin: 2,
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(6, 14, 10, 14),
              children: [
                _CoverUploadSlot(coverUrl: editorState.draft?.coverUrl),
                const SizedBox(height: 12),
                _CategoryDropdown(selectedCode: editorState.draft?.category),
                const SizedBox(height: 12),
                _MapAssociationSection(mapName: editorState.draft?.mapName),
                const SizedBox(height: 12),
                _TagsInput(tags: editorState.draft?.tags ?? const []),
                const SizedBox(height: 12),
                _SummaryInput(summary: editorState.draft?.summary),
                const SizedBox(height: 12),
                _ValidationChecklist(errors: editorState.validateErrors),
              ],
            ),
          ),
        ),
        // 顶/底渐隐指示器（提示用户上下还有内容）
        if (_showTopIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(
              isTop: true,
              bgColor: colors.cardBg,
            ),
          ),
        if (_showBottomIndicator)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(
              isTop: false,
              bgColor: colors.cardBg,
            ),
          ),
      ],
    );
  }
}

// ─── 封面上传槽 ────────────────────────────────────────────────────────────

class _CoverUploadSlot extends StatefulWidget {
  final String? coverUrl;
  const _CoverUploadSlot({this.coverUrl});

  @override
  State<_CoverUploadSlot> createState() => _CoverUploadSlotState();
}

class _CoverUploadSlotState extends State<_CoverUploadSlot> {
  final FileUploadService _uploadService = FileUploadService();
  bool _hovering = false;
  bool _isUploading = false;
  double _uploadProgress = 0;

  /// 已签名 URL 缓存（针对 fileId 引用）
  Future<String>? _signedCoverFuture;

  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  @override
  void didUpdateWidget(covariant _CoverUploadSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _resolveCover();
    }
  }

  void _resolveCover() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty) {
      _signedCoverFuture = null;
      return;
    }
    _signedCoverFuture = ImageUrlService.instance.getSignedUrl(url);
  }

  Future<void> _handleUpload() async {
    if (_isUploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.path == null) return;

      final file = File(picked.path!);

      final validation = FileValidationUtils.validateFile(file);
      if (!validation.isValid) {
        if (mounted) {
          ToastUtils.showError(
            context,
            validation.errorMessage ?? '文件验证失败',
          );
        }
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      // 上传到图床（与 RichTextEditor 走同一服务）
      final uploadResult = await _uploadService.uploadToImageBed(file);

      if (!mounted) return;

      // 存为 fileId 引用，与项目其他模块一致（评论 / 攻略正文 / 头像等）
      final ref = ImageUrlService.createFileIdRef(uploadResult.fileId);
      context.read<GuideEditorBloc>().add(UpdateCover(ref));

      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });

      ToastUtils.showSuccess(context, '封面上传成功');
    } catch (e) {
      LogService.e('封面上传失败', e);
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
        ToastUtils.showError(context, '封面上传失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    final hasCover =
        widget.coverUrl != null && widget.coverUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: '16:9 封面'),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: MouseRegion(
            cursor: _isUploading
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: colors.fieldBg,
                borderRadius: BorderRadius.circular(_T.radiusField),
                border: Border.all(
                  color: _hovering ? colors.accent : colors.borderSoft,
                  width: _hovering ? 1.4 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(_T.radiusField),
                  onTap: _isUploading ? null : _handleUpload,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_T.radiusField),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasCover)
                          _buildCoverImage()
                        else
                          _buildEmptyState(),
                        // hover 蒙层（已选时显示「点击替换封面」）
                        if (hasCover && !_isUploading)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _hovering ? 1 : 0,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.file_upload_outlined,
                                      size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    '点击替换封面',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // 上传中状态
                        if (_isUploading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _uploadProgress > 0 && _uploadProgress < 1
                                      ? '上传中 ${(_uploadProgress * 100).toInt()}%'
                                      : '上传中...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final colors = _T.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 28,
            color: colors.textMuted,
          ),
          const SizedBox(height: 6),
          Text(
            '点击上传封面',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    final colors = _T.of(context);
    if (_signedCoverFuture == null) {
      return Container(color: colors.fieldBg);
    }
    return FutureBuilder<String>(
      future: _signedCoverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            color: colors.fieldBg,
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.textMuted,
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: colors.fieldBg,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: colors.textMuted,
            ),
          );
        }
        return DiskCachedImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          // 限制解码尺寸，节省内存
          cacheWidth: 800,
        );
      },
    );
  }
}

// ─── 分类下拉 ────────────────────────────────────────────────────────────────

class _CategoryDropdown extends StatefulWidget {
  final String? selectedCode;
  const _CategoryDropdown({this.selectedCode});

  @override
  State<_CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<_CategoryDropdown> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: '分类', required: true),
        const SizedBox(height: 8),
        BlocBuilder<GuideCategoriesBloc, GuideCategoriesState>(
          builder: (context, catState) {
            if (catState.status == CategoriesStatus.failure) {
              return const _CategoryFailedState();
            }
            if (catState.status == CategoriesStatus.loading) {
              return _buildLoadingDropdown();
            }
            final isAdmin =
                _checkIsAdmin(context.read<AuthBloc>().state);
            final categories = catState.items.where((cat) {
              if (!cat.isActive) return false;
              if (cat.isAdminOnly && !isAdmin) return false;
              return true;
            }).toList();
            return MouseRegion(
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: _buildDropdown(context, categories),
            );
          },
        ),
      ],
    );
  }

  bool _checkIsAdmin(AuthState authState) {
    final userGroup = authState.userInfo?.userGroup;
    if (userGroup == null) return false;
    return userGroup.toLowerCase().contains('admin') ||
        userGroup.toLowerCase().contains('管理');
  }

  Widget _buildLoadingDropdown() {
    final colors = _T.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _fieldDecoration(context),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '加载分类中...',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    List<GuideCategoryDef> categories,
  ) {
    final colors = _T.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _fieldDecoration(context, hovering: _hovering),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (widget.selectedCode?.isEmpty ?? true) ? null : widget.selectedCode,
          hint: Text(
            '选择分类',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
          dropdownColor: colors.fieldBg,
          borderRadius: BorderRadius.circular(_T.radiusField),
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
          items: categories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat.code,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (code) {
            if (code != null) {
              context.read<GuideEditorBloc>().add(UpdateCategory(code));
            }
          },
        ),
      ),
    );
  }
}

class _CategoryFailedState extends StatelessWidget {
  const _CategoryFailedState();

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(_T.radiusField),
        border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text('分类加载失败',
                style: TextStyle(fontSize: 12, color: colors.danger)),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<GuideCategoriesBloc>()
                  .add(const LoadCategories(force: true));
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colors.accent,
            ),
            child: const Text('重试', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── 关联地图 ────────────────────────────────────────────────────────────────

class _MapAssociationSection extends StatefulWidget {
  final String? mapName;
  const _MapAssociationSection({this.mapName});

  @override
  State<_MapAssociationSection> createState() => _MapAssociationSectionState();
}

class _MapAssociationSectionState extends State<_MapAssociationSection> {
  Timer? _debounceTimer;
  List<GuideListItem>? _mapGuides;
  int _mapGuidesTotal = 0;
  bool _isLoadingGuides = false;
  bool _hovering = false;

  /// 完整的 MapInfo（用于显示 mapLabel + mapBackground）。
  /// 选择器关闭时由父级回填；从服务端草稿加载时通过 [_fetchMapInfo] 异步获取。
  MapInfo? _mapInfo;
  bool _isLoadingMapInfo = false;

  @override
  void initState() {
    super.initState();
    if (widget.mapName != null && widget.mapName!.isNotEmpty) {
      _fetchMapInfo(widget.mapName!);
      _onMapChanged();
    }
  }

  @override
  void didUpdateWidget(_MapAssociationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapName != widget.mapName) {
      // 草稿中地图变化时，若已缓存的 MapInfo 与新 mapName 不一致则重置并重新拉取
      if (widget.mapName == null || widget.mapName!.isEmpty) {
        _mapInfo = null;
      } else if (_mapInfo == null || _mapInfo!.mapName != widget.mapName) {
        _fetchMapInfo(widget.mapName!);
      }
      _onMapChanged();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 通过地图数据库接口反查 MapInfo（仅在父级未直接提供时调用）
  Future<void> _fetchMapInfo(String mapName) async {
    if (!mounted) return;
    setState(() => _isLoadingMapInfo = true);
    try {
      final response = await MapContributionApi().getAllMaps(
        MapListRequest(
          pagination: const PaginationParams(pageIndex: 1, pageSize: 1),
          mapName: mapName,
        ),
      );
      final hit = response?.items.firstWhere(
        (m) => m.mapName == mapName,
        orElse: () => MapInfo(mapName: mapName, mapLabel: mapName),
      );
      if (mounted) {
        setState(() {
          _mapInfo = hit;
          _isLoadingMapInfo = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mapInfo = MapInfo(mapName: mapName, mapLabel: mapName);
          _isLoadingMapInfo = false;
        });
      }
    }
  }

  void _onMapChanged() {
    _debounceTimer?.cancel();
    if (widget.mapName == null || widget.mapName!.isEmpty) {
      setState(() {
        _mapGuides = null;
        _mapGuidesTotal = 0;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), _loadMapGuides);
  }

  Future<void> _loadMapGuides() async {
    if (!mounted || widget.mapName == null) return;
    setState(() => _isLoadingGuides = true);

    try {
      final response = await GuideApi().getGuides(
        query: GuideListQuery(
          mapName: widget.mapName,
          pageSize: 3,
          sortBy: GuideSortBy.hot,
        ),
      );
      if (mounted) {
        setState(() {
          _mapGuides = response.items;
          _mapGuidesTotal = response.total;
          _isLoadingGuides = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingGuides = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: '关联地图(可选)'),
        const SizedBox(height: 8),
        _buildMapSelector(context),
        if (widget.mapName != null && widget.mapName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildMapGuidesPreview(context),
        ],
      ],
    );
  }

  Widget _buildMapSelector(BuildContext context) {
    final hasMap = widget.mapName != null && widget.mapName!.isNotEmpty;
    if (!hasMap) {
      return _buildEmptySelector(context);
    }
    return _buildSelectedCard(context);
  }

  /// 未选中时的空槽位（与已选时完全相同的高度，只是无背景图 + 提示文案）
  Widget _buildEmptySelector(BuildContext context) {
    final colors = _T.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_T.radiusField),
          border: Border.all(
            color: _hovering ? colors.accent : colors.borderSoft,
            width: _hovering ? 1.4 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_T.radiusField),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: colors.fieldBg)),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_T.radiusField),
                      onTap: () => _openMapPicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: colors.borderSoft,
                              ),
                              child: Icon(
                                Icons.map_outlined,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '点击选择关联地图',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ],
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

  /// 已选中时的卡片：固定高度 64，带地图背景图 + 渐变遮罩 + 白字 + 译名/原名前图标
  Widget _buildSelectedCard(BuildContext context) {
    final colors = _T.of(context);
    final info = _mapInfo;
    final displayLabel = info?.mapLabel ?? widget.mapName!;
    final mapNameSlug = widget.mapName!;
    final hasBackground =
        info?.mapBackground != null && info!.mapBackground!.isNotEmpty;
    final hasDifferentLabel = displayLabel != mapNameSlug;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_T.radiusField),
          border: Border.all(
            color: _hovering ? colors.accent : colors.borderSoft,
            width: _hovering ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.25 : 0.12),
              blurRadius: _hovering ? 10 : 4,
              offset: Offset(0, _hovering ? 4 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_T.radiusField),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                if (hasBackground)
                  Positioned.fill(
                    child: MapBackground(
                      mapName: mapNameSlug,
                      imageUrl: info.mapBackground,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                    ),
                  )
                else
                  Positioned.fill(child: Container(color: colors.fieldBg)),
                if (hasBackground)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (_isLoadingMapInfo && !hasBackground)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_T.radiusField),
                      onTap: () => _openMapPicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 译名（中文）：使用翻译图标
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.translate,
                                        size: 13,
                                        color: hasBackground
                                            ? Colors.white
                                                .withValues(alpha: 0.95)
                                            : colors.textPrimary,
                                        shadows: hasBackground
                                            ? [
                                                Shadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          displayLabel,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: hasBackground
                                                ? Colors.white
                                                : colors.textPrimary,
                                            shadows: hasBackground
                                                ? [
                                                    Shadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.6),
                                                      blurRadius: 4,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 原名（slug）：使用地图图标
                                  if (hasDifferentLabel) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.map_outlined,
                                          size: 12,
                                          color: hasBackground
                                              ? Colors.white
                                                  .withValues(alpha: 0.7)
                                              : colors.textMuted,
                                          shadows: hasBackground
                                              ? [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.6),
                                                    blurRadius: 4,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            mapNameSlug,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: hasBackground
                                                  ? Colors.white
                                                      .withValues(alpha: 0.78)
                                                  : colors.textMuted,
                                              shadows: hasBackground
                                                  ? [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.6),
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // 点击卡片本身就能打开选择器替换地图，所以这里只保留指示器图标
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: hasBackground
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : colors.textSecondary,
                            ),
                          ],
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

  Future<void> _openMapPicker(BuildContext context) async {
    final editorBloc = context.read<GuideEditorBloc>();
    final selected = await GuideMapPickerSheet.show(
      context,
      current: _mapInfo,
    );
    if (!mounted) return;
    if (selected == null && _mapInfo != null) {
      // 移除关联
      setState(() => _mapInfo = null);
      editorBloc.add(const UpdateMap(null));
    } else if (selected != null) {
      // 缓存完整的 MapInfo（包含 mapBackground / mapLabel）
      setState(() => _mapInfo = selected);
      editorBloc.add(UpdateMap(selected));
    }
  }

  Widget _buildMapGuidesPreview(BuildContext context) {
    final colors = _T.of(context);
    if (_isLoadingGuides) {
      return Padding(
        padding: EdgeInsets.only(top: 6),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.textMuted,
            ),
          ),
        ),
      );
    }
    if (_mapGuides == null || _mapGuides!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.fieldBg,
        borderRadius: BorderRadius.circular(_T.radiusField),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '该地图已有 $_mapGuidesTotal 篇攻略',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...(_mapGuides!.map((guide) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GuideCompactCard(
                  title: guide.title,
                  coverUrl: guide.coverUrl,
                  authorName: guide.authorName,
                  viewCount: guide.viewCount,
                  likeCount: guide.likeCount,
                  commentCount: guide.commentCount,
                  onTap: () {
                    final navigator =
                        DesktopNavigatorProvider.of(context);
                    navigator?.openGuideDetail(guide.id);
                  },
                ),
              ))),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _handleViewMore(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                foregroundColor: colors.accent,
              ),
              child: const Text('查看更多 →',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleViewMore(BuildContext context) {
    if (widget.mapName == null || widget.mapName!.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MapGuidesDialog(
        mapName: widget.mapName!,
        mapLabel: _mapInfo?.mapLabel,
      ),
    );
  }
}

// ─── 标签输入 ────────────────────────────────────────────────────────────────

class _TagsInput extends StatefulWidget {
  final List<String> tags;
  const _TagsInput({required this.tags});

  @override
  State<_TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<_TagsInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    if (widget.tags.contains(trimmed)) return; // 去重
    if (widget.tags.length >= 5) return;        // 最多 5 个
    final newTags = [...widget.tags, trimmed];
    context.read<GuideEditorBloc>().add(UpdateTags(newTags));
    _controller.clear();
    setState(() => _showSuggestions = false);
    context.read<GuideTagSuggestBloc>().add(const Reset());
  }

  void _removeTag(String tag) {
    final newTags = widget.tags.where((t) => t != tag).toList();
    context.read<GuideEditorBloc>().add(UpdateTags(newTags));
  }

  void _onInputChanged(String value) {
    if (value.trim().isNotEmpty) {
      context.read<GuideTagSuggestBloc>().add(Suggest(value.trim()));
      setState(() => _showSuggestions = true);
    } else {
      context.read<GuideTagSuggestBloc>().add(const Reset());
      setState(() => _showSuggestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: '标签', hint: '最多 5 个'),
        const SizedBox(height: 8),
        if (widget.tags.length < 5) _buildInputField(),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.tags.map(_buildTagChip).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField() {
    final colors = _T.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: _fieldDecoration(context),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onInputChanged,
            onSubmitted: _addTag,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '输入标签后回车添加',
              hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (_showSuggestions)
          BlocBuilder<GuideTagSuggestBloc, GuideTagSuggestState>(
            builder: (context, suggestState) {
              if (suggestState.suggestions.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: colors.fieldBg,
                  borderRadius: BorderRadius.circular(_T.radiusField),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: suggestState.suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestState.suggestions[index];
                    return _SuggestionTile(
                      label: suggestion,
                      onTap: () => _addTag(suggestion),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    return _TagChip(label: tag, onRemove: () => _removeTag(tag));
  }
}

class _TagChip extends StatefulWidget {
  final String label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: _hovering ? colors.accentHover : colors.accent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onRemove,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${widget.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _hovering ? 1 : 0.7,
                  child: const Icon(Icons.close,
                      size: 11, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionTile({required this.label, required this.onTap});

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovering
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ─── 摘要 ────────────────────────────────────────────────────────────────────

class _SummaryInput extends StatefulWidget {
  final String? summary;
  const _SummaryInput({this.summary});

  @override
  State<_SummaryInput> createState() => _SummaryInputState();
}

class _SummaryInputState extends State<_SummaryInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.summary ?? '');
  }

  @override
  void didUpdateWidget(_SummaryInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.summary != oldWidget.summary &&
        widget.summary != _controller.text) {
      _controller.text = widget.summary ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: '摘要', hint: '不填自动取正文前 100 字'),
        const SizedBox(height: 8),
        Container(
          decoration: _fieldDecoration(context),
          child: TextField(
            controller: _controller,
            onChanged: (value) {
              context
                  .read<GuideEditorBloc>()
                  .add(UpdateSummary(value.isEmpty ? null : value));
            },
            maxLines: 4,
            maxLength: 200,
            style: TextStyle(
              fontSize: 13,
              color: colors.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '简要介绍这篇攻略的核心内容...',
              hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterStyle: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 校验清单 ────────────────────────────────────────────────────────────────

class _ValidationChecklist extends StatelessWidget {
  final List<EditorValidateError> errors;
  const _ValidationChecklist({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: '提交检查'),
        const SizedBox(height: 6),
        _CheckItem(
          label: '标题（2-60 字）',
          passed: !errors.contains(EditorValidateError.titleRequired),
        ),
        _CheckItem(
          label: '分类已选择',
          passed: !errors.contains(EditorValidateError.categoryRequired) &&
              !errors.contains(EditorValidateError.categoryInvalid),
        ),
        _CheckItem(
          label: '正文 ≥ 50 字',
          passed: !errors.contains(EditorValidateError.contentTooShort),
        ),
        _CheckItem(
          label: '标签 ≤ 5 个',
          passed: !errors.contains(EditorValidateError.tagsTooMany),
        ),
        _CheckItem(
          label: '图片 ≤ 100 张',
          passed: !errors.contains(EditorValidateError.imagesTooMany),
        ),
        _CheckItem(
          label: 'B 站视频 ≤ 5 个',
          passed: !errors.contains(EditorValidateError.videosTooMany),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool passed;
  const _CheckItem({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 14,
            color: passed ? colors.success : colors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: passed ? colors.textSecondary : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 底部操作区 ──────────────────────────────────────────────────────────────

class _FooterActions extends StatelessWidget {
  final GuideEditorState state;
  const _FooterActions({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    final phase = state.phase;
    final isSaving =
        phase == EditorPhase.saving || phase == EditorPhase.savingRemote;
    final isPublishing = phase == EditorPhase.publishing;
    final isEditingExisting = state.draft?.guideId != null && state.draft!.guideId! > 0;
    final canPublish =
        state.canPublish && !isPublishing && phase != EditorPhase.submitted;

    final categoriesState = context.watch<GuideCategoriesBloc>().state;
    final isCategoriesFailed =
        categoriesState.status == CategoriesStatus.failure;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 36,
            child: _HoverButton(
              onPressed: isSaving
                  ? null
                  : () => context.read<GuideEditorBloc>().add(
                        const SaveDraftRequested(manual: true),
                      ),
              icon: isSaving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textMuted,
                      ),
                    )
                  : Icon(Icons.save_outlined,
                      size: 16, color: colors.textSecondary),
              label: Text(
                '保存草稿',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: colors.fieldBg,
              hoverBackgroundColor: colors.fieldBgHover,
              borderColor: colors.borderSoft,
              hoverBorderColor: colors.borderHover,
            ),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: !canPublish
                ? (isCategoriesFailed
                    ? (isEditingExisting ? '分类加载失败，无法提交' : '分类加载失败，无法发布')
                    : '请完成左侧"提交检查"中的所有项')
                : '',
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: _HoverButton(
                onPressed: canPublish
                    ? () => context
                        .read<GuideEditorBloc>()
                        .add(const PublishRequested())
                    : null,
                icon: isPublishing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        size: 16, color: Colors.white),
                label: Text(
                  isEditingExisting ? '提交修改' : '发布',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: colors.accent,
                hoverBackgroundColor: colors.accentHover,
                disabledBackgroundColor:
                    colors.accent.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用 hover 高亮按钮（支持禁用态 + 可选边框）
class _HoverButton extends StatefulWidget {
  /// 点击回调；null 表示禁用
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final Color backgroundColor;
  final Color hoverBackgroundColor;
  /// 禁用态背景色；null 时使用 [backgroundColor]
  final Color? disabledBackgroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;

  const _HoverButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.hoverBackgroundColor,
    this.disabledBackgroundColor,
    this.borderColor,
    this.hoverBorderColor,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final bg = disabled
        ? (widget.disabledBackgroundColor ?? widget.backgroundColor)
        : (_hovering
            ? widget.hoverBackgroundColor
            : widget.backgroundColor);
    final border = widget.borderColor == null
        ? null
        : Border.all(
            color: _hovering
                ? (widget.hoverBorderColor ?? widget.borderColor!)
                : widget.borderColor!,
          );

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_T.radiusField),
          border: border,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_T.radiusField),
            onTap: widget.onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.icon,
                  const SizedBox(width: 8),
                  widget.label,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 共享小组件 ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? hint;
  final bool required;
  const _SectionLabel({
    required this.label,
    this.hint,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        if (required)
          Text(' *',
              style: TextStyle(color: colors.danger, fontSize: 13)),
        if (hint != null) ...[
          const SizedBox(width: 6),
          Text(
            hint!,
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

BoxDecoration _fieldDecoration(BuildContext context, {bool hovering = false}) {
  final colors = _T.of(context);
  return BoxDecoration(
    color: hovering ? colors.fieldBgHover : colors.fieldBg,
    borderRadius: BorderRadius.circular(_T.radiusField),
    border: Border.all(
      color: hovering ? colors.borderHover : colors.borderSoft,
    ),
  );
}

// ─── 该地图全部攻略弹窗 ─────────────────────────────────────────────────────

/// 在编辑器内查看该地图所有攻略的弹窗。
///
/// 与「查看更多 →」入口配套：点击不再跳走攻略列表，而是在编辑器之上叠一层
/// 弹窗，分页加载该地图下的攻略。点击单条卡片走 [DesktopNavigator.openGuideDetail]，
/// 由上层负责未保存内容的拦截校验。
class _MapGuidesDialog extends StatefulWidget {
  final String mapName;
  final String? mapLabel;

  const _MapGuidesDialog({
    required this.mapName,
    this.mapLabel,
  });

  @override
  State<_MapGuidesDialog> createState() => _MapGuidesDialogState();
}

class _MapGuidesDialogState extends State<_MapGuidesDialog> {
  static const int _pageSize = 20;

  final _scrollController = ScrollController();
  final List<GuideListItem> _items = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await GuideApi().getGuides(
        query: GuideListQuery(
          mapName: widget.mapName,
          page: 1,
          pageSize: _pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(response.items);
        _total = response.total;
        _page = 1;
        _hasMore = _items.length < _total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败，请稍后重试';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await GuideApi().getGuides(
        query: GuideListQuery(
          mapName: widget.mapName,
          page: nextPage,
          pageSize: _pageSize,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(response.items);
        _page = nextPage;
        _total = response.total;
        _hasMore = _items.length < _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _openDetail(int id) {
    final navigator = DesktopNavigatorProvider.of(context);
    Navigator.of(context).pop();
    navigator?.openGuideDetail(id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _T.of(context);
    final displayName =
        (widget.mapLabel != null && widget.mapLabel!.isNotEmpty)
            ? '${widget.mapLabel}（${widget.mapName}）'
            : widget.mapName;

    return Dialog(
      backgroundColor: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_T.radiusCard),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 640,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, displayName),
            const Divider(height: 1),
            Flexible(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayName) {
    final colors = _T.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '该地图的攻略',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$displayName · 共 $_total 篇',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭',
            icon: Icon(Icons.close, color: colors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = _T.of(context);
    if (_loading && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colors.accent,
            ),
          ),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.danger, size: 32),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadFirstPage,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            '暂无攻略',
            style: TextStyle(color: colors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textMuted,
                ),
              ),
            ),
          );
        }
        final guide = _items[index];
        return GuideCompactCard(
          title: guide.title,
          coverUrl: guide.coverUrl,
          authorName: guide.authorName,
          viewCount: guide.viewCount,
          likeCount: guide.likeCount,
          commentCount: guide.commentCount,
          onTap: () => _openDetail(guide.id),
        );
      },
    );
  }
}
