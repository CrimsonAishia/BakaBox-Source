import 'package:bakabox_app/core/widgets/baka_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/core.dart';
import '../../../desktop/widgets/lobby/lobby_user_profile_panel.dart';
import '../../../desktop/games/lobby_game.dart';

/// 移动端在线玩家列表 BottomSheet 组件
///
/// 优先使用 [LobbyState.allOnlineUsers]（非空时），
/// 否则降级使用 [LobbyState.users]。
/// 打开时自动触发 [LobbyOnlineStatsRequested] 获取全服在线列表。
///
/// 支持搜索和状态筛选（全部/在线/游戏中/挤服中/暖服中），与桌面端一致。
class OnlinePlayersSheet extends StatefulWidget {
  const OnlinePlayersSheet({super.key});

  @override
  State<OnlinePlayersSheet> createState() => _OnlinePlayersSheetState();
}

class _OnlinePlayersSheetState extends State<OnlinePlayersSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 状态筛选：null=全部, 'online'=在线, 'inGame'=游戏中, 'queuing'=挤服中, 'warming'=暖服中
  String? _statusFilter;

  Set<String> _followedIds = {};
  String? _highlightedUserId;

  @override
  void initState() {
    super.initState();
    _loadFollowedIds();
    // 打开时请求一次全服在线用户列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LobbyBloc>().add(const LobbyOnlineStatsRequested());
      }
    });
  }

  void _loadFollowedIds() {
    final list = StorageUtils.getStringList('lobby_followed_user_ids');
    _followedIds = list.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    LobbyGame.activeInstance?.cancelFocus();
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
            !status.contains('暖服') &&
            !status.contains('热身') &&
            !status.contains('主菜单');
      case 'inGame':
        return status.contains('游戏中') ||
            status.contains('热身') ||
            status.contains('主菜单');
      case 'queuing':
        return status.contains('挤服');
      case 'warming':
        return status.contains('暖服');
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

  /// 兜底去重，确保列表中同一用户只出现一次。
  List<LobbyUser> _dedupUsers(List<LobbyUser> users) {
    String? selfBizId;
    for (final user in users) {
      if (user.isSelf &&
          user.businessUserId != null &&
          user.businessUserId!.isNotEmpty) {
        selfBizId = user.businessUserId;
        break;
      }
    }

    final seen = <String>{};
    var selfKept = false;
    final result = <LobbyUser>[];
    for (final user in users) {
      if (user.isSelf) {
        if (selfKept) continue;
        selfKept = true;
        result.add(user);
        continue;
      }
      if (selfBizId != null &&
          user.businessUserId != null &&
          user.businessUserId!.isNotEmpty &&
          user.businessUserId == selfBizId) {
        continue;
      }
      final key =
          (user.businessUserId != null && user.businessUserId!.isNotEmpty)
          ? 'biz_${user.businessUserId}'
          : 'uid_${user.userId}';
      if (seen.add(key)) {
        result.add(user);
      }
    }
    return result;
  }

  void _showPlayerContextMenu(
    BuildContext context,
    LobbyUser user,
    bool isFollowed,
    Offset globalPosition,
  ) {
    setState(() => _highlightedUserId = user.userId);

    // 移动端面板位于底部，遮挡了下方 70% 的高度
    // 为了让角色显示在上方 30% 可视区域的中心稍偏下一点（防贴顶），偏移量设为屏幕高度的 25%
    final screenHeight = MediaQuery.of(context).size.height;
    LobbyGame.activeInstance?.focusOnUser(
      user.userId,
      panelOffset: Offset(0, screenHeight * 0.25),
    );

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _MobilePlayerPopupMenu(
        position: globalPosition,
        isFollowed: isFollowed,
        onInvestigate: () {
          entry.remove();
          LobbyGame.activeInstance?.cancelFocus();
          setState(() => _highlightedUserId = null);
          LobbyUserProfilePanel.show(context, user);
        },
        onToggleFollow: () {
          entry.remove();
          _toggleFollow(user, isFollowed);
          LobbyGame.activeInstance?.cancelFocus();
          setState(() => _highlightedUserId = null);
        },
        onDismiss: () {
          entry.remove();
          LobbyGame.activeInstance?.cancelFocus();
          setState(() => _highlightedUserId = null);
        },
      ),
    );

    overlay.insert(entry);
  }

  void _toggleFollow(LobbyUser user, bool isFollowed) {
    setState(() {
      if (isFollowed) {
        _followedIds.remove(user.businessUserId);
      } else {
        if (user.businessUserId != null && user.businessUserId!.isNotEmpty) {
          _followedIds.add(user.businessUserId!);
        }
      }
      StorageUtils.setStringList(
        'lobby_followed_user_ids',
        _followedIds.toList(),
      );
    });
    LobbyGame.activeInstance?.reloadFollowedUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.96),
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
          final countWarming = _countForFilter(searchedUsers, 'warming');

          final currentMapUserIds = state.users.map((u) => u.userId).toSet();

          final displayUsers =
              searchedUsers
                  .where((u) => _matchesFilter(u, _statusFilter))
                  .toList()
                ..sort((a, b) {
                  // 1. 自己最前
                  if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
                  // 2. 无名玩家最后
                  final aNoName = a.displayName.trim().isEmpty || a.isAnonymous;
                  final bNoName = b.displayName.trim().isEmpty || b.isAnonymous;
                  if (aNoName != bNoName) return aNoName ? 1 : -1;
                  // 3. 关注用户靠前
                  final aFollowed = _followedIds.contains(a.businessUserId);
                  final bFollowed = _followedIds.contains(b.businessUserId);
                  if (aFollowed != bFollowed) return aFollowed ? -1 : 1;
                  // 4. 当前地图靠前
                  final aOnMap = currentMapUserIds.contains(a.userId);
                  final bOnMap = currentMapUserIds.contains(b.userId);
                  if (aOnMap != bOnMap) return aOnMap ? -1 : 1;
                  // 5. 按名称排序
                  return a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  );
                });

          final dedupedUsers = _dedupUsers(displayUsers);

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
                  countWarming: countWarming,
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
                          itemCount: dedupedUsers.length,
                          findChildIndexCallback: (Key key) {
                            if (key is ValueKey<String>) {
                              final id = key.value;
                              final index = dedupedUsers.indexWhere((u) {
                                final uid = u.businessUserId?.isNotEmpty == true
                                    ? 'biz_${u.businessUserId}'
                                    : 'uid_${u.userId}';
                                return uid == id;
                              });
                              if (index >= 0) return index;
                            }
                            return null;
                          },
                          itemBuilder: (context, index) {
                            final user = dedupedUsers[index];
                            final isFollowed = _followedIds.contains(
                              user.businessUserId,
                            );
                            final isHighlighted =
                                _highlightedUserId == user.userId;
                            final isOnCurrentMap = currentMapUserIds.contains(
                              user.userId,
                            );
                            String? userMapName;
                            if (isOnCurrentMap) {
                              userMapName = state.mapConfig?.displayName;
                            } else if (user.mapId != null) {
                              userMapName = '地图 ${user.mapId}';
                            }

                            return _PlayerListTileMobile(
                              user: user,
                              isFollowed: isFollowed,
                              isHighlighted: isHighlighted,
                              isOnCurrentMap: isOnCurrentMap,
                              currentMapName: isOnCurrentMap
                                  ? state.mapConfig?.displayName
                                  : userMapName,
                              onTapDown: user.isAnonymous
                                  ? null
                                  : user.isSelf
                                  ? (_) => LobbyUserProfilePanel.show(
                                      context,
                                      user,
                                    )
                                  : (details) => _showPlayerContextMenu(
                                      context,
                                      user,
                                      isFollowed,
                                      details.globalPosition,
                                    ),
                            );
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
                colors: [AppColors.lobbyBlue, Color(0xFF0B66C2)],
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
                            AppColors.sky400,
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
    required int countWarming,
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
                const SizedBox(width: 6),
                _buildFilterChip('warming', '暖服中', countWarming),
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
              ? AppColors.lobbyBlue.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.lobbyBlue.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: isSelected
                ? AppColors.lobbyBlue
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
class _PlayerListTileMobile extends StatelessWidget {
  final LobbyUser user;
  final bool isFollowed;
  final bool isHighlighted;
  final bool isOnCurrentMap;
  final String? currentMapName;
  final void Function(TapDownDetails)? onTapDown;

  const _PlayerListTileMobile({
    required this.user,
    this.isFollowed = false,
    this.isHighlighted = false,
    this.isOnCurrentMap = true,
    this.currentMapName,
    this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFF40C4FF).withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF40C4FF).withValues(alpha: 0.7)
              : user.isSelf
              ? AppColors.lobbyBlue.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF40C4FF).withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: onTapDown,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 头像
                _buildAvatar(user),
                const SizedBox(width: 12),
                // 名称、状态、地图
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          color: isFollowed
                              ? const Color(0xFFFFD740)
                              : isHighlighted
                              ? const Color(0xFF40C4FF)
                              : Colors.white,
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
                                color: isHighlighted
                                    ? const Color(0xFF81D4FA)
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 第三行：地图标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOnCurrentMap
                              ? const Color(0xFF4ADE80).withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isOnCurrentMap
                                ? const Color(0xFF4ADE80).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          isOnCurrentMap
                              ? currentMapName != null
                                    ? '$currentMapName（本地图）'
                                    : '本地图'
                              : (currentMapName ?? '其他地图'),
                          style: TextStyle(
                            color: isOnCurrentMap
                                ? const Color(0xFF4ADE80).withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 自己的标识或箭头
                if (user.isSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lobbyBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.lobbyBlue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      '我',
                      style: TextStyle(
                        color: AppColors.lobbyBlue,
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
        child: BakaCachedImage(
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
              ? AppColors.lobbyBlue
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
          ? AppColors.lobbyBlue.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.1),
      child: const Icon(Icons.person, size: 22, color: Colors.white54),
    );
  }
}

/// 移动端玩家交互弹出菜单
class _MobilePlayerPopupMenu extends StatelessWidget {
  final Offset position;
  final bool isFollowed;
  final VoidCallback onInvestigate;
  final VoidCallback onToggleFollow;
  final VoidCallback onDismiss;

  const _MobilePlayerPopupMenu({
    required this.position,
    required this.isFollowed,
    required this.onInvestigate,
    required this.onToggleFollow,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸，计算菜单实际位置（防止溢出）
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 120.0;
    const menuHeight = 90.0; // 适当增加高度适应移动端触控
    final dx = (position.dx + menuWidth > screenSize.width)
        ? position.dx - menuWidth
        : position.dx;
    final dy = (position.dy + menuHeight > screenSize.height)
        ? position.dy - menuHeight
        : position.dy;

    return Stack(
      children: [
        // 背景遮罩（透明，点击关闭）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 菜单本体
        Positioned(
          left: dx,
          top: dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: menuWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MobilePopupMenuItem(
                    icon: Icons.search,
                    label: '调查',
                    onTap: onInvestigate,
                  ),
                  _MobilePopupMenuItem(
                    icon: isFollowed ? Icons.favorite : Icons.favorite_border,
                    iconColor: isFollowed ? const Color(0xFFFFD740) : null,
                    label: isFollowed ? '取消关注' : '关注',
                    onTap: onToggleFollow,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 移动端弹出菜单项
class _MobilePopupMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _MobilePopupMenuItem({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
  final source = state.allOnlineUsers.isNotEmpty
      ? state.allOnlineUsers
      : state.users;
  return source.where((user) => user.isOnline).toList()..sort((a, b) {
    if (a.isSelf) return -1;
    if (b.isSelf) return 1;
    return a.displayName.compareTo(b.displayName);
  });
}
