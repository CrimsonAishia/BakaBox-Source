import 'package:flutter/material.dart';

import '../../../core/models/queue_user.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/constants/app_colors.dart';

/// 挤服用户头像组件
///
/// 根据用户类型显示不同的头像：
/// - 已登录用户：显示用户头像
/// - 当前用户（未登录）：显示"我"字的圆形头像
/// - 其他未登录用户：显示"匿"字的圆形头像
///
/// 当前用户会有绿色边框和发光效果
class QueueUserAvatar extends StatelessWidget {
  /// 用户数据
  final QueueUser user;

  /// 头像大小
  final double size;

  /// 是否是暖服
  final bool isWarmup;

  const QueueUserAvatar({super.key, required this.user, this.size = 36, this.isWarmup = false});

  @override
  Widget build(BuildContext context) {
    return _QueueUserTooltip(
      user: user,
      isWarmup: isWarmup,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: user.isSelf
              ? Border.all(color: Colors.green, width: 2)
              : null,
          boxShadow: user.isSelf
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipOval(child: _buildAvatarContent()),
      ),
    );
  }

  /// 构建头像内容
  Widget _buildAvatarContent() {
    // 已登录用户：显示头像
    if (!user.isAnonymous &&
        user.avatarUrl != null &&
        user.avatarUrl!.isNotEmpty) {
      return DiskCachedImage(
        imageUrl: user.avatarUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: _buildTextAvatar('...'),
        errorWidget: _buildTextAvatar('?'),
      );
    }

    // 当前用户（未登录）：显示"我"
    if (user.isSelf) {
      return _buildTextAvatar('我', color: Colors.green.shade700);
    }

    // 其他未登录用户：显示"匿"
    return _buildTextAvatar('匿', color: Colors.grey.shade600);
  }

  /// 构建文字头像
  Widget _buildTextAvatar(String text, {Color? color}) {
    return Container(
      width: size,
      height: size,
      color: color ?? Colors.grey.shade700,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// 自定义 Tooltip，hover 时显示用户名 + 挤服时长（每次显示时实时计算）
class _QueueUserTooltip extends StatelessWidget {
  final QueueUser user;
  final Widget child;
  final bool isWarmup;

  const _QueueUserTooltip({required this.user, required this.child, this.isWarmup = false});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h小时$m分$s秒';
    if (m > 0) return '$m分$s秒';
    return '$s秒';
  }

  String _getDisplayName() {
    if (user.isSelf) return '我';
    if (user.isAnonymous) return '未登录用户';
    return user.nickname ?? '未知';
  }

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(user.joinedAt);
    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: _getDisplayName(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '\n已${isWarmup ? '暖服' : '挤'} ${_formatDuration(duration)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: child,
    );
  }
}
