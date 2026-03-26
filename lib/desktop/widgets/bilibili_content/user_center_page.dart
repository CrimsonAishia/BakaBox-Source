import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/core.dart';
import '../../../core/widgets/disk_cached_image.dart';
import 'bilibili_content_form_page.dart';

/// 内容用户中心页面组件
class BilibiliUserCenterPage extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String, BilibiliContentType)? onDelete;

  const BilibiliUserCenterPage({
    super.key,
    required this.onClose,
    this.onDelete,
  });

  @override
  State<BilibiliUserCenterPage> createState() => _BilibiliUserCenterPageState();
}

class _BilibiliUserCenterPageState extends State<BilibiliUserCenterPage> {
  // 视频列表分页
  int _videoCurrentPage = 1;

  // 封面相关状态
  bool _isLoadingLiveRoomInfo = false;
  String? _liveRoomCoverUrl;
  String? _liveRoomTitle;

  static const _bilibiliBlue = Color(0xFF00A1D6);
  static const _bilibiliBlueLight = Color(0xFF00C8FF);
  static const int _videoPageSize = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMyContent();
    });
  }

  /// 获取我的内容
  void _fetchMyContent() {
    context.read<BilibiliContentBloc>().add(
      const BilibiliContentFetchMyRequested(),
    );
  }

  /// 获取直播间最新的封面和标题
  Future<void> _fetchLatestLiveRoomInfo() async {
    final state = context.read<BilibiliContentBloc>().state;
    // 优先使用 myLiveRoom，否则从列表中查找
    final room =
        state.myLiveRoom ??
        (state.myLiveRoomId != null
            ? state.liveRooms
                  .where((r) => r.id == state.myLiveRoomId)
                  .firstOrNull
            : null);

    if (room == null) {
      // 如果还没有直播间，等待下次调用
      return;
    }

    // 如果已经有数据，直接使用
    if (room.title != null || room.coverUrl != null) {
      setState(() {
        _liveRoomCoverUrl = room.displayCover;
        _liveRoomTitle = room.displayTitle;
      });
      return;
    }

    setState(() => _isLoadingLiveRoomInfo = true);

    try {
      final roomInfo = await BilibiliService().getRoomInfo(room.roomId);
      if (roomInfo == null) return;

      if (!mounted) return;
      setState(() {
        _liveRoomCoverUrl = roomInfo.coverUrl;
        _liveRoomTitle = roomInfo.title;
      });
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) {
        setState(() => _isLoadingLiveRoomInfo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BilibiliContentBloc, BilibiliContentState>(
      listenWhen: (previous, current) =>
          previous.myLiveRoomId != current.myLiveRoomId ||
          previous.myLiveRoom != current.myLiveRoom ||
          (previous.myLiveRoom?.enabled != current.myLiveRoom?.enabled) ||
          previous.lastOperationSuccess != current.lastOperationSuccess,
      listener: (context, state) {
        // 当我的直播间数据变化时，获取最新的封面和标题
        if (state.myLiveRoomId != null) {
          _fetchLatestLiveRoomInfo();
        }
        // 监听操作结果，显示Toast
        if (state.lastOperationSuccess != null) {
          final isSuccess = state.lastOperationSuccess!;
          final message =
              state.lastOperationMessage ?? (isSuccess ? '操作成功' : '操作失败');
          if (isSuccess) {
            ToastUtils.showSuccess(context, message);
          } else {
            ToastUtils.showError(context, message);
          }
          // 清除操作结果状态
          context.read<BilibiliContentBloc>().add(
            const BilibiliContentClearOperationResult(),
          );
        }
      },
      child: BlocBuilder<BilibiliContentBloc, BilibiliContentState>(
        builder: (context, state) {
          return _buildContent(context, state);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, BilibiliContentState state) {
    final bloc = context.watch<BilibiliContentBloc>();
    final watchedState = bloc.state;
    // 优先使用 myLiveRoom，否则从列表中查找
    final myLiveRoom =
        watchedState.myLiveRoom ??
        (watchedState.myLiveRoomId != null
            ? watchedState.liveRooms
                  .where((r) => r.id == watchedState.myLiveRoomId)
                  .firstOrNull
            : null);
    // 用户所有视频列表（包含所有审核状态）
    final myVideos = watchedState.myVideos;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final washiColor = isDark
        ? const Color(0xFF2A2520)
        : const Color(0xFFF5F0E6);
    final inkColor = isDark ? const Color(0xFFE8E0D8) : const Color(0xFF2C1810);
    final navBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final scrollBrown = isDark
        ? const Color(0xFFB8956A)
        : const Color(0xFF8B4513);

    return _buildMainPage(
      context,
      washiColor,
      inkColor,
      navBgColor,
      scrollBrown,
      myLiveRoom,
      myVideos,
    );
  }

  void _toggleLiveRoomEnabled(bool enabled) {
    final state = context.read<BilibiliContentBloc>().state;
    final roomId = state.myLiveRoomId;
    if (roomId == null) return;

    context.read<BilibiliContentBloc>().add(
      BilibiliContentToggleLiveRoomRequested(id: roomId, enabled: enabled),
    );
  }

  void _confirmDelete(String id, BilibiliContentType contentType) {
    final contentTypeName = contentType == BilibiliContentType.video
        ? '视频'
        : '专栏';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这个$contentTypeName吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDelete(id, contentType);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _performDelete(String id, BilibiliContentType contentType) {
    widget.onDelete?.call(id, contentType); // 兼容外部传入
    context.read<BilibiliContentBloc>().add(
      BilibiliContentDeleteRequested(id: id, contentType: contentType),
    );
  }

  /// 打开B站链接
  Future<void> _openBilibiliLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开链接'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 打开直播间链接
  void _openLiveRoomLink(String roomId) {
    _openBilibiliLink('https://live.bilibili.com/$roomId');
  }

  /// 打开视频链接
  void _openVideoLink(String bvid) {
    _openBilibiliLink('https://www.bilibili.com/video/$bvid');
  }

  /// 格式化播放量显示
  String _formatViewCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}千';
    } else if (count < 100000000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    } else {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    }
  }

  /// 打开添加/编辑直播间表单
  void _openLiveRoomForm({LiveRoom? liveRoom}) {
    _openFormPage(
      editMode: 'liveRoom',
      isEditing: liveRoom != null,
      liveRoom: liveRoom,
    );
  }

  /// 打开添加/编辑视频表单
  void _openVideoForm({BilibiliVideo? video}) {
    _openFormPage(
      editMode: 'video',
      isEditing: video != null,
      video: video,
      editingVideoId: video?.id,
    );
  }

  /// 打开表单页面
  void _openFormPage({
    required String editMode,
    required bool isEditing,
    LiveRoom? liveRoom,
    BilibiliVideo? video,
    String? editingVideoId,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭表单',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 580,
              height: 520,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: BilibiliContentFormPage(
                editMode: editMode,
                isEditing: isEditing,
                liveRoom: liveRoom,
                video: video,
                editingVideoId: editingVideoId,
                onClose: () => Navigator.of(context).pop(),
                onCancel: () => Navigator.of(context).pop(),
                onSubmitSuccess: () {
                  Navigator.of(context).pop();
                  // 刷新我的内容
                  _fetchMyContent();
                  // 如果是直播间，刷新封面
                  if (editMode == 'liveRoom') {
                    _fetchLatestLiveRoomInfo();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainPage(
    BuildContext context,
    Color washiColor,
    Color inkColor,
    Color navBgColor,
    Color scrollBrown,
    dynamic myLiveRoom,
    List<BilibiliVideo> myVideos,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: washiColor)),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 32,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    navBgColor,
                    navBgColor.withValues(alpha: 0.5),
                    washiColor.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.5, -0.3),
                  radius: 1.0,
                  colors: [
                    _bilibiliBlue.withValues(alpha: isDark ? 0.15 : 0.1),
                    _bilibiliBlue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(0),
            child: Container(
              decoration: BoxDecoration(
                color: washiColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scrollBrown.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildMainHeader(inkColor, scrollBrown),
                  Container(
                    height: 1,
                    color: scrollBrown.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLiveRoomSettingCard(
                                  title: '我的直播间',
                                  subtitle: _liveRoomTitle ?? '未设置',
                                  roomId: myLiveRoom?.roomId,
                                  icon: Icons.live_tv,
                                  hasContent: myLiveRoom != null,
                                  coverUrl: _liveRoomCoverUrl,
                                  isEnabled: myLiveRoom?.enabled ?? false,
                                  viewCount: myLiveRoom?.viewCount,
                                  onTap: myLiveRoom != null
                                      ? () => _openLiveRoomLink(
                                          myLiveRoom!.roomId,
                                        )
                                      : () => _openLiveRoomForm(),
                                  onEdit: myLiveRoom != null
                                      ? () => _openLiveRoomForm(
                                          liveRoom: myLiveRoom,
                                        )
                                      : null,
                                  onToggleEnabled: myLiveRoom != null
                                      ? _toggleLiveRoomEnabled
                                      : null,
                                  inkColor: inkColor,
                                  scrollBrown: scrollBrown,
                                ),
                                const SizedBox(height: 12),
                                _buildVideoListSection(
                                  title: '我的视频',
                                  videos: myVideos,
                                  onAdd: () => _openVideoForm(),
                                  onEdit: (video) =>
                                      _openVideoForm(video: video),
                                  inkColor: inkColor,
                                  scrollBrown: scrollBrown,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (myVideos.isNotEmpty)
                          _buildPaginationControls(
                            currentPage: _videoCurrentPage.clamp(
                              1,
                              (myVideos.length / _videoPageSize).ceil().clamp(
                                1,
                                999,
                              ),
                            ),
                            totalPages: (myVideos.length / _videoPageSize)
                                .ceil()
                                .clamp(1, 999),
                            inkColor: inkColor,
                            onPageChanged: (page) =>
                                setState(() => _videoCurrentPage = page),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeader(Color inkColor, Color scrollBrown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _bilibiliBlue.withValues(alpha: 0.08),
            _bilibiliBlue.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_bilibiliBlueLight, _bilibiliBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '用户中心',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: inkColor,
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: _bilibiliBlue.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '返回',
                    style: TextStyle(
                      color: _bilibiliBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: _bilibiliBlue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRoomSettingCard({
    required String title,
    required String subtitle,
    required String? roomId,
    required IconData icon,
    required bool hasContent,
    String? coverUrl,
    required bool isEnabled,
    int? viewCount,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    Function(bool)? onToggleEnabled,
    required Color inkColor,
    required Color scrollBrown,
  }) {
    final isLoading = hasContent && _isLoadingLiveRoomInfo;

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: hasContent
                ? LinearGradient(
                    colors: [
                      _bilibiliBlue.withValues(alpha: 0.1),
                      _bilibiliBlue.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasContent ? null : Colors.grey.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasContent
                  ? _bilibiliBlue.withValues(alpha: 0.25)
                  : Colors.grey.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 封面区域
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isLoading)
                        Container(
                          color: _bilibiliBlue.withValues(alpha: 0.1),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (coverUrl != null)
                        DiskCachedImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: _bilibiliBlue.withValues(alpha: 0.1),
                            child: Icon(icon, color: _bilibiliBlue, size: 24),
                          ),
                        )
                      else
                        Container(
                          color: _bilibiliBlue.withValues(alpha: 0.1),
                          child: Icon(icon, color: _bilibiliBlue, size: 24),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: inkColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (roomId != null) ...[
                        Row(
                          children: [
                            Text(
                              '房间号: $roomId',
                              style: TextStyle(
                                fontSize: 11,
                                color: _bilibiliBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (viewCount != null && viewCount > 0) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.visibility,
                                size: 12,
                                color: inkColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatViewCount(viewCount),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: inkColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (isLoading)
                        SizedBox(
                          height: 14,
                          child: LinearProgressIndicator(
                            backgroundColor: _bilibiliBlue.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _bilibiliBlue,
                            ),
                          ),
                        )
                      else
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasContent
                                ? _bilibiliBlue
                                : inkColor.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onToggleEnabled != null) ...[
                      _buildToggleSwitch(
                        isEnabled: isEnabled,
                        onToggle: onToggleEnabled,
                        inkColor: inkColor,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildActionButton(
                      icon: hasContent ? Icons.edit : Icons.add,
                      onTap: hasContent && onEdit != null ? onEdit : onTap,
                      tooltip: hasContent ? '编辑' : '添加',
                      inkColor: inkColor,
                      isPrimary: true,
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

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
    required String tooltip,
    required Color inkColor,
    bool isLoading = false,
    bool isPrimary = false,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [_bilibiliBlueLight, _bilibiliBlue],
                  )
                : null,
            color: isPrimary ? null : _bilibiliBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bilibiliBlue.withValues(alpha: 0.3)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  icon,
                  size: 16,
                  color:
                      iconColor ?? (isPrimary ? Colors.white : _bilibiliBlue),
                ),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch({
    required bool isEnabled,
    required Function(bool) onToggle,
    required Color inkColor,
  }) {
    return Tooltip(
      message: isEnabled ? '已启用，点击停用' : '已停用，点击启用',
      child: InkWell(
        onTap: () => onToggle(!isEnabled),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled
                  ? Colors.green.withValues(alpha: 0.4)
                  : Colors.red.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.play_arrow : Icons.pause,
                size: 14,
                color: isEnabled ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                isEnabled ? '启用中' : '已停用',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isEnabled ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoListSection({
    required String title,
    required List<BilibiliVideo> videos,
    required VoidCallback onAdd,
    required Function(BilibiliVideo) onEdit,
    required Color inkColor,
    required Color scrollBrown,
  }) {
    final pageCount = videos.isEmpty
        ? 1
        : (videos.length / _videoPageSize).ceil().clamp(1, 999);
    final safePage = _videoCurrentPage.clamp(1, pageCount);

    // 由分页器组件自己通过监听变化或参数校准
    final startIndex = ((safePage - 1) * _videoPageSize).clamp(
      0,
      videos.length,
    );
    final endIndex = (startIndex + _videoPageSize).clamp(0, videos.length);
    final paginatedVideos = videos.isEmpty
        ? <BilibiliVideo>[]
        : videos.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle, color: _bilibiliBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: inkColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _bilibiliBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${videos.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: _bilibiliBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_bilibiliBlueLight, _bilibiliBlue],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '添加视频',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (videos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  color: Colors.grey.withValues(alpha: 0.5),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '暂无视频，点击上方添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: inkColor.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _bilibiliBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bilibiliBlue.withValues(alpha: 0.15)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  for (int i = 0; i < paginatedVideos.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _buildVideoListItem(
                      video: paginatedVideos[i],
                      onTap: () => _openVideoLink(paginatedVideos[i].bvid),
                      onEdit: () => onEdit(paginatedVideos[i]),
                      onDelete: () => _confirmDelete(
                        paginatedVideos[i].id,
                        BilibiliContentType.video,
                      ),
                      inkColor: inkColor,
                      scrollBrown: scrollBrown,
                      isLast: i == paginatedVideos.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required Color inkColor,
    required Function(int) onPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentPage > 1
                    ? _bilibiliBlue.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentPage > 1
                      ? _bilibiliBlue.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: currentPage > 1 ? _bilibiliBlue : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _bilibiliBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$currentPage / $totalPages',
              style: TextStyle(
                color: _bilibiliBlue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentPage < totalPages
                    ? _bilibiliBlue.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentPage < totalPages
                      ? _bilibiliBlue.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: currentPage < totalPages ? _bilibiliBlue : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoListItem({
    required BilibiliVideo video,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required Color inkColor,
    required Color scrollBrown,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: 120,
                      height: 68,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          video.displayCover != null
                              ? DiskCachedImage(
                                  imageUrl: video.displayCover!,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: _bilibiliBlue.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: _bilibiliBlue,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: _bilibiliBlue.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: _bilibiliBlue,
                                    size: 24,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: inkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              video.bvid,
                              style: TextStyle(
                                fontSize: 11,
                                color: inkColor.withValues(alpha: 0.4),
                              ),
                            ),
                            if (video.viewCount > 0) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.visibility,
                                size: 12,
                                color: inkColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatViewCount(video.viewCount),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: inkColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 作者信息：头像 + 名称
                        Row(
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: video.displayFace != null
                                    ? Image.network(
                                        video.displayFace!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: _bilibiliBlue.withValues(
                                            alpha: 0.2,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            size: 10,
                                            color: _bilibiliBlue.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: _bilibiliBlue.withValues(
                                          alpha: 0.2,
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          size: 10,
                                          color: _bilibiliBlue.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                video.ownerName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: inkColor.withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (video.isRejected && video.auditRemark != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '拒绝: ${video.auditRemark}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (video.category != null && video.category!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _bilibiliBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _bilibiliBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            video.category!,
                            style: TextStyle(
                              color: _bilibiliBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (video.category != null && video.category!.isNotEmpty)
                        const SizedBox(width: 8),
                      _buildVideoAuditBadge(video),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('编辑', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          foregroundColor: _bilibiliBlue,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('删除', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          foregroundColor: Colors.red.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: scrollBrown.withValues(alpha: 0.15)),
      ],
    );
  }

  Widget _buildVideoAuditBadge(BilibiliVideo video) {
    final status = video.auditStatus ?? 'pending';
    Color bgColor, textColor = Colors.white;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        bgColor = Colors.orange.withValues(alpha: 0.9);
        text = '待审核';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
        bgColor = Colors.green.withValues(alpha: 0.9);
        text = '已通过';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        bgColor = Colors.red.withValues(alpha: 0.9);
        text = '已拒绝';
        icon = Icons.close;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
