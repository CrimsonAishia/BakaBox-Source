import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/bloc/server/server_bloc.dart';
import '../../../core/bloc/server/server_event.dart';
import '../../../core/bloc/server/server_state.dart';
import '../../../core/utils/map_runtime_utils.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/services/status_window_service.dart';
import '../../../core/services/map_change_monitor_service.dart';
import '../../../core/widgets/map_background.dart';
import 'server_history_dialog.dart';
import 'server_card_skeleton.dart';
import '../queue/queue_window.dart';
import '../../../core/widgets/map_contribution_dialog.dart';

/// 服务器卡片
class ServerCard extends StatefulWidget {
  final ExtendedServerItem server;
  final VoidCallback? onTap;
  final VoidCallback? onDelete; // 删除回调（仅自定义服务器）

  const ServerCard({
    super.key,
    required this.server,
    this.onTap,
    this.onDelete,
  });

  @override
  State<ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<ServerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _rgbController;
  bool _isConnecting = false;
  bool _isHovered = false;
  
  // 浮动面板相关
  OverlayEntry? _floatingPanelEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isPanelHovered = false; // 追踪面板hover状态
  
  // 监听 StatusWindowService 状态
  final StatusWindowService _statusService = StatusWindowService();
  StreamSubscription<OperationState>? _stateSubscription;
  
  // 换图监控服务
  final MapChangeMonitorService _mapMonitorService = MapChangeMonitorService();
  StreamSubscription<Set<String>>? _monitorSubscription;
  bool _isMonitoring = false;
  
  // 热身时间刷新定时器
  Timer? _warmupRefreshTimer;

  @override
  void initState() {
    super.initState();
    _rgbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    // 监听状态变化，当操作完成或游戏关闭时重置连接状态
    _stateSubscription = _statusService.stateStream.listen(_onStatusChanged);
    
    // 初始化换图监控状态
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    if (address != null) {
      _isMonitoring = _mapMonitorService.isMonitoring(address);
    }
    _monitorSubscription = _mapMonitorService.monitorStateStream.listen(_onMonitorStateChanged);
    
    // 如果处于热身状态，启动刷新定时器
    _updateWarmupTimer();
  }
  
  @override
  void didUpdateWidget(covariant ServerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检查热身状态变化，更新定时器
    _updateWarmupTimer();
  }
  
  /// 更新热身刷新定时器
  void _updateWarmupTimer() {
    if (_isWarmingUp && _warmupRefreshTimer == null) {
      // 热身中，启动每秒刷新
      _warmupRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isWarmingUp) {
          setState(() {});
        } else {
          _warmupRefreshTimer?.cancel();
          _warmupRefreshTimer = null;
        }
      });
    } else if (!_isWarmingUp && _warmupRefreshTimer != null) {
      // 热身结束，停止定时器
      _warmupRefreshTimer?.cancel();
      _warmupRefreshTimer = null;
    }
  }
  
  void _onMonitorStateChanged(Set<String> monitoredAddresses) {
    if (!mounted) return;
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    if (address != null) {
      final newState = monitoredAddresses.contains(address);
      if (newState != _isMonitoring) {
        setState(() => _isMonitoring = newState);
      }
    }
  }
  
  void _onStatusChanged(OperationState state) {
    if (!mounted) return;
    
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    
    // 触发重建以更新按钮状态
    setState(() {
      // 重置连接状态的条件：
      // 1. 当前服务器的操作完成（成功、失败、暂停）
      // 2. 游戏关闭
      // 3. 状态被重置（type=none, status=idle）
      if (_isConnecting) {
        final isCurrentServer = state.serverAddress == address;
        final isReset = state.type == OperationType.none && state.status == OperationStatus.idle;
        final isCompleted = state.status == OperationStatus.success ||
            state.status == OperationStatus.failed ||
            state.status == OperationStatus.serverFull ||
            state.status == OperationStatus.paused;
        
        // 当状态被重置，或当前服务器操作完成，或游戏关闭时，重置连接状态
        if (isReset || (isCurrentServer && isCompleted) || !state.isGameRunning) {
          _isConnecting = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _safeRemoveOverlay();
    _stateSubscription?.cancel();
    _monitorSubscription?.cancel();
    _warmupRefreshTimer?.cancel();
    _rgbController.dispose();
    super.dispose();
  }

  /// 显示浮动功能面板
  void _showFloatingPanel() {
    if (_floatingPanelEntry != null) return;
    if (!mounted) return;
    
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    
    _floatingPanelEntry = OverlayEntry(
      builder: (context) => _FloatingActionPanel(
        link: _layerLink,
        server: widget.server,
        isMonitoring: _isMonitoring,
        onMapEdit: () {
          _hideFloatingPanel();
          _showContributionDialog(context);
        },
        onMapMonitor: () {
          _hideFloatingPanel();
          _toggleMapMonitor();
        },
        onRefreshCache: () {
          _hideFloatingPanel();
          _refreshMapCache();
        },
        onDelete: widget.server.serverItem.isCustom ? () {
          _hideFloatingPanel();
          _showDeleteConfirmDialog(context);
        } : null,
        onHoverChanged: (isHovered) {
          _isPanelHovered = isHovered;
          if (!isHovered) {
            _tryHidePanel();
          }
        },
      ),
    );
    overlay.insert(_floatingPanelEntry!);
  }

  /// 安全移除 overlay entry
  void _safeRemoveOverlay() {
    final entry = _floatingPanelEntry;
    _floatingPanelEntry = null;
    _isPanelHovered = false; // 重置面板hover状态
    if (entry != null && entry.mounted) {
      try {
        entry.remove();
      } catch (_) {
        // 忽略移除时的错误
      }
    }
  }

  /// 隐藏浮动功能面板
  void _hideFloatingPanel() {
    _safeRemoveOverlay();
  }

  /// 尝试隐藏面板（只有当卡片和面板都没有hover时才隐藏）
  void _tryHidePanel() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isHovered && !_isPanelHovered && mounted) {
        _hideFloatingPanel();
      }
    });
  }

  /// 处理卡片hover状态变化
  void _onCardHoverChanged(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _showFloatingPanel();
    } else {
      _tryHidePanel();
    }
  }


  bool get _isWarmingUp {
    // 自定义服务器不进行热身检测
    if (widget.server.serverItem.isCustom) {
      return false;
    }
    
    return MapRuntimeUtils.isWarmingUp(
      widget.server.mapRuntime,
      fetchedAt: widget.server.mapRuntimeLastFetched,
      mapName: widget.server.serverData?.map,
      hasError: widget.server.mapRuntimeError,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _onCardHoverChanged(true),
        onExit: (_) => _onCardHoverChanged(false),
        child: AnimatedBuilder(
          animation: _rgbController,
          builder: (context, child) {
            final rgbColor = _getRgbColor(_rgbController.value);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: _isHovered
                    ? Border.all(
                        color: _isWarmingUp
                            ? rgbColor.withValues(alpha: 0.8)
                            : const Color(0xFF0080FF).withValues(alpha: 0.6),
                        width: 2,
                      )
                    : null,
                boxShadow: [
                  if (_isWarmingUp) ...[
                    BoxShadow(
                      color: rgbColor,
                      blurRadius: _isHovered ? 20 : 8,
                      spreadRadius: _isHovered ? 4 : 0,
                    ),
                    if (_isHovered)
                      BoxShadow(
                        color: rgbColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ] else ...[
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0xFF0080FF).withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: _isHovered ? 16 : 4,
                      spreadRadius: _isHovered ? 1 : 0,
                      offset: Offset(0, _isHovered ? 4 : 2),
                      ),
                      if (_isHovered)
                        BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 165, // 固定高度
                  child: Stack(
                    children: [
                      // 地图背景
                      Positioned.fill(child: _buildMapBackground()),
                      // 渐变遮罩
                      Positioned.fill(child: _buildGradientOverlay()),
                      // Hover 高亮遮罩
                      if (_isHovered)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isWarmingUp
                                    ? [
                                        rgbColor.withValues(alpha: 0.1),
                                        Colors.transparent,
                                        rgbColor.withValues(alpha: 0.08),
                                      ]
                                    : [
                                        const Color(0xFF0080FF)
                                            .withValues(alpha: 0.08),
                                        Colors.transparent,
                                        const Color(0xFF0080FF)
                                            .withValues(alpha: 0.05),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      // 热身边框
                      if (_isWarmingUp) _buildWarmupBorder(),
                      // 刷新加载指示器
                      _buildRefreshIndicator(),
                      // 内容
                      _buildContent(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getRgbColor(double value) {
    // RGB循环：红->绿->蓝->红
    final colors = [
      const Color(0xFFFF4444),
      const Color(0xFF44FF44),
      const Color(0xFF4488FF),
      const Color(0xFFFF8844),
    ];
    final index = (value * colors.length).floor() % colors.length;
    final nextIndex = (index + 1) % colors.length;
    final t = (value * colors.length) % 1.0;
    return Color.lerp(colors[index], colors[nextIndex], t)!;
  }

  Widget _buildWarmupBorder() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _getRgbColor(_rgbController.value),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildMapBackground() {
    // 使用 mapInfo 的背景图
    final mapUrl = widget.server.mapInfo?.mapUrl;
    
    return MapBackground(
      mapName: widget.server.serverData?.map,
      imageUrl: mapUrl,
    );
  }

  /// 刷新加载指示器（骨架屏）
  Widget _buildRefreshIndicator() {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
        if (address == null || !(state.isMapRefreshing(address))) {
          return const SizedBox.shrink();
        }

        // 使用骨架屏覆盖整个卡片
        return const Positioned.fill(
          child: ServerCardSkeleton(),
        );
      },
    );
  }

  /// 渐变遮罩
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }

  /// 内容区域 - 左右布局
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧信息
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildLeftContent(),
            ),
          ),
          const SizedBox(width: 10),
          // 右侧玩家数量和运行时间
          _buildRightContent(),
        ],
      ),
    );
  }

  Widget _buildLeftContent() {
    final data = widget.server.serverData;
    final address = widget.server.serverItem.address ?? '未知地址';
    final hostName =
        data?.hostName ?? widget.server.serverItem.address ?? '未知服务器';
    final mapName = data?.map ?? '未知地图';

    // 获取地图显示名称
    final mapLabel = widget.server.mapInfo?.mapLabel;
    // 确保中文名不为空字符串
    final chineseName = (mapLabel?.isNotEmpty == true) ? mapLabel : null;
    // 显示格式：有中文名时 "英文名 (中文名)"，否则只显示英文名
    final displayMapName = chineseName != null 
        ? '$mapName ($chineseName)' 
        : mapName;

    // 只使用系统 ping 的结果
    final ping = widget.server.pingInfo?.ping;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 服务器名称
        Text(
          hostName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
              Shadow(color: Colors.black, blurRadius: 8),
              Shadow(color: Colors.black, offset: Offset(1, 1)),
              Shadow(color: Colors.black, offset: Offset(-1, -1)),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        // 地图名称（使用中文翻译，过长时滚动）
        Row(
          children: [
            const Text(
              '地图：',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [
                  Shadow(
                      color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
            ),
            Expanded(
              child: _MarqueeText(
                text: displayMapName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(0, 1)),
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // 地址和延迟
        Row(
          children: [
            Text(
              address,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(
                      color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
            ),
            // 复制图标
            _CopyIconButton(
              onTap: () => _copyConnectCommand(address),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('|', style: TextStyle(color: Colors.white30)),
            ),
            _buildPingBadge(ping),
          ],
        ),
        const SizedBox(height: 10),
        // 按钮组
        _buildButtonGroup(),
      ],
    );
  }

  Widget _buildPingBadge(int? ping) {
    if (ping == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF999999).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '???',
          style: TextStyle(
            color: Color(0xFF999999),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Color color;
    if (ping < 50) {
      color = const Color(0xFF00D084);
    } else if (ping < 100) {
      color = const Color(0xFF52C41A);
    } else if (ping < 150) {
      color = const Color(0xFFFAAD14);
    } else if (ping < 300) {
      color = const Color(0xFFFF7A45);
    } else {
      color = const Color(0xFFFF4D4F);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Text(
        '${ping}ms',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildButtonGroup() {
    final data = widget.server.serverData;
    final isDisabled = data == null || widget.server.isLoading;
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    final isCustomServer = widget.server.serverItem.isCustom; // 判断是否为自定义服务器
    
    // 检查全局操作状态
    final globalState = _statusService.state;
    final isGlobalBusy = globalState.type != OperationType.none && 
        globalState.status == OperationStatus.running;
    final isCurrentServerBusy = globalState.serverAddress == address && isGlobalBusy;
    final isOtherServerBusy = globalState.serverAddress != address && isGlobalBusy;
    
    // 确定连接按钮的文本和状态
    String connectText;
    bool connectDisabled;
    
    if (_isConnecting || isCurrentServerBusy) {
      if (globalState.type == OperationType.launching) {
        connectText = '启动中...';
      } else if (globalState.type == OperationType.connecting) {
        connectText = '连接中...';
      } else {
        connectText = '连接中...';
      }
      connectDisabled = true;
    } else if (isOtherServerBusy) {
      connectText = '连接';
      connectDisabled = true; // 其他服务器正在操作时禁用
    } else {
      connectText = '连接';
      connectDisabled = isDisabled;
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _buildBtn(
          text: connectText,
          bgColor: Colors.white,
          textColor: const Color(0xFF0080FF),
          onPressed: connectDisabled ? null : _handleConnect,
        ),
        _buildBtn(
          text: '挤服',
          bgColor: const Color(0xFFFF6E6E),
          textColor: Colors.white,
          onPressed: isDisabled || isGlobalBusy ? null : () => _showQueueWindow(context),
        ),
        _buildBtn(
          text: '玩家',
          bgColor: const Color(0xFF10B981),
          textColor: Colors.white,
          onPressed: isDisabled ? null : widget.onTap,
        ),
        // 只有非自定义服务器才显示历史按钮
        if (!isCustomServer)
          _buildBtn(
            text: '历史',
            bgColor: const Color(0xFFF59E0B),
            textColor: Colors.white,
            onPressed: () => _showHistoryDialog(context),
          ),
      ],
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context) {
    final address = widget.server.serverItem.address ?? 
                    widget.server.serverItem.serverAddress ?? 
                    '未知地址';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除服务器 "$address" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 切换换图监控
  Future<void> _toggleMapMonitor() async {
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    if (address == null) return;

    final serverName = widget.server.serverData?.hostName ?? address;
    final currentMap = widget.server.serverData?.map;
    final currentMapCn = widget.server.mapInfo?.mapLabel;

    final isNowMonitoring = await _mapMonitorService.toggleMonitor(
      serverAddress: address,
      serverName: serverName,
      currentMap: currentMap,
      currentMapCn: currentMapCn,
    );

    if (mounted) {
      ToastUtils.showSuccess(
        context,
        isNowMonitoring ? '已开启换图监控' : '已关闭换图监控',
      );
    }
  }

  /// 刷新地图信息
  void _refreshMapCache() {
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    final mapName = widget.server.serverData?.map;
    
    if (address == null || mapName == null) {
      return;
    }

    // 通过 context 获取 ServerBloc 并发送刷新事件
    context.read<ServerBloc>().add(ServerRefreshMapCache(
      address: address,
      mapName: mapName,
    ));
  }

  Widget _buildBtn({
    required String text,
    required Color bgColor,
    required Color textColor,
    VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;

    return Material(
      color: disabled ? const Color(0xFFCCCCCC) : bgColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              color: disabled ? const Color(0xFF666666) : textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 是否处于离线/维护状态
  bool get _isOffline => widget.server.hasError && widget.server.serverData == null;
  
  /// 是否处于服务器启动状态（graphics_settings 地图）
  bool get _isStarting => widget.server.serverData?.map == 'graphics_settings';

  Widget _buildRightContent() {
    final data = widget.server.serverData;
    final players = data?.players ?? 0;
    final maxPlayers = data?.maxPlayers ?? 0;

    // 离线/维护状态显示
    if (_isOffline) {
      return _buildOfflineStatus();
    }
    
    // 服务器启动状态显示
    if (_isStarting) {
      return _buildStartingStatus();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 玩家数量
        _buildPlayerCount(players, maxPlayers),
        const SizedBox(height: 8),
        // 地图运行时间（自定义服务器不显示）
        if (data?.map != null &&
            !widget.server.isLoading &&
            !widget.server.serverItem.isCustom)
          _buildRuntimeInfo(),
      ],
    );
  }

  /// 离线/维护状态显示
  Widget _buildOfflineStatus() {
    return _buildStatusCard(
      icon: Icons.cloud_off_rounded,
      text: '离线',
      color: const Color(0xFFEF4444),
    );
  }

  /// 服务器启动状态显示
  Widget _buildStartingStatus() {
    return _buildStatusCard(
      icon: Icons.refresh_rounded,
      text: '启动中',
      color: const Color(0xFFF97316),
    );
  }

  /// 通用状态卡片
  Widget _buildStatusCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 玩家数量 - 当前人数/最大人数（行内斜杠分隔）
  Widget _buildPlayerCount(int players, int maxPlayers) {
    Color primaryColor;
    Color bgColor;

    if (players >= maxPlayers && maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336);
      bgColor = const Color(0xFFFEEAEA);
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      primaryColor = const Color(0xFFFF9800);
      bgColor = const Color(0xFFFFF9E6);
    } else {
      primaryColor = const Color(0xFF0080FF);
      bgColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // 当前人数（大字）
          Text(
            '$players',
            style: TextStyle(
              color: primaryColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          // 斜杠
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '/',
              style: TextStyle(
                color: const Color(0xFF9CA3AF),
                fontSize: 20,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          // 最大人数（小字）
          Text(
            '$maxPlayers',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeInfo() {
    final hasError = widget.server.mapRuntimeError;
    final isLoading = widget.server.mapRuntime == null && !hasError;
    final mapName = widget.server.serverData?.map;
    final fetchedAt = widget.server.mapRuntimeLastFetched;

    String displayText;
    if (_isWarmingUp) {
      displayText = MapRuntimeUtils.getWarmupDisplay(
        widget.server.mapRuntime,
        fetchedAt: fetchedAt,
        mapName: mapName,
      );
    } else {
      displayText = MapRuntimeUtils.getRuntimeDisplay(
        mapRuntime: widget.server.mapRuntime,
        fetchedAt: fetchedAt,
        isLoading: widget.server.isLoading,
        hasError: hasError,
      );
    }

    Color iconColor;
    Color textColor;
    Color bgColor;
    Color borderColor;

    if (hasError) {
      iconColor = const Color(0xFFF0A020);
      textColor = const Color(0xFFF0A020);
      bgColor = const Color(0xFFF0A020).withValues(alpha: 0.15);
      borderColor = const Color(0xFFF0A020).withValues(alpha: 0.3);
    } else if (_isWarmingUp) {
      iconColor = const Color(0xFFFF9800);
      textColor = const Color(0xFFE65100);
      bgColor = Colors.white.withValues(alpha: 0.98);
      borderColor = const Color(0xFFFF9800);
    } else if (isLoading) {
      iconColor = const Color(0xFF9CA3AF);
      textColor = const Color(0xFF6B7280);
      bgColor = const Color(0xFF9CA3AF).withValues(alpha: 0.15);
      borderColor = const Color(0xFF9CA3AF).withValues(alpha: 0.2);
    } else {
      iconColor = const Color(0xFF10B981);
      textColor = const Color(0xFF1F2937);
      bgColor = Colors.white.withValues(alpha: 0.95);
      borderColor = Colors.white.withValues(alpha: 0.3);
    }

    return Column(
      children: [
        // 运行时间
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          constraints: const BoxConstraints(minWidth: 80),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: _isWarmingUp ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.clockOutline, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                displayText,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: _isWarmingUp ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // 周出现次数
        if (widget.server.mapRuntime?.weeklyOccurrences != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isWarmingUp
                    ? const Color(0xFFFFF9E6).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isWarmingUp
                      ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                  children: [
                    const TextSpan(text: '一周出现'),
                    TextSpan(
                      text: '${widget.server.mapRuntime!.weeklyOccurrences}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const TextSpan(text: '次'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleConnect() async {
    if (_isConnecting) return;

    final address = widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address == null) {
      if (mounted) {
        ToastUtils.showError(context, '服务器地址无效');
      }
      return;
    }

    setState(() => _isConnecting = true);

    final serverName = widget.server.serverData?.hostName ?? address;
    final mapName = widget.server.serverData?.map;
    final mapInfo = widget.server.mapInfo;
    final statusService = StatusWindowService();

    // 使用 StatusWindowService 执行连接（自动处理浮窗）
    // connectToServer 会等待连接完成后才返回
    final success = await statusService.connectToServer(
      serverAddress: address,
      serverName: serverName,
      mapName: mapName,
      mapNameCn: mapInfo?.mapLabel,
      mapBackground: mapInfo?.mapUrl,
    );

    // connectToServer 返回后，连接流程已完成，此时显示 Toast
    if (mounted) {
      final state = statusService.state;
      if (success) {
        ToastUtils.showSuccess(context, '进去啦！');
      } else if (state.status == OperationStatus.serverFull) {
        ToastUtils.showWarning(context, '服务器已满');
      } else if (state.message != null && state.message!.isNotEmpty) {
        ToastUtils.showError(context, state.message!);
      }
      setState(() => _isConnecting = false);
    }
  }

  void _copyConnectCommand(String address) {
    Clipboard.setData(ClipboardData(text: 'connect $address'));
    ToastUtils.showSuccess(context, '已复制连接命令');
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ServerHistoryDialog(server: widget.server),
    );
  }

  void _showQueueWindow(BuildContext context) async {
    final address = widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address == null) return;

    // 直接使用主窗口对话框进行挤服操作
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: QueueWindow(
            serverAddress: address,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
  }

  /// 显示地图贡献对话框
  /// Requirements: 4.4
  void _showContributionDialog(BuildContext context) {
    final mapName = widget.server.serverData?.map;
    if (mapName == null) return;

    final mapLabel = widget.server.mapInfo?.mapLabel;
    
    MapContributionDialog.show(
      context,
      mapName: mapName,
      mapLabel: mapLabel,
    );
  }
}


/// 滚动文本组件 - 文本过长时自动滚动
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(_MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollController.jumpTo(0);
      _isScrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!mounted) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    setState(() => _needsScroll = maxScroll > 0);
    if (_needsScroll && !_isScrolling) {
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScroll) return;
    _isScrolling = true;
    
    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll) break;
      
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) break;
      
      // 滚动到末尾
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 30).toInt().clamp(1000, 5000)),
        curve: Curves.linear,
      );
      
      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      
      // 滚动回开头
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
      
      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}


/// 复制图标按钮 - 带hover效果和鼠标指针变化
class _CopyIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CopyIconButton({required this.onTap});

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(
            Icons.copy,
            size: 14,
            color: _isHovered ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// 浮动功能面板 - 卡片右侧展开（重新设计版本）
class _FloatingActionPanel extends StatefulWidget {
  final LayerLink link;
  final ExtendedServerItem server;
  final bool isMonitoring;
  final VoidCallback? onMapEdit;
  final VoidCallback? onMapMonitor;
  final VoidCallback? onRefreshCache;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onHoverChanged;

  const _FloatingActionPanel({
    required this.link,
    required this.server,
    required this.isMonitoring,
    this.onMapEdit,
    this.onMapMonitor,
    this.onRefreshCache,
    this.onDelete,
    this.onHoverChanged,
  });

  @override
  State<_FloatingActionPanel> createState() => _FloatingActionPanelState();
}

class _FloatingActionPanelState extends State<_FloatingActionPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<double>(begin: -12, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 构建按钮列表
  List<_FloatingButtonConfig> _buildButtonConfigs(bool isDisabled, bool isRefreshing) {
    return [
      _FloatingButtonConfig(
        icon: MdiIcons.pencilOutline,
        label: '编辑',
        color: const Color(0xFF8B5CF6),
        isDisabled: isDisabled,
        onTap: isDisabled ? null : widget.onMapEdit,
      ),
      _FloatingButtonConfig(
        icon: MdiIcons.refresh,
        label: '刷新缓存',
        color: const Color(0xFFF59E0B),
        isDisabled: isDisabled || isRefreshing,
        tooltip: '获取最新地图信息',
        onTap: (isDisabled || isRefreshing) ? null : widget.onRefreshCache,
      ),
      _FloatingButtonConfig(
        icon: widget.isMonitoring ? MdiIcons.bellRing : MdiIcons.bellOutline,
        label: '换图监控',
        color: widget.isMonitoring
            ? const Color(0xFF10B981)
            : const Color(0xFF3B82F6),
        isActive: widget.isMonitoring,
        isDisabled: isDisabled,
        onTap: isDisabled ? null : widget.onMapMonitor,
      ),
      if (widget.onDelete != null)
        _FloatingButtonConfig(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          color: const Color(0xFFEF4444),
          onTap: widget.onDelete,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.server.serverData;
    final isDisabled = data == null || widget.server.isLoading;
    
    // 获取刷新状态
    final address = widget.server.serverItem.address ?? widget.server.serverItem.serverAddress;
    
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final isRefreshing = address != null && (state.isMapRefreshing(address));
        
        // 构建按钮配置列表
        final buttons = _buildButtonConfigs(isDisabled, isRefreshing);

        // 每列最多2个按钮，计算需要的列数
        const maxPerColumn = 2;
        const columnWidth = 54.0;
        const columnGap = 4.0;
        final columnCount = (buttons.length / maxPerColumn).ceil();
        final panelWidth =
            columnCount * columnWidth + (columnCount - 1) * columnGap + 12;

        // 将按钮分配到各列
        final columns = <List<_FloatingButtonConfig>>[];
        for (var i = 0; i < buttons.length; i += maxPerColumn) {
          columns.add(buttons.sublist(
            i,
            (i + maxPerColumn).clamp(0, buttons.length),
          ));
        }

        return Positioned(
          width: panelWidth + 8,
          child: CompositedTransformFollower(
            link: widget.link,
            targetAnchor: Alignment.centerRight,
            followerAnchor: Alignment.centerLeft,
            offset: const Offset(6, 0),
            child: MouseRegion(
              onEnter: (_) => widget.onHoverChanged?.call(true),
              onExit: (_) => widget.onHoverChanged?.call(false),
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_slideAnimation.value, 0),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: _animController.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: const Color(0xFF94A3B8),
                    strokeWidth: 1.5,
                    dashWidth: 6,
                    dashSpace: 4,
                    radius: 12,
                  ),
                  child: Container(
                    width: panelWidth,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xF0FFFFFF),
                          Color(0xE8F8FAFC),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(4, 4),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < columns.length; i++) ...[
                              if (i > 0) const SizedBox(width: columnGap),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final config in columns[i])
                                    _FloatingActionButton(
                                      icon: config.icon,
                                      label: config.label,
                                      color: config.color,
                                      isActive: config.isActive,
                                      isDisabled: config.isDisabled,
                                      tooltip: config.tooltip,
                                      onTap: config.onTap,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 浮动按钮配置
class _FloatingButtonConfig {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final bool isDisabled;
  final String? tooltip;
  final VoidCallback? onTap;

  const _FloatingButtonConfig({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    this.isDisabled = false,
    this.tooltip,
    this.onTap,
  });
}

/// 浮动面板中的操作按钮（重新设计版本）
class _FloatingActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final bool isDisabled;
  final String? tooltip;
  final VoidCallback? onTap;

  const _FloatingActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    this.isDisabled = false,
    this.tooltip,
    this.onTap,
  });

  @override
  State<_FloatingActionButton> createState() => _FloatingActionButtonState();
}

class _FloatingActionButtonState extends State<_FloatingActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isDisabled || widget.onTap == null;
    final isHighlighted = widget.isActive || (_isHovered && !isDisabled);

    final button = MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) {
        if (!isDisabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isHighlighted && !isDisabled
                ? widget.color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标容器
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  // 激活状态使用实色背景
                  color: widget.isActive && !isDisabled
                      ? widget.color
                      : isDisabled
                          ? const Color(0xFFE2E8F0)
                          : _isHovered
                              ? widget.color.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isActive && !isDisabled
                        ? widget.color
                        : isHighlighted && !isDisabled
                            ? widget.color.withValues(alpha: 0.4)
                            : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isActive && !isDisabled
                          ? widget.color.withValues(alpha: 0.35)
                          : _isHovered && !isDisabled
                              ? widget.color.withValues(alpha: 0.2)
                              : Colors.transparent,
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: isDisabled
                      ? const Color(0xFFCBD5E1)
                      : widget.isActive
                          ? Colors.white
                          : _isHovered
                              ? widget.color
                              : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              // 标签文字
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDisabled
                      ? const Color(0xFFCBD5E1)
                      : isHighlighted
                          ? widget.color
                          : const Color(0xFF64748B),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 如果有 tooltip，包裹 Tooltip widget
    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        verticalOffset: 10,
        child: button,
      );
    }

    return button;
  }
}

/// 虚线边框绘制器
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = _createDashedPath(path);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source) {
    final dashPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = dashWidth.clamp(0, metric.length - distance);
        dashPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        dashSpace != oldDelegate.dashSpace ||
        radius != oldDelegate.radius;
  }
}
