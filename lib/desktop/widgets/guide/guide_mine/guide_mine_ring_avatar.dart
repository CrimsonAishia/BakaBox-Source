import 'package:flutter/material.dart';

import '../../../../core/widgets/signed_network_image.dart';

/// 带蓝色光环的圆形头像（个人资料区使用）
class GuideMineRingAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallback;
  final double size;
  final Color ringColor;

  const GuideMineRingAvatar({
    super.key,
    this.avatarUrl,
    required this.fallback,
    required this.size,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final inner = size - 6;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: SizedBox(
          width: inner,
          height: inner,
          child: SignedNetworkImage(
            url: avatarUrl,
            fallback: _buildFallback(),
            cacheWidth: (inner * 2).toInt(),
            cacheHeight: (inner * 2).toInt(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: ringColor.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          fallback.isNotEmpty ? fallback.characters.first.toUpperCase() : '?',
          style: TextStyle(
            color: ringColor,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
