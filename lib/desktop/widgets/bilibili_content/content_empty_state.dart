import 'package:flutter/material.dart';

/// B站内容空状态组件
class BilibiliContentEmptyState extends StatelessWidget {
  final int currentTabIndex;

  static const _bilibiliBlue = Color(0xFF00A1D6);

  const BilibiliContentEmptyState({super.key, required this.currentTabIndex});

  @override
  Widget build(BuildContext context) {
    final inkColor = _getInkColor(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _bilibiliBlue.withValues(alpha: 0.1),
                      _bilibiliBlue.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Icon(
                currentTabIndex == 0
                    ? Icons.live_tv_outlined
                    : Icons.video_library_outlined,
                size: 56,
                color: _bilibiliBlue.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            currentTabIndex == 0 ? '暂无直播间' : '暂无视频',
            style: TextStyle(
              fontSize: 16,
              color: inkColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角"用户中心"添加内容',
            style: TextStyle(
              fontSize: 13,
              color: inkColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Color _getInkColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE8E0D8)
        : const Color(0xFF2C1810);
  }
}
