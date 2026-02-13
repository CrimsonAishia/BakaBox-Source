import 'package:flutter/material.dart';

import '../../../core/models/queue_user.dart';
import '../../../core/widgets/disk_cached_image.dart';

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

  const QueueUserAvatar({
    super.key,
    required this.user,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltipText(),
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

  /// 获取 Tooltip 文本
  ///
  /// 规则：
  /// - 当前用户：显示"我"
  /// - 匿名用户：显示"匿名用户"
  /// - 已登录用户：显示昵称或"未知"
  String _getTooltipText() {
    if (user.isSelf) return '我';
    if (user.isAnonymous) return '匿名用户';
    return user.nickname ?? '未知';
  }

  /// 构建头像内容
  Widget _buildAvatarContent() {
    // 已登录用户：显示头像
    if (!user.isAnonymous && user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
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
