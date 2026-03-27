import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/models/map_tag_models.dart';
import '../../../core/bloc/server/server_bloc.dart';
import '../../../core/bloc/server/server_event.dart';
import '../../../core/bloc/server/server_state.dart';
import '../../../core/utils/map_runtime_utils.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/services/status_window_service.dart';
import '../../../core/services/map_change_monitor_service.dart';
import '../../../core/widgets/map_background.dart';
import '../../../core/widgets/csgo_legacy_install_dialog.dart';
import '../../../core/widgets/csgo_manual_launch_dialog.dart';
import 'server_history_dialog.dart';
import 'server_card_skeleton.dart';
import '../queue/queue_window.dart';
import '../../../core/widgets/map_contribution_dialog.dart';
import '../edit_server_dialog.dart';

/// 服务器卡片
class ServerCard extends StatefulWidget {
  final ExtendedServerItem server;
  final String? categoryName; // 分类名称
  final VoidCallback? onTap;
  final VoidCallback? onDelete; // 删除回调（仅自定义服务器）
  final bool disableHoverEffect; // 是否禁用悬浮效果（排序模式时用）

  const ServerCard({
    super.key,
    required this.server,
    this.categoryName,
    this.onTap,
    this.onDelete,
    this.disableHoverEffect = false,
  });

  @override
  State<ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<ServerCard> with TickerProviderStateMixin {
  // RGB 动画控制器（仅热身状态时创建，节省内存）
  AnimationController? _rgbController;
  // 跑马灯动画控制器（仅挤服状态时创建）
  AnimationController? _marchingAntsController;
  bool _isConnecting = false;
  bool _isHovered = false;

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
    // 延迟创建动画控制器，只在热身状态时创建
    _updateAnimationController();

    // 监听状态变化，当操作完成或游戏关闭时重置连接状态
    _stateSubscription = _statusService.stateStream.listen(_onStatusChanged);

    // 初始化换图监控状态
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address != null) {
      _isMonitoring = _mapMonitorService.isMonitoring(address);
      // 检查是否正在挤服，初始化跑马灯动画
      _updateMarchingAntsController();
    }
    _monitorSubscription = _mapMonitorService.monitorStateStream.listen(
      _onMonitorStateChanged,
    );

    // 如果处于热身状态，启动刷新定时器
    _updateWarmupTimer();
  }

  @override
  void didUpdateWidget(covariant ServerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 只在热身状态真正改变时更新
    final oldWarmingUp = oldWidget.server.serverItem.isCustom
        ? false
        : MapRuntimeUtils.isWarmingUp(
            oldWidget.server.mapRuntime,
            fetchedAt: oldWidget.server.mapRuntimeLastFetched,
            mapName: oldWidget.server.serverData?.map,
            hasError: oldWidget.server.mapRuntimeError,
          );

    if (oldWarmingUp != _isWarmingUp) {
      _updateWarmupTimer();
      _updateAnimationController();
    }

    // 检查地址是否改变，更新监控状态
    final oldAddress =
        oldWidget.server.serverItem.address ??
        oldWidget.server.serverItem.serverAddress;
    final newAddress =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (oldAddress != newAddress && newAddress != null) {
      _isMonitoring = _mapMonitorService.isMonitoring(newAddress);
    }
  }

  /// 更新动画控制器（仅热身状态时创建）
  void _updateAnimationController() {
    if (_isWarmingUp && _rgbController == null) {
      // 热身中，创建动画控制器
      _rgbController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    } else if (!_isWarmingUp && _rgbController != null) {
      // 热身结束，释放动画控制器
      _rgbController?.dispose();
      _rgbController = null;
    }
  }

  /// 更新跑马灯动画控制器（仅挤服状态时创建）
  void _updateMarchingAntsController() {
    final isQueueing = _isCurrentServerQueueing;
    if (isQueueing && _marchingAntsController == null) {
      _marchingAntsController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    } else if (!isQueueing && _marchingAntsController != null) {
      _marchingAntsController?.dispose();
      _marchingAntsController = null;
    }
  }

  /// 检查当前服务器是否正在挤服
  bool get _isCurrentServerQueueing {
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    final globalState = _statusService.state;
    return globalState.type == OperationType.queueing &&
        globalState.status == OperationStatus.running &&
        globalState.serverAddress == address;
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
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address != null) {
      final newState = monitoredAddresses.contains(address);
      if (newState != _isMonitoring) {
        setState(() => _isMonitoring = newState);
      }
    }
  }

  void _onStatusChanged(OperationState state) {
    if (!mounted) return;

    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;

    // 更新跑马灯动画控制器
    _updateMarchingAntsController();

    // 触发重建以更新按钮状态
    setState(() {
      // 重置连接状态的条件：
      // 1. 当前服务器的操作完成（成功、失败、暂停）
      // 2. 游戏关闭
      // 3. 状态被重置（type=none, status=idle）
      if (_isConnecting) {
        final isCurrentServer = state.serverAddress == address;
        final isReset =
            state.type == OperationType.none &&
            state.status == OperationStatus.idle;
        final isCompleted =
            state.status == OperationStatus.success ||
            state.status == OperationStatus.failed ||
            state.status == OperationStatus.serverFull ||
            state.status == OperationStatus.paused;

        // 当状态被重置，或当前服务器操作完成，或游戏关闭时，重置连接状态
        if (isReset ||
            (isCurrentServer && isCompleted) ||
            !state.isGameRunning) {
          _isConnecting = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _monitorSubscription?.cancel();
    _warmupRefreshTimer?.cancel();
    _rgbController?.dispose();
    _marchingAntsController?.dispose();
    super.dispose();
  }

  /// 处理卡片hover状态变化
  void _onCardHoverChanged(bool isHovered) {
    if (!mounted) return;

    // 如果禁用了悬浮效果（排序模式），不响应 hover
    if (widget.disableHoverEffect) return;

    if (_isHovered != isHovered) {
      setState(() => _isHovered = isHovered);
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onCardHoverChanged(true),
      onExit: (_) => _onCardHoverChanged(false),
      child: _rgbController != null
          ? AnimatedBuilder(
              animation: _rgbController!,
              builder: (context, child) =>
                  _buildCardContent(_getRgbColor(_rgbController!.value)),
            )
          : _buildCardContent(const Color(0xFF0080FF)),
    );
  }

  /// 构建卡片内容
  Widget _buildCardContent(Color rgbColor) {
    final isQueueing = _isCurrentServerQueueing;

    // 边框颜色优先级：挤服 > 热身 > hover > 无
    Color borderColor;
    if (isQueueing && _isHovered) {
      borderColor = const Color(0xFF22C55E).withValues(alpha: 0.8);
    } else if (_isHovered && _isWarmingUp) {
      borderColor = rgbColor.withValues(alpha: 0.8);
    } else if (_isHovered) {
      borderColor = const Color(0xFF0080FF).withValues(alpha: 0.6);
    } else {
      borderColor = Colors.transparent;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (isQueueing) ...[
            // 挤服时绿色发光
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ] else if (_isWarmingUp) ...[
            BoxShadow(color: rgbColor, blurRadius: 8),
          ] else ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6), // 内部圆角略小，配合边框
        child: SizedBox(
          height: 136, // 140 - 2*2 边框
          child: Stack(
            children: [
              // 地图背景
              Positioned.fill(child: _buildMapBackground()),
              // 渐变遮罩
              Positioned.fill(child: _buildGradientOverlay()),
              // 边框效果优先级：挤服 > 热身
              // 挤服跑马灯边框（最高优先级）
              if (isQueueing && _marchingAntsController != null)
                _buildMarchingAntsBorder()
              // 热身边框（挤服时不显示）
              else if (_isWarmingUp)
                _buildWarmupBorder(rgbColor),
              // 刷新加载指示器
              _buildRefreshIndicator(),
              // 内容
              _buildContent(),
              // 监控黄点
              if (_isMonitoring) _buildMonitoringIndicator(),
              // Hover 时的毛玻璃操作层
              _buildHoverActionOverlay(),
            ],
          ),
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

  Widget _buildWarmupBorder(Color rgbColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: rgbColor, width: 2),
        ),
      ),
    );
  }

  /// 挤服跑马灯边框
  Widget _buildMarchingAntsBorder() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _marchingAntsController!,
        builder: (context, child) {
          return CustomPaint(
            painter: _MarchingAntsPainter(
              progress: _marchingAntsController!.value,
              borderRadius: 6,
            ),
          );
        },
      ),
    );
  }

  /// 监控中浮动黄点（卡片右上角）
  Widget _buildMonitoringIndicator() {
    return Positioned(top: 8, right: 8, child: _FloatingYellowDot());
  }

  Widget _buildMapBackground() {
    // 使用 mapInfo 的背景图
    final mapUrl = widget.server.mapInfo?.mapUrl;

    // 卡片高度 165，宽度约 400-600
    // 使用 2 倍分辨率保证清晰度，同时限制解码尺寸节省内存
    return MapBackground(
      mapName: widget.server.serverData?.map,
      imageUrl: mapUrl,
      cacheWidth: 800, // 2x 显示宽度
      cacheHeight: 330, // 2x 显示高度
    );
  }

  /// 刷新加载指示器（骨架屏）
  Widget _buildRefreshIndicator() {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final address =
            widget.server.serverItem.address ??
            widget.server.serverItem.serverAddress;
        if (address == null || !(state.isMapRefreshing(address))) {
          return const SizedBox.shrink();
        }

        // 使用骨架屏覆盖整个卡片
        return const Positioned.fill(child: ServerCardSkeleton());
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
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
    // 使用 getDisplayName 方法：优先备注名，其次服务器名，最后地址
    final hostName = widget.server.serverItem.getDisplayName(data?.hostName);
    final mapName = data?.map ?? '未知地图';

    // 获取地图显示名称
    final mapLabel = widget.server.mapInfo?.mapLabel;
    // 确保中文名不为空字符串
    final chineseName = (mapLabel?.isNotEmpty == true) ? mapLabel : null;
    // 显示格式：有中文名时 "中文名 (英文名)"，否则只显示英文名
    final displayMapName = chineseName != null
        ? '$chineseName ($mapName)'
        : mapName;

    // 只使用系统 ping 的结果
    final ping = widget.server.pingInfo?.ping;

    // 统一紧凑间距
    final verticalSpacing = 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 服务器名称
        Text(
          hostName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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
        SizedBox(height: verticalSpacing),
        // 地图名称（使用中文翻译，过长时滚动）
        Row(
          children: [
            Icon(
              MdiIcons.map,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MarqueeText(
                text: displayMapName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: verticalSpacing),
        // 地址和延迟
        Row(
          children: [
            Icon(
              MdiIcons.ip,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 6),
            Text(
              address,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
            ),
            // 复制图标
            _CopyIconButton(onTap: () => _copyConnectCommand(address)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('|', style: TextStyle(color: Colors.white30)),
            ),
            _buildPingBadge(ping),
          ],
        ),
        // 地图标签（非 hover 时显示，hover 时隐藏）
        if (!_isHovered) ...[
          SizedBox(height: verticalSpacing),
          _buildMapTagRow(widget.server.mapInfo?.tags ?? []),
        ],
      ],
    );
  }

  /// 地图标签行
  Widget _buildMapTagRow(List<MapTagSimple> tags) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          tags.isEmpty ? MdiIcons.tagOffOutline : MdiIcons.tagOutline,
          size: 16,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        if (tags.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Text(
              '暂无标签',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((tag) => _buildTagChip(tag)).toList(),
            ),
          ),
      ],
    );
  }

  /// 构建单个标签
  Widget _buildTagChip(MapTagSimple tag) {
    final tagColorValue = tag.colorValue;

    // 有颜色时的处理
    if (tagColorValue != null) {
      final darkColor = Color.lerp(tagColorValue, Colors.black, 0.2)!;
      final lightColor = Color.lerp(tagColorValue, Colors.white, 0.6)!;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // 渐变背景，从浅到深，增加层次感
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              tagColorValue.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColorValue.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tagColorValue.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: tagColorValue.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, 0),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
        ),
      );
    }

    // 无颜色时的处理
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
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

  /// Hover 时的操作工具栏
  Widget _buildHoverActionOverlay() {
    if (!_isHovered) return const SizedBox.shrink();

    final data = widget.server.serverData;
    // 离线状态下也允许点击连接和挤服按钮（用户可能想重试连接）
    // 只在加载中时禁用连接和挤服
    final isLoading = widget.server.isLoading;
    // 需要服务器数据的按钮使用这个判断
    final needsServerData = data == null;
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    final isCustomServer = widget.server.serverItem.isCustom;

    // 检查全局操作状态
    final globalState = _statusService.state;
    final isGlobalBusy =
        globalState.type != OperationType.none &&
        globalState.status == OperationStatus.running;
    final isCurrentServerBusy =
        globalState.serverAddress == address && isGlobalBusy;
    final isOtherServerBusy =
        globalState.serverAddress != address && isGlobalBusy;

    // 检查是否正在挤服
    final isQueueing =
        globalState.type == OperationType.queueing &&
        globalState.status == OperationStatus.running;
    final isCurrentServerQueueing =
        isQueueing && globalState.serverAddress == address;
    final isOtherServerQueueing =
        isQueueing && globalState.serverAddress != address;

    // 确定连接按钮的文本和状态
    // 离线状态也允许连接（让用户可以重试）
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
      connectDisabled = true;
    } else {
      connectText = '连接';
      // 只在加载中时禁用，离线状态也允许连接
      connectDisabled = isLoading;
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, value * 50),
            child: Opacity(opacity: 1 - value, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.only(
            left: 14,
            right: 14,
            top: 12,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: Row(
            children: [
              // 主操作按钮组
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildActionBtn(
                    text: connectText,
                    icon: Icons.play_arrow_rounded,
                    bgColor: const Color(0xFF0080FF),
                    onPressed: connectDisabled ? null : _handleConnect,
                  ),
                  _buildActionBtn(
                    text: isCurrentServerQueueing ? '挤服中' : '挤服',
                    icon: MdiIcons.accountGroup,
                    bgColor: const Color(0xFFFF6E6E),
                    // 离线状态也允许挤服（让用户可以重试），只在加载中时禁用
                    onPressed: isLoading || address == null
                        ? null
                        : isCurrentServerQueueing
                        ? () => _openQueueDialog(context, address)
                        : isOtherServerQueueing
                        ? () => _showQueueBusyTip(context)
                        : () => _showQueueWindow(context),
                  ),
                ],
              ),
              // 分隔线
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              // 次要操作按钮组
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildSecondaryBtn(
                      icon: Icons.people_outline_rounded,
                      tooltip: '玩家列表',
                      color: const Color(0xFF10B981),
                      // 需要服务器数据
                      onPressed: needsServerData || isLoading
                          ? null
                          : widget.onTap,
                    ),
                    if (!isCustomServer)
                      _buildSecondaryBtn(
                        icon: Icons.history_rounded,
                        tooltip: '历史记录',
                        color: const Color(0xFFF59E0B),
                        // 历史记录不需要服务器数据
                        onPressed: () => _showHistoryDialog(context),
                      ),
                    if (isCustomServer)
                      _buildSecondaryBtn(
                        icon: MdiIcons.pencilOutline,
                        tooltip: '编辑服务器',
                        color: const Color(0xFF0EA5E9),
                        onPressed: () => _showEditIpDialog(context),
                      )
                    else
                      _buildSecondaryBtn(
                        icon: MdiIcons.imageEditOutline,
                        tooltip: '编辑地图',
                        color: const Color(0xFF8B5CF6),
                        // 需要服务器数据
                        onPressed: needsServerData || isLoading
                            ? null
                            : () => _showContributionDialog(context),
                      ),
                    _buildSecondaryBtn(
                      icon: MdiIcons.refresh,
                      tooltip: '刷新缓存',
                      color: const Color(0xFFF59E0B),
                      // 刷新缓存不需要服务器数据，但需要在非加载中状态
                      onPressed: isLoading ? null : _refreshMapCache,
                    ),
                    _buildSecondaryBtn(
                      icon: _isMonitoring
                          ? MdiIcons.bellRing
                          : MdiIcons.bellOutline,
                      tooltip: '换图监控',
                      color: const Color(0xFF3B82F6),
                      isActive: _isMonitoring,
                      // 换图监控不需要服务器数据，但需要在非加载中状态
                      onPressed: isLoading ? null : _toggleMapMonitor,
                    ),
                    if (isCustomServer && widget.onDelete != null)
                      _buildSecondaryBtn(
                        icon: Icons.delete_outline_rounded,
                        tooltip: '删除',
                        color: const Color(0xFFEF4444),
                        onPressed: () => _showDeleteConfirmDialog(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 主操作按钮
  Widget _buildActionBtn({
    required String text,
    required IconData icon,
    required Color bgColor,
    VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;

    return Material(
      color: disabled ? Colors.white.withValues(alpha: 0.1) : bgColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: disabled
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: disabled
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 次要操作按钮（图标按钮）
  Widget _buildSecondaryBtn({
    required IconData icon,
    required String tooltip,
    Color? color,
    bool isActive = false,
    VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    final btnColor = color ?? Colors.white;

    return Tooltip(
      message: tooltip,
      child: _HoverIconButton(
        icon: icon,
        color: btnColor,
        isActive: isActive,
        disabled: disabled,
        onPressed: onPressed,
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context) {
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress ??
        '未知地址';
    final nickname = widget.server.serverItem.nickname;
    // 如果有备注名，显示 "备注名 (地址)"，否则只显示地址
    final displayName = nickname != null && nickname.isNotEmpty
        ? '$nickname ($address)'
        : address;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除服务器 "$displayName" 吗？'),
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

  /// 显示编辑IP对话框
  void _showEditIpDialog(BuildContext context) {
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress ??
        '';
    final categoryName = widget.categoryName ?? '';
    final currentNickname = widget.server.serverItem.nickname;

    if (address.isEmpty || categoryName.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => EditServerDialog(
        currentAddress: address,
        currentNickname: currentNickname,
        categoryName: categoryName,
        onConfirm: (newAddress, nickname) {
          if (mounted) {
            context.read<ServerBloc>().add(
              ServerEditServer(
                categoryName: categoryName,
                oldServerAddress: address,
                newServerAddress: newAddress,
                nickname: nickname,
              ),
            );
          }
        },
      ),
    );
  }

  /// 切换换图监控
  Future<void> _toggleMapMonitor() async {
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address == null) return;

    // 使用 getDisplayName：优先备注名，其次服务器名，最后地址
    final serverName = widget.server.serverItem.getDisplayName(
      widget.server.serverData?.hostName,
    );
    final currentMap = widget.server.serverData?.map;

    final isNowMonitoring = await _mapMonitorService.toggleMonitor(
      serverAddress: address,
      serverName: serverName,
      categoryName: widget.categoryName,
      currentMap: currentMap,
    );

    if (mounted) {
      ToastUtils.showSuccess(context, isNowMonitoring ? '已开启换图监控' : '已关闭换图监控');
    }
  }

  /// 刷新地图信息
  void _refreshMapCache() {
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    final mapName = widget.server.serverData?.map;

    if (address == null || mapName == null) {
      return;
    }

    // 通过 context 获取 ServerBloc 并发送刷新事件
    context.read<ServerBloc>().add(
      ServerRefreshMapCache(address: address, mapName: mapName),
    );
  }

  /// 是否处于离线/维护状态
  bool get _isOffline =>
      widget.server.hasError && widget.server.serverData == null;

  /// 是否处于服务器启动状态（graphics_settings 地图）
  bool get _isStarting => widget.server.serverData?.map == 'graphics_settings';

  /// 检测是否为僵尸地图
  ///
  /// 僵尸地图前缀：ze_（zombie escape）、zm_（zombie mod）
  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) return false;
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
  }

  /// 构建比分显示组件
  ///
  /// 普通模式：CT(蓝) X : Y T(黄)
  /// 僵尸模式：人类(绿) X : Y 僵尸(红)
  /// 数据过期（unknown）：全部灰色显示
  Widget _buildScoreDisplay(
    int ctScore,
    int tScore,
    String? mapName, {
    String? dataQuality,
  }) {
    final isZombie = _isZombieMap(mapName);
    final isUnknown = dataQuality == 'unknown';

    // 颜色定义（unknown 时全部灰色）
    final Color leftColor;
    final Color rightColor;
    final Color iconColor;

    if (isUnknown) {
      leftColor = const Color(0xFF9CA3AF); // 灰色
      rightColor = const Color(0xFF9CA3AF); // 灰色
      iconColor = const Color(0xFF9CA3AF); // 灰色
    } else if (isZombie) {
      leftColor = const Color(0xFF22C55E); // 人类 - 绿色
      rightColor = const Color(0xFFEF4444); // 僵尸 - 红色
      iconColor = const Color(0xFF6B7280); // 深灰色
    } else {
      leftColor = const Color(0xFF3B82F6); // CT - 蓝色
      rightColor = const Color(0xFFEAB308); // T - 黄色
      iconColor = const Color(0xFF6B7280); // 深灰色
    }

    // 标签
    final leftLabel = isZombie ? '人类' : 'CT';
    final rightLabel = isZombie ? '僵尸' : 'T';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$leftLabel $ctScore',
          style: TextStyle(
            color: leftColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(MdiIcons.swordCross, size: 12, color: iconColor),
        ),
        Text(
          '$tScore $rightLabel',
          style: TextStyle(
            color: rightColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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

    final showRuntime =
        data?.map != null &&
        !widget.server.isLoading &&
        !widget.server.serverItem.isCustom;

    // hover 时紧凑间距，非 hover 时稍宽松间距
    final verticalSpacing = _isHovered ? 6.0 : 6.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 玩家数量
        _buildPlayerCount(players, maxPlayers),
        // 地图运行时间（自定义服务器不显示）
        if (showRuntime) ...[
          SizedBox(height: verticalSpacing),
          _buildRuntimeInfo(),
        ],
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
          Icon(icon, color: color, size: 28),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
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
                fontSize: 18,
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

    final weeklyOccurrences = widget.server.mapRuntime?.weeklyOccurrences;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: _isWarmingUp ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 运行时间
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.clockOutline, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Text(
                displayText,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // 比分显示（非热身且有有效比分数据时，0:0不显示）或周出现次数
          if (!_isWarmingUp &&
              widget.server.teamScores?.ctScore != null &&
              widget.server.teamScores?.tScore != null &&
              (widget.server.teamScores!.ctScore! > 0 ||
                  widget.server.teamScores!.tScore! > 0)) ...[
            const SizedBox(height: 2),
            _buildScoreDisplay(
              widget.server.teamScores!.ctScore!,
              widget.server.teamScores!.tScore!,
              mapName,
              dataQuality: widget.server.teamScores!.dataQuality,
            ),
          ] else if (weeklyOccurrences != null) ...[
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
                children: [
                  const TextSpan(text: '一周内出现'),
                  TextSpan(
                    text: ' $weeklyOccurrences ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const TextSpan(text: '次'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleConnect() async {
    if (_isConnecting) return;

    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address == null) {
      if (mounted) {
        ToastUtils.showError(context, '服务器地址无效');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isConnecting = true);

    // 使用 getDisplayName：优先备注名，其次服务器名，最后地址
    final serverName = widget.server.serverItem.getDisplayName(
      widget.server.serverData?.hostName,
    );
    final mapName = widget.server.serverData?.map;
    final mapInfo = widget.server.mapInfo;
    final gameType = widget.server.serverData?.gameType;

    // 使用已有的 StatusWindowService 实例
    final success = await _statusService.connectToServer(
      serverAddress: address,
      serverName: serverName,
      mapName: mapName,
      mapNameCn: mapInfo?.mapLabel,
      mapBackground: mapInfo?.mapUrl,
      gameType: gameType,
    );

    // connectToServer 返回后，连接流程已完成，此时显示 Toast
    if (mounted) {
      final state = _statusService.state;
      if (success) {
        ToastUtils.showSuccess(context, '进去啦！');
      } else if (state.needCsgoLegacy) {
        // 需要安装 CSGO Legacy，显示教程对话框
        _showCsgoLegacyInstallDialog();
      } else if (state.needManualLaunch) {
        // CSGO 已安装但未运行，显示手动启动对话框
        _showCsgoManualLaunchDialog(address);
      } else if (state.status == OperationStatus.serverFull) {
        ToastUtils.showWarning(context, '服务器已满');
      } else if (state.message != null && state.message!.isNotEmpty) {
        ToastUtils.showError(context, state.message!);
      }
      setState(() => _isConnecting = false);
    }
  }

  void _showCsgoLegacyInstallDialog() {
    showDialog(
      context: context,
      builder: (context) => const CsgoLegacyInstallDialog(),
    );
  }

  void _showCsgoManualLaunchDialog(String serverAddress) {
    showDialog(
      context: context,
      builder: (context) =>
          CsgoManualLaunchDialog(serverAddress: serverAddress),
    );
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
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address == null) return;

    final statusService = StatusWindowService();
    final currentState = statusService.state;

    // 检查是否有正在进行的挤服
    if (currentState.type == OperationType.queueing &&
        currentState.status == OperationStatus.running) {
      // 如果是同一个服务器，直接打开对话框查看详情
      if (currentState.serverAddress == address) {
        _openQueueDialog(context, address);
        return;
      }

      // 不同服务器，提示无法切换
      _showQueueBusyTip(context);
      return;
    }

    // 打开挤服对话框
    if (context.mounted) {
      _openQueueDialog(context, address);
    }
  }

  void _showQueueBusyTip(BuildContext context) {
    ToastUtils.showWarning(context, '正在挤服中，无法切换服务器');
  }

  void _openQueueDialog(BuildContext context, String address) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: QueueWindow(
          serverAddress: address,
          isCustomServer: widget.server.serverItem.isCustom,
          initialServerInfo: widget.server.serverData,
          initialMapInfo: widget.server.mapInfo,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// 显示地图贡献对话框
  /// Requirements: 4.4
  void _showContributionDialog(BuildContext context) {
    if (!mounted) return;

    final mapName = widget.server.serverData?.map;
    if (mapName == null) return;

    final mapLabel = widget.server.mapInfo?.mapLabel;

    MapContributionDialog.show(context, mapName: mapName, mapLabel: mapLabel);
  }
}

/// 滚动文本组件 - 文本过长时自动滚动
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  ScrollController? _scrollController;
  bool _needsScroll = false;
  bool _isScrolling = false;
  double _measuredOverflowWidth = 0;

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
      // 安全地重置滚动位置
      if (_scrollController != null && _scrollController!.hasClients) {
        try {
          _scrollController!.jumpTo(0);
        } catch (_) {
          // 忽略跳转失败
        }
      }
      _isScrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  double _measureOverflowWidth(BuildContext context) {
    final renderObject = context.findRenderObject();
    final viewportWidth = renderObject is RenderBox ? renderObject.size.width : 0.0;
    if (viewportWidth <= 0) return 0;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return (textPainter.width - viewportWidth).clamp(0.0, double.infinity);
  }

  void _checkOverflow() {
    if (!mounted || _scrollController == null) return;
    if (!_scrollController!.hasClients) return;

    final measuredOverflowWidth = _measureOverflowWidth(context);
    final maxScroll = _scrollController!.position.maxScrollExtent;
    final targetOverflowWidth = measuredOverflowWidth > maxScroll
        ? measuredOverflowWidth
        : maxScroll;
    final needsScroll = targetOverflowWidth > 0;

    if (needsScroll != _needsScroll ||
        (targetOverflowWidth - _measuredOverflowWidth).abs() > 0.5) {
      setState(() {
        _needsScroll = needsScroll;
        _measuredOverflowWidth = targetOverflowWidth;
      });
    }
    if (_needsScroll && !_isScrolling) {
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || !_needsScroll || _scrollController == null) return;
    _isScrolling = true;

    while (mounted && _needsScroll && _isScrolling) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll || _scrollController == null) break;

      final maxScroll = _scrollController!.position.maxScrollExtent;
      final targetOffset = _measuredOverflowWidth > maxScroll
          ? _measuredOverflowWidth
          : maxScroll;
      if (targetOffset <= 0) break;

      // 滚动到末尾
      try {
        await _scrollController!.animateTo(
          targetOffset,
          duration: Duration(
            milliseconds: (targetOffset * 30).toInt().clamp(1000, 5000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        // ScrollController 可能已被 dispose
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;

      // 滚动回开头
      try {
        await _scrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // ScrollController 可能已被 dispose
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    // 离屏渲染（如 screenshot captureFromLongWidget）时没有 View ancestor，
    // SingleChildScrollView 内部会调用 View.of(context) 导致断言失败，
    // 此时降级为普通 Text
    if (View.maybeOf(context) == null) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(widget.text, style: widget.style, maxLines: 1),
          ),
        );
      },
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

/// 带 Hover 效果的图标按钮
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final bool disabled;
  final VoidCallback? onPressed;

  const _HoverIconButton({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.disabled,
    this.onPressed,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHovered = _isHovered && !widget.disabled;

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.color.withValues(alpha: 0.35)
                : isHovered
                ? widget.color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: widget.disabled ? 0.05 : 0.15),
            borderRadius: BorderRadius.circular(4),
            border: widget.isActive
                ? Border.all(color: widget.color, width: 1.5)
                : isHovered
                ? Border.all(
                    color: widget.color.withValues(alpha: 0.6),
                    width: 1,
                  )
                : null,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.disabled
                ? Colors.white.withValues(alpha: 0.3)
                : widget.isActive || isHovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// 挤服边框绘制器 - 绿色流光 + 脉冲效果
class _MarchingAntsPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  _MarchingAntsPainter({required this.progress, required this.borderRadius});

  // 挤服主题色：绿色
  static const _primaryColor = Color(0xFF22C55E);
  static const _glowColor = Color(0xFF4ADE80);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics().first;
    final totalLength = pathMetrics.length;

    // 脉冲效果（呼吸感）
    final pulse = (0.5 + 0.5 * (progress * 2 * 3.14159).abs() % 1).clamp(
      0.3,
      1.0,
    );

    // 1. 绘制底层发光边框（整圈微弱发光）
    final baseGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = _primaryColor.withValues(alpha: 0.2 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, baseGlowPaint);

    // 2. 绘制底层实线边框
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _primaryColor.withValues(alpha: 0.5);
    canvas.drawPath(path, basePaint);

    // 3. 绘制两道对向流光（更有动感）
    _drawFlowingLight(canvas, pathMetrics, totalLength, progress);
    _drawFlowingLight(canvas, pathMetrics, totalLength, (progress + 0.5) % 1.0);
  }

  void _drawFlowingLight(
    Canvas canvas,
    ui.PathMetric pathMetrics,
    double totalLength,
    double prog,
  ) {
    const glowLength = 100.0;
    const tailLength = 150.0;

    final headPosition = prog * totalLength;

    // 绘制拖尾
    for (var i = 0.0; i < tailLength; i += 3) {
      var pos = headPosition - i;
      if (pos < 0) pos += totalLength;

      final alpha = (1 - i / tailLength).clamp(0.0, 1.0) * 0.5;
      final width = 3.0 * (1 - i / tailLength).clamp(0.3, 1.0);

      final segmentEnd = (pos + 4).clamp(0.0, totalLength);
      if (segmentEnd > pos) {
        final tailPath = pathMetrics.extractPath(pos, segmentEnd);
        final tailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = _glowColor.withValues(alpha: alpha);
        canvas.drawPath(tailPath, tailPaint);
      }
    }

    // 绘制流光头部
    final glowStart = headPosition;
    var glowEnd = headPosition + glowLength;

    // 处理循环
    if (glowEnd > totalLength) {
      // 绘制到末尾
      final path1 = pathMetrics.extractPath(glowStart, totalLength);
      _drawGlowSegment(canvas, path1);
      // 从头开始
      final path2 = pathMetrics.extractPath(0, glowEnd - totalLength);
      _drawGlowSegment(canvas, path2);
    } else {
      final glowPath = pathMetrics.extractPath(glowStart, glowEnd);
      _drawGlowSegment(canvas, glowPath);
    }
  }

  void _drawGlowSegment(Canvas canvas, Path glowPath) {
    // 外层大发光
    final outerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..color = _primaryColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(glowPath, outerGlow);

    // 中层发光
    final midGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = _glowColor.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(glowPath, midGlow);

    // 核心亮线
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawPath(glowPath, core);
  }

  @override
  bool shouldRepaint(_MarchingAntsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 浮动黄点
class _FloatingYellowDot extends StatefulWidget {
  @override
  State<_FloatingYellowDot> createState() => _FloatingYellowDotState();
}

class _FloatingYellowDotState extends State<_FloatingYellowDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD700),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
