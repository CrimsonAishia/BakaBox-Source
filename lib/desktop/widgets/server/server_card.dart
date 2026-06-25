import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../core/models/server_models.dart';
import '../../../core/models/map_tag_models.dart';
import '../../../core/constants/operation_colors.dart';
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
import '../warmup/warmup_window.dart';
import '../../../core/widgets/map_contribution_dialog.dart';
import '../edit_server_dialog.dart';
import '../../../core/constants/app_colors.dart';
import 'server_card_components/server_card_marquee_text.dart';
import 'server_card_components/server_card_overflow_tag_row.dart';
import 'server_card_components/server_card_icon_buttons.dart';
import 'server_card_components/hover_tag_popover.dart';
import 'server_card_components/server_card_floating_yellow_dot.dart';
import 'server_card_components/server_card_painters.dart';
import '../../../core/utils/map_tag_utils.dart';

/// 服务器卡片
class ServerCard extends StatefulWidget {
  final ExtendedServerItem server;
  final String? categoryName; // 分类名称
  final VoidCallback? onTap;
  final VoidCallback? onDelete; // 删除回调（仅自定义服务器）

  const ServerCard({
    super.key,
    required this.server,
    this.categoryName,
    this.onTap,
    this.onDelete,
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

  bool _hasTagOverflow = false; // 标签是否被截断（出现 +N 徽章）

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

  @override
  Widget build(BuildContext context) {
    final sortedTags = MapTagUtils.prepareTags(widget.server.mapInfo?.tags.toList() ?? []);

    return HoverTagPopover(
      tags: sortedTags,
      isHovered: _isHovered,
      hasOverflow: _hasTagOverflow,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!mounted) return;
          setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (!mounted) return;
          setState(() => _isHovered = false);
        },
          child: _rgbController != null
              ? AnimatedBuilder(
                  animation: _rgbController!,
                  builder: (context, child) =>
                      _buildCardContent(_getRgbColor(_rgbController!.value)),
                )
              : _buildCardContent(AppColors.primary),
        ),
    );
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

  /// 构建卡片内容
  Widget _buildCardContent(Color rgbColor) {
    final isQueueing = _isCurrentServerQueueing;

    // 边框颜色优先级：挤服 > 热身 > hover > 无
    Color borderColor;
    if (isQueueing && _isHovered) {
      borderColor = AppColors.green500.withValues(alpha: 0.8);
    } else if (_isHovered && _isWarmingUp) {
      borderColor = rgbColor.withValues(alpha: 0.8);
    } else if (_isHovered) {
      borderColor = AppColors.primary.withValues(alpha: 0.6);
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
              color: AppColors.green500.withValues(alpha: 0.4),
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
          height: 132, // 136 - 2*2 边框
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
            painter: ServerCardMarchingAntsPainter(
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
    return Positioned(top: 8, right: 8, child: ServerCardFloatingYellowDot());
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
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
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress ??
        '未知地址';
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
              child: ServerCardMarqueeText(
                text: displayMapName,
                copyText: mapName,
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
            ServerCardCopyIconButton(onTap: () => _copyConnectCommand(address)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('|', style: TextStyle(color: Colors.white30)),
            ),
            _buildPingBadge(ping),
          ],
        ),
        // 地图标签（非 hover 时显示，hover 时隐藏，让位给底部操作层）
        if (!_isHovered) ...[
          SizedBox(height: verticalSpacing),
          _buildMapTagRow(MapTagUtils.prepareTags(widget.server.mapInfo?.tags.toList() ?? [])),
        ],
      ],
    );
  }

  /// 地图标签行
  Widget _buildMapTagRow(List<MapTagSimple> tags) {
    if (tags.isEmpty) {
      return Row(
        children: [
          Icon(
            MdiIcons.tagOffOutline,
            size: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
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
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          MdiIcons.tagOutline,
          size: 16,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ServerCardOverflowTagRow(
            tags: tags,
            showPrefix: true,
            onOverflowChanged: (overflow) {
              if (!mounted) return;
              if (_hasTagOverflow != overflow) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _hasTagOverflow = overflow);
                });
              }
            },
          ),
        ),
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

    // 暖服是后台操作，允许进入所有服务器，因此暖服时不阻塞"连接"按钮
    final isConnectBlockingBusy =
        isGlobalBusy && globalState.type != OperationType.warming;
    final isCurrentServerBusy =
        globalState.serverAddress == address && isConnectBlockingBusy;
    final isOtherServerBusy =
        globalState.serverAddress != address && isConnectBlockingBusy;

    // 检查是否正在挤服
    final isQueueing =
        globalState.type == OperationType.queueing &&
        globalState.status == OperationStatus.running;
    final isCurrentServerQueueing =
        isQueueing && globalState.serverAddress == address;
    final isOtherServerQueueing =
        isQueueing && globalState.serverAddress != address;

    // 检查是否正在暖服
    final isWarming =
        globalState.type == OperationType.warming &&
        globalState.status == OperationStatus.running;
    final isCurrentServerWarming =
        isWarming && globalState.serverAddress == address;
    final isOtherServerWarming =
        isWarming && globalState.serverAddress != address;

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
            top: 8,
            bottom: 5,
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
                    bgColor: AppColors.primary,
                    onPressed: connectDisabled ? null : _handleConnect,
                  ),
                  _buildActionBtn(
                    text: isCurrentServerQueueing ? '挤服中' : '挤服',
                    icon: MdiIcons.accountGroup,
                    bgColor: const Color(0xFFFF6E6E),
                    onPressed: _resolveQueueAction(
                      context,
                      address: address,
                      isLoading: isLoading,
                      isWarming: isWarming,
                      isCurrentServerQueueing: isCurrentServerQueueing,
                      isOtherServerQueueing: isOtherServerQueueing,
                    ),
                  ),
                  // 自定义服务器隐藏暖服按钮
                  if (!isCustomServer)
                    _buildActionBtn(
                      text: isCurrentServerWarming ? '暖服中' : '暖服',
                      icon: MdiIcons.fire,
                      bgColor: AppColors.amber500,
                      onPressed: _resolveWarmupAction(
                        context,
                        address: address,
                        isLoading: isLoading,
                        isCurrentServerQueueing: isCurrentServerQueueing,
                        isCurrentServerWarming: isCurrentServerWarming,
                        isOtherServerWarming: isOtherServerWarming,
                        isOtherServerQueueing: isOtherServerQueueing,
                      ),
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
                      color: AppColors.emerald500,
                      // 需要服务器数据
                      onPressed: needsServerData || isLoading
                          ? null
                          : widget.onTap,
                    ),
                    if (!isCustomServer)
                      _buildSecondaryBtn(
                        icon: Icons.history_rounded,
                        tooltip: '历史记录',
                        color: AppColors.amber500,
                        // 历史记录不需要服务器数据
                        onPressed: () => _showHistoryDialog(context),
                      ),
                    if (isCustomServer)
                      _buildSecondaryBtn(
                        icon: MdiIcons.pencilOutline,
                        tooltip:
                            widget.server.serverItem.dataSourceMode == 'api'
                            ? '编辑备注'
                            : '编辑服务器',
                        color: const Color(0xFF0EA5E9),
                        onPressed: () => _showEditIpDialog(context),
                      )
                    else
                      _buildSecondaryBtn(
                        icon: MdiIcons.imageEditOutline,
                        tooltip: '编辑地图',
                        color: AppColors.violet500,
                        // 需要服务器数据
                        onPressed: needsServerData || isLoading
                            ? null
                            : () => _showContributionDialog(context),
                      ),
                    _buildSecondaryBtn(
                      icon: MdiIcons.refresh,
                      tooltip: '刷新缓存',
                      color: AppColors.amber500,
                      // 刷新缓存不需要服务器数据，但需要在非加载中状态
                      onPressed: isLoading ? null : _refreshMapCache,
                    ),
                    _buildSecondaryBtn(
                      icon: _isMonitoring
                          ? MdiIcons.bellRing
                          : MdiIcons.bellOutline,
                      tooltip: '换图监控',
                      color: AppColors.blue500,
                      isActive: _isMonitoring,
                      // 换图监控不需要服务器数据，但需要在非加载中状态
                      onPressed: isLoading ? null : _toggleMapMonitor,
                    ),
                    if (isCustomServer && widget.onDelete != null)
                      _buildSecondaryBtn(
                        icon: Icons.delete_outline_rounded,
                        tooltip: '删除',
                        color: AppColors.red500,
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
  /// 计算"挤服"按钮的点击行为；返回 null 表示按钮置灰不可点。
  ///
  /// 置灰场景：加载中、无地址、有其他服务器在暖服。
  /// 注意：人已在本服内不再禁用，改由挤服面板内弹窗确认（不强制拦截）。
  VoidCallback? _resolveQueueAction(
    BuildContext context, {
    required String? address,
    required bool isLoading,
    required bool isWarming,
    required bool isCurrentServerQueueing,
    required bool isOtherServerQueueing,
  }) {
    // 离线状态也允许挤服（让用户重试），只在加载中 / 无地址 / 暖服中禁用
    if (isLoading || address == null || isWarming) return null;
    // 正在挤本服：点击打开挤服面板
    if (isCurrentServerQueueing) {
      return () => _openQueueDialog(context, address);
    }
    // 其他服务器正在挤服：提示忙碌
    if (isOtherServerQueueing) return () => _showQueueBusyTip(context);
    // 人已在本服内：不禁用按钮，打开挤服面板后由其内部弹窗确认（不强制拦截）
    return () => _showQueueWindow(context);
  }

  /// 计算"暖服"按钮的点击行为；返回 null 表示按钮置灰不可点。
  ///
  /// 置灰场景：加载中、无地址、本服正在挤服。
  /// 注意：人已在本服内不再禁用，改由暖服面板内弹窗确认（不强制拦截）。
  VoidCallback? _resolveWarmupAction(
    BuildContext context, {
    required String? address,
    required bool isLoading,
    required bool isCurrentServerQueueing,
    required bool isCurrentServerWarming,
    required bool isOtherServerWarming,
    required bool isOtherServerQueueing,
  }) {
    // 离线状态也允许暖服，只在加载中 / 无地址 / 本服挤服中禁用
    if (isLoading || address == null || isCurrentServerQueueing) return null;
    // 正在暖本服：点击打开暖服面板
    if (isCurrentServerWarming) {
      return () => _openWarmupDialog(context, address);
    }
    // 其他服务器正在暖服 / 挤服：提示忙碌
    if (isOtherServerWarming) return () => _showWarmupBusyTip(context);
    if (isOtherServerQueueing) return () => _showQueueBusyTip(context);
    return () => _showWarmupWindow(context);
  }

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
      child: ServerCardHoverIconButton(
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
              backgroundColor: AppColors.red500,
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
        isReadOnlyAddress: widget.server.serverItem.dataSourceMode == 'api',
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
      leftColor = AppColors.gray400; // 灰色
      rightColor = AppColors.gray400; // 灰色
      iconColor = AppColors.gray400; // 灰色
    } else if (isZombie) {
      leftColor = AppColors.green500; // 人类 - 绿色
      rightColor = AppColors.red500; // 僵尸 - 红色
      iconColor = AppColors.gray500; // 深灰色
    } else {
      leftColor = AppColors.blue500; // CT - 蓝色
      rightColor = const Color(0xFFEAB308); // T - 黄色
      iconColor = AppColors.gray500; // 深灰色
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

    // API 数据源的自定义服务器由第三方接口提供地图运行时间（map_changed_at），
    // 需要显示运行时间；其余自定义服务器（A2S 模式）不显示。
    final isApiSourced = widget.server.serverItem.dataSourceMode == 'api';
    final showRuntime =
        data?.map != null &&
        !widget.server.isLoading &&
        (!widget.server.serverItem.isCustom ||
            (isApiSourced && widget.server.mapRuntime != null));

    Color bgColor;
    if (players >= maxPlayers && maxPlayers > 0) {
      bgColor = const Color(0xFFFEEAEA);
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      bgColor = const Color(0xFFFFF9E6);
    } else {
      bgColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _buildPlayerCount(players, maxPlayers)),
            if (showRuntime) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 1,
                child: CustomPaint(painter: ServerCardDashedLinePainter()),
              ),
              const SizedBox(height: 4),
              Center(child: _buildRuntimeInfo()),
            ],
          ],
        ),
      ),
    );
  }

  /// 离线/维护状态显示
  Widget _buildOfflineStatus() {
    return _buildStatusCard(
      icon: Icons.cloud_off_rounded,
      text: '离线',
      color: AppColors.red500,
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

  Widget _buildPlayerCount(int players, int maxPlayers) {
    Color primaryColor;

    if (players >= maxPlayers && maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336);
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      primaryColor = AppColors.orange;
    } else {
      primaryColor = AppColors.primary;
    }

    final int queueCount = widget.server.queueCount;
    final int warmupCount = widget.server.warmupCount;
    final int extraCount = queueCount + warmupCount;

    return Row(
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
        if (extraCount > 0)
          _buildExtraCount(queueCount, warmupCount, extraCount),
        // 斜杠
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '/',
            style: TextStyle(
              color: AppColors.gray400,
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
            color: AppColors.gray500,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildExtraCount(int queueCount, int warmupCount, int extraCount) {
    final Widget badge;
    if (queueCount > 0 && warmupCount > 0) {
      badge = ShaderMask(
        shaderCallback: (bounds) =>
            OperationColors.queueWarmupGradient.createShader(bounds),
        child: Text(
          '+$extraCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      );
    } else if (queueCount > 0) {
      badge = Text(
        '+$extraCount',
        style: const TextStyle(
          color: OperationColors.queue, // 红色 - 挤服
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      );
    } else {
      badge = Text(
        '+$extraCount',
        style: const TextStyle(
          color: OperationColors.warmup, // 黄色 - 暖服
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      );
    }

    // 拼装 tooltip 文案：仅挤服 / 仅暖服 / 两者都有
    final lines = <String>[
      if (queueCount > 0) '🔴 挤服中 $queueCount 人',
      if (warmupCount > 0) '🟡 暖服中 $warmupCount 人',
    ];
    return Tooltip(
      message: lines.join('\n'),
      preferBelow: false, // 强制显示在上方
      waitDuration: const Duration(milliseconds: 300),
      verticalOffset: 16,
      // 用透明 padding 扩大 hover 命中范围
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: badge,
      ),
    );
  }

  Widget _buildRuntimeInfo() {
    final hasError = widget.server.mapRuntimeError;
    if (hasError) return const SizedBox.shrink();

    final isLoading = widget.server.mapRuntimeFetching;
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
        isLoading: isLoading,
        hasError: hasError,
      );
    }

    Color iconColor;
    Color textColor;

    if (_isWarmingUp) {
      iconColor = AppColors.orange;
      textColor = const Color(0xFFE65100);
    } else if (isLoading) {
      iconColor = AppColors.gray400;
      textColor = AppColors.gray500;
    } else {
      iconColor = AppColors.emerald500;
      textColor = AppColors.gray800;
    }

    final weeklyOccurrences = widget.server.mapRuntime?.weeklyOccurrences;

    return Column(
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
        // 周出现次数
        if (weeklyOccurrences != null) ...[
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
              children: [
                const TextSpan(text: '一周内出现'),
                TextSpan(
                  text: ' $weeklyOccurrences ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue500,
                  ),
                ),
                const TextSpan(text: '次'),
              ],
            ),
          ),
        ],
        // 比分显示（非热身且有有效比分数据时，0:0不显示）
        if (!_isWarmingUp &&
            widget.server.teamScores?.ctScore != null &&
            widget.server.teamScores?.tScore != null &&
            widget.server.teamScores!.matchesMap(mapName) &&
            (widget.server.teamScores!.ctScore! > 0 ||
                widget.server.teamScores!.tScore! > 0)) ...[
          const SizedBox(height: 2),
          _buildScoreDisplay(
            widget.server.teamScores!.ctScore!,
            widget.server.teamScores!.tScore!,
            mapName,
            dataQuality: widget.server.teamScores!.dataQuality,
          ),
        ],
      ],
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
    final appId = widget.server.serverData?.appId;

    // 使用已有的 StatusWindowService 实例
    final success = await _statusService.connectToServer(
      serverAddress: address,
      serverName: serverName,
      mapName: mapName,
      mapNameCn: mapInfo?.mapLabel,
      mapBackground: mapInfo?.mapUrl,
      gameType: gameType,
      appId: appId,
    );

    // connectToServer 返回后，连接流程已完成，此时显示 Toast
    if (mounted) {
      final state = _statusService.state;
      if (success) {
        ToastUtils.showSuccess(context, state.message ?? '成功加入服务器');
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
          serverName: widget.server.serverItem.getDisplayName(
            widget.server.serverData?.hostName,
          ),
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showWarmupWindow(BuildContext context) async {
    final address =
        widget.server.serverItem.address ??
        widget.server.serverItem.serverAddress;
    if (address == null) return;

    final statusService = StatusWindowService();
    final currentState = statusService.state;

    // 检查是否有正在进行的暖服
    if (currentState.type == OperationType.warming &&
        currentState.status == OperationStatus.running) {
      // 如果是同一个服务器，直接打开对话框查看详情
      if (currentState.serverAddress == address) {
        _openWarmupDialog(context, address);
        return;
      }

      // 不同服务器，提示无法切换
      _showWarmupBusyTip(context);
      return;
    }

    // 打开暖服对话框
    if (context.mounted) {
      _openWarmupDialog(context, address);
    }
  }

  void _showWarmupBusyTip(BuildContext context) {
    ToastUtils.showWarning(context, '正在暖服中，无法切换服务器');
  }

  void _openWarmupDialog(BuildContext context, String address) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: WarmupWindow(
          serverAddress: address,
          isCustomServer: widget.server.serverItem.isCustom,
          initialServerInfo: widget.server.serverData,
          initialMapInfo: widget.server.mapInfo,
          serverName: widget.server.serverItem.getDisplayName(
            widget.server.serverData?.hostName,
          ),
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// 显示地图贡献对话框
  void _showContributionDialog(BuildContext context) {
    if (!mounted) return;

    final mapName = widget.server.serverData?.map;
    if (mapName == null) return;

    final mapLabel = widget.server.mapInfo?.mapLabel;
    final isDifficultySeparated =
        widget.server.serverItem.isDifficultySeparated;
    final serverAddress = widget.server.serverItem.address;

    MapContributionDialog.show(
      context,
      mapName: mapName,
      mapLabel: mapLabel,
      isDifficultySeparated: isDifficultySeparated,
      serverAddress: serverAddress,
    );
  }
}

/// 滚动文本组件 - 文本过长时自动滚动
