import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/core.dart';
import '../../../core/widgets/disk_cached_image.dart';

/// B站内容 - 新增/编辑直播间/视频表单
class BilibiliContentFormPage extends StatefulWidget {
  /// 编辑模式: 'liveRoom' = 直播间, 'video' = 视频
  final String editMode;
  /// 是否为编辑模式（true=编辑已有，false=新增）
  final bool isEditing;
  /// 如果是编辑视频，传入视频ID
  final String? editingVideoId;
  /// 直播间数据（编辑时使用）
  final LiveRoom? liveRoom;
  /// 视频数据（编辑时使用）
  final BilibiliVideo? video;
  /// 关闭表单回调
  final VoidCallback onClose;
  /// 取消编辑回调
  final VoidCallback onCancel;
  /// 提交成功回调
  final VoidCallback onSubmitSuccess;

  const BilibiliContentFormPage({
    super.key,
    required this.editMode,
    required this.isEditing,
    this.editingVideoId,
    this.liveRoom,
    this.video,
    required this.onClose,
    required this.onCancel,
    required this.onSubmitSuccess,
  });

  @override
  State<BilibiliContentFormPage> createState() => _BilibiliContentFormPageState();
}

class _BilibiliContentFormPageState extends State<BilibiliContentFormPage> {
  static const _bilibiliBlue = Color(0xFF00A1D6);
  static const _bilibiliBlueLight = Color(0xFF00C8FF);
  static const _bilibiliPink = Color(0xFFFB7299);

  // 表单控制器
  final _formKey = GlobalKey<FormState>();
  final _contentIdController = TextEditingController();
  final _focusNode = FocusNode();

  // 防抖 Timer
  Timer? _debounceTimer;

  // 封面相关状态
  bool _isFetchingFromBiliBili = false;
  String? _fetchedCoverUrl;
  String? _fetchedContentId;
  String? _fetchedTitle;
  String? _fetchedOwnerFace;
  String? _fetchedOwnerUid;
  String? _fetchedOwnerName;
  String? _validationError;

  // 表单提交中状态
  bool _isSubmitting = false;

  // 分类相关状态
  int? _selectedCategoryId;

  bool get _isLiveRoom => widget.editMode == 'liveRoom';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _initFormData();
    // 加载分类列表
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final bloc = context.read<BilibiliContentBloc>();
    final state = bloc.state;
    if (state.videoCategories.isEmpty) {
      bloc.add(const BilibiliContentFetchCategoriesRequested());
    }
  }

  void _initFormData() {
    if (widget.isEditing) {
      if (_isLiveRoom && widget.liveRoom != null) {
        _contentIdController.text = widget.liveRoom!.roomId;
        _fetchedContentId = widget.liveRoom!.roomId;
        // 编辑时自动从B站获取最新信息
        _fetchBiliBiliInfo();
      } else if (!_isLiveRoom && widget.video != null) {
        _contentIdController.text = widget.video!.bvid;
        _fetchedContentId = widget.video!.bvid;
        _selectedCategoryId = widget.video!.categoryId;
        // 编辑时自动从B站获取最新信息
        _fetchBiliBiliInfo();
      }
    } else {
      // 新增视频时，如果没有选择分类，默认选第一个
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setDefaultCategory();
      });
    }
  }

  void _setDefaultCategory() {
    if (!mounted) return;
    final bloc = context.read<BilibiliContentBloc>();
    final categories = bloc.state.videoCategories;
    // 如果有分类且没有选择任何分类，默认选第一个
    if (categories.isNotEmpty && _selectedCategoryId == null) {
      setState(() {
        _selectedCategoryId = categories.first.id;
      });
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _debouncedFetchBiliBiliInfo();
    }
  }

  void _debouncedFetchBiliBiliInfo() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchBiliBiliInfo();
    });
  }

  @override
  void dispose() {
    _contentIdController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBiliBiliInfo() async {
    final contentId = _contentIdController.text.trim();
    if (contentId.isEmpty) return;

    // 清除之前的验证错误
    setState(() => _validationError = null);
    setState(() => _isFetchingFromBiliBili = true);

    try {
      if (_isLiveRoom) {
        final roomId = BilibiliService.extractRoomId(contentId);
        if (roomId == null) {
          setState(() {
            _validationError = '请输入正确的直播间ID或链接';
            _isFetchingFromBiliBili = false;
          });
          return;
        }

        if (roomId != contentId && mounted) {
          _contentIdController.value = TextEditingValue(
            text: roomId,
            selection: TextSelection.collapsed(offset: roomId.length),
          );
        }

        final roomInfo = await BilibiliService().getRoomInfo(roomId, bypassCache: true);
        if (roomInfo == null) {
          setState(() {
            _validationError = '无法获取直播间信息，请检查ID是否正确';
            _isFetchingFromBiliBili = false;
          });
          return;
        }

        // 获取主播头像
        String? ownerFace;
        if (roomInfo.userId != null) {
          final userInfo = await BilibiliService().getUserInfo(roomInfo.userId!);
          ownerFace = userInfo?.face;
        }

        if (!mounted) return;
        setState(() {
          _fetchedContentId = contentId;
          _fetchedCoverUrl = roomInfo.coverUrl;
          _fetchedTitle = roomInfo.title;
          _fetchedOwnerUid = roomInfo.userId;
          _fetchedOwnerName = roomInfo.userName;
          _fetchedOwnerFace = ownerFace;
        });
      } else {
        final bvid = BilibiliService.extractBvid(contentId);
        if (bvid == null) {
          setState(() {
            _validationError = '请输入正确的BV号或视频链接';
            _isFetchingFromBiliBili = false;
          });
          return;
        }

        if (bvid != contentId && mounted) {
          _contentIdController.value = TextEditingValue(
            text: bvid,
            selection: TextSelection.collapsed(offset: bvid.length),
          );
        }

        final videoInfo = await BilibiliService().getVideoInfo(bvid, bypassCache: true);
        if (videoInfo == null) {
          setState(() {
            _validationError = '无法获取视频信息，请检查BV号是否正确';
            _isFetchingFromBiliBili = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          _fetchedContentId = contentId;
          _fetchedCoverUrl = videoInfo.coverUrl;
          _fetchedTitle = videoInfo.title;
          _fetchedOwnerFace = videoInfo.ownerFace;
          _fetchedOwnerUid = videoInfo.mid;
          _fetchedOwnerName = videoInfo.author;
        });
      }
    } catch (e) {
      LogService.e('获取B站信息失败', e);
      setState(() {
        _validationError = '获取B站信息失败，请稍后重试';
        _isFetchingFromBiliBili = false;
      });
    } finally {
      if (_validationError == null) {
        setState(() => _isFetchingFromBiliBili = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final contentId = _contentIdController.text.trim();
    final bloc = context.read<BilibiliContentBloc>();

    // 前置拦截：防止防抖还未发起时提交导致新ID使用旧信息的数据污染
    if (_fetchedContentId != contentId || _fetchedTitle == null) {
      setState(() => _isSubmitting = true);
      await _fetchBiliBiliInfo();
      if (_fetchedTitle == null) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ToastUtils.showError(context, '获取B站最新数据失败，请检查ID是否正确');
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);

    if (widget.isEditing) {
      if (_isLiveRoom) {
        final currentRoom = widget.liveRoom;
        if (currentRoom == null) {
          setState(() => _isSubmitting = false);
          if (mounted) {
            ToastUtils.showError(context, '直播间数据加载失败');
          }
          return;
        }
        final newRoomId = contentId;
        final roomIdChanged = newRoomId != currentRoom.roomId;
        final roomId = BilibiliService.extractRoomId(newRoomId);

        // 如果房间ID变化了，使用新获取的 ownerUid 和 ownerName
        final ownerUid = roomIdChanged ? _fetchedOwnerUid : currentRoom.ownerUid;
        final ownerName = roomIdChanged ? _fetchedOwnerName : currentRoom.ownerName;

        bloc.add(
          BilibiliContentUpdateRequested(
            id: currentRoom.id,
            contentType: BilibiliContentType.liveRoom,
            roomId: roomIdChanged ? roomId : null,
            title: _fetchedTitle,
            coverUrl: _fetchedCoverUrl,
            ownerUid: ownerUid,
            ownerName: ownerName,
          ),
        );
      } else {
        final currentVideo = widget.video;
        if (currentVideo == null) {
          setState(() => _isSubmitting = false);
          if (mounted) {
            ToastUtils.showError(context, '视频数据加载失败');
          }
          return;
        }
        final newBvid = _contentIdController.text.trim();
        final bvidChanged = newBvid != currentVideo.bvid;
        final newOwnerFace = bvidChanged ? _fetchedOwnerFace : currentVideo.ownerFace;

        bloc.add(
          BilibiliContentUpdateRequested(
            id: currentVideo.id,
            contentType: BilibiliContentType.video,
            bvid: bvidChanged ? BilibiliService.extractBvid(newBvid) : null,
            title: _fetchedTitle ?? currentVideo.title,
            coverUrl: _fetchedCoverUrl ?? currentVideo.coverUrl,
            ownerUid: _fetchedOwnerUid ?? currentVideo.ownerUid,
            ownerName: _fetchedOwnerName ?? currentVideo.ownerName,
            ownerFace: newOwnerFace,
            publishedAt: currentVideo.publishedAt?.toIso8601String(),
            duration: currentVideo.duration,
            categoryId: _selectedCategoryId,
          ),
        );
      }
    } else {
      bloc.add(
        BilibiliContentAddRequested(
          contentId: contentId,
          contentType: _isLiveRoom ? BilibiliContentType.liveRoom : BilibiliContentType.video,
          coverUrl: _fetchedCoverUrl,
          title: _fetchedTitle,
          ownerFace: _isLiveRoom ? null : _fetchedOwnerFace,
          ownerUid: _fetchedOwnerUid,
          ownerName: _fetchedOwnerName,
          publishedAt: null,
          duration: null,
          categoryId: _selectedCategoryId,
        ),
      );
    }

    _waitForOperationAndReturn(bloc);
  }

  Future<void> _waitForOperationAndReturn(BilibiliContentBloc bloc) async {
    try {
      await bloc.stream
          .firstWhere((state) => state.lastOperationSuccess != null)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // 忽略超时或流错误
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);
    widget.onSubmitSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return _buildFormContent(context);
  }

  Widget _buildFormContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final washiColor = isDark ? const Color(0xFF2A2520) : const Color(0xFFF5F0E6);
    final inkColor = isDark ? const Color(0xFFE8E0D8) : const Color(0xFF2C1810);
    final scrollBrown = isDark ? const Color(0xFFB8956A) : const Color(0xFF8B4513);
    final accentColor = _isLiveRoom ? _bilibiliPink : _bilibiliBlue;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 头部
            _buildFormHeader(inkColor, scrollBrown, accentColor),
            Container(height: 1, color: scrollBrown.withValues(alpha: 0.15)),
            // 内容区
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputSection(inkColor, scrollBrown, accentColor, isDark),
                      const SizedBox(height: 16),
                      if (!_isLiveRoom) _buildCategorySelector(inkColor, scrollBrown, accentColor, isDark),
                      if (!_isLiveRoom) const SizedBox(height: 16),
                      _buildPreviewSection(washiColor, inkColor, scrollBrown, accentColor, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader(Color inkColor, Color scrollBrown, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.1),
            accentColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isLiveRoom
                    ? [_bilibiliPink, _bilibiliPink.withValues(alpha: 0.85)]
                    : [_bilibiliBlueLight, _bilibiliBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                _isLiveRoom ? Icons.live_tv : Icons.play_circle,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.isEditing ? "编辑" : "添加"}${_isLiveRoom ? "直播间" : "视频"}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: inkColor,
                  ),
                ),
                Text(
                  widget.isEditing
                      ? '修改 ${_isLiveRoom ? "直播间" : "视频"} 信息'
                      : '输入 ${_isLiveRoom ? "直播间ID" : "BV号"} 添加',
                  style: TextStyle(
                    fontSize: 11,
                    color: inkColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // 取消按钮
          _buildTextButton(
            label: '取消',
            onTap: _isSubmitting ? null : widget.onCancel,
            color: inkColor,
          ),
          const SizedBox(width: 8),
          // 保存按钮
          _buildPrimaryButton(
            label: _isSubmitting ? '提交中' : '保存',
            onTap: (_isSubmitting || _isFetchingFromBiliBili) ? null : _submitForm,
            isLoading: _isSubmitting,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTextButton({
    required String label,
    VoidCallback? onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: onTap == null ? Colors.grey : color.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    VoidCallback? onTap,
    bool isLoading = false,
    required Color accentColor,
  }) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isDisabled || isLoading
              ? null
              : LinearGradient(
                  colors: _isLiveRoom
                      ? [_bilibiliPink, _bilibiliPink.withValues(alpha: 0.85)]
                      : [_bilibiliBlueLight, accentColor],
                ),
          color: isDisabled ? Colors.grey[400] : (isLoading ? accentColor.withValues(alpha: 0.8) : null),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(Color inkColor, Color scrollBrown, Color accentColor, bool isDark) {
    final inputBg = isDark ? const Color(0xFF3D3632) : Colors.white;

    if (widget.isEditing) {
      return _buildEditingInfoCard(inkColor, scrollBrown, accentColor, inputBg, isDark);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLiveRoom ? Icons.live_tv : Icons.videocam,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                _isLiveRoom ? '直播间ID或链接' : 'BV号或视频链接',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                ),
              ),
              const Spacer(),
              if (_isFetchingFromBiliBili)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                InkWell(
                  onTap: _fetchBiliBiliInfo,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.refresh, size: 16, color: accentColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contentIdController,
            focusNode: _focusNode,
            style: TextStyle(fontSize: 14, color: inkColor),
            decoration: InputDecoration(
              hintText: _isLiveRoom ? '例如: live.bilibili.com/123456' : '例如: BV1xx411c7mD',
              hintStyle: TextStyle(color: inkColor.withValues(alpha: 0.35), fontSize: 13),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2520) : const Color(0xFFFAF8F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              errorText: _validationError,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入${_isLiveRoom ? "直播间ID" : "BV号"}';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditingInfoCard(
    Color inkColor,
    Color scrollBrown,
    Color accentColor,
    Color inputBg,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isLiveRoom ? Icons.link : Icons.edit_note,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                _isLiveRoom ? 'B站直播间ID' : 'B站视频BV号',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '编辑中',
                  style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _contentIdController,
                  focusNode: _focusNode,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: accentColor),
                  decoration: InputDecoration(
                    hintText: _isLiveRoom ? '直播间ID' : 'BV号',
                    hintStyle: TextStyle(color: inkColor.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2520) : const Color(0xFFFAF8F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accentColor, width: 1.5),
                    ),
                    errorText: _validationError,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _isFetchingFromBiliBili ? null : _fetchBiliBiliInfo,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: _isFetchingFromBiliBili
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh, size: 18, color: accentColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(
    Color washiColor,
    Color inkColor,
    Color scrollBrown,
    Color accentColor,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题+作者预览
        Expanded(
          child: _buildTitleAndAuthorPreview(
            inkColor: inkColor,
            scrollBrown: scrollBrown,
            accentColor: accentColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        // 封面预览
        Expanded(
          child: _buildCoverPreview(
            washiColor: washiColor,
            inkColor: inkColor,
            scrollBrown: scrollBrown,
            accentColor: accentColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleAndAuthorPreview({
    required Color inkColor,
    required Color scrollBrown,
    required Color accentColor,
    required bool isDark,
  }) {
    final hasTitle = _fetchedTitle != null;
    final hasAuthor = _fetchedOwnerName != null && _fetchedOwnerName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D3632) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题部分
          Row(
            children: [
              Icon(Icons.title, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                '标题',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: inkColor),
              ),
              const Spacer(),
              Icon(
                hasTitle ? Icons.check_circle : Icons.pending,
                size: 12,
                color: hasTitle ? Colors.green : inkColor.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fetchedTitle ?? '等待获取...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: hasTitle ? inkColor : inkColor.withValues(alpha: 0.4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // 作者部分
          Row(
            children: [
              Icon(Icons.person, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                '作者',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: inkColor),
              ),
              const Spacer(),
              Icon(
                hasAuthor ? Icons.check_circle : Icons.pending,
                size: 12,
                color: hasAuthor ? Colors.green : inkColor.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasAuthor)
            Row(
              children: [
                // 作者头像
                if (_fetchedOwnerFace != null && _fetchedOwnerFace!.isNotEmpty)
                  ClipOval(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.network(
                        _fetchedOwnerFace!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accentColor.withValues(alpha: 0.2),
                          child: Icon(Icons.person, size: 16, color: accentColor),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 16, color: accentColor),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fetchedOwnerName ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
              Text(
                '等待获取...',
                style: TextStyle(
                fontSize: 11,
                color: inkColor.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(
    Color inkColor,
    Color scrollBrown,
    Color accentColor,
    bool isDark,
  ) {
    return BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
      builder: (context, state) {
        final categories = state.videoCategories;
        final inputBg = isDark ? const Color(0xFF3D3632) : Colors.white;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.category,
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '视频分类',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: inkColor,
                    ),
                  ),
                  const Spacer(),
                  if (categories.isEmpty)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                Text(
                  '加载中...',
                  style: TextStyle(
                    fontSize: 12,
                    color: inkColor.withValues(alpha: 0.5),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in categories)
                      _buildCategoryChip(
                        category.name,
                        category.id,
                        _selectedCategoryId,
                        accentColor,
                        isDark,
                        inkColor,
                        () {
                          setState(() {
                            _selectedCategoryId = category.id;
                          });
                        },
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(
    String label,
    int categoryId,
    int? selectedCategoryId,
    Color accentColor,
    bool isDark,
    Color inkColor,
    VoidCallback onTap,
  ) {
    final isSelected = categoryId == selectedCategoryId;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() {}),
          onExit: (_) => setState(() {}),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.white24 : Colors.black12),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? accentColor : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverPreview({
    required Color washiColor,
    required Color inkColor,
    required Color scrollBrown,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D3632) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scrollBrown.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                '封面',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: inkColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 封面图
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: washiColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _fetchedCoverUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        DiskCachedImage(
                          imageUrl: _fetchedCoverUrl!,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '已获取',
                                  style: TextStyle(fontSize: 9, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 24, color: inkColor.withValues(alpha: 0.2)),
                          const SizedBox(height: 4),
              Text(
                '等待获取...',
                style: TextStyle(fontSize: 10, color: inkColor.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
