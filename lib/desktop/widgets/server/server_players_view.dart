import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/source_server_service.dart';

enum PlayerSortOption { name, score, time }

class ServerPlayersView extends StatefulWidget {
  final ExtendedServerItem server;
  final bool isDark;

  const ServerPlayersView({
    super.key,
    required this.server,
    required this.isDark,
  });

  @override
  State<ServerPlayersView> createState() => _ServerPlayersViewState();
}

class _ServerPlayersViewState extends State<ServerPlayersView> {
  bool _isLoadingPlayers = false;
  String? _playerError;
  List<PlayerInfo> _players = [];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _playerScrollController = ScrollController();
  String _searchQuery = '';
  PlayerSortOption _sortOption = PlayerSortOption.name;

  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _playerScrollController.addListener(_updateScrollIndicators);

    // 首次进入时拉取一次数据
    _fetchPlayerList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _playerScrollController.removeListener(_updateScrollIndicators);
    _playerScrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!mounted || !_playerScrollController.hasClients) return;
    final position = _playerScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  Future<void> _fetchPlayerList() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPlayers = true;
      _playerError = null;
    });

    try {
      final address =
          widget.server.serverItem.address ??
          widget.server.serverItem.serverAddress;
      if (address == null || address.isEmpty) {
        if (mounted) {
          setState(() {
            _playerError = '服务器地址无效';
            _isLoadingPlayers = false;
          });
        }
        return;
      }

      final parts = address.split(':');
      if (parts.length != 2) {
        if (mounted) {
          setState(() {
            _playerError = '服务器地址格式错误';
            _isLoadingPlayers = false;
          });
        }
        return;
      }

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final players = await SourceServerService.getServerPlayers(
        ip,
        port,
        timeout: 5000,
      );

      if (!mounted) return;

      if (players.isNotEmpty) {
        final playerList = players
            .asMap()
            .entries
            .map(
              (entry) => PlayerInfo(
                index: entry.key,
                name: entry.value.name,
                score: entry.value.score,
                duration: entry.value.duration.toInt(),
              ),
            )
            .toList();

        setState(() {
          _players = playerList;
          _isLoadingPlayers = false;
        });
      } else {
        final playerCount = widget.server.serverData?.players ?? 0;
        if (playerCount > 55) {
          setState(() {
            _playerError =
                '未接收到服务器返回数据：疑似受底层通信协议单包体积限制，中文名称占用字节较大，当55人左右及以上时极易超出上限导致获取失败';
            _isLoadingPlayers = false;
          });
        } else if (playerCount == 0) {
          setState(() {
            _players = [];
            _isLoadingPlayers = false;
          });
        } else {
          setState(() {
            _playerError = '获取玩家列表失败，请点击刷新重试';
            _isLoadingPlayers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _playerError = '获取玩家列表失败，请点击刷新重试';
          _isLoadingPlayers = false;
        });
      }
    }
  }

  List<PlayerInfo> get _filteredPlayers {
    var playersList = _players.where((player) {
      if (_searchQuery.isEmpty) return true;
      return player.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    playersList.sort((a, b) {
      switch (_sortOption) {
        case PlayerSortOption.name:
          return a.name.compareTo(b.name);
        case PlayerSortOption.score:
          return b.score.compareTo(a.score);
        case PlayerSortOption.time:
          return b.duration.compareTo(a.duration);
      }
    });
    return playersList;
  }

  String _formatGameTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '$hours小时$minutes分钟';
    return '$minutes分钟';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final iconColor = isDark ? Colors.white54 : Colors.black54;
    final inputBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final dropdownColor = isDark ? AppColors.slate800 : Colors.white;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: '搜索玩家...',
                      hintStyle: TextStyle(color: hintColor),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: iconColor,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      if (mounted) {
                        setState(() => _searchQuery = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: inputBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PlayerSortOption>(
                    value: _sortOption,
                    dropdownColor: dropdownColor,
                    style: TextStyle(color: textColor),
                    icon: Icon(Icons.arrow_drop_down, color: iconColor),
                    items: const [
                      DropdownMenuItem(
                        value: PlayerSortOption.name,
                        child: Text('按名称排序'),
                      ),
                      DropdownMenuItem(
                        value: PlayerSortOption.score,
                        child: Text('按得分排序'),
                      ),
                      DropdownMenuItem(
                        value: PlayerSortOption.time,
                        child: Text('按时长排序'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && mounted) {
                        setState(() => _sortOption = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _fetchPlayerList,
                icon: Icon(Icons.refresh, color: iconColor),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        Expanded(child: _buildPlayerList(isDark)),
      ],
    );
  }

  Widget _buildPlayerList(bool isDark) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    if (_isLoadingPlayers && _players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('正在获取玩家列表...', style: TextStyle(color: subTextColor)),
          ],
        ),
      );
    }

    if (_playerError != null && _players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircle, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_playerError!, style: TextStyle(color: subTextColor)),
          ],
        ),
      );
    }

    final filteredList = _filteredPlayers;

    if (filteredList.isEmpty && !_isLoadingPlayers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.accountOff,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text('暂无玩家数据', style: TextStyle(color: subTextColor)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _playerScrollController,
          padding: const EdgeInsets.all(24),
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final player = filteredList[index];
            return _buildPlayerItem(player, index, isDark);
          },
        ),
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: true, isDark: isDark),
          ),
        if (_canScrollDown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildScrollIndicator(isTop: false, isDark: isDark),
          ),
      ],
    );
  }

  Widget _buildScrollIndicator({required bool isTop, required bool isDark}) {
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final iconColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.3,
    );
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.8),
              bgColor.withValues(alpha: 0),
            ],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(top: isTop ? 4 : 0, bottom: isTop ? 0 : 4),
          child: Icon(
            isTop
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerItem(PlayerInfo player, int index, bool isDark) {
    final rowBgColor = isDark
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.black.withValues(alpha: 0.02);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: index.isEven ? rowBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              player.name.isEmpty ? '未知玩家' : player.name,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.trophy, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '${player.score}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(MdiIcons.clockOutline, size: 16, color: hintColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _formatGameTime(player.duration),
                    style: TextStyle(color: subTextColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
