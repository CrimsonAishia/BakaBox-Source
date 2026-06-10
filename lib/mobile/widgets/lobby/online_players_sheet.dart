import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/core.dart';
import '../../../desktop/widgets/lobby/lobby_user_profile_panel.dart';

/// 移动端在线玩家列表 BottomSheet 组件
///
/// 优先使用 [LobbyState.allOnlineUsers]（非空时），
/// 否则降级使用 [LobbyState.users]。
/// 打开时自动触发 [LobbyOnlineStatsRequested] 获取全服在线列表。
///
/// 支持搜索和状态筛选（全部/在线/游戏中/挤服中），与桌面端一致。
class OnlinePlayersSheet extends StatefulWidget {
  const OnlinePlayersSheet({super.key});

  @override
  State<OnlinePlayersSheet> createState() => _OnlinePlayersSheetState();
}

class _OnlinePlayersSheetState extends State<OnlinePlayersSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 状态筛选：null=全部, 'online'=在线, 'inGame'=游戏中, 'queuing'=挤服中
  String? _statusFilter;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 判断单个用户是否匹配指定筛选条件
  bool _matchesFilter(LobbyUser user, String? filter) {
    if (filter == null) return true;
    final status = (user.statusText ?? '在线').toLowerCase();
    switch (filter) {
      case 'online':
        return !status.contains('游戏中') &&
            !status.contains('挤服') &&
            !status.contains('热身') &&
            !status.contains('主菜单');
      case 'inGame':
        return status.contains('游戏中') ||
            status.contains('热身') ||
            status.contains('主菜单');
      case 'queuing':
        return status.contains('挤服');
      default:
        return true;
    }
  }

  /// 返回搜索过滤后、状态过滤前的在线用户列表
  List<LobbyUser> _getSearchedUsers(LobbyState state) {
    final source = state.allOnlineUsers.isNotEmpty
        ? state.allOnlineUsers
        : state.users;
    var filtered = source.where((user) => user.isOnline).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((user) => user.displayName.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  /// 计算指定筛选条件下的人数
  int _countForFilter(List<LobbyUser> searchedUsers, String? filter) {
    return searchedUsers.where((u) => _matchesFilter(u, filter)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: BlocBuilder<LobbyBloc, LobbyState>(
        builder: (context, state) {
          final searchedUsers = _getSearchedUsers(state);
          final countAll = searchedUsers.length;
          final countOnline = _countForFilter(searchedUsers, 'online');
          final countInGame = _countForFilter(searchedUsers, 'inGame');
          final countQueuing = _countForFilter(searchedUsers, 'queuing');

          final displayUsers =
              searchedUsers
                  .where((u) => _matchesFilter(u, _statusFilter))
                  .toList()
                ..sort((a, b) {
                  if (a.isSelf) return -1;
                  if (b.isSelf) return 1;
                  return a.displayName.compareTo(b.displayName);
                });

          return SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHandle(),
                _buildHeader(
                  context,
                  state.allOnlineUsers.isNotEmpty
                      ? state.totalOnlineCount
                      : state.onlineCount,
                  state.isLoadingAllOnlineUsers,
                ),
                // 搜索和筛选栏
                _buildFilterBar(
                  countAll: countAll,
                  countOnline: countOnline,
                  countInGame: countInGame,
                  countQueuing: countQueuing,
                ),
                const Divider(height: 1, color: Colors.white10),
                // 玩家列表
                Expanded(
                  child:
                      state.isLoadingAllOnlineUsers &&
                          state.allOnlineUsers.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white54,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                '正在加载玩家列表...',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : displayUsers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty || _statusFilter != null
                                ? '没有匹配的玩家'
                                : '暂无在线玩家',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          itemCount: displayUsers.length,
                          itemBuilder: (context, index) {
                            return _PlayerTileMobile(user: displayUsers[index]);
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
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1D9BF0), Color(0xFF0B66C2)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.group, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '在线玩家',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$count 人在线',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar({
    required int countAll,
    required int countOnline,
    required int countInGame,
    required int countQueuing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // 搜索框
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索玩家...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 状态筛选标签
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(null, '全部', countAll),
                const SizedBox(width: 6),
                _buildFilterChip('online', '在线', countOnline),
                const SizedBox(width: 6),
                _buildFilterChip('inGame', '游戏中', countInGame),
                const SizedBox(width: 6),
                _buildFilterChip('queuing', '挤服中', countQueuing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? filterValue, String label, int count) {
    final isSelected = _statusFilter == filterValue;
    final displayText = isSelected ? '$label ($count)' : label;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1D9BF0).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D9BF0).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF1D9BF0)
                : Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 玩家列表项（移动端）
///
/// 点击已登录用户弹出 [LobbyUserProfilePanel] 九宫格面板。
class _PlayerTileMobile extends StatelessWidget {
  final LobbyUser user;

  const _PlayerTileMobile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: user.isSelf
              ? const Color(0xFF1D9BF0).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: user.isAnonymous
              ? null
              : () => LobbyUserProfilePanel.show(context, user),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 头像
                _buildAvatar(user),
                const SizedBox(width: 12),
                // 名称和状态
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user.isOnline
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              user.statusText ?? '在线',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 自己的标识
                if (user.isSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9BF0).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF1D9BF0).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      '我',
                      style: TextStyle(
                        color: Color(0xFF1D9BF0),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (!user.isAnonymous)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(LobbyUser user) {
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    Widget avatar;
    if (hasAvatar) {
      avatar = ClipOval(
        child: Image.network(
          user.avatarUrl!,
          width: 40,
          height: 40,
          cacheWidth: 64,
          cacheHeight: 64,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
        ),
      );
    } else {
      avatar = _buildFallbackAvatar();
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: user.isSelf
              ? const Color(0xFF1D9BF0)
              : Colors.white.withValues(alpha: 0.1),
          width: user.isSelf ? 2 : 1,
        ),
      ),
      child: avatar,
    );
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: user.isSelf
          ? const Color(0xFF1D9BF0).withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.1),
      child: const Icon(Icons.person, size: 22, color: Colors.white54),
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
  final source = state.allOnlineUsers.isNotEmpty
      ? state.allOnlineUsers
      : state.users;
  return source.where((user) => user.isOnline).toList()..sort((a, b) {
    if (a.isSelf) return -1;
    if (b.isSelf) return 1;
    return a.displayName.compareTo(b.displayName);
  });
}
