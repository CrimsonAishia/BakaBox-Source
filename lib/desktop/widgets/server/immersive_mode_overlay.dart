import 'dart:async';
import 'dart:convert';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screenshot/screenshot.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../core/api/server_api.dart';
import '../../../core/bloc/server/server_bloc.dart';
import '../../../core/bloc/server/server_state.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/source_server_service.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/utils/storage_utils.dart';
import 'server_card.dart';
import 'server_card_skeleton.dart';
import 'server_detail_dialog.dart';

/// 自动刷新间隔（秒）
const int _kImmersiveRefreshInterval = 15;

/// 存储 key：沉浸模式选中的分类
const String _kImmersiveSelectedCategoriesKey = 'immersive_selected_categories';

/// 沉浸式模式覆盖层
/// 全屏显示所有服务器卡片，一行两个，支持多分类筛选
class ImmersiveModeOverlay extends StatefulWidget {
  const ImmersiveModeOverlay({super.key});

  /// 显示沉浸式模式，返回 Future 在关闭后完成
  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ImmersiveModeOverlay();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<ImmersiveModeOverlay> createState() => _ImmersiveModeOverlayState();
}

class _ImmersiveModeOverlayState extends State<ImmersiveModeOverlay> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ScreenshotController _screenshotController = ScreenshotController();
  
  // 选中的分类名称集合（用于多选筛选）
  Set<String> _selectedCategories = {};
  
  // 本地管理的服务器数据（按分类存储）
  final Map<String, List<ExtendedServerItem>> _categoryServersMap = {};
  final Set<String> _loadingCategories = {};
  
  // 刷新定时器
  Timer? _refreshTimer;
  int _countdown = _kImmersiveRefreshInterval;
  bool _isRefreshing = false;
  
  // 截图预览相关
  Uint8List? _screenshotPreview;
  bool _showScreenshotPreview = false;
  bool _isTakingScreenshot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initializeData();
    });
  }

  void _initializeData() {
    final state = context.read<ServerBloc>().state;
    
    // 从存储中恢复选中的分类
    final savedCategories = _loadSavedCategories(state);
    
    if (savedCategories.isNotEmpty) {
      // 使用保存的分类
      _selectedCategories = savedCategories;
      
      // 复用当前分类的服务器数据（如果在选中列表中）
      if (state.selectedCategory?.modelName != null &&
          savedCategories.contains(state.selectedCategory!.modelName!)) {
        _categoryServersMap[state.selectedCategory!.modelName!] = List.from(state.servers);
      }
      
      // 加载其他选中但还没有数据的分类
      for (final categoryName in savedCategories) {
        if (!_categoryServersMap.containsKey(categoryName)) {
          _loadNewCategory(categoryName);
        }
      }
    } else if (state.selectedCategory?.modelName != null) {
      // 没有保存的分类，使用当前选中的分类
      _selectedCategories = {state.selectedCategory!.modelName!};
      _categoryServersMap[state.selectedCategory!.modelName!] = List.from(state.servers);
    }
    
    setState(() {});
    _startRefreshTimer();
  }

  /// 从存储中加载保存的分类（过滤掉不存在的分类）
  Set<String> _loadSavedCategories(ServerState state) {
    final savedList = StorageUtils.getStringList(_kImmersiveSelectedCategoriesKey);
    if (savedList.isEmpty) return {};
    
    // 获取所有有效的分类名称
    final validCategoryNames = state.serverCategories
        .where((c) => c.modelName != null)
        .map((c) => c.modelName!)
        .toSet();
    
    // 过滤掉不存在的分类
    return savedList.where((name) => validCategoryNames.contains(name)).toSet();
  }

  /// 保存选中的分类到存储
  Future<void> _saveSelectedCategories() async {
    await StorageUtils.setStringList(
      _kImmersiveSelectedCategoriesKey,
      _selectedCategories.toList(),
    );
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _countdown = _kImmersiveRefreshInterval;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _refreshAllSelectedCategories();
          _countdown = _kImmersiveRefreshInterval;
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _showServerDetails(ExtendedServerItem server) {
    showDialog(
      context: context,
      builder: (context) => ServerDetailDialog(server: server),
    );
  }

  /// 刷新所有选中分类的服务器（并行执行）
  Future<void> _refreshAllSelectedCategories() async {
    if (_isRefreshing || _selectedCategories.isEmpty) return;
    
    setState(() => _isRefreshing = true);
    
    final state = context.read<ServerBloc>().state;
    
    // 并行刷新所有选中的分类
    final futures = <Future<void>>[];
    
    for (final categoryName in _selectedCategories) {
      final category = state.serverCategories.firstWhere(
        (c) => c.modelName == categoryName,
        orElse: () => ServerCategory(serverList: []),
      );
      
      if (category.serverList.isEmpty) continue;
      
      futures.add(_refreshCategoryServers(category));
    }
    
    await Future.wait(futures);
    
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  /// 刷新单个分类的服务器数据（保留已有数据，只更新）
  Future<void> _refreshCategoryServers(ServerCategory category) async {
    final categoryName = category.modelName;
    if (categoryName == null) return;
    
    try {
      // 获取已有的服务器列表，如果没有则创建新的
      var servers = _categoryServersMap[categoryName];
      
      if (servers == null || servers.isEmpty) {
        // 首次加载，创建新列表
        servers = category.serverList.map((serverItem) {
          return ExtendedServerItem(
            serverItem: serverItem,
            isLoading: true,
          );
        }).toList();
        _categoryServersMap[categoryName] = servers;
      }
      
      // 并行获取所有服务器信息
      final futures = <Future<void>>[];
      
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        final address = server.serverItem.address ?? server.serverItem.serverAddress;
        if (address == null) continue;
        
        futures.add(_fetchServerInfo(categoryName, i, address));
      }
      
      await Future.wait(futures);
    } catch (e) {
      LogService.e('刷新分类 $categoryName 服务器失败: $e', e);
    }
  }

  /// 加载单个分类的服务器数据
  Future<void> _loadCategoryServers(ServerCategory category) async {
    final categoryName = category.modelName;
    if (categoryName == null) return;
    
    setState(() {
      _loadingCategories.add(categoryName);
    });
    
    try {
      // 初始化服务器列表
      final servers = category.serverList.map((serverItem) {
        return ExtendedServerItem(
          serverItem: serverItem,
          isLoading: true,
        );
      }).toList();
      
      _categoryServersMap[categoryName] = servers;
      if (mounted) setState(() {});
      
      // 并行获取所有服务器信息
      final futures = <Future<void>>[];
      
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        final address = server.serverItem.address ?? server.serverItem.serverAddress;
        if (address == null) continue;
        
        futures.add(_fetchServerInfo(categoryName, i, address));
      }
      
      await Future.wait(futures);
    } catch (e) {
      LogService.e('加载分类 $categoryName 服务器失败: $e', e);
    } finally {
      if (mounted) {
        setState(() {
          _loadingCategories.remove(categoryName);
        });
      }
    }
  }

  /// 获取单个服务器信息（包含 mapInfo、mapRuntime、ping）
  Future<void> _fetchServerInfo(
    String categoryName,
    int index,
    String address,
  ) async {
    final serverApi = ServerApi();
    
    try {
      final parts = address.split(':');
      if (parts.length != 2) return;
      
      final ip = parts[0];
      final port = int.parse(parts[1]);
      final info = await SourceServerService.getServerInfo(ip, port, timeout: 10000);
      
      if (!mounted) return;
      
      final servers = _categoryServersMap[categoryName];
      if (servers == null || index >= servers.length) return;
      
      final existingServer = servers[index];
      final isCustomServer = existingServer.serverItem.isCustom;
      
      if (info != null) {
        final newMap = info.map;
        final oldMap = existingServer.serverData?.map;
        final mapChanged = oldMap != null && oldMap != newMap && newMap != 'graphics_settings';
        
        final serverData = ServerInfo(
          hostName: info.name,
          map: info.map,
          players: info.players,
          maxPlayers: info.maxPlayers,
          gameType: info.gameType,
          pingLatency: info.ping,
        );
        
        // 更新服务器数据
        servers[index] = existingServer.copyWith(
          serverData: serverData,
          isLoading: false,
          hasError: false,
          consecutiveFailures: 0,
          isOffline: false,
          // 换图时清除旧的地图数据
          mapInfo: mapChanged ? null : existingServer.mapInfo,
          mapRuntime: mapChanged ? null : existingServer.mapRuntime,
        );
        
        if (mounted) setState(() {});
        
        // 异步获取额外数据（不阻塞主流程）
        final isValidMap = newMap != 'graphics_settings';
        if (isValidMap) {
          // 获取地图背景图
          final needFetchMapInfo = mapChanged ||
              existingServer.mapInfo == null ||
              (oldMap != null && oldMap != newMap);
          if (needFetchMapInfo) {
            _fetchMapInfoAsync(categoryName, index, address, newMap, serverApi);
          }
          
          // 自定义服务器不获取 mapRuntime
          if (!isCustomServer && (mapChanged || existingServer.mapRuntime == null)) {
            _fetchMapRuntimeAsync(categoryName, index, address, newMap, serverApi);
          }
        }
        
        // 获取 ping（如果还没有）
        if (existingServer.pingInfo == null) {
          _fetchPingAsync(categoryName, index, address, ip);
        }
      } else {
        // 查询失败，增加失败计数
        final newFailureCount = existingServer.consecutiveFailures + 1;
        final isNowOffline = newFailureCount >= 3;
        
        servers[index] = existingServer.copyWith(
          isLoading: false,
          hasError: true,
          consecutiveFailures: newFailureCount,
          isOffline: isNowOffline,
          clearServerData: isNowOffline,
          clearMapRuntime: isNowOffline,
          clearMapInfo: isNowOffline,
        );
        
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      
      final servers = _categoryServersMap[categoryName];
      if (servers == null || index >= servers.length) return;
      
      final existingServer = servers[index];
      final newFailureCount = existingServer.consecutiveFailures + 1;
      final isNowOffline = newFailureCount >= 3;
      
      servers[index] = existingServer.copyWith(
        isLoading: false,
        hasError: true,
        consecutiveFailures: newFailureCount,
        isOffline: isNowOffline,
        clearServerData: isNowOffline,
        clearMapRuntime: isNowOffline,
        clearMapInfo: isNowOffline,
      );
      
      if (mounted) setState(() {});
    }
  }

  /// 异步获取地图背景图
  void _fetchMapInfoAsync(
    String categoryName,
    int index,
    String address,
    String mapName,
    ServerApi serverApi,
  ) {
    serverApi.getMapInfo(mapName).then((mapInfo) {
      if (!mounted) return;
      
      final servers = _categoryServersMap[categoryName];
      if (servers == null || index >= servers.length) return;
      
      // 确认地址匹配
      final currentAddress = servers[index].serverItem.address ??
          servers[index].serverItem.serverAddress;
      if (currentAddress != address) return;
      
      servers[index] = servers[index].copyWith(mapInfo: mapInfo);
      setState(() {});
    }).catchError((e) {
      LogService.w('获取地图信息失败 ($mapName): $e');
    });
  }

  /// 异步获取地图运行时间
  void _fetchMapRuntimeAsync(
    String categoryName,
    int index,
    String address,
    String mapName,
    ServerApi serverApi,
  ) {
    serverApi.getMapRuntime(address, mapName).then((runtime) {
      if (!mounted) return;
      
      final servers = _categoryServersMap[categoryName];
      if (servers == null || index >= servers.length) return;
      
      final currentAddress = servers[index].serverItem.address ??
          servers[index].serverItem.serverAddress;
      if (currentAddress != address) return;
      
      servers[index] = servers[index].copyWith(
        mapRuntime: runtime,
        mapRuntimeLastFetched: DateTime.now().millisecondsSinceEpoch,
        mapRuntimeError: false,
      );
      setState(() {});
    }).catchError((e) {
      if (!mounted) return;
      
      final servers = _categoryServersMap[categoryName];
      if (servers == null || index >= servers.length) return;
      
      servers[index] = servers[index].copyWith(mapRuntimeError: true);
      setState(() {});
    });
  }

  /// 异步获取 ping
  void _fetchPingAsync(
    String categoryName,
    int index,
    String address,
    String ip,
  ) async {
    try {
      // forceCodepage: true 解决 Windows 中文系统编码问题
      // encoding: Utf8Codec(allowMalformed: true) 忽略非 UTF-8 字符
      final ping = Ping(
        ip,
        count: 2,
        timeout: 2,
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
        final servers = _categoryServersMap[categoryName];
        if (servers == null || index >= servers.length) return;
        
        final currentAddress = servers[index].serverItem.address ??
            servers[index].serverItem.serverAddress;
        if (currentAddress != address) return;
        
        // 计算平均延迟
        final avgMs = results.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/
            results.length;
        
        final pingInfo = ServerPingInfo(
          ip: ip,
          ping: avgMs,
          pingStatus: 'success',
        );
        servers[index] = servers[index].copyWith(pingInfo: pingInfo);
        setState(() {});
      }
    } catch (e) {
      LogService.w('获取 ping 失败 ($ip): $e');
    }
  }

  /// 切换分类选中状态
  void _toggleCategory(String categoryName) {
    setState(() {
      if (_selectedCategories.contains(categoryName)) {
        // 至少保留一个选中
        if (_selectedCategories.length > 1) {
          _selectedCategories.remove(categoryName);
        }
      } else {
        _selectedCategories.add(categoryName);
        // 如果该分类还没有数据，加载它
        if (!_categoryServersMap.containsKey(categoryName)) {
          _loadNewCategory(categoryName);
        }
      }
    });
    // 保存选中状态
    _saveSelectedCategories();
  }

  /// 加载新选中的分类
  void _loadNewCategory(String categoryName) {
    final state = context.read<ServerBloc>().state;
    final category = state.serverCategories.firstWhere(
      (c) => c.modelName == categoryName,
      orElse: () => ServerCategory(serverList: []),
    );
    
    if (category.serverList.isNotEmpty) {
      _loadCategoryServers(category);
    }
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    final state = context.read<ServerBloc>().state;
    final allCategoryNames = state.serverCategories
        .where((c) => c.modelName != null)
        .map((c) => c.modelName!)
        .toSet();
    
    setState(() {
      if (_selectedCategories.length == allCategoryNames.length) {
        // 当前全选，变为只选第一个
        _selectedCategories = {allCategoryNames.first};
      } else {
        // 全选
        _selectedCategories = allCategoryNames;
        // 加载所有未加载的分类
        for (final name in allCategoryNames) {
          if (!_categoryServersMap.containsKey(name)) {
            _loadNewCategory(name);
          }
        }
      }
    });
    // 保存选中状态
    _saveSelectedCategories();
  }

  /// 手动刷新
  void _manualRefresh() {
    if (_isRefreshing) return;
    _countdown = _kImmersiveRefreshInterval;
    _refreshAllSelectedCategories();
  }

  /// 截图并复制到剪切板
  Future<void> _takeScreenshot() async {
    if (_isTakingScreenshot) return;
    
    setState(() {
      _isTakingScreenshot = true;
    });
    
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final categoryServers = _getSelectedCategoryServers();
      
      if (categoryServers.isEmpty) {
        LogService.w('截图失败：没有服务器数据');
        return;
      }
      
      // 获取当前的 ServerBloc
      final serverBloc = context.read<ServerBloc>();
      
      // 计算截图内容的尺寸
      final screenWidth = MediaQuery.of(context).size.width;
      // 每行2个卡片，每个卡片高度140（136+4border），加上间距和标题
      final totalCategories = categoryServers.length;
      // 标题区域 ~42 + 24间距 + 每个分类(标题36 + 12间距 + 卡片行数*(140+16) + 24间距)
      final cardRows = categoryServers.fold<int>(0, (sum, c) => sum + (c.servers.length / 2).ceil());
      final estimatedHeight = 42.0 + 24 + totalCategories * (36.0 + 12 + 24) + cardRows * (140.0 + 16) + 48;
      
      // 限制最大高度，防止服务器过多时生成超大图片导致内存溢出
      // pixelRatio=2.0 时，8000px 逻辑高度 = 16000px 实际像素高度，已经足够
      const maxHeight = 8000.0;
      final clampedHeight = estimatedHeight.clamp(200.0, maxHeight);
      
      // 使用 captureFromWidget 替代 captureFromLongWidget
      // captureFromLongWidget 的测量阶段使用 _MeasurementView（普通 RenderBox），
      // 没有 View ancestor，导致 SingleChildScrollView 等 widget 调用 View.of() 失败
      final pngBytes = await _screenshotController.captureFromWidget(
        InheritedTheme.captureAll(
          context,
          BlocProvider.value(
            value: serverBloc,
            child: Material(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
              child: _buildFullContentForScreenshot(isDark, categoryServers),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
        context: context,
        targetSize: Size(screenWidth, clampedHeight),
      );

      // 复制到剪切板
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        LogService.w('截图失败：剪切板不可用');
        return;
      }

      final item = DataWriterItem();
      item.add(Formats.png(pngBytes));
      await clipboard.write([item]);

      // 显示预览
      setState(() {
        _screenshotPreview = pngBytes;
        _showScreenshotPreview = true;
      });

      // 3秒后隐藏预览并释放内存
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showScreenshotPreview = false;
            _screenshotPreview = null;
          });
        }
      });

      LogService.i('截图已复制到剪切板');
    } catch (e) {
      LogService.e('截图失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTakingScreenshot = false;
        });
      }
    }
  }
  
  /// 构建用于截图的完整内容（不使用 ListView，直接展开所有内容）
  Widget _buildFullContentForScreenshot(bool isDark, List<_CategoryServers> categoryServers) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '沉浸模式',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '共 ${categoryServers.fold<int>(0, (sum, c) => sum + c.servers.length)} 个服务器',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 所有分类的服务器
          ...categoryServers.map((item) => _buildCategorySectionForScreenshot(isDark, item)),
        ],
      ),
    );
  }
  
  /// 构建用于截图的分类区块
  Widget _buildCategorySectionForScreenshot(bool isDark, _CategoryServers item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              if (item.category.isCustom) ...[
                const Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                item.category.modelName ?? '未知分类',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.servers.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 服务器网格 - 使用原始 ServerCard
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: item.servers.map((server) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 48 - 16) / 2,
              child: ServerCard(
                server: server,
                disableHoverEffect: true,
                onTap: () {},
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 获取所有选中分类的服务器
  List<_CategoryServers> _getSelectedCategoryServers() {
    final state = context.read<ServerBloc>().state;
    final result = <_CategoryServers>[];
    
    for (final categoryName in _selectedCategories) {
      final category = state.serverCategories.firstWhere(
        (c) => c.modelName == categoryName,
        orElse: () => ServerCategory(serverList: []),
      );
      
      final servers = _categoryServersMap[categoryName] ?? [];
      if (category.modelName != null) {
        result.add(_CategoryServers(
          category: category,
          servers: servers,
          isLoading: _loadingCategories.contains(categoryName),
        ));
      }
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF3F4F6),
            body: Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: _buildServerList(isDark),
                ),
              ],
            ),
          ),
          // 截图预览
          _buildScreenshotPreview(isDark),
        ],
      ),
    );
  }

  /// 构建截图预览
  Widget _buildScreenshotPreview(bool isDark) {
    // 限制预览最大高度，防止溢出屏幕
    final maxPreviewHeight = MediaQuery.of(context).size.height - 80;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: 16,
      right: _showScreenshotPreview ? 16 : -220,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showScreenshotPreview ? 1.0 : 0.0,
        child: Container(
          width: 200,
          constraints: BoxConstraints(maxHeight: maxPreviewHeight),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已复制到剪切板',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
              // 预览图（限制高度，可滚动查看）
              if (_screenshotPreview != null)
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                    child: Image.memory(
                      _screenshotPreview!,
                      width: 200,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final categories = state.serverCategories.where((c) => c.modelName != null).toList();
        final totalServers = _categoryServersMap.values.fold<int>(0, (s, v) => s + v.length);

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 左侧：图标 + 统计
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_selectedCategories.length} 个分类 · $totalServers 台服务器',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 16),
              // 分隔线
              Container(
                width: 1,
                height: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              const SizedBox(width: 16),
              // 筛选按钮
              _buildFilterButton(isDark, categories),
              const Spacer(),
              // 右侧操作区
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildRefreshIndicator(isDark),
                  const SizedBox(width: 10),
                  _buildScreenshotButton(isDark),
                  const SizedBox(width: 14),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 14),
                  _buildExitButton(isDark),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(bool isDark, List<ServerCategory> categories) {
    final selectedCount = _selectedCategories.length;
    final totalCount = categories.length;
    final isFiltered = selectedCount < totalCount;

    return Tooltip(
      message: '筛选分类',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFilterDialog(isDark, categories),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isFiltered
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFiltered
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: isFiltered
                      ? const Color(0xFF3B82F6)
                      : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                ),
                const SizedBox(width: 6),
                Text(
                  isFiltered ? '$selectedCount / $totalCount 分类' : '全部分类',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isFiltered
                        ? const Color(0xFF3B82F6)
                        : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                  ),
                ),
                if (isFiltered) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(bool isDark, List<ServerCategory> categories) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allSelected = _selectedCategories.length == categories.length;

            void toggle(String name) {
              setState(() => _toggleCategory(name));
              setDialogState(() {});
            }

            void toggleAll() {
              setState(() => _toggleSelectAll());
              setDialogState(() {});
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 360,
                constraints: const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '筛选分类',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          const Spacer(),
                          // 全选/取消全选
                          GestureDetector(
                            onTap: toggleAll,
                            child: Text(
                              allSelected ? '取消全选' : '全选',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                    ),
                    // 分类列表
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: categories.length,
                        itemBuilder: (_, i) {
                          final cat = categories[i];
                          final name = cat.modelName!;
                          final isSelected = _selectedCategories.contains(name);
                          final isLoading = _loadingCategories.contains(name);
                          final isCustom = cat.isCustom;
                          final activeColor = isCustom
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6);

                          return InkWell(
                            onTap: () => toggle(name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  // 勾选框
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? activeColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isSelected
                                            ? activeColor
                                            : (isDark
                                                ? Colors.white24
                                                : const Color(0xFFD1D5DB)),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded,
                                            size: 13, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  if (isCustom) ...[
                                    Icon(Icons.folder_outlined,
                                        size: 15, color: activeColor),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF1F2937))
                                            : (isDark
                                                ? Colors.white60
                                                : const Color(0xFF6B7280)),
                                      ),
                                    ),
                                  ),
                                  if (isLoading)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation(
                                            activeColor),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScreenshotButton(bool isDark) {
    return Tooltip(
      message: '截图并复制到剪切板',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isTakingScreenshot ? null : _takeScreenshot,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: _isTakingScreenshot
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        isDark ? Colors.white70 : const Color(0xFF6B7280),
                      ),
                    ),
                  )
                : Icon(
                    Icons.photo_camera_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton(bool isDark) {
    return Tooltip(
      message: '退出',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _close,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshIndicator(bool isDark) {
    final progress = _isRefreshing ? 0.0 : _countdown / _kImmersiveRefreshInterval;
    
    return MouseRegion(
      cursor: _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isRefreshing ? null : _manualRefresh,
        child: Tooltip(
          message: _isRefreshing ? '刷新中...' : '点击立即刷新',
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: _isRefreshing
                      ? const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF0A020)),
                        )
                      : CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF18A058)),
                        ),
                ),
                Text(
                  _isRefreshing ? '...' : '$_countdown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerList(bool isDark) {
    final categoryServers = _getSelectedCategoryServers();

    if (categoryServers.isEmpty) {
      return _buildEmptyState(isDark);
    }

    // 检查是否所有分类都在加载中且没有数据
    final allLoading = categoryServers.every((c) => c.isLoading && c.servers.isEmpty);
    if (allLoading) {
      return _buildLoadingList(isDark);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: categoryServers.length,
      itemBuilder: (context, index) {
        final item = categoryServers[index];
        return _buildCategorySection(isDark, item);
      },
    );
  }

  Widget _buildCategorySection(bool isDark, _CategoryServers item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              if (item.category.isCustom) ...[
                const Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                item.category.modelName ?? '未知分类',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.servers.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ),
              if (item.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        // 服务器卡片（一行两个）
        if (item.servers.isEmpty && item.isLoading)
          _buildCategoryLoadingRow()
        else
          _buildServerGrid(isDark, item.servers),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryLoadingRow() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: ServerCardSkeleton()),
          SizedBox(width: 16),
          Expanded(child: ServerCardSkeleton()),
        ],
      ),
    );
  }

  Widget _buildServerGrid(bool isDark, List<ExtendedServerItem> servers) {
    final rows = <Widget>[];
    for (var i = 0; i < servers.length; i += 2) {
      final first = servers[i];
      final second = i + 1 < servers.length ? servers[i + 1] : null;
      
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildServerCard(first)),
              const SizedBox(width: 16),
              Expanded(
                child: second != null
                    ? _buildServerCard(second)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildServerCard(ExtendedServerItem server) {
    final showSkeleton = server.serverData == null && server.isLoading;
    
    return showSkeleton
        ? const ServerCardSkeleton()
        : ServerCard(
            key: ValueKey('immersive_${server.serverItem.address}'),
            server: server,
            onTap: () => _showServerDetails(server),
          );
  }

  Widget _buildLoadingList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(child: ServerCardSkeleton()),
                SizedBox(width: 16),
                Expanded(child: ServerCardSkeleton()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: isDark ? Colors.white24 : const Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无服务器',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请选择分类查看服务器',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类服务器数据
class _CategoryServers {
  final ServerCategory category;
  final List<ExtendedServerItem> servers;
  final bool isLoading;

  _CategoryServers({
    required this.category,
    required this.servers,
    this.isLoading = false,
  });
}
