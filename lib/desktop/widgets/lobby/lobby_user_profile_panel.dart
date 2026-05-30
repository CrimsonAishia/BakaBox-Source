import 'package:flutter/material.dart';

import '../../../core/models/lobby_models.dart';
import 'lobby_inventory_panel.dart';
import 'lobby_user_info_panel.dart';

/// 用户资料九宫格面板
///
/// 点击在线面板中的已登录用户时弹出。
class LobbyUserProfilePanel extends StatefulWidget {
  final LobbyUser user;
  final VoidCallback onClose;

  const LobbyUserProfilePanel({
    super.key,
    required this.user,
    required this.onClose,
  });

  /// 以对话框形式显示用户资料面板
  static Future<void> show(BuildContext context, LobbyUser user) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: LobbyUserProfilePanel(
          user: user,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  State<LobbyUserProfilePanel> createState() => _LobbyUserProfilePanelState();
}

class _LobbyUserProfilePanelState extends State<LobbyUserProfilePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F2E), Color(0xFF0F1624)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A3A5C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.06),
                  blurRadius: 40,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_buildHeader(), _buildGrid()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部用户基本信息
  Widget _buildHeader() {
    final user = widget.user;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1D9BF0).withValues(alpha: 0.12),
            const Color(0xFF0B66C2).withValues(alpha: 0.06),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF2A3A5C).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user.isOnline
                            ? const Color(0xFF4ADE80)
                            : Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        user.statusText ?? '在线',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(LobbyUser user) {
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF1D9BF0).withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D9BF0).withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                user.avatarUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
              )
            : _buildFallbackAvatar(),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 40,
      height: 40,
      color: const Color(0xFF1D9BF0).withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: Colors.white54, size: 22),
    );
  }

  /// 九宫格功能入口（固定3列布局，位置不随项目数量变化）
  Widget _buildGrid() {
    final items = <_GridItem?>[
      _GridItem(
        id: 'personal_data',
        icon: Icons.bar_chart_rounded,
        label: '个人数据',
        color: const Color(0xFF1D9BF0),
      ),
      _GridItem(
        id: 'inventory',
        icon: Icons.inventory_2_outlined,
        label: '库存统计',
        color: const Color(0xFF4ADE80),
      ),
      // 未来可扩展更多功能入口
    ];

    // 补齐到3的倍数，保证网格对齐
    while (items.length % 3 != 0) {
      items.add(null);
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item == null) return const SizedBox.shrink();
          return _GridItemWidget(item: item, onTap: () => _onItemTap(item.id));
        },
      ),
    );
  }

  void _onItemTap(String id) {
    switch (id) {
      case 'personal_data':
        Navigator.of(context).pop();
        LobbyUserInfoPanel.show(context, widget.user);
        break;
      case 'inventory':
        Navigator.of(context).pop();
        LobbyInventoryPanel.show(context, widget.user);
        break;
    }
  }
}

/// 九宫格项数据
class _GridItem {
  final String id;
  final IconData icon;
  final String label;
  final Color color;

  const _GridItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// 九宫格项组件
class _GridItemWidget extends StatefulWidget {
  final _GridItem item;
  final VoidCallback onTap;

  const _GridItemWidget({required this.item, required this.onTap});

  @override
  State<_GridItemWidget> createState() => _GridItemWidgetState();
}

class _GridItemWidgetState extends State<_GridItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.item.color.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? widget.item.color.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                color: widget.item.color.withValues(
                  alpha: _hovered ? 1.0 : 0.8,
                ),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.label,
                style: TextStyle(
                  color: _hovered
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
