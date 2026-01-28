import 'package:flutter/material.dart';

import '../../../core/models/map_contribution_models.dart';
import '../../../core/services/image_url_service.dart';
import '../../../core/widgets/disk_cached_image.dart';
import '../../../core/widgets/map_contribution_dialog.dart';
import '../../../core/widgets/marquee_text.dart';
import 'map_history_dialog.dart';

/// 地图信息卡片组件
/// 
/// 显示单个地图的信息卡片，点击后弹出贡献对话框
class MapInfoCard extends StatefulWidget {
  final MapInfo mapInfo;

  const MapInfoCard({
    super.key,
    required this.mapInfo,
  });

  @override
  State<MapInfoCard> createState() => _MapInfoCardState();
}

class _MapInfoCardState extends State<MapInfoCard> {
  bool _isHovered = false;

  void _showContributionDialog() {
    MapContributionDialog.show(
      context,
      mapName: widget.mapInfo.mapName,
      mapLabel: widget.mapInfo.mapLabel,
    );
  }

  void _showHistoryDialog() {
    MapHistoryDialog.show(
      context,
      mapName: widget.mapInfo.mapName,
      mapLabel: widget.mapInfo.mapLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF0080FF)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFF0080FF).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图
                _buildMapBackground(widget.mapInfo, isDark),
                
                // 底部渐变遮罩（始终显示）
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isHovered ? 100 : 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: _isHovered ? 0.95 : 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 地图名称（始终显示）
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: _isHovered ? 56 : 12,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeText(
                          text: widget.mapInfo.mapName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        MarqueeText(
                          text: '译名：${widget.mapInfo.mapLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Hover 时显示的按钮
                if (_isHovered)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildBottomButton(
                            icon: Icons.info_outline,
                            label: '地图信息',
                            onPressed: _showContributionDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBottomButton(
                            icon: Icons.history,
                            label: '运行记录',
                            onPressed: _showHistoryDialog,
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
    );
  }

  Widget _buildMapBackground(MapInfo mapInfo, bool isDark) {
    if (mapInfo.mapBackground == null || mapInfo.mapBackground!.isEmpty) {
      return Container(
        color: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE5E7EB),
        child: Center(
          child: Icon(
            Icons.map_outlined,
            size: 48,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.2),
          ),
        ),
      );
    }

    return FutureBuilder<String>(
      future: ImageUrlService.instance.getSignedUrl(mapInfo.mapBackground!),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? mapInfo.mapBackground!;
        return DiskCachedImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE5E7EB),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: Container(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE5E7EB),
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _BottomButton(
      icon: icon,
      label: label,
      onPressed: onPressed,
    );
  }
}

/// 底部按钮组件（带 hover 效果）
class _BottomButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_BottomButton> createState() => _BottomButtonState();
}

class _BottomButtonState extends State<_BottomButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
