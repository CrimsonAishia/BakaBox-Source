import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/core.dart';

/// 移动端在线玩家列表 BottomSheet 组件
///
/// 优先使用 [LobbyState.allOnlineUsers]（非空时），
/// 否则降级使用 [LobbyState.users]。
/// 打开时自动触发 [LobbyOnlineStatsRequested] 获取全服在线列表。
class OnlinePlayersSheet extends StatefulWidget {
  const OnlinePlayersSheet({super.key});

  @override
  State<OnlinePlayersSheet> createState() => _OnlinePlayersSheetState();
}

class _OnlinePlayersSheetState extends State<OnlinePlayersSheet> {
  @override
  void initState() {
    super.initState();
    // 打开时请求一次全服在线用户列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LobbyBloc>().add(const LobbyOnlineStatsRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: BlocBuilder<LobbyBloc, LobbyState>(
        builder: (context, state) {
          final players = resolvePlayerList(state);

          return SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(context, players.length, state.isLoadingAllOnlineUsers),
                Expanded(
                  child: players.isEmpty
                      ? Center(
                          child: Text(
                            '暂无在线玩家',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: players.length,
                          itemBuilder: (context, index) {
                            return _buildPlayerTile(context, players[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline,
              size: 22, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Text(
            '在线玩家 ($count)',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerTile(BuildContext context, LobbyUser user) {
    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: _buildAvatar(user),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (user.isSelf) ...[
            const SizedBox(width: 6),
            const Text(
              '你',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        user.statusText ?? '在线',
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
      trailing: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: user.isOnline ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildAvatar(LobbyUser user) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(user.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      child: Text(
        user.nickname.isNotEmpty ? user.nickname[0] : '?',
        style: const TextStyle(fontSize: 16, color: Colors.white70),
      ),
    );
  }
}

/// Resolves which player list to display.
///
/// Prefers [LobbyState.allOnlineUsers] when non-empty,
/// falls back to [LobbyState.users].
/// Only includes online users. Sorted: self first, then by displayName.
/// Exposed as a top-level function for property-based testing.
List<LobbyUser> resolvePlayerList(LobbyState state) {
  final source =
      state.allOnlineUsers.isNotEmpty ? state.allOnlineUsers : state.users;
  return source.where((user) => user.isOnline).toList()
    ..sort((a, b) {
      if (a.isSelf) return -1;
      if (b.isSelf) return 1;
      return a.displayName.compareTo(b.displayName);
    });
}
