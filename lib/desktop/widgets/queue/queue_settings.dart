import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/utils/server_item_utils.dart';

/// 挤服设置面板
class QueueSettings extends StatelessWidget {
  final int targetPlayers;
  final int threadCount;
  final bool enableAutoRetry;
  final bool disabled;
  final bool isGameRunning;
  final int maxPlayers; // 服务器最大人数
  final String? gameType; // 游戏类型，用于判断是否为 CSGO
  final ValueChanged<int>? onTargetPlayersChanged;
  final ValueChanged<int>? onThreadCountChanged;
  final ValueChanged<bool>? onAutoRetryChanged;

  const QueueSettings({
    super.key,
    required this.targetPlayers,
    required this.threadCount,
    required this.enableAutoRetry,
    this.disabled = false,
    this.isGameRunning = false,
    this.maxPlayers = 64,
    this.gameType,
    this.onTargetPlayersChanged,
    this.onThreadCountChanged,
    this.onAutoRetryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 判断是否为 CSGO 服务器
    final isCsgoServer = ServerItemUtils.isCsgoServer(gameType);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                MdiIcons.cog,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '挤服设置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 目标人数设置
          _buildTargetPlayersSlider(context, isDark),
          const SizedBox(height: 16),
          
          // 线程数量设置
          _buildThreadCountSlider(context, isDark),
          
          // 自动重试开关（CSGO 服务器不显示）
          if (!isCsgoServer) ...[
            const SizedBox(height: 16),
            _buildAutoRetrySwitch(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetPlayersSlider(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    // 目标人数最大值为 maxPlayers - 1，因为满人时无法进入
    final effectiveMaxPlayers = (maxPlayers > 1 ? maxPlayers : 64) - 1;
    final effectiveTargetPlayers = targetPlayers.clamp(1, effectiveMaxPlayers);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.accountGroup,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  '服务器多少人的时候进入',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$effectiveTargetPlayers人',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: effectiveTargetPlayers.toDouble(),
            min: 1,
            max: effectiveMaxPlayers.toDouble(),
            divisions: effectiveMaxPlayers - 1,
            onChanged: disabled ? null : (value) {
              onTargetPlayersChanged?.call(value.toInt());
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1人',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              '$effectiveMaxPlayers人',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThreadCountSlider(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final effectiveThreadCount = threadCount.clamp(3, 6);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.cpu64Bit,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  '线程数量',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$effectiveThreadCount个',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: effectiveThreadCount.toDouble(),
            min: 3,
            max: 6,
            divisions: 3,
            onChanged: disabled ? null : (value) {
              onThreadCountChanged?.call(value.toInt());
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '3个',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              '6个',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoRetrySwitch(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final canEnableAutoRetry = isGameRunning;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                MdiIcons.refresh,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '自动重试',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          richMessage: TextSpan(
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: '这是啥？\n',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              TextSpan(
                                text: '开了这个，没进去的话会自动继续挤\n\n',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              TextSpan(
                                text: '● ',
                                style: TextStyle(color: Colors.green.shade400, fontSize: 12),
                              ),
                              TextSpan(
                                text: '能看到连接、加载、进游戏的状态\n',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              TextSpan(
                                text: '● ',
                                style: TextStyle(color: Colors.orange.shade400, fontSize: 12),
                              ),
                              TextSpan(
                                text: '满了或者没连上会自动再试\n\n',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              TextSpan(
                                text: '需要用 BakaBox 启动游戏才行',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          preferBelow: false,
                          verticalOffset: 20,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.help,
                            child: Icon(
                              MdiIcons.helpCircleOutline,
                              size: 18,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!canEnableAutoRetry)
                      Text(
                        '需要使用启动器启动游戏',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enableAutoRetry,
          onChanged: (disabled || !canEnableAutoRetry) ? null : onAutoRetryChanged,
        ),
      ],
    );
  }
}
