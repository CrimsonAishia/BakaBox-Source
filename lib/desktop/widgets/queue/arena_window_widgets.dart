import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/utils/map_utils.dart';
import '../../../core/utils/player_count_utils.dart';
import '../../../core/widgets/map_background.dart';

/// 竞技场面板容器装饰（挤服 / 暖服共用）
BoxDecoration arenaPanelDecoration(bool isDark) {
  return BoxDecoration(
    color: isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.5)
        : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05),
    ),
  );
}

/// 挤服 / 暖服窗口头部
///
/// 地图背景 + 渐变遮罩 + 服务器信息（名称、地图、IP、玩家数）+ 关闭按钮。
class ArenaWindowHeader extends StatelessWidget {
  /// 标题（如"挤服" / "暖服"）
  final String title;

  /// 服务器名称（已处理好的展示名）
  final String serverName;

  /// 地图原始名称
  final String mapName;

  /// 地图背景图 URL
  final String? mapUrl;

  /// 服务器地址（IP:端口）
  final String serverAddress;

  /// 当前玩家数
  final int players;

  /// 最大玩家数
  final int maxPlayers;

  /// 是否已初始化（false 时显示加载遮罩）
  final bool isInitialized;

  /// 关闭回调
  final VoidCallback onClose;

  const ArenaWindowHeader({
    super.key,
    required this.title,
    required this.serverName,
    required this.mapName,
    required this.mapUrl,
    required this.serverAddress,
    required this.players,
    required this.maxPlayers,
    required this.isInitialized,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final playerColor = PlayerCountUtils.getPlayerCountColor(
      players,
      maxPlayers,
    );

    return Container(
      height: 130,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        color: Color(0xFF1E293B),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 地图背景
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: MapBackground(mapName: mapName, imageUrl: mapUrl),
          ),
          // 渐变遮罩
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          // 服务器信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：标题和关闭按钮
                Row(
                  children: [
                    Icon(
                      MdiIcons.accountMultiplePlus,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // 玩家数量标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: playerColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            MdiIcons.accountGroup,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$players/$maxPlayers',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 关闭按钮
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 服务器名称
                Text(
                  serverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 服务器信息标签
                Row(
                  children: [
                    _InfoChip(
                      icon: MdiIcons.map,
                      text: MapUtils.formatMapName(mapName),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoChip(icon: MdiIcons.ip, text: serverAddress),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 加载遮罩
          if (!isInitialized)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 头部信息标签（图标 + 文本）
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 竞技场中心服务器图标（挤服 / 暖服共用）
///
/// 根据服务器状态显示不同颜色的光晕：
/// - 红色：服务器满员，无法加入
/// - 绿色：服务器有空位，可以加入（或有用户成功加入时）
class ArenaServerIcon extends StatefulWidget {
  /// 是否可以加入（服务器有空位）
  final bool canJoin;

  /// 是否有用户刚成功加入
  final bool hasUserJoined;

  const ArenaServerIcon({
    super.key,
    required this.canJoin,
    this.hasUserJoined = false,
  });

  @override
  State<ArenaServerIcon> createState() => _ArenaServerIconState();
}

class _ArenaServerIconState extends State<ArenaServerIcon>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 颜色过渡动画
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;

  static const _greenColor = Color(0xFF22C55E);
  static const _redColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 颜色过渡动画控制器
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    final initialColor = (widget.canJoin || widget.hasUserJoined)
        ? _greenColor
        : _redColor;
    _colorAnimation = ColorTween(begin: initialColor, end: initialColor)
        .animate(
          CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
        );
  }

  @override
  void didUpdateWidget(ArenaServerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCanJoin = oldWidget.canJoin || oldWidget.hasUserJoined;
    final newCanJoin = widget.canJoin || widget.hasUserJoined;

    if (oldCanJoin != newCanJoin) {
      final fromColor = oldCanJoin ? _greenColor : _redColor;
      final toColor = newCanJoin ? _greenColor : _redColor;

      _colorAnimation = ColorTween(begin: fromColor, end: toColor).animate(
        CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
      );
      _colorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _colorAnimation]),
      builder: (context, child) {
        final glowColor = _colorAnimation.value ?? _greenColor;

        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // 外层光晕
              BoxShadow(
                color: glowColor.withValues(alpha: 0.3 * _pulseAnimation.value),
                blurRadius: 30 * _pulseAnimation.value,
                spreadRadius: 10 * _pulseAnimation.value,
              ),
              // 内层光晕
              BoxShadow(
                color: glowColor.withValues(alpha: 0.5 * _pulseAnimation.value),
                blurRadius: 15 * _pulseAnimation.value,
                spreadRadius: 3 * _pulseAnimation.value,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/queue/server.png',
            width: 80,
            height: 80,
          ),
        );
      },
    );
  }
}
