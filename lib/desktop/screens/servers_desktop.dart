import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../core/core.dart';
import '../../core/services/status_window_service.dart';
import '../widgets/server/server_card.dart';
import '../widgets/server/server_card_skeleton.dart';
import '../widgets/category_card.dart';
import '../widgets/refresh_progress.dart';
import '../widgets/server/server_detail_dialog.dart';
import '../widgets/server/immersive_mode_overlay.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/edit_category_dialog.dart';
import '../widgets/add_server_dialog.dart';
import '../widgets/map_subscription/map_subscription_dialog.dart';

// ==================== 常量定义 ====================

/// 自动刷新间隔（秒）
const int _kRefreshInterval = 15;

/// 分类人数刷新间隔（秒）- 未选中分类的刷新频率
const int _kCategoryCountsRefreshInterval = 60;

class ServersDesktop extends StatefulWidget {
  const ServersDesktop({super.key});

  @override
  State<ServersDesktop> createState() => _ServersDesktopState();
}

class _ServersDesktopState extends State<ServersDesktop> {
  ServerBloc? _serverBloc;
  bool _isInitialized = false;

  // 状态窗口服务（用于共享游戏状态）
  final StatusWindowService _statusService = StatusWindowService();

  // 游戏状态监听订阅
  StreamSubscription? _gameStatusSubscription;

  // 游戏运行状态（从 StatusWindowService 共享）
  bool _isGameRunning = false;
  bool _isLaunchingGame = false;

  // ScrollController for lists
  final ScrollController _serversScrollController = ScrollController();

  // 滚动指示器状态
  bool _canScrollUpServers = false;
  bool _canScrollDownServers = false;

  // Ping 相关
  int _lastPingRequestId = 0;
  bool _isPingFetching = false; // 防止重复触发

  // 分类人数刷新定时器
  Timer? _categoryCountsRefreshTimer;
  int _categoryCountsCountdown = _kCategoryCountsRefreshInterval;

  // 沉浸模式标志（用于暂停正常模式的机制）
  bool _isInImmersiveMode = false;

  // 分类列表刷新动画 key（应用 pending categories 时递增，驱动 AnimatedSwitcher）
  int _categoriesListAnimKey = 0;

  @override
  void initState() {
    super.initState();

    // 监听服务器列表滚动
    _serversScrollController.addListener(_updateServersScrollIndicators);

    // 启动分类人数刷新定时器
    _startCategoryCountsRefreshTimer();

    // 监听游戏状态变化
    _initGameStatusListener();
  }

  /// 初始化游戏状态监听
  void _initGameStatusListener() {
    // 立即检查一次游戏状态
    _checkGameStatus();

    // 监听 StatusWindowService 状态变化
    _gameStatusSubscription = _statusService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isGameRunning = state.isGameRunning;
          // 判断是否正在启动游戏：type == launching && status == running
          _isLaunchingGame =
              state.type == OperationType.launching &&
              state.status == OperationStatus.running;
        });
      }
    });
  }

  /// 检查游戏状态
  Future<void> _checkGameStatus() async {
    final state = _statusService.state;
    if (mounted && state.isGameRunning != _isGameRunning) {
      setState(() {
        _isGameRunning = state.isGameRunning;
      });
    }
  }

  void _updateServersScrollIndicators() {
    if (!_serversScrollController.hasClients) return;
    final position = _serversScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUpServers || canDown != _canScrollDownServers) {
      setState(() {
        _canScrollUpServers = canUp;
        _canScrollDownServers = canDown;
      });
    }
  }


  /// 延迟获取所有服务器的 ping（防抖 + 并行获取）
  void _scheduleDelayedPingFetch() {
    // 沉浸模式下不触发 ping 获取
    if (_isInImmersiveMode) return;
    // 防止重复触发
    if (_isPingFetching) return;

    final requestId = ++_lastPingRequestId;

    // 延迟 300ms 后获取 ping（等待服务器数据加载）
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || requestId != _lastPingRequestId) return;
      _fetchPingsIfNeeded(requestId);
    });
  }

  /// 检查并获取缺失的 ping
  void _fetchPingsIfNeeded(int requestId) {
    final bloc = _serverBloc;
    if (bloc == null || _isPingFetching) return;

    final currentServers = bloc.state.servers;
    // 只获取有数据但没有 ping 的服务器
    final serversNeedingPing = currentServers
        .where((s) => s.serverData != null && s.pingInfo == null)
        .toList();

    if (serversNeedingPing.isNotEmpty) {
      _fetchAllServerPings(serversNeedingPing, requestId);
    } else if (currentServers.any((s) => s.serverData == null && s.isLoading)) {
      // 如果有服务器还在加载中，再等待 800ms 后重试
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || requestId != _lastPingRequestId) return;
        _fetchPingsIfNeeded(requestId);
      });
    }
  }

  /// 并行获取所有服务器的 ping
  Future<void> _fetchAllServerPings(
    List<ExtendedServerItem> servers,
    int requestId,
  ) async {
    final bloc = _serverBloc;
    if (bloc == null || servers.isEmpty || _isPingFetching) return;

    _isPingFetching = true;

    try {
      // 并行获取所有服务器的 ping，限制并发数为 5
      const maxConcurrent = 5;
      final chunks = <List<ExtendedServerItem>>[];

      for (var i = 0; i < servers.length; i += maxConcurrent) {
        chunks.add(
          servers.sublist(
            i,
            i + maxConcurrent > servers.length
                ? servers.length
                : i + maxConcurrent,
          ),
        );
      }

      for (final chunk in chunks) {
        if (!mounted || requestId != _lastPingRequestId) break;

        // 并行获取这一批服务器的 ping
        await Future.wait(
          chunk.map((server) => _fetchServerPing(server, bloc)),
          eagerError: false, // 不因单个失败而中断
        );
      }
    } finally {
      _isPingFetching = false;
    }
  }

  /// 获取单个服务器的 ping
  Future<void> _fetchServerPing(
    ExtendedServerItem server,
    ServerBloc bloc,
  ) async {
    final address =
        server.serverItem.address ?? server.serverItem.serverAddress;
    if (address == null || address.isEmpty) return;

    final ip = address.split(':')[0];
    if (ip.isEmpty) return;

    try {
      // 发送 2 次 ping（减少次数加快速度）
      // forceCodepage: true 解决 Windows 中文系统编码问题
      // encoding: Utf8Codec(allowMalformed: true) 忽略非 UTF-8 字符
      final ping = Ping(
        ip,
        count: 2,
        timeout: 2, // 2秒超时
        forceCodepage: true,
        encoding: const Utf8Codec(allowMalformed: true),
      );
      final results = <Duration>[];

      await for (final event in ping.stream) {
        if (!mounted) break;
        if (event.response != null && event.response!.time != null) {
          results.add(event.response!.time!);
        }
      }

      if (results.isNotEmpty && mounted) {
        // 计算平均延迟
        final avgMs =
            results.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/
            results.length;

        // 计算 ping 状态
        String pingStatus;
        if (avgMs < 50) {
          pingStatus = 'excellent';
        } else if (avgMs < 100) {
          pingStatus = 'good';
        } else if (avgMs < 150) {
          pingStatus = 'fair';
        } else if (avgMs < 300) {
          pingStatus = 'poor';
        } else {
          pingStatus = 'bad';
        }

        final pingInfo = ServerPingInfo(
          ip: ip,
          ping: avgMs,
          pingStatus: pingStatus,
        );

        bloc.add(
          ServerUpdateSingleServer(address: address, pingInfo: pingInfo),
        );
      }
    } catch (e) {
      // 忽略 ping 获取失败
      LogService.d('Ping 获取失败 ($ip): $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _serverBloc = context.read<ServerBloc>();

    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bloc = _serverBloc;
        if (bloc != null) {
          if (bloc.state.serverCategories.isEmpty && !bloc.state.isLoading) {
            bloc.add(ServerFetchList());
          } else {
            // 分类已加载，检查是否需要自动选择第一个分类
            _autoSelectFirstCategory(bloc.state);

            // 检查是否需要立即刷新：如果距离上次刷新超过5秒，立即刷新
            final lastRefresh = bloc.state.lastRefreshTime;
            if (lastRefresh != null &&
                bloc.state.selectedCategory != null &&
                DateTime.now().difference(lastRefresh).inSeconds > 5) {
              bloc.add(ServerRefreshServers());
            }
          }
          bloc.add(ServerStartPeriodicRefresh());

          // 兜底：延迟检查是否有服务器缺少 ping（确保在所有初始化完成后）
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _checkAndFetchMissingPings();
          });
        }
      });
    }
  }

  /// 兜底检查：如果有服务器有数据但缺少 ping，触发获取
  void _checkAndFetchMissingPings() {
    // 沉浸模式下不触发 ping 获取
    if (_isInImmersiveMode) return;
    final bloc = _serverBloc;
    if (bloc == null) return;

    final serversNeedingPing = bloc.state.servers
        .where((s) => s.serverData != null && s.pingInfo == null)
        .toList();

    if (serversNeedingPing.isNotEmpty) {
      _scheduleDelayedPingFetch();
    }
  }

  /// 桌面端自动选择第一个分类（如果没有选中分类）
  void _autoSelectFirstCategory(ServerState state) {
    // 防止重复触发：检查是否已选中分类或正在加载
    if (!mounted || state.selectedCategory != null || state.isLoading) return;
    if (state.serverCategories.isNotEmpty) {
      // 恢复上次选择的分类
      final lastCategoryName = StorageUtils.getString('last_selected_category');
      if (lastCategoryName != null) {
        try {
          final lastCategory = state.serverCategories.firstWhere(
            (c) => c.modelName == lastCategoryName,
          );
          if (lastCategory.isCustom) {
            context.read<ServerBloc>().add(const ServerSwitchTab(1));
          }
          context.read<ServerBloc>().add(ServerSelectCategory(lastCategory));
          return;
        } catch (_) {
          // 找不到保存的分类时忽略，继续走默认逻辑
        }
      }

      // 优先选择默认分类（API 分类）的第一个
      final defaultCategories = state.serverCategories
          .where((c) => !c.isCustom)
          .toList();
      if (defaultCategories.isNotEmpty) {
        context.read<ServerBloc>().add(
          ServerSelectCategory(defaultCategories.first),
        );
      } else {
        // 如果没有默认分类，选择自定义分类的第一个
        final customCategories = state.serverCategories
            .where((c) => c.isCustom)
            .toList();
        if (customCategories.isNotEmpty) {
          // 切换到自定义 tab
          context.read<ServerBloc>().add(const ServerSwitchTab(1));
          context.read<ServerBloc>().add(
            ServerSelectCategory(customCategories.first),
          );
        }
      }
    }
  }

  /// 处理分类点击，切换分类时清理图片内存缓存
  void _onCategoryTap(ServerCategory category) {
    final currentCategory = context.read<ServerBloc>().state.selectedCategory;
    // 切换到不同分类时，清理图片内存缓存
    if (currentCategory?.modelName != category.modelName) {
      PaintingBinding.instance.imageCache.clear();
      if (category.modelName != null) {
        StorageUtils.setString('last_selected_category', category.modelName!);
      }
    }
    context.read<ServerBloc>().add(ServerSelectCategory(category));
  }

  /// 显示编辑分类对话框
  void _showEditCategoryDialog(ServerCategory category) async {
    final categoryName = category.modelName;
    if (categoryName == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => EditCategoryDialog(currentName: categoryName),
    );

    if (newName != null && mounted) {
      context.read<ServerBloc>().add(
        ServerRenameCategory(oldName: categoryName, newName: newName),
      );
    }
  }

  /// 启动分类人数刷新定时器
  void _startCategoryCountsRefreshTimer() {
    _categoryCountsRefreshTimer?.cancel();
    _categoryCountsCountdown = _kCategoryCountsRefreshInterval;

    _categoryCountsRefreshTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _categoryCountsCountdown--;

      if (_categoryCountsCountdown <= 0) {
        // 触发分类人数刷新
        _serverBloc?.add(ServerUpdateCategoryOnlineCounts());
        _categoryCountsCountdown = _kCategoryCountsRefreshInterval - 1;
      }
    });
  }

  /// 停止分类人数刷新定时器
  void _stopCategoryCountsRefreshTimer() {
    _categoryCountsRefreshTimer?.cancel();
    _categoryCountsRefreshTimer = null;
  }

  @override
  void dispose() {
    _serverBloc?.add(ServerStopPeriodicRefresh());
    _stopCategoryCountsRefreshTimer();
    _gameStatusSubscription?.cancel();
    _serversScrollController.removeListener(_updateServersScrollIndicators);
    _serversScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // 监听错误消息
        BlocListener<ServerBloc, ServerState>(
          listenWhen: (previous, current) =>
              current.error != null && current.error != previous.error,
          listener: (context, state) {
            if (state.error != null) {
              ToastUtils.showError(context, state.error!);
            }
          },
        ),
        // 监听成功消息
        BlocListener<ServerBloc, ServerState>(
          listenWhen: (previous, current) =>
              current.successMessage != null &&
              current.successMessage != previous.successMessage,
          listener: (context, state) {
            if (state.successMessage != null) {
              ToastUtils.showSuccess(context, state.successMessage!);
            }
          },
        ),
        // 服务器数据变化时获取 ping（合并监听逻辑）
        BlocListener<ServerBloc, ServerState>(
          listenWhen: (previous, current) {
            // 情况1：加载完成（首次加载或切换分类）
            final loadingFinished =
                previous.isLoadingServers && !current.isLoadingServers;
            // 情况2：服务器列表变化
            final serversChanged =
                previous.servers.length != current.servers.length;
            // 情况3：有新的服务器数据加载完成（比较前后状态）
            final previousServersWithData = previous.servers
                .where((s) => s.serverData != null)
                .length;
            final currentServersWithData = current.servers
                .where((s) => s.serverData != null)
                .length;
            final newServerDataLoaded =
                currentServersWithData > previousServersWithData;
            // 情况4：定期刷新完成（lastRefreshTime 变化且有缺少 ping 的服务器）
            final refreshCompleted =
                previous.lastRefreshTime != current.lastRefreshTime &&
                current.servers.any(
                  (s) => s.serverData != null && s.pingInfo == null,
                );

            return current.servers.isNotEmpty &&
                (loadingFinished ||
                    serversChanged ||
                    newServerDataLoaded ||
                    refreshCompleted);
          },
          listener: (context, state) => _scheduleDelayedPingFetch(),
        ),
        // 分类加载完成后自动选择第一个
        BlocListener<ServerBloc, ServerState>(
          listenWhen: (previous, current) =>
              previous.isLoading &&
              !current.isLoading &&
              current.serverCategories.isNotEmpty &&
              current.selectedCategory == null,
          listener: (context, state) => _autoSelectFirstCategory(state),
        ),
        // 应用 pending categories 时触发分类列表刷新动画
        // 仅当 serverCategories 实际发生变化时触发（dismiss 不改变 categories，不触发）
        BlocListener<ServerBloc, ServerState>(
          listenWhen: (previous, current) =>
              previous.pendingCategories != null &&
              current.pendingCategories == null &&
              previous.serverCategories != current.serverCategories,
          listener: (context, state) {
            setState(() => _categoriesListAnimKey++);
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF3F4F6),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.fromLTRB(15, 50, 15, 0),
          child: _buildMainContent(),
        ),
      ),
    );
  }

  /// 处理自动刷新（定期刷新）
  void _handleRefresh(ServerState state) {
    // 沉浸模式下不触发自动刷新
    if (_isInImmersiveMode) return;
    if (state.selectedCategory != null) {
      // 定期刷新使用普通刷新（保留现有数据，只更新变化的部分）
      context.read<ServerBloc>().add(ServerRefreshServers());
    }
  }

  /// 处理手动强制刷新（重置所有状态）
  /// 每次点击都执行强制刷新，就像浏览器刷新一样
  void _handleForceRefresh() {
    context.read<ServerBloc>().add(ServerForceRefresh());
  }

  /// 热身通知开关按钮
  Widget _buildWarmupNotificationToggle(bool isDark) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) =>
          previous.warmupNotificationEnabled !=
          current.warmupNotificationEnabled,
      builder: (context, settingsState) {
        final isEnabled = settingsState.warmupNotificationEnabled;
        final warmupColor = const Color(0xFFFF9800);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? warmupColor.withValues(alpha: 0.12)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled
                  ? warmupColor.withValues(alpha: 0.3)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  key: ValueKey(isEnabled),
                  size: 15,
                  color: isEnabled
                      ? warmupColor
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '热身通知',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isEnabled
                      ? warmupColor
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 22,
                width: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: isEnabled,
                    onChanged: (value) {
                      context.read<SettingsBloc>().add(
                        SettingsSetWarmupNotificationEnabled(value),
                      );
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: warmupColor,
                    inactiveThumbColor: isDark
                        ? Colors.white54
                        : Colors.grey.shade400,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 启动游戏按钮
  Widget _buildLaunchGameButton(bool isDark) {
    // 正在启动游戏时显示启动中状态
    if (_isLaunchingGame) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '启动中...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      );
    }

    // 游戏已运行时显示已启动状态
    if (_isGameRunning) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.checkCircle, size: 18, color: Colors.green),
            const SizedBox(width: 6),
            const Text(
              '游戏已启动',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    // 游戏未运行时显示启动按钮
    return Tooltip(
      message: '启动游戏',
      child: InkWell(
        onTap: _launchGame,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MdiIcons.gamepadVariant,
                size: 18,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                '启动游戏',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 启动游戏
  Future<void> _launchGame() async {
    if (_isLaunchingGame || _isGameRunning) return;

    // 使用 StatusWindowService 启动游戏（与挤服页面共享状态）
    await _statusService.launchGame();

    if (!mounted) return;

    // 获取最新状态判断结果
    final state = _statusService.state;
    if (state.status == OperationStatus.success) {
      ToastUtils.showSuccess(context, '游戏启动成功');
    } else if (state.status == OperationStatus.failed) {
      ToastUtils.showError(context, state.message ?? '启动游戏失败');
    }
  }

  /// 服务器设置按钮
  Widget _buildServerSettingsButton(bool isDark) {
    return Tooltip(
      message: '服务器设置',
      child: InkWell(
        onTap: () => _showServerSettingsPanel(context),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 20,
            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  /// 显示服务器设置面板
  void _showServerSettingsPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: _ServerSettingsDialog(),
      ),
    );
  }

  /// 主内容区域（左右布局）
  Widget _buildMainContent() {
    return Row(
      children: [
        // 左侧服务器列表
        Expanded(child: _buildServersColumn()),
        const SizedBox(width: 5),
        // 右侧分类列表
        SizedBox(width: 300, child: _buildCategoriesColumn()),
      ],
    );
  }

  /// 左侧服务器列表列
  Widget _buildServersColumn() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 列标题和添加按钮
          _buildServersHeader(),
          // 服务器列表
          Expanded(child: _buildServersList()),
        ],
      ),
    );
  }

  /// 服务器列表头部（包含添加按钮和倒计时）
  Widget _buildServersHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final canAddServer = state.selectedCategory?.isCustom == true;
        final categoryName = state.selectedCategory?.modelName ?? '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 4, 15, 5),
          child: Row(
            children: [
              // 服务器标题
              Text(
                '服务器',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // 倒计时刷新组件
              if (state.selectedCategory != null) ...[
                const SizedBox(width: 12),
                // 热身通知开关（仅非自定义分类显示）
                if (!canAddServer) ...[
                  _buildWarmupNotificationToggle(isDark),
                  const SizedBox(width: 8),
                ],
                // 启动游戏按钮
                _buildLaunchGameButton(isDark),
                const SizedBox(width: 8),
                // 添加服务器按钮（仅自定义分类显示）
                if (canAddServer) ...[
                  Tooltip(
                    message: '添加服务器',
                    child: InkWell(
                      onTap: _showAddServerDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 地图订阅按钮
                Tooltip(
                  message: '地图订阅',
                  child: InkWell(
                    onTap: () {
                      // ignore: avoid_dynamic_calls
                      MapSubscriptionDialog.show(context);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: isDark
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 沉浸式模式按钮
                Tooltip(
                  message: '沉浸模式',
                  child: InkWell(
                    onTap: () async {
                      // 进入沉浸模式前暂停正常模式的刷新机制
                      _isInImmersiveMode = true;
                      _serverBloc?.add(ServerStopPeriodicRefresh());
                      _stopCategoryCountsRefreshTimer();
                      await ImmersiveModeOverlay.show(context);
                      // 退出沉浸模式后恢复正常模式的刷新机制
                      if (mounted) {
                        _isInImmersiveMode = false;
                        _serverBloc?.add(ServerStartPeriodicRefresh());
                        _startCategoryCountsRefreshTimer();
                        // 立即刷新一次，防止数据过旧
                        _serverBloc?.add(ServerRefreshServers());
                        // 立即触发 ping 获取
                        _scheduleDelayedPingFetch();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 20,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 服务器设置按钮（仅自定义分类显示）
                if (canAddServer) ...[
                  _buildServerSettingsButton(isDark),
                  const SizedBox(width: 8),
                ],
                CompactRefreshProgress(
                  key: ValueKey(
                    'refresh_${categoryName}_${state.countdownResetKey}',
                  ),
                  refreshInterval: _kRefreshInterval,
                  onRefresh: () => _handleRefresh(state),
                  onForceRefresh: () => _handleForceRefresh(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 服务器列表内容
  Widget _buildServersList() {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        if (state.selectedCategory == null) {
          return _buildEmptyState(
            icon: Icons.dns_outlined,
            title: '选择一个服务器分类',
            subtitle: '点击右侧列表中的分类查看服务器',
          );
        }

        // 没有服务器数据时显示骨架屏（仅在首次加载时）
        if (state.servers.isEmpty && state.isLoadingServers) {
          return _buildLoadingList(4);
        }

        if (state.error != null && state.servers.isEmpty) {
          return _buildErrorState(state.error!);
        }

        // 空分类（自定义分类没有服务器）
        if (state.servers.isEmpty) {
          final isCustomCategory = state.selectedCategory?.isCustom ?? false;
          return _buildEmptyState(
            icon: isCustomCategory
                ? Icons.add_circle_outline
                : Icons.cloud_off_outlined,
            title: isCustomCategory ? '暂无服务器' : '暂无服务器数据',
            subtitle: isCustomCategory
                ? '点击上方 + 按钮添加服务器到此分类'
                : '请点击刷新按钮或选择其他分类',
          );
        }

        // 有服务器数据时，每个卡片独立显示（骨架屏或真实内容）
        return _buildServerCardList();
      },
    );
  }

  /// 服务器卡片列表
  Widget _buildServerCardList() {
    // 延迟检查滚动状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateServersScrollIndicators();
    });

    return Stack(
      children: [
        BlocBuilder<ServerBloc, ServerState>(
          builder: (context, state) {
            final isCustomCategory = state.selectedCategory?.isCustom == true;
            final categoryName = state.selectedCategory?.modelName;

            // 根据排序模式获取服务器列表（仅自定义分类生效）
            final settingsState = context.watch<SettingsBloc>().state;
            final sortMode = settingsState.serverSortMode;

            // 置顶在线模式：对服务器进行排序（仅自定义分类）
            List<ExtendedServerItem> sortedServers;
            if (sortMode == ServerSortMode.pinOnline && isCustomCategory) {
              sortedServers = _sortServersByOnlineStatus(state.servers);
            } else {
              sortedServers = state.servers;
            }

            // 手动排序模式 + 自定义分类：使用可拖拽排序列表
            if (sortMode == ServerSortMode.manual &&
                isCustomCategory &&
                categoryName != null) {
              return _buildReorderableServerList(
                context,
                state,
                sortedServers,
                categoryName,
              );
            }

            // 其他情况使用普通列表（默认分类或置顶在线模式）
            return _buildNormalServerList(context, state, sortedServers);
          },
        ),
        // 顶部滚动指示器
        if (_canScrollUpServers)
          Positioned(
            top: 0,
            left: 0,
            right: 12,
            child: _buildScrollIndicator(isTop: true),
          ),
        // 底部滚动指示器
        if (_canScrollDownServers)
          Positioned(
            bottom: 0,
            left: 0,
            right: 12,
            child: _buildScrollIndicator(isTop: false),
          ),
      ],
    );
  }

  /// 服务器在线状态排序（在线 > 加载中 > 离线）
  /// - 在线服务器排在最前面（获取到数据的服务器，无论人数）
  /// - 加载中的服务器排在中间，保持原始相对顺序
  /// - 离线服务器排在最后（无法获取数据的服务器）
  List<ExtendedServerItem> _sortServersByOnlineStatus(
    List<ExtendedServerItem> servers,
  ) {
    // 分离三个状态
    final onlineServers = <ExtendedServerItem>[];
    final loadingServers = <ExtendedServerItem>[];
    final offlineServers = <ExtendedServerItem>[];

    for (final server in servers) {
      final hasData = server.serverData != null;
      final isLoading = server.isLoading;

      if (hasData) {
        // 在线服务器：获取到数据的服务器，无论玩家数量
        onlineServers.add(server);
      } else if (isLoading) {
        // 加载中的服务器：正在等待响应
        loadingServers.add(server);
      } else {
        // 离线服务器：没有数据且不在加载中（已超时或错误）
        offlineServers.add(server);
      }
    }

    // 合并：在线 + 加载中 + 离线
    return [...onlineServers, ...loadingServers, ...offlineServers];
  }

  /// 构建普通服务器列表（非自定义分类）
  Widget _buildNormalServerList(
    BuildContext context,
    ServerState state,
    List<ExtendedServerItem> servers,
  ) {
    return Scrollbar(
      controller: _serversScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _serversScrollController,
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        itemCount: servers.length,
        itemBuilder: (context, index) =>
            _buildServerCardItem(context, state, servers[index], index),
      ),
    );
  }

  /// 构建可拖拽排序的服务器列表（自定义分类）
  Widget _buildReorderableServerList(
    BuildContext context,
    ServerState state,
    List<ExtendedServerItem> servers,
    String categoryName,
  ) {
    return Scrollbar(
      controller: _serversScrollController,
      thumbVisibility: true,
      child: ReorderableListView.builder(
        scrollController: _serversScrollController,
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        itemCount: servers.length,
        buildDefaultDragHandles: false, // 禁用默认拖拽手柄，使用自定义的
        onReorder: (oldIndex, newIndex) {
          // ReorderableListView 的 newIndex 在向下移动时需要调整
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          if (oldIndex != newIndex) {
            context.read<ServerBloc>().add(
              ServerReorderServers(
                categoryName: categoryName,
                oldIndex: oldIndex,
                newIndex: newIndex,
              ),
            );
          }
        },
        proxyDecorator: (child, index, animation) {
          // 拖拽时的装饰器 - 只添加阴影，不包裹额外的 Material
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final double animValue = Curves.easeInOut.transform(
                animation.value,
              );
              return Transform.scale(
                scale: 1.0 + (0.02 * animValue), // 轻微放大效果
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF3B82F6,
                        ).withValues(alpha: 0.4 * animValue),
                        blurRadius: 20 * animValue,
                        spreadRadius: 2 * animValue,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3 * animValue),
                        blurRadius: 15 * animValue,
                        offset: Offset(0, 8 * animValue),
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final server = servers[index];
          // 使用服务器地址作为唯一 key，确保拖拽时的稳定性
          final serverKey =
              server.serverItem.address ??
              server.serverItem.serverAddress ??
              'server_$index';
          return _buildDraggableServerCardItem(
            key: ValueKey(serverKey),
            context: context,
            state: state,
            server: server,
            index: index,
          );
        },
      ),
    );
  }

  /// 构建单个服务器卡片项（用于普通列表）
  Widget _buildServerCardItem(
    BuildContext context,
    ServerState state,
    ExtendedServerItem server,
    int index,
  ) {
    final showSkeleton = server.isLoading && server.serverData == null;
    // 在 A2S 加载阶段显示加载文字
    final String? loadingText =
        showSkeleton && state.loadingPhase == LoadingPhase.loadingA2S
        ? '正在获取服务器数据...'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: showSkeleton
            ? ServerCardSkeleton(
                key: ValueKey('skeleton_$index'),
                loadingText: loadingText,
              )
            : ServerCard(
                key: ValueKey(server.serverItem.address),
                server: server,
                categoryName: state.selectedCategory?.isCustom == true
                    ? state.selectedCategory?.modelName
                    : null,
                onTap: () => _showServerDetails(server),
                onDelete: server.serverItem.isCustom
                    ? () {
                        final categoryName = state.selectedCategory?.modelName;
                        final address =
                            server.serverItem.address ??
                            server.serverItem.serverAddress;
                        if (categoryName != null && address != null) {
                          context.read<ServerBloc>().add(
                            ServerDeleteServer(
                              categoryName: categoryName,
                              serverAddress: address,
                            ),
                          );
                        }
                      }
                    : null,
              ),
      ),
    );
  }

  /// 构建可拖拽的服务器卡片项（用于可排序列表）
  Widget _buildDraggableServerCardItem({
    required Key key,
    required BuildContext context,
    required ServerState state,
    required ExtendedServerItem server,
    required int index,
  }) {
    final showSkeleton = server.isLoading && server.serverData == null;

    // 构建卡片内容
    final Widget cardContent = showSkeleton
        ? const ServerCardSkeleton()
        : ServerCard(
            key: ValueKey('card_${server.serverItem.address}'),
            server: server,
            categoryName: state.selectedCategory?.modelName,
            // 保留 hover 效果，通过长按触发拖拽
            onTap: () => _showServerDetails(server),
            onDelete: () {
              final categoryName = state.selectedCategory?.modelName;
              final address =
                  server.serverItem.address ??
                  server.serverItem.serverAddress;
              if (categoryName != null && address != null) {
                context.read<ServerBloc>().add(
                  ServerDeleteServer(
                    categoryName: categoryName,
                    serverAddress: address,
                  ),
                );
              }
            },
          );

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      // 使用自定义长按监听器，长按 500ms 后触发拖拽
      child: _LongPressDraggableWrapper(
        index: index,
        child: cardContent,
      ),
    );
  }

  /// 加载中列表
  Widget _buildLoadingList(int count) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
      itemCount: count.clamp(1, 6),
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 15),
        child: ServerCardSkeleton(),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFCCCCCC),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final state = context.read<ServerBloc>().state;
                if (state.selectedCategory != null) {
                  context.read<ServerBloc>().add(
                    ServerSelectCategory(state.selectedCategory!),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0080FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧分类列表列
  Widget _buildCategoriesColumn() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab 标签栏
              _buildTabBar(),
              // 分类列表
              Expanded(child: _buildCategoriesList()),
            ],
          ),
        ),
        // 分类更新浮层提示（覆盖在列表上方）
        _buildPendingCategoriesOverlay(),
      ],
    );
  }

  /// 分类更新浮层提示（检测到新分类时从顶部滑入）
  Widget _buildPendingCategoriesOverlay() {
    return BlocBuilder<ServerBloc, ServerState>(
      buildWhen: (previous, current) =>
          (previous.pendingCategories == null) !=
          (current.pendingCategories == null),
      builder: (context, state) {
        final hasPending = state.pendingCategories != null;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return IgnorePointer(
          ignoring: !hasPending,
          child: AnimatedSlide(
            offset: hasPending ? Offset.zero : const Offset(0, -1.5),
            duration: const Duration(milliseconds: 350),
            curve: hasPending ? Curves.easeOutBack : Curves.easeIn,
            child: AnimatedOpacity(
              opacity: hasPending ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Material(
                    elevation: hasPending ? 8 : 0,
                    shadowColor: const Color(0xFF0080FF).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF1E3A5F),
                                  const Color(0xFF1A2F4A),
                                ]
                              : [
                                  const Color(0xFFEFF6FF),
                                  const Color(0xFFDBEAFE),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0080FF).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题行
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0080FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.system_update_alt_rounded,
                                  size: 18,
                                  color: Color(0xFF0080FF),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '分类列表有更新',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1E40AF),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '服务器分类已在后台更新，点击应用以刷新列表',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 关闭按钮
                              InkWell(
                                onTap: () => context.read<ServerBloc>().add(
                                  const ServerDismissPendingCategories(),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF93C5FD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // 操作按钮行
                          Row(
                            children: [
                              const Spacer(),
                              // 稍后按钮
                              InkWell(
                                onTap: () => context.read<ServerBloc>().add(
                                  const ServerDismissPendingCategories(),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : const Color(0xFF93C5FD),
                                    ),
                                  ),
                                  child: Text(
                                    '稍后',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 立即应用按钮
                              InkWell(
                                onTap: () => context.read<ServerBloc>().add(
                                  const ServerApplyPendingCategories(),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0080FF),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0080FF).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '立即应用',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  /// 构建 Tab 标签栏
  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Tab 标签组
              Expanded(
                child: Row(
                  children: [
                    _buildTabButton(
                      label: '默认',
                      count: state.serverCategories
                          .where((c) => !c.isCustom)
                          .length,
                      isSelected: state.selectedTabIndex == 0,
                      onTap: () => context.read<ServerBloc>().add(
                        const ServerSwitchTab(0),
                      ),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildTabButton(
                      label: '自定义',
                      count: state.serverCategories
                          .where((c) => c.isCustom)
                          .length,
                      isSelected: state.selectedTabIndex == 1,
                      onTap: () => context.read<ServerBloc>().add(
                        const ServerSwitchTab(1),
                      ),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // 添加分类按钮（只在自定义 tab 显示）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.selectedTabIndex == 1
                    ? Tooltip(
                        message: '添加自定义分类',
                        child: InkWell(
                          onTap: _showAddCategoryDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0080FF,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF0080FF,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Color(0xFF0080FF),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个 Tab 按钮
  Widget _buildTabButton({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0080FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF111827))
                    : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0080FF).withValues(alpha: 0.15)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF0080FF)
                      : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 分类列表内容
  Widget _buildCategoriesList() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        // animation 对新 child 是 0→1（进入），对旧 child 是 1→0（退出）
        // 新内容从下方轻微滑入，旧内容原地淡出（不位移，避免方向混乱）
        final isEntering = animation.status == AnimationStatus.forward ||
            animation.status == AnimationStatus.completed;
        return FadeTransition(
          opacity: animation,
          child: isEntering
              ? SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                )
              : child,
        );
      },
      child: _CategoriesListContent(
        key: ValueKey(_categoriesListAnimKey),
        onCategoryTap: _onCategoryTap,
        onEditCategory: _showEditCategoryDialog,
      ),
    );
  }

  /// 构建滚动指示器
  Widget _buildScrollIndicator({required bool isTop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB);
    return IgnorePointer(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.9),
              bgColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        padding: EdgeInsets.only(top: isTop ? 2 : 0, bottom: isTop ? 0 : 2),
        child: Icon(
          isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
          size: 28,
        ),
      ),
    );
  }

  void _showServerDetails(ExtendedServerItem server) {
    showDialog(
      context: context,
      builder: (context) => ServerDetailDialog(server: server),
    );
  }

  /// 显示添加分类对话框
  void _showAddCategoryDialog() {
    showDialog<String>(
      context: context,
      builder: (context) => const AddCategoryDialog(),
    ).then((categoryName) {
      if (!mounted) return;
      if (categoryName != null && categoryName.isNotEmpty) {
        context.read<ServerBloc>().add(ServerAddCategory(categoryName));
      }
    });
  }

  /// 显示添加服务器对话框
  void _showAddServerDialog() {
    final state = context.read<ServerBloc>().state;
    final categoryName = state.selectedCategory?.modelName;

    if (categoryName == null) return;

    showDialog<AddServerResult>(
      context: context,
      builder: (context) => AddServerDialog(categoryName: categoryName),
    ).then((result) {
      if (!mounted) return;
      if (result != null && result.address.isNotEmpty) {
        context.read<ServerBloc>().add(
          ServerAddServer(
            categoryName: categoryName,
            serverAddress: result.address,
            nickname: result.nickname,
          ),
        );
      }
    });
  }
}

/// 服务器设置对话框
class _ServerSettingsDialog extends StatelessWidget {
  const _ServerSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '服务器设置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 排序模式说明
              Text(
                '排序模式',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              // 排序模式选项
              BlocBuilder<SettingsBloc, SettingsState>(
                buildWhen: (previous, current) =>
                    previous.serverSortMode != current.serverSortMode,
                builder: (context, state) {
                  return Column(
                    children: [
                      _buildSortModeOption(
                        context: context,
                        mode: ServerSortMode.manual,
                        title: '手动排序',
                        description: '通过长按拖动调整服务器顺序',
                        isSelected: state.serverSortMode == ServerSortMode.manual,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildSortModeOption(
                        context: context,
                        mode: ServerSortMode.pinOnline,
                        title: '置顶在线服务器',
                        description: '在线服务器自动排在前面，离线服务器自动排在后面',
                        isSelected: state.serverSortMode == ServerSortMode.pinOnline,
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建排序模式选项
  Widget _buildSortModeOption({
    required BuildContext context,
    required ServerSortMode mode,
    required String title,
    required String description,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        context.read<SettingsBloc>().add(SettingsSetServerSortMode(mode));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0080FF).withValues(alpha: 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0080FF).withValues(alpha: 0.4)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 单选按钮
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0080FF)
                      : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0080FF),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0080FF)
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义长按拖拽包装器 - 长按触发拖拽，不影响 hover
///
/// 使用 ReorderableDelayedDragStartListener 作为核心，长按后触发拖拽
/// 同时播放视觉反馈动画（按下即显示，长按过程中持续）
class _LongPressDraggableWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _LongPressDraggableWrapper({
    required this.index,
    required this.child,
  });

  @override
  State<_LongPressDraggableWrapper> createState() => _LongPressDraggableWrapperState();
}

class _LongPressDraggableWrapperState extends State<_LongPressDraggableWrapper> {
  // 是否正在长按（按下但未松开）
  bool _isLongPressing = false;

  // 开始长按
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != 1) return;
    _isLongPressing = true;
    setState(() {});
  }

  // 结束长按
  void _onPointerUp(PointerUpEvent event) {
    _isLongPressing = false;
    setState(() {});
  }

  // 取消长按
  void _onPointerCancel(PointerCancelEvent event) {
    _isLongPressing = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ReorderableDelayedDragStartListener(
        index: widget.index,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: _isLongPressing
                ? Border.all(
                    color: const Color(0xFF0080FF),
                    width: 2,
                  )
                : null,
            boxShadow: _isLongPressing
                ? [
                    BoxShadow(
                      color: const Color(0xFF0080FF).withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: AnimatedScale(
            scale: _isLongPressing ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ==================== 分类列表独立组件 ====================

/// 分类列表内容组件（独立 StatefulWidget，持有自己的 ScrollController）
/// 使用独立组件是为了配合 AnimatedSwitcher：动画过渡期间新旧两个实例同时存在，
/// 各自持有独立的 ScrollController，避免同一 controller attach 到多个 ScrollView 的断言错误。
class _CategoriesListContent extends StatefulWidget {
  final void Function(ServerCategory) onCategoryTap;
  final void Function(ServerCategory) onEditCategory;

  const _CategoriesListContent({
    super.key,
    required this.onCategoryTap,
    required this.onEditCategory,
  });

  @override
  State<_CategoriesListContent> createState() => _CategoriesListContentState();
}

class _CategoriesListContentState extends State<_CategoriesListContent> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canUp = pos.pixels > 0;
    final canDown = pos.pixels < pos.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        // 首次加载且没有分类数据时显示加载指示器
        if (state.isLoading && state.serverCategories.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0080FF)),
            ),
          );
        }

        if (state.error != null && state.serverCategories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.error ?? '加载失败'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<ServerBloc>().add(ServerFetchList()),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final filteredCategories = state.filteredCategories;

        if (filteredCategories.isEmpty) {
          final isCustomTab = state.selectedTabIndex == 1;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustomTab ? Icons.add_circle_outline : Icons.dns_outlined,
                    size: 48,
                    color: isDark ? Colors.white24 : const Color(0xFFCCCCCC),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCustomTab ? '暂无自定义分类' : '暂无默认分类',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCustomTab ? '点击上方 + 按钮添加自定义分类' : '系统默认分类将在此显示',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // 延迟检查滚动状态
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateScrollIndicators();
        });

        final bgColor = isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF9FAFB);

        return Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: _buildListView(context, state, filteredCategories),
            ),
            // 顶部滚动指示器
            if (_canScrollUp)
              Positioned(
                top: 0,
                left: 0,
                right: 12,
                child: _buildScrollIndicator(isTop: true, bgColor: bgColor),
              ),
            // 底部滚动指示器
            if (_canScrollDown)
              Positioned(
                bottom: 0,
                left: 0,
                right: 12,
                child: _buildScrollIndicator(isTop: false, bgColor: bgColor),
              ),
          ],
        );
      },
    );
  }

  Widget _buildListView(
    BuildContext context,
    ServerState state,
    List<ServerCategory> filteredCategories,
  ) {
    final isCustomTab = state.selectedTabIndex == 1;

    if (isCustomTab && filteredCategories.isNotEmpty) {
      return ReorderableListView.builder(
        scrollController: _scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        itemCount: filteredCategories.length,
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          if (oldIndex != newIndex) {
            context.read<ServerBloc>().add(
              ServerReorderCategories(oldIndex: oldIndex, newIndex: newIndex),
            );
          }
        },
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          final categoryName = category.modelName ?? '';
          final isSelected =
              state.selectedCategory?.modelName == categoryName;
          final onlineCount = state.getCategoryOnlineCount(categoryName);
          final isLoadingOnlineCount =
              !state.hasEverLoadedOnlineCounts &&
              state.isLoadingOnlineCounts &&
              !state.hasCategoryOnlineCount(categoryName);

          return ReorderableDragStartListener(
            index: index,
            key: ValueKey('category_$categoryName'),
            child: CategoryCard(
              category: category,
              isSelected: isSelected,
              onlineCount: onlineCount,
              isLoadingOnlineCount: isLoadingOnlineCount,
              onTap: () => widget.onCategoryTap(category),
              onEdit: category.isCustom
                  ? () => widget.onEditCategory(category)
                  : null,
              onDelete: category.isCustom
                  ? () => context.read<ServerBloc>().add(
                        ServerDeleteCategory(categoryName),
                      )
                  : null,
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        final categoryName = category.modelName ?? '';
        final isSelected =
            state.selectedCategory?.modelName == categoryName;
        final onlineCount = state.getCategoryOnlineCount(categoryName);
        final isLoadingOnlineCount =
            !state.hasEverLoadedOnlineCounts &&
            state.isLoadingOnlineCounts &&
            !state.hasCategoryOnlineCount(categoryName);

        return CategoryCard(
          category: category,
          isSelected: isSelected,
          onlineCount: onlineCount,
          isLoadingOnlineCount: isLoadingOnlineCount,
          onTap: () => widget.onCategoryTap(category),
          onEdit: category.isCustom
              ? () => widget.onEditCategory(category)
              : null,
          onDelete: category.isCustom
              ? () => context.read<ServerBloc>().add(
                    ServerDeleteCategory(categoryName),
                  )
              : null,
        );
      },
    );
  }

  Widget _buildScrollIndicator({
    required bool isTop,
    required Color bgColor,
  }) {
    return IgnorePointer(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.9),
              bgColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Icon(
            isTop ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: bgColor.computeLuminance() > 0.5
                ? Colors.black26
                : Colors.white24,
            size: 20,
          ),
        ),
      ),
    );
  }
}
