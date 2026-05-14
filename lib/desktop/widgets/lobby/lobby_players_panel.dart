import 'package:flutter/material.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';

/// 玩家列表面板
class LobbyPlayersPanel extends StatelessWidget {
  final LobbyState state;
  final VoidCallback? onClose;

  const LobbyPlayersPanel({super.key, required this.state, this.onClose});

  @override
  Widget build(BuildContext context) {
    // 获取在线用户并排序：自己排第一，匿名用户排最后，其他按字母排序
    final onlineUsers = state.users.where((user) => user.isOnline).toList()
      ..sort((a, b) {
        // 自己排在第一位
        if (a.isSelf) return -1;
        if (b.isSelf) return 1;
        // 匿名用户排在最后
        if (a.isAnonymous && !b.isAnonymous) return 1;
        if (!a.isAnonymous && b.isAnonymous) return -1;
        // 其他玩家按 displayName 字母排序
        return a.displayName.compareTo(b.displayName);
      });

    return LobbyPanelShell(
      width: 280,
      title: '在线玩家',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: onlineUsers.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '暂无在线玩家',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: onlineUsers.length,
                itemBuilder: (context, index) {
                  final user = onlineUsers[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: _PlayerAvatar(user: user),
                    title: Text(
                      user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      user.statusText ?? '在线',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                    trailing: user.isSelf
                        ? const Text(
                            '你',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }
}

/// 玩家头像组件
/// 有 avatarUrl 则显示网络头像，否则显示问号图标
class _PlayerAvatar extends StatelessWidget {
  final LobbyUser user;

  const _PlayerAvatar({required this.user});

  static const int _avatarSize = 64; // 缓存尺寸（2x 显示尺寸）

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    if (hasAvatar) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: user.isSelf
            ? const Color(0xFF38BDF8)
            : Colors.white.withValues(alpha: 0.2),
        child: ClipOval(
          child: Image.network(
            user.avatarUrl!,
            width: 32,
            height: 32,
            cacheWidth: _avatarSize,
            cacheHeight: _avatarSize,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackAvatar();
            },
          ),
        ),
      );
    }

    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: user.isSelf
          ? const Color(0xFF38BDF8)
          : Colors.white.withValues(alpha: 0.2),
      child: const Icon(
        Icons.help_outline,
        size: 18,
        color: Colors.white70,
      ),
    );
  }
}

/// 面板通用外壳
class LobbyPanelShell extends StatelessWidget {
  final double width;
  final String title;
  final Widget child;
  final VoidCallback? onClose;

  const LobbyPanelShell({
    super.key,
    required this.width,
    required this.title,
    required this.child,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 600),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (onClose != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.circle,
                  size: 10,
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
