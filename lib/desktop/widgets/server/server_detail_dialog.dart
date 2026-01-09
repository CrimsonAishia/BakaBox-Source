import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/api/server_api.dart';
import '../../../core/services/source_server_service.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/widgets/map_background.dart';

/// 玩家排序选项
enum PlayerSortOption { name, score, time }

/// 服务器详情弹窗
/// 显示服务器详细信息和玩家列表
class ServerDetailDialog extends StatefulWidget {
  final ExtendedServerItem server;

  const ServerDetailDialog({
    super.key,
    required this.server,
  });

  @override
  State<ServerDetailDialog> createState() => _ServerDetailDialogState();
}

class _ServerDetailDialogState extends State<ServerDetailDialog> {
  final ServerApi _serverApi = ServerApi();
  
  // 状态
  bool _isLoading = true;
  bool _isLoadingPlayers = false;
  String? _error;
  String? _playerError;
  ServerDetailInfo? _serverDetail;
  int? _pingLatency;
  
  // 玩家列表控制
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _playerScrollController = ScrollController();
  String _searchQuery = '';
  PlayerSortOption _sortOption = PlayerSortOption.name;
  
  // 滚动指示器状态
  bool _canScrollUp = false;
  bool _canScrollDown = false;
  
  // 自动刷新
  Timer? _refreshTimer;
  static const int _refreshInterval = 10; // 10秒刷新一次玩家列表

  @override
  void initState() {
    super.initState();
    _playerScrollController.addListener(_updateScrollIndicators);
    _fetchServerDetail();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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


  /// 启动自动刷新
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _refreshInterval),
      (_) => _fetchPlayerList(),
    );
  }

  /// 获取服务器详情
  Future<void> _fetchServerDetail() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final address = widget.server.serverItem.address;
      if (address == null || address.isEmpty) {
        if (mounted) {
          setState(() {
            _error = '服务器地址无效';
            _isLoading = false;
          });
        }
        return;
      }

      if (widget.server.serverData != null) {
        setState(() {
          _serverDetail = ServerDetailInfo(
            serverInfo: widget.server.serverData!,
            playerList: [],
          );
          _isLoading = false;
        });
        // 单独获取玩家列表
        _fetchPlayerList();
      } else {
        setState(() {
          _error = '无法获取服务器信息';
          _isLoading = false;
        });
      }

      // 异步获取延迟信息
      _fetchPingLatency();
    } catch (e) {
      LogService.e('获取服务器详情失败: $e', e);
      if (mounted) {
        setState(() {
          _error = '获取服务器信息失败';
          _isLoading = false;
        });
      }
    }
  }

  /// 获取延迟信息
  Future<void> _fetchPingLatency() async {
    final address = widget.server.serverItem.address;
    if (address == null) return;

    final ip = address.split(':').first;
    if (ip.isEmpty) return;

    try {
      final pingInfo = await _serverApi.getServerPing(ip);
      if (pingInfo != null && mounted) {
        setState(() {
          _pingLatency = pingInfo.ping;
        });
      } else if (mounted) {
        // 使用现有延迟数据
        setState(() {
          _pingLatency = widget.server.pingInfo?.ping ?? 
                         widget.server.serverData?.pingLatency;
        });
      }
    } catch (e) {
      LogService.w('获取延迟信息失败: $e');
      if (mounted) {
        setState(() {
          _pingLatency = widget.server.pingInfo?.ping ?? 
                         widget.server.serverData?.pingLatency;
        });
      }
    }
  }

  /// 获取玩家列表（使用 A2S 协议直接查询）
  Future<void> _fetchPlayerList() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPlayers = true;
      _playerError = null;
    });

    try {
      final address = widget.server.serverItem.address;
      if (address == null || address.isEmpty) {
        if (mounted) {
          setState(() {
            _playerError = '服务器地址无效';
            _isLoadingPlayers = false;
          });
        }
        return;
      }

      // 解析地址
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
      if (port == null) {
        if (mounted) {
          setState(() {
            _playerError = '服务器端口无效';
            _isLoadingPlayers = false;
          });
        }
        return;
      }

      // 使用 SourceServerService 直接获取玩家列表
      final players = await SourceServerService.getServerPlayers(ip, port, timeout: 5000);
      
      if (!mounted) return;
      
      if (players.isNotEmpty) {
        // 转换为 PlayerInfo 列表
        final playerList = players.asMap().entries.map((entry) => PlayerInfo(
          index: entry.key,
          name: entry.value.name,
          score: entry.value.score,
          duration: entry.value.duration.toInt(),
        )).toList();
        
        setState(() {
          _serverDetail = ServerDetailInfo(
            serverInfo: _serverDetail?.serverInfo ?? widget.server.serverData ?? ServerInfo(
              hostName: '未知服务器',
              map: '未知地图',
              players: players.length,
              maxPlayers: 0,
            ),
            playerList: playerList,
          );
          _isLoadingPlayers = false;
        });
      } else {
        // 检查玩家数量，提供友好提示
        final playerCount = widget.server.serverData?.players ?? 0;
        if (playerCount > 55) {
          setState(() {
            _playerError = '由于A2S_PLAYER协议限制，无法获取超过55人服务器的玩家详情';
            _isLoadingPlayers = false;
          });
        } else if (playerCount == 0) {
          setState(() {
            _serverDetail = ServerDetailInfo(
              serverInfo: _serverDetail?.serverInfo ?? widget.server.serverData ?? ServerInfo(
                hostName: '未知服务器',
                map: '未知地图',
                players: 0,
                maxPlayers: 0,
              ),
              playerList: [],
            );
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
      LogService.e('获取玩家列表失败: $e', e);
      if (mounted) {
        setState(() {
          _playerError = '获取玩家列表失败，请点击刷新重试';
          _isLoadingPlayers = false;
        });
      }
    }
  }

  /// 获取过滤和排序后的玩家列表
  List<PlayerInfo> get _filteredPlayers {
    if (_serverDetail?.playerList == null) return [];

    var players = _serverDetail!.playerList.where((player) {
      if (_searchQuery.isEmpty) return true;
      return player.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    players.sort((a, b) {
      switch (_sortOption) {
        case PlayerSortOption.name:
          return a.name.compareTo(b.name);
        case PlayerSortOption.score:
          return b.score.compareTo(a.score);
        case PlayerSortOption.time:
          return b.duration.compareTo(a.duration);
      }
    });

    return players;
  }

  /// 格式化游戏时间
  String _formatGameTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }

  /// 获取延迟颜色
  Color _getPingColor(int? ping) {
    if (ping == null) return Colors.grey;
    if (ping < 50) return const Color(0xFF4CAF50);
    if (ping < 100) return const Color(0xFFFFC107);
    if (ping < 150) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 550,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    final serverInfo = _serverDetail?.serverInfo ?? widget.server.serverData;
    final mapName = serverInfo?.map ?? '未知地图';
    final mapUrl = widget.server.mapInfo?.mapUrl;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: const Color(0xFF1E293B),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.7),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        serverInfo?.hostName ?? '未知服务器',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 刷新按钮
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _isLoading ? null : _fetchServerDetail,
                      tooltip: '刷新',
                    ),
                    // 关闭按钮
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭',
                    ),
                  ],
                ),
                const Spacer(),
                // 服务器关键信息
                Row(
                  children: [
                    _buildInfoChip(MdiIcons.map, _getFormattedMapName(mapName)),
                    const SizedBox(width: 12),
                    _buildInfoChip(MdiIcons.ip, widget.server.serverItem.address ?? '未知'),
                    const SizedBox(width: 12),
                    if (_pingLatency != null)
                      _buildPingChip(_pingLatency!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取格式化的地图名称
  String _getFormattedMapName(String mapName) {
    return MapUtils.formatMapName(mapName);
  }

  /// 构建信息标签
  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  /// 构建延迟标签
  Widget _buildPingChip(int ping) {
    final color = _getPingColor(ping);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.signal, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${ping}ms',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }


  /// 构建内容区域
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
            ),
            SizedBox(height: 16),
            Text('加载服务器详情中...', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircle, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchServerDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildPlayerListHeader(),
        Expanded(child: _buildPlayerList()),
      ],
    );
  }

  /// 构建玩家列表头部
  Widget _buildPlayerListHeader() {
    final playerCount = _serverDetail?.playerList.length ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(MdiIcons.accountGroup, color: const Color(0xFF0080FF), size: 20),
              const SizedBox(width: 8),
              Text(
                '玩家列表 ($playerCount)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 搜索框
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索玩家...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _searchQuery = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 排序选项
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PlayerSortOption>(
                    value: _sortOption,
                    items: const [
                      DropdownMenuItem(value: PlayerSortOption.name, child: Text('按名称')),
                      DropdownMenuItem(value: PlayerSortOption.score, child: Text('按得分')),
                      DropdownMenuItem(value: PlayerSortOption.time, child: Text('按时长')),
                    ],
                    onChanged: (value) {
                      if (value != null && mounted) {
                        setState(() {
                          _sortOption = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建玩家列表
  Widget _buildPlayerList() {
    // 延迟检查滚动状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });
    
    // 玩家加载错误提示
    if (_playerError != null && (_serverDetail?.playerList.isEmpty ?? true)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircle, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _playerError!,
                style: const TextStyle(color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPlayerList,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final players = _filteredPlayers;

    // 没有玩家数据
    if (players.isEmpty && !_isLoadingPlayers) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.accountSearch, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('没有找到匹配的玩家', style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.accountOff, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无玩家数据', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    // 玩家列表警告提示
    Widget? warningBanner;
    if (_playerError != null && players.isNotEmpty) {
      warningBanner = Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(MdiIcons.alertCircle, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _playerError!,
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (warningBanner != null) warningBanner,
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _playerScrollController,
                padding: const EdgeInsets.all(16),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return _buildPlayerItem(player, index);
                },
              ),
              // 顶部滚动指示器
              if (_canScrollUp)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildScrollIndicator(isTop: true),
                ),
              // 底部滚动指示器
              if (_canScrollDown)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildScrollIndicator(isTop: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建滚动指示器
  Widget _buildScrollIndicator({required bool isTop}) {
    return IgnorePointer(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: isTop 
              ? null 
              : const BorderRadius.vertical(bottom: Radius.circular(16)),
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 2 : 0, bottom: isTop ? 0 : 2),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: const Color(0xFF6B7280),
          size: 24,
        ),
      ),
    );
  }

  /// 构建玩家项
  Widget _buildPlayerItem(PlayerInfo player, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index.isEven 
            ? Colors.grey.withValues(alpha: 0.05) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 序号
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 玩家名称
          Expanded(
            flex: 3,
            child: Text(
              player.name.isEmpty ? '未知玩家' : player.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 得分
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.trophy, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${player.score}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // 游戏时长
          SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(MdiIcons.clockOutline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _formatGameTime(player.duration),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
