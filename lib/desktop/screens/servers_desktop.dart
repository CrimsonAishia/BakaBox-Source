import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dart_ping/dart_ping.dart';
import '../../core/core.dart';
import '../widgets/page_layout.dart';
import '../widgets/server/server_card.dart';
import '../widgets/server/server_card_skeleton.dart';
import '../widgets/category_card.dart';
import '../widgets/refresh_progress.dart';
import '../widgets/server/server_detail_dialog.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/add_server_dialog.dart';

/// 自动刷新间隔（秒）
const int _kRefreshInterval = 15;

class ServersDesktop extends StatefulWidget {
  const ServersDesktop({super.key});

  @override
  State<ServersDesktop> createState() => _ServersDesktopState();
}

class _ServersDesktopState extends State<ServersDesktop> {
  ServerBloc? _serverBloc;
  bool _isInitialized = false;
  
  // ScrollController for lists
  final ScrollController _serversScrollController = ScrollController();
  final ScrollController _categoriesScrollController = ScrollController();
  
  // 滚动指示器状态
  bool _canScrollUpServers = false;
  bool _canScrollDownServers = false;
  bool _canScrollUpCategories = false;
  bool _canScrollDownCategories = false;
  
  // Ping 相关
  int _lastPingRequestId = 0;

  @override
  void initState() {
    super.initState();
    
    // 监听服务器列表滚动
    _serversScrollController.addListener(_updateServersScrollIndicators);
    // 监听分类列表滚动
    _categoriesScrollController.addListener(_updateCategoriesScrollIndicators);
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
  
  void _updateCategoriesScrollIndicators() {
    if (!_categoriesScrollController.hasClients) return;
    final position = _categoriesScrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUpCategories || canDown != _canScrollDownCategories) {
      setState(() {
        _canScrollUpCategories = canUp;
        _canScrollDownCategories = canDown;
      });
    }
  }
  
  /// 延迟获取所有服务器的 ping
  void _scheduleDelayedPingFetch() {
    final requestId = ++_lastPingRequestId;
    
    // 延迟 500ms 后获取 ping
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || requestId != _lastPingRequestId) return;
      
      // 从 bloc 获取最新的服务器列表
      final bloc = _serverBloc;
      if (bloc == null) return;
      
      final currentServers = bloc.state.servers;
      final serversWithData = currentServers.where((s) => s.serverData != null).toList();
      if (serversWithData.isNotEmpty) {
        _fetchAllServerPings(serversWithData);
      } else {
        // 如果还没有服务器数据，再等待 1 秒
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted || requestId != _lastPingRequestId) return;
          final bloc = _serverBloc;
          if (bloc == null) return;
          
          final laterServers = bloc.state.servers;
          final serversWithDataLater = laterServers.where((s) => s.serverData != null).toList();
          if (serversWithDataLater.isNotEmpty) {
            _fetchAllServerPings(serversWithDataLater);
          }
        });
      }
    });
  }
  
  /// 批量获取所有服务器的 ping
  Future<void> _fetchAllServerPings(List<ExtendedServerItem> servers) async {
    final bloc = _serverBloc;
    if (bloc == null || servers.isEmpty) return;
    
    // 串行获取 ping，避免同时创建多个 Ping 实例
    for (final server in servers) {
      if (!mounted) break;
      await _fetchServerPing(server, bloc);
    }
  }

  /// 获取单个服务器的 ping
  Future<void> _fetchServerPing(
      ExtendedServerItem server, ServerBloc bloc) async {
    final address = server.serverItem.address;
    if (address == null || address.isEmpty) return;

    final ip = address.split(':')[0];
    if (ip.isEmpty) return;

    try {
      // 发送 3 次 ping
      // forceCodepage: true 解决 Windows 中文系统编码问题
      // encoding: Utf8Codec(allowMalformed: true) 忽略非 UTF-8 字符
      final ping = Ping(
        ip, 
        count: 3, 
        timeout: 3,
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
        final avgMs = results.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/ results.length;
        
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

        bloc.add(ServerUpdateSingleServer(
          address: address,
          pingInfo: pingInfo,
        ));
      }
    } catch (e) {
      // 忽略 ping 获取失败
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
          }
          bloc.add(ServerStartPeriodicRefresh());
        }
      });
    }
  }

  /// 桌面端自动选择第一个分类（如果没有选中分类）
  void _autoSelectFirstCategory(ServerState state) {
    if (!mounted) return;
    if (state.selectedCategory == null && 
        state.serverCategories.isNotEmpty && 
        !state.isLoading) {
      // 优先选择默认分类（API 分类）的第一个
      final defaultCategories = state.serverCategories.where((c) => !c.isCustom).toList();
      if (defaultCategories.isNotEmpty) {
        context.read<ServerBloc>().add(ServerSelectCategory(defaultCategories.first));
      } else {
        // 如果没有默认分类，选择自定义分类的第一个
        final customCategories = state.serverCategories.where((c) => c.isCustom).toList();
        if (customCategories.isNotEmpty) {
          // 切换到自定义 tab
          context.read<ServerBloc>().add(const ServerSwitchTab(1));
          context.read<ServerBloc>().add(ServerSelectCategory(customCategories.first));
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
    }
    context.read<ServerBloc>().add(ServerSelectCategory(category));
  }

  @override
  void dispose() {
    _serverBloc?.add(ServerStopPeriodicRefresh());
    _serversScrollController.removeListener(_updateServersScrollIndicators);
    _categoriesScrollController.removeListener(_updateCategoriesScrollIndicators);
    _serversScrollController.dispose();
    _categoriesScrollController.dispose();
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
        // 服务器数据加载完成后获取 ping
        BlocListener<ServerBloc, ServerState>(
          listenWhen: (previous, current) =>
              previous.isLoadingServers &&
              !current.isLoadingServers &&
              current.servers.isNotEmpty,
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
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF3F4F6),
        body: PageLayout(
          title: '服务器列表',
          subtitle: '选择一个服务器开始游戏',
          headerActions: _buildHeaderActions(),
          child: _buildMainContent(),
        ),
      ),
    );
  }

  /// 头部操作区域（刷新进度）
  Widget _buildHeaderActions() {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        if (state.selectedCategory == null) {
          return const SizedBox.shrink();
        }
        
        return CompactRefreshProgress(
          refreshInterval: _kRefreshInterval,
          onRefresh: () => _handleRefresh(state),
        );
      },
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

  /// 服务器列表头部（包含添加按钮）
  Widget _buildServersHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final canAddServer = state.selectedCategory?.isCustom == true;

        return Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '服务器',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // 始终占位，避免高度变动
              AnimatedOpacity(
                opacity: canAddServer ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !canAddServer,
                  child: Tooltip(
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
                ),
              ),
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
            icon: isCustomCategory ? Icons.add_circle_outline : Icons.cloud_off_outlined,
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
        Scrollbar(
          controller: _serversScrollController,
          thumbVisibility: true,
          child: BlocBuilder<ServerBloc, ServerState>(
            builder: (context, state) {
              // 使用 state.servers 确保数据一致性
              final currentServers = state.servers;
              return ListView.builder(
                controller: _serversScrollController,
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                itemCount: currentServers.length,
                itemBuilder: (context, index) {
                  final server = currentServers[index];
                  // 每个卡片独立判断：加载中且无数据时显示骨架屏
                  final showSkeleton = server.isLoading && server.serverData == null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: showSkeleton
                          ? const ServerCardSkeleton()
                          : ServerCard(
                              key: ValueKey(server.serverItem.address),
                              server: server,
                              // 只有自定义分类才传递分类名（用于换图通知显示）
                              categoryName: state.selectedCategory?.isCustom == true
                                  ? state.selectedCategory?.modelName
                                  : null,
                              onTap: () => _showServerDetails(server),
                              onDelete: server.serverItem.isCustom
                                  ? () {
                                      final categoryName = state.selectedCategory?.modelName;
                                      final address = server.serverItem.address ?? 
                                                      server.serverItem.serverAddress;
                                      if (categoryName != null && address != null) {
                                        context.read<ServerBloc>().add(ServerDeleteServer(
                                          categoryName: categoryName,
                                          serverAddress: address,
                                        ));
                                      }
                                    }
                                  : null,
                            ),
                    ),
                  );
                },
              );
            },
          ),
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
            Icon(Icons.warning_amber_rounded,
                size: 48, color: Colors.orange.shade400),
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
                  context
                      .read<ServerBloc>()
                      .add(ServerSelectCategory(state.selectedCategory!));
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
          // Tab 标签栏
          _buildTabBar(),
          // 分类列表
          Expanded(child: _buildCategoriesList()),
        ],
      ),
    );
  }

  /// 构建 Tab 标签栏
  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
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
                      count: state.serverCategories.where((c) => !c.isCustom).length,
                      isSelected: state.selectedTabIndex == 0,
                      onTap: () => context.read<ServerBloc>().add(const ServerSwitchTab(0)),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildTabButton(
                      label: '自定义',
                      count: state.serverCategories.where((c) => c.isCustom).length,
                      isSelected: state.selectedTabIndex == 1,
                      onTap: () => context.read<ServerBloc>().add(const ServerSwitchTab(1)),
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
                              color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF0080FF).withValues(alpha: 0.3),
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
              color: isSelected
                  ? const Color(0xFF0080FF)
                  : Colors.transparent,
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
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
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

  /// 分类列表头部（包含添加按钮）- 已废弃，功能移至 Tab 栏
  @Deprecated('Use _buildTabBar instead')
  Widget _buildCategoryHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '服务器分类',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // 添加分类按钮
          Tooltip(
            message: '添加自定义分类',
            child: InkWell(
              onTap: _showAddCategoryDialog,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Color(0xFF0080FF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分类列表内容
  Widget _buildCategoriesList() {
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

        // 根据当前 tab 过滤分类列表
        final filteredCategories = state.filteredCategories;

        if (filteredCategories.isEmpty) {
          // 空状态提示
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
                    isCustomTab
                        ? '点击上方 + 按钮添加自定义分类'
                        : '系统默认分类将在此显示',
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
          _updateCategoriesScrollIndicators();
        });

        return Stack(
          children: [
            Scrollbar(
              controller: _categoriesScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _categoriesScrollController,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  final categoryName = category.modelName ?? '';
                  final isSelected =
                      state.selectedCategory?.modelName == categoryName;
                  final onlineCount = state.getCategoryOnlineCount(categoryName);
                  // 只在首次加载且该分类还没有获取到人数时显示loading
                  // 一旦该分类有了人数数据（即使是0），就不再显示loading
                  final isLoadingOnlineCount = !state.hasEverLoadedOnlineCounts && 
                      state.isLoadingOnlineCounts &&
                      !state.hasCategoryOnlineCount(categoryName);

                  return CategoryCard(
                    category: category,
                    isSelected: isSelected,
                    onlineCount: onlineCount,
                    isLoadingOnlineCount: isLoadingOnlineCount,
                    onTap: () => _onCategoryTap(category),
                    onDelete: category.isCustom
                        ? () {
                            context
                                .read<ServerBloc>()
                                .add(ServerDeleteCategory(categoryName));
                          }
                        : null,
                  );
                },
              ),
            ),
            // 顶部滚动指示器
            if (_canScrollUpCategories)
              Positioned(
                top: 0,
                left: 0,
                right: 12,
                child: _buildScrollIndicator(isTop: true),
              ),
            // 底部滚动指示器
            if (_canScrollDownCategories)
              Positioned(
                bottom: 0,
                left: 0,
                right: 12,
                child: _buildScrollIndicator(isTop: false),
              ),
          ],
        );
      },
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

  void _handleRefresh(ServerState state) {
    if (state.selectedCategory != null) {
      context.read<ServerBloc>().add(ServerRefreshServers());
    }
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
    
    showDialog<String>(
      context: context,
      builder: (context) => AddServerDialog(categoryName: categoryName),
    ).then((serverAddress) {
      if (!mounted) return;
      if (serverAddress != null && serverAddress.isNotEmpty) {
        context.read<ServerBloc>().add(ServerAddServer(
          categoryName: categoryName,
          serverAddress: serverAddress,
        ));
      }
    });
  }
}
