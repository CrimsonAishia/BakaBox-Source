import 'package:flutter/material.dart';

import '../../services/image_url_service.dart';
import '../../utils/formatters.dart';
import '../disk_cached_image.dart';
import 'guide_tokens.dart';

/// 详情页作者信息条
///
/// 包含：头像 24 circle + 昵称 + 相对时间 + 阅读时间 + 浏览数 + 更多菜单（举报/拉黑）。
///
/// 用法：
/// ```dart
/// GuideAuthorBar(
///   authorId: guide.authorId,
///   authorName: guide.authorName,
///   authorAvatar: guide.authorAvatar,
///   publishedAt: guide.publishedAt?.toIso8601String() ?? guide.createdAt.toIso8601String(),
///   readingTimeMin: guide.readingTimeMin,
///   viewCount: guide.viewCount,
///   currentUserId: authBloc.userId,
///   onAuthorTap: () {},
///   onReport: () => ReportDialog.show(context, targetId: guide.id, targetType: 'guide'),
///   onBlock: (userId) => handleBlock(userId),
/// )
/// ```
class GuideAuthorBar extends StatefulWidget {
  /// 作者 ID
  final int authorId;

  /// 作者昵称
  final String authorName;

  /// 作者头像 URL
  final String? authorAvatar;

  /// 发布时间（ISO 8601 字符串，用于 Formatters.formatDate 相对显示）
  final String publishedAt;

  /// 预估阅读时间（分钟）
  final int readingTimeMin;

  /// 浏览数
  final int viewCount;

  /// 当前登录用户 ID（null 表示未登录，用于判断是否显示拉黑选项）
  final int? currentUserId;

  /// 点击作者回调
  final VoidCallback? onAuthorTap;

  /// 点击「举报」
  final VoidCallback? onReport;

  /// 点击「拉黑此用户」，参数为作者 userId
  final ValueChanged<int>? onBlock;

  const GuideAuthorBar({
    super.key,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.publishedAt,
    this.readingTimeMin = 0,
    this.viewCount = 0,
    this.currentUserId,
    this.onAuthorTap,
    this.onReport,
    this.onBlock,
  });

  @override
  State<GuideAuthorBar> createState() => _GuideAuthorBarState();
}

class _GuideAuthorBarState extends State<GuideAuthorBar> {
  Future<String>? _signedAvatarFuture;

  @override
  void initState() {
    super.initState();
    _loadAvatarUrl();
  }

  @override
  void didUpdateWidget(GuideAuthorBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorAvatar != widget.authorAvatar) {
      _loadAvatarUrl();
    }
  }

  void _loadAvatarUrl() {
    final url = widget.authorAvatar;
    if (url != null && url.isNotEmpty) {
      _signedAvatarFuture = ImageUrlService.instance.getSignedUrl(url);
    } else {
      _signedAvatarFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GuideTokens.space12),
      child: Row(
        children: [
          // 头像
          GestureDetector(onTap: widget.onAuthorTap, child: _buildAvatar()),
          const SizedBox(width: GuideTokens.space8),

          // 昵称
          GestureDetector(
            onTap: widget.onAuthorTap,
            child: Text(
              widget.authorName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: GuideTokens.textPrimary(context),
              ),
            ),
          ),

          const SizedBox(width: GuideTokens.space12),

          // 分隔点
          _buildDot(context),
          const SizedBox(width: GuideTokens.space12),

          // 相对时间
          Text(
            Formatters.formatDate(widget.publishedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: GuideTokens.textTertiary(context),
            ),
          ),

          const Spacer(),

          // 阅读时间
          if (widget.readingTimeMin > 0) ...[
            Icon(
              Icons.schedule_outlined,
              size: 14,
              color: GuideTokens.textTertiary(context),
            ),
            const SizedBox(width: GuideTokens.space4),
            Text(
              '${widget.readingTimeMin} 分钟阅读',
              style: theme.textTheme.bodySmall?.copyWith(
                color: GuideTokens.textTertiary(context),
              ),
            ),
            const SizedBox(width: GuideTokens.space16),
          ],

          // 浏览数
          Icon(
            Icons.visibility_outlined,
            size: 14,
            color: GuideTokens.textTertiary(context),
          ),
          const SizedBox(width: GuideTokens.space4),
          Text(
            _formatCount(widget.viewCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: GuideTokens.textTertiary(context),
            ),
          ),

          // 更多菜单（举报 / 拉黑）— 仅非自己的攻略显示
          if (_shouldShowMoreMenu) ...[
            const SizedBox(width: GuideTokens.space12),
            _buildMoreMenu(context),
          ],
        ],
      ),
    );
  }

  /// 是否应该显示更多菜单（非自己的攻略时显示）
  bool get _shouldShowMoreMenu {
    return widget.currentUserId == null ||
        widget.currentUserId != widget.authorId;
  }

  Widget _buildMoreMenu(BuildContext context) {
    final actionColor = GuideTokens.textTertiary(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 18, color: actionColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        minimumSize: const Size(28, 28),
        padding: const EdgeInsets.all(4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 16),
                SizedBox(width: 8),
                Text('举报'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                Icon(Icons.block, size: 16),
                SizedBox(width: 8),
                Text('拉黑此用户'),
              ],
            ),
          ),
        ];
      },
      onSelected: (value) {
        switch (value) {
          case 'report':
            widget.onReport?.call();
          case 'block':
            widget.onBlock?.call(widget.authorId);
        }
      },
    );
  }

  Widget _buildAvatar() {
    return ClipOval(
      child: SizedBox(
        width: 24,
        height: 24,
        child: _signedAvatarFuture != null
            ? FutureBuilder<String>(
                future: _signedAvatarFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return DiskCachedImage(
                      imageUrl: snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: 48,
                      cacheHeight: 48,
                    );
                  }
                  return _buildFallbackAvatar();
                },
              )
            : _buildFallbackAvatar(),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          widget.authorName.isNotEmpty
              ? widget.authorName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDot(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: GuideTokens.textTertiary(context),
        shape: BoxShape.circle,
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    return count.toString();
  }
}
