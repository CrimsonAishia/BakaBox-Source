import 'dart:async';
import 'dart:convert';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../core/api/score_api.dart';
import '../../../core/api/server_api.dart';
import '../../../core/bloc/server/server_bloc.dart';
import '../../../core/bloc/server/server_state.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/realtime/realtime_score_updates_channel.dart';
import '../../../core/services/network_mode_service.dart';
import '../../../core/services/source_server_service.dart';
import '../../../core/services/status_window_service.dart';
import '../../../core/utils/log_service.dart';
import '../../../core/utils/map_runtime_utils.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/map_background.dart';
import '../common_scroll_indicator.dart';
import '../queue/queue_window.dart';
import 'server_card.dart';
import 'server_card_skeleton.dart';
import 'server_detail_dialog.dart';
import '../../../core/constants/app_colors.dart';

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
          return FadeTransition(opacity: animation, child: child);
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

  // 比分查询频率限制（60秒）
  DateTime? _lastScoreFetchTime;
  static const Duration _scoreFetchInterval = Duration(seconds: 60);

  // 截图预览相关
  Uint8List? _screenshotPreview;
  bool _showScreenshotPreview = false;
  bool _isTakingScreenshot = false;

  // 滚动指示器状态
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  // 简约模式（表格视图）
  bool _isCompactMode = false;

  // 监听 StatusWindowService 状态（用于简约模式操作按钮状态更新）
  final StatusWindowService _statusService = StatusWindowService();
  StreamSubscription<OperationState>? _statusSubscription;

  /// 弱网模式切换监听（运行时切换时启停定时器）
  StreamSubscription<bool>? _networkModeSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    // 监听操作状态变化，更新简约模式的按钮状态
    _statusSubscription = _statusService.stateStream.listen((_) {
      if (mounted && _isCompactMode) {
        setState(() {});
      }
    });

    // 弱网开关切换：开启 → 立即停定时器；关闭 → 重启定时器
    _networkModeSubscription = NetworkModeService.instance.changes.listen((
      weakNetwork,
    ) {
      if (!mounted) return;
      if (weakNetwork) {
        _refreshTimer?.cancel();
        _refreshTimer = null;
        setState(() {});
      } else {
        _startRefreshTimer();
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initializeData();
    });
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canUp = position.pixels > 0;
    final canDown = position.pixels < position.maxScrollExtent;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  void _initializeData() {
    final state = context.read<ServerBloc>().state;
    final defaultCategoryNames = state.serverCategories
        .where((c) => c.modelName != null && !c.isCustom)
        .map((c) => c.modelName!)
        .toSet();
    final fallbackCategoryNames = state.serverCategories
        .where((c) => c.modelName != null)
        .map((c) => c.modelName!)
        .toSet();

    // 从存储中恢复选中的分类
    final savedCategories = _loadSavedCategories(state);

    if (savedCategories.isNotEmpty) {
      // 使用保存的分类
      _selectedCategories = savedCategories;

      // 复用当前分类的服务器数据（如果在选中列表中）
      if (state.selectedCategory?.modelName != null &&
          savedCategories.contains(state.selectedCategory!.modelName!)) {
        _categoryServersMap[state.selectedCategory!.modelName!] = List.from(
          state.servers,
        );
      }

      // 加载其他选中但还没有数据的分类
      for (final categoryName in savedCategories) {
        if (!_categoryServersMap.containsKey(categoryName)) {
          _loadNewCategory(categoryName);
        }
      }
    } else {
      // 首次进入默认全选非自定义分类；若不存在则回退到全部分类
      _selectedCategories = defaultCategoryNames.isNotEmpty
          ? defaultCategoryNames
          : fallbackCategoryNames;

      if (state.selectedCategory?.modelName != null) {
        _categoryServersMap[state.selectedCategory!.modelName!] = List.from(
          state.servers,
        );
      }

      for (final categoryName in _selectedCategories) {
        if (!_categoryServersMap.containsKey(categoryName)) {
          _loadNewCategory(categoryName);
        }
      }
    }

    setState(() {});
    _startRefreshTimer();

    // 初始化完成后，获取所有已加载分类的比分数据
    _fetchBatchScores();
  }

  /// 从存储中加载保存的分类（过滤掉不存在的分类）
  Set<String> _loadSavedCategories(ServerState state) {
    final savedList = StorageUtils.getStringList(
      _kImmersiveSelectedCategoriesKey,
    );
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
    // 弱网模式下不启动倒计时自动刷新，仅由用户手动触发
    if (NetworkModeService.instance.weakNetwork) {
      LogService.d('[ImmersiveMode] 弱网模式，跳过自动刷新');
      return;
    }
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
    _statusSubscription?.cancel();
    _networkModeSubscription?.cancel();
    _refreshTimer?.cancel();
    _scrollController.removeListener(_updateScrollIndicators);
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

    // 刷新完成后，批量获取比分数据
    if (mounted) {
      await _fetchBatchScores();
    }

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  /// 批量获取所有选中分类服务器的比分数据
  Future<void> _fetchBatchScores() async {
    // 频率限制：距上次查询不到 60 秒则跳过
    if (_lastScoreFetchTime != null &&
        DateTime.now().difference(_lastScoreFetchTime!) < _scoreFetchInterval) {
      LogService.d(
        '[沉浸模式] 批量比分查询跳过: 距上次查询不到 ${_scoreFetchInterval.inSeconds} 秒',
      );
      return;
    }

    try {
      // 收集所有服务器地址
      final addresses = <String>[];
      for (final categoryName in _selectedCategories) {
        final servers = _categoryServersMap[categoryName];
        if (servers == null) continue;

        for (final server in servers) {
          final address =
              server.serverItem.address ?? server.serverItem.serverAddress;
          if (address != null && address.isNotEmpty) {
            addresses.add(address);
          }
        }
      }

      if (addresses.isEmpty) return;

      // 比分数据来源：
      // - 正常模式：读取 score.updates WS 频道在 ServerBloc 启动时缓存的最新 snapshot
      // - 弱网模式：WS 已停，改为通过 HTTP 批量查询接口获取
      final scores = <String, dynamic>{};
      if (NetworkModeService.instance.weakNetwork) {
        final httpScores = await ScoreApi().fetchScoresBatch(addresses);
        if (!mounted) return;
        httpScores.forEach((address, score) {
          if (score.dataQuality == 'unknown') return;
          scores[address] = score;
        });
      } else {
        final snapshot = RealtimeScoreUpdatesChannel().latestSnapshot;
        for (final address in addresses) {
          final score = snapshot[address];
          if (score != null) scores[address] = score;
        }
      }

      if (scores.isEmpty || !mounted) return;

      // 将比分数据合并到对应的服务器
      for (final categoryName in _selectedCategories) {
        final servers = _categoryServersMap[categoryName];
        if (servers == null) continue;

        for (int i = 0; i < servers.length; i++) {
          final server = servers[i];
          final address =
              server.serverItem.address ?? server.serverItem.serverAddress;
          if (address == null) continue;

          final score = scores[address];
          if (score == null || score.ctScore == null || score.tScore == null) {
            continue;
          }

          // 创建 TeamScores 并更新服务器
          final teamScores = TeamScores(
            ctScore: score.ctScore,
            tScore: score.tScore,
            dataQuality: score.dataQuality,
          );

          servers[i] = server.copyWith(teamScores: teamScores);
        }
      }

      if (mounted) {
        _lastScoreFetchTime = DateTime.now();
        setState(() {});
        LogService.d('[沉浸模式] 批量比分查询完成: ${scores.length} 个服务器有比分数据');
      }
    } catch (e) {
      // 静默失败，不影响主流程
      LogService.w('[沉浸模式] 批量比分查询失败: $e');
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
          return ExtendedServerItem(serverItem: serverItem, isLoading: true);
        }).toList();
        _categoryServersMap[categoryName] = servers;
      }

      // 并行获取所有服务器信息
      final futures = <Future<void>>[];

      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        final address =
            server.serverItem.address ?? server.serverItem.serverAddress;
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
        return ExtendedServerItem(serverItem: serverItem, isLoading: true);
      }).toList();

      _categoryServersMap[categoryName] = servers;
      if (mounted) setState(() {});

      // 并行获取所有服务器信息
      final futures = <Future<void>>[];

      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        final address =
            server.serverItem.address ?? server.serverItem.serverAddress;
        if (address == null) continue;

        futures.add(_fetchServerInfo(categoryName, i, address));
      }

      await Future.wait(futures);

      // 加载完成后，获取该分类的比分数据
      if (mounted) {
        await _fetchCategoryScores(categoryName);
      }
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

  /// 获取单个分类服务器的比分数据
  Future<void> _fetchCategoryScores(String categoryName) async {
    try {
      final servers = _categoryServersMap[categoryName];
      if (servers == null || servers.isEmpty) return;

      // 收集该分类的服务器地址
      final addresses = <String>[];
      for (final server in servers) {
        final address =
            server.serverItem.address ?? server.serverItem.serverAddress;
        if (address != null && address.isNotEmpty) {
          addresses.add(address);
        }
      }

      if (addresses.isEmpty) return;

      // 比分数据来源：
      // - 正常模式：读取 score.updates WS 频道的 snapshot
      // - 弱网模式：WS 已停，改为通过 HTTP 批量查询接口获取
      final scores = <String, dynamic>{};
      if (NetworkModeService.instance.weakNetwork) {
        final httpScores = await ScoreApi().fetchScoresBatch(addresses);
        if (!mounted) return;
        httpScores.forEach((address, score) {
          if (score.dataQuality == 'unknown') return;
          scores[address] = score;
        });
      } else {
        final snapshot = RealtimeScoreUpdatesChannel().latestSnapshot;
        for (final address in addresses) {
          final score = snapshot[address];
          if (score != null) scores[address] = score;
        }
      }

      if (scores.isEmpty || !mounted) return;

      // 将比分数据合并到对应的服务器
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        final address =
            server.serverItem.address ?? server.serverItem.serverAddress;
        if (address == null) continue;

        final score = scores[address];
        if (score == null || score.ctScore == null || score.tScore == null) {
          continue;
        }

        // 创建 TeamScores 并更新服务器
        final teamScores = TeamScores(
          ctScore: score.ctScore,
          tScore: score.tScore,
          dataQuality: score.dataQuality,
        );

        servers[i] = server.copyWith(teamScores: teamScores);
      }

      if (mounted) {
        setState(() {});
        LogService.d('[沉浸模式] 分类 $categoryName 比分查询完成: ${scores.length} 个结果');
      }
    } catch (e) {
      LogService.w('[沉浸模式] 分类 $categoryName 比分查询失败: $e');
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
      final info = await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: 5000,
      );

      if (!mounted) return;

      final servers = _categoryServersMap[categoryName];
      if (servers == null || index >= servers.length) return;

      final existingServer = servers[index];
      final isCustomServer = existingServer.serverItem.isCustom;

      if (info != null) {
        final newMap = info.map;
        final oldMap = existingServer.serverData?.map;
        final mapChanged =
            oldMap != null && oldMap != newMap && newMap != 'graphics_settings';

        final serverData = ServerInfo(
          hostName: info.name,
          map: info.map,
          players: info.players,
          maxPlayers: info.maxPlayers,
          gameType: info.gameType,
          pingLatency: info.ping,
          appId: info.appId,
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
          final needFetchMapInfo =
              mapChanged ||
              existingServer.mapInfo == null ||
              (oldMap != null && oldMap != newMap);
          if (needFetchMapInfo) {
            _fetchMapInfoAsync(categoryName, index, address, newMap, serverApi);
          }

          // 自定义服务器不获取 mapRuntime
          if (!isCustomServer &&
              (mapChanged || existingServer.mapRuntime == null)) {
            _fetchMapRuntimeAsync(
              categoryName,
              index,
              address,
              newMap,
              serverApi,
            );
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
    serverApi
        .getMapInfo(mapName)
        .then((mapInfo) {
          if (!mounted) return;

          final servers = _categoryServersMap[categoryName];
          if (servers == null || index >= servers.length) return;

          // 确认地址匹配
          final currentAddress =
              servers[index].serverItem.address ??
              servers[index].serverItem.serverAddress;
          if (currentAddress != address) return;

          servers[index] = servers[index].copyWith(mapInfo: mapInfo);
          setState(() {});
        })
        .catchError((e) {
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
    serverApi
        .getMapRuntime(address, mapName)
        .then((runtime) {
          if (!mounted) return;

          final servers = _categoryServersMap[categoryName];
          if (servers == null || index >= servers.length) return;

          final currentAddress =
              servers[index].serverItem.address ??
              servers[index].serverItem.serverAddress;
          if (currentAddress != address) return;

          servers[index] = servers[index].copyWith(
            mapRuntime: runtime,
            mapRuntimeLastFetched: DateTime.now().millisecondsSinceEpoch,
            mapRuntimeError: false,
          );
          setState(() {});
        })
        .catchError((e) {
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

        final currentAddress =
            servers[index].serverItem.address ??
            servers[index].serverItem.serverAddress;
        if (currentAddress != address) return;

        // 计算平均延迟
        final avgMs =
            results.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/
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
      final cardRows = categoryServers.fold<int>(
        0,
        (sum, c) => sum + (c.servers.length / 2).ceil(),
      );
      final estimatedHeight =
          42.0 +
          24 +
          totalCategories * (36.0 + 12 + 24) +
          cardRows * (140.0 + 16) +
          48;

      // 限制最大高度，防止服务器过多时生成超大图片导致内存溢出
      // pixelRatio=2.0 时，8000px 逻辑高度 = 16000px 实际像素高度，已经足够
      const maxHeight = 8000.0;
      final clampedHeight = estimatedHeight.clamp(200.0, maxHeight);

      // 使用 captureFromWidget 替代 captureFromLongWidget
      // captureFromLongWidget 的测量阶段使用 _MeasurementView（普通 RenderBox），
      // 没有 View ancestor，导致 SingleChildScrollView 等 widget 调用 View.of() 失败
      final pngBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: InheritedTheme.captureAll(
            context,
            BlocProvider.value(
              value: serverBloc,
              child: Material(
                color: isDark
                    ? AppColors.slate900
                    : AppColors.gray100,
                child: _buildFullContentForScreenshot(isDark, categoryServers),
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 300),
        pixelRatio: 2.0,
        context: context,
        targetSize: Size(screenWidth, clampedHeight),
      );

      // 将 PNG 转换为压缩的 JPEG（质量 85%，清晰且体积小）
      final jpegBytes = await _compressToJpeg(pngBytes, quality: 85);

      // 复制到剪切板
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        LogService.w('截图失败：剪切板不可用');
        return;
      }

      final item = DataWriterItem();
      // 使用 JPEG 格式
      item.add(Formats.jpeg(jpegBytes));
      await clipboard.write([item]);

      // 显示预览（使用压缩后的图片）
      setState(() {
        _screenshotPreview = jpegBytes;
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

      LogService.i(
        '截图已复制到剪切板 (JPEG ${(jpegBytes.length / 1024).toStringAsFixed(1)}KB)',
      );
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

  /// 将 PNG 图片压缩为 JPEG
  Future<Uint8List> _compressToJpeg(
    Uint8List pngBytes, {
    int quality = 85,
  }) async {
    // 使用 image 包解码 PNG
    final image = img.decodePng(pngBytes);
    if (image == null) {
      throw Exception('无法解码 PNG 图片');
    }

    // 编码为 JPEG，quality 范围 0-100
    final jpegBytes = img.encodeJpg(image, quality: quality);

    return Uint8List.fromList(jpegBytes);
  }

  /// 构建用于截图的完整内容（不使用 ListView，直接展开所有内容，不显示 header）
  Widget _buildFullContentForScreenshot(
    bool isDark,
    List<_CategoryServers> categoryServers,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 所有分类的服务器（不显示 header）
          ...categoryServers.map(
            (item) => _buildCategorySectionForScreenshot(isDark, item),
          ),
        ],
      ),
    );
  }

  /// 构建用于截图的分类区块
  Widget _buildCategorySectionForScreenshot(
    bool isDark,
    _CategoryServers item,
  ) {
    // 计算该分类的在线人数
    int categoryPlayers = 0;
    for (final server in item.servers) {
      categoryPlayers += server.serverData?.players ?? 0;
    }

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
                  color: AppColors.emerald500,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                item.category.modelName ?? '未知分类',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray800,
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
                  '${item.servers.length} 服务器 · $categoryPlayers 人',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 服务器网格 - 使用静态卡片避免动画导致的 layer 问题
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: item.servers.map((server) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 48 - 16) / 2,
              child: _buildStaticServerCard(isDark, server),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 构建静态服务器卡片（用于截图，不包含动画，完整复刻 ServerCard 样式）
  Widget _buildStaticServerCard(bool isDark, ExtendedServerItem server) {
    final data = server.serverData;
    final address =
        server.serverItem.address ??
        server.serverItem.serverAddress ??
        '未知地址';
    final hostName = server.serverItem.getDisplayName(data?.hostName);
    final mapName = data?.map ?? '未知地图';
    final mapLabel = server.mapInfo?.mapLabel;
    final chineseName = (mapLabel?.isNotEmpty == true) ? mapLabel : null;
    final displayMapName = chineseName != null
        ? '$chineseName ($mapName)'
        : mapName;
    final players = data?.players ?? 0;
    final maxPlayers = data?.maxPlayers ?? 0;

    // 运行时间相关
    final mapRuntime = server.mapRuntime;
    final fetchedAt = server.mapRuntimeLastFetched;
    final hasRuntimeError = server.mapRuntimeError;
    final isCustomServer = server.serverItem.isCustom;

    // 比分相关
    final teamScores = server.teamScores;
    final hasValidScore =
        teamScores?.ctScore != null &&
        teamScores?.tScore != null &&
        (teamScores!.ctScore! > 0 || teamScores.tScore! > 0);

    // 是否显示运行时间（与原卡片逻辑一致）
    // API 数据源的自定义服务器由第三方接口提供地图运行时间，需要显示。
    final isApiSourced = server.serverItem.dataSourceMode == 'api';
    final showRuntime =
        data?.map != null &&
        (!isCustomServer || (isApiSourced && mapRuntime != null));

    return Container(
      height: 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 地图背景（复用 MapBackground 组件，确保与正常卡片一致）
            Positioned.fill(
              child: MapBackground(
                mapName: mapName,
                imageUrl: server.mapInfo?.mapUrl,
              ),
            ),
            // 渐变遮罩（与原卡片一致：从上到下）
            Positioned.fill(
              child: Container(
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
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧信息
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 服务器名称（与原卡片完全一致的样式）
                          Text(
                            hostName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                                Shadow(color: Colors.black, blurRadius: 8),
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                ),
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(-1, -1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          // 地图名称
                          Row(
                            children: [
                              const Text(
                                '地图：',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
                              Expanded(
                                child: Text(
                                  displayMapName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 地址（截图不显示 ping）
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 右侧玩家数量和运行时间
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStaticPlayerCount(
                        players,
                        maxPlayers,
                        server.queueCount,
                        server.warmupCount,
                      ),
                      if (showRuntime) ...[
                        const SizedBox(height: 6),
                        _buildStaticRuntimeInfo(
                          mapRuntime: mapRuntime,
                          fetchedAt: fetchedAt,
                          hasError: hasRuntimeError,
                          mapName: mapName,
                          teamScores: teamScores,
                          hasValidScore: hasValidScore,
                          weeklyOccurrences: mapRuntime?.weeklyOccurrences,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建静态玩家数量显示
  Widget _buildStaticPlayerCount(
    int players,
    int maxPlayers,
    int queueCount,
    int warmupCount,
  ) {
    Color primaryColor;
    Color bgColor;

    if (players >= maxPlayers && maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336);
      bgColor = const Color(0xFFFEEAEA);
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      primaryColor = AppColors.orange;
      bgColor = const Color(0xFFFFF9E6);
    } else {
      primaryColor = AppColors.primary;
      bgColor = Colors.white;
    }

    final int extraCount = queueCount + warmupCount;

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
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _buildStaticExtraCount(
                queueCount,
                warmupCount,
                extraCount,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '/',
              style: TextStyle(
                color: primaryColor.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          Text(
            '$maxPlayers',
            style: TextStyle(
              color: primaryColor.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticExtraCount(
    int queueCount,
    int warmupCount,
    int extraCount,
  ) {
    if (queueCount > 0 && warmupCount > 0) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFF44336), AppColors.amber500], // 红色到黄色渐变
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
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
      return Text(
        '+$extraCount',
        style: const TextStyle(
          color: Color(0xFFF44336), // 红色 - 挤服
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      );
    } else {
      return Text(
        '+$extraCount',
        style: const TextStyle(
          color: AppColors.amber500, // 黄色 - 暖服
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      );
    }
  }

  /// 构建静态运行时间信息（用于截图）
  Widget _buildStaticRuntimeInfo({
    required MapRuntimeData? mapRuntime,
    required int? fetchedAt,
    required bool hasError,
    required String mapName,
    required TeamScores? teamScores,
    required bool hasValidScore,
    required int? weeklyOccurrences,
  }) {
    // 使用 MapRuntimeUtils 计算运行时间显示
    final displayText = MapRuntimeUtils.getRuntimeDisplay(
      mapRuntime: mapRuntime,
      fetchedAt: fetchedAt,
      isLoading: mapRuntime == null && !hasError,
      hasError: hasError,
    );

    Color iconColor = AppColors.gray500;
    Color textColor = AppColors.gray500;
    Color bgColor = Colors.white.withValues(alpha: 0.95);
    Color borderColor = Colors.white.withValues(alpha: 0.3);

    if (hasError) {
      iconColor = const Color(0xFFF0A020);
      textColor = const Color(0xFFF0A020);
      bgColor = const Color(0xFFF0A020).withValues(alpha: 0.15);
      borderColor = const Color(0xFFF0A020).withValues(alpha: 0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
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
          // 比分显示或周出现次数
          if (hasValidScore) ...[
            const SizedBox(height: 2),
            _buildStaticScoreDisplay(
              teamScores!.ctScore!,
              teamScores.tScore!,
              mapName,
              dataQuality: teamScores.dataQuality,
            ),
          ] else if (weeklyOccurrences != null) ...[
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
        ],
      ),
    );
  }

  /// 构建静态比分显示（用于截图）
  Widget _buildStaticScoreDisplay(
    int ctScore,
    int tScore,
    String mapName, {
    String? dataQuality,
  }) {
    final isZombie = _isZombieMap(mapName);
    final isUnknown = dataQuality == 'unknown';

    final Color leftColor;
    final Color rightColor;
    final Color iconColor;

    if (isUnknown) {
      leftColor = AppColors.gray400;
      rightColor = AppColors.gray400;
      iconColor = AppColors.gray400;
    } else if (isZombie) {
      leftColor = AppColors.green500;
      rightColor = AppColors.red500;
      iconColor = AppColors.gray500;
    } else {
      leftColor = AppColors.blue500;
      rightColor = const Color(0xFFEAB308);
      iconColor = AppColors.gray500;
    }

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

  /// 检测是否为僵尸地图
  bool _isZombieMap(String? mapName) {
    if (mapName == null || mapName.isEmpty) return false;
    final lowerName = mapName.toLowerCase();
    return lowerName.startsWith('ze_') || lowerName.startsWith('zm_');
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
        result.add(
          _CategoryServers(
            category: category,
            servers: servers,
            isLoading: _loadingCategories.contains(categoryName),
          ),
        );
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
                ? AppColors.slate900
                : AppColors.gray100,
            body: Column(
              children: [
                _buildHeader(isDark),
                Expanded(child: _buildServerList(isDark)),
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
            color: isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.green500.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green500.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.green500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已复制到剪切板',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              // 预览图（限制高度，可滚动查看）
              if (_screenshotPreview != null)
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
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
        final categories = state.serverCategories
            .where((c) => c.modelName != null)
            .toList();
        final totalServers = _categoryServersMap.values.fold<int>(
          0,
          (s, v) => s + v.length,
        );

        // 计算总在线人数
        int totalPlayers = 0;
        for (final servers in _categoryServersMap.values) {
          for (final server in servers) {
            totalPlayers += server.serverData?.players ?? 0;
          }
        }

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.slate700
                    : AppColors.gray200,
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
                      AppColors.blue500.withValues(alpha: 0.15),
                      AppColors.violet500.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.blue500,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_selectedCategories.length} 个分类 · $totalServers 台服务器 · $totalPlayers 人在线',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.gray700,
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
                  _buildViewModeToggle(isDark),
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
    final accentColor = isFiltered
        ? AppColors.blue500
        : (isDark ? Colors.white70 : const Color(0xFF4B5563));

    return Tooltip(
      message: '点击这里切换分类显示',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFilterDialog(isDark, categories),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isFiltered
                  ? AppColors.blue500.withValues(alpha: 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFiltered
                    ? AppColors.blue500.withValues(alpha: 0.4)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_right_alt_rounded,
                  size: 18,
                  color: accentColor,
                ),
                const SizedBox(width: 2),
                Icon(Icons.tune_rounded, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFiltered ? '$selectedCount / $totalCount 分类' : '全部分类',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      '点击切换显示分类',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: isDark
                            ? Colors.white38
                            : AppColors.gray400,
                      ),
                    ),
                  ],
                ),
                if (isFiltered) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.blue500,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: accentColor,
                ),
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
                  color: isDark ? AppColors.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.slate700
                        : AppColors.gray200,
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
                            color: AppColors.blue500,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '筛选分类',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.gray800,
                                ),
                              ),
                              Text(
                                '默认全选，可按需取消不想看的分类',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.gray400,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // 全选/取消全选
                          GestureDetector(
                            onTap: toggleAll,
                            child: Text(
                              allSelected ? '取消全选' : '全选',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.blue500,
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
                              color: isDark
                                  ? Colors.white38
                                  : AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.slate700
                          : AppColors.gray200,
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
                              ? AppColors.emerald500
                              : AppColors.blue500;

                          return InkWell(
                            onTap: () => toggle(name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
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
                                                  : AppColors.gray300),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  if (isCustom) ...[
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 15,
                                      color: activeColor,
                                    ),
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
                                                  : AppColors.gray800)
                                            : (isDark
                                                  ? Colors.white60
                                                  : AppColors.gray500),
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
                                          activeColor,
                                        ),
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

  /// 构建视图模式切换按钮
  Widget _buildViewModeToggle(bool isDark) {
    return Tooltip(
      message: _isCompactMode ? '切换到卡片视图' : '切换到简约视图',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isCompactMode = !_isCompactMode),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isCompactMode
                  ? AppColors.blue500.withValues(alpha: 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isCompactMode
                    ? AppColors.blue500.withValues(alpha: 0.4)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            child: Icon(
              _isCompactMode
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
              size: 20,
              color: _isCompactMode
                  ? AppColors.blue500
                  : (isDark ? Colors.white70 : AppColors.gray500),
            ),
          ),
        ),
      ),
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
                        isDark ? Colors.white70 : AppColors.gray500,
                      ),
                    ),
                  )
                : Icon(
                    Icons.photo_camera_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : AppColors.gray500,
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
              color: isDark ? Colors.white70 : AppColors.gray500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshIndicator(bool isDark) {
    final isWeakNetwork = NetworkModeService.instance.weakNetwork;
    final progress = _isRefreshing
        ? 0.0
        : _countdown / _kImmersiveRefreshInterval;

    return MouseRegion(
      cursor: _isRefreshing
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isRefreshing ? null : _manualRefresh,
        child: Tooltip(
          message: _isRefreshing
              ? '刷新中...'
              : (isWeakNetwork ? '弱网模式：点击手动刷新' : '点击立即刷新'),
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
                    valueColor: AlwaysStoppedAnimation(
                      Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                // 进度环（弱网下不显示倒计时进度）
                SizedBox(
                  width: 38,
                  height: 38,
                  child: _isRefreshing
                      ? const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF0A020)),
                        )
                      : (isWeakNetwork
                            ? const SizedBox.shrink()
                            : CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF18A058),
                                ),
                              )),
                ),
                // 中心：弱网下显示刷新图标，正常模式显示倒数秒数
                _isRefreshing
                    ? const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF0A020),
                        ),
                      )
                    : isWeakNetwork
                        ? const Icon(
                            Icons.refresh,
                            size: 18,
                            color: Color(0xFFF0A020),
                          )
                        : Text(
                            '$_countdown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.gray700,
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
    final allLoading = categoryServers.every(
      (c) => c.isLoading && c.servers.isEmpty,
    );
    if (allLoading) {
      return _buildLoadingList(isDark);
    }

    // 延迟检查滚动状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: categoryServers.length,
          itemBuilder: (context, index) {
            final item = categoryServers[index];
            // 根据模式选择不同的渲染方式
            return _isCompactMode
                ? _buildCompactCategorySection(isDark, item)
                : _buildCategorySection(isDark, item);
          },
        ),
        // 顶部滚动指示器
        if (_canScrollUp)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(
              isTop: true,
              color: isDark ? Colors.white : AppColors.gray500,
            ),
          ),
        // 底部滚动指示器
        if (_canScrollDown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CommonScrollIndicator(
              isTop: false,
              color: isDark ? Colors.white : AppColors.gray500,
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySection(bool isDark, _CategoryServers item) {
    // 计算该分类的在线人数
    int categoryPlayers = 0;
    for (final server in item.servers) {
      categoryPlayers += server.serverData?.players ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              if (item.category.isCustom) ...[
                const Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: AppColors.emerald500,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                item.category.modelName ?? '未知分类',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.servers.length} 服务器 · $categoryPlayers 人',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ),
              if (item.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue500),
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryLoadingRow() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: ServerCardSkeleton()),
          SizedBox(width: 12),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildServerCard(first)),
              const SizedBox(width: 12),
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
              color: isDark ? Colors.white : AppColors.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请选择分类查看服务器',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }


  /// 构建简约模式的分类区块
  Widget _buildCompactCategorySection(bool isDark, _CategoryServers item) {
    // 计算该分类的在线人数
    int categoryPlayers = 0;
    for (final server in item.servers) {
      categoryPlayers += server.serverData?.players ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              if (item.category.isCustom) ...[
                const Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: AppColors.emerald500,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                item.category.modelName ?? '未知分类',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.gray800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.servers.length} 服务器 · $categoryPlayers 人',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ),
              if (item.isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue500),
                  ),
                ),
              ],
            ],
          ),
        ),
        // 表格
        if (item.servers.isEmpty && item.isLoading)
          _buildCompactLoadingRows(isDark, item.category.isCustom)
        else
          _buildCompactTable(isDark, item.servers, item.category.isCustom),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 构建简约模式加载占位
  Widget _buildCompactLoadingRows(bool isDark, bool isCustomCategory) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.gray200,
        ),
      ),
      child: Column(
        children: List.generate(
          3,
          (index) =>
              _buildCompactLoadingRow(isDark, index == 2, isCustomCategory),
        ),
      ),
    );
  }

  Widget _buildCompactLoadingRow(
    bool isDark,
    bool isLast,
    bool isCustomCategory,
  ) {
    final placeholderColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.slate700
                      : AppColors.gray200,
                ),
              ),
      ),
      child: Row(
        children: [
          // 状态指示器占位
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: placeholderColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // 服务器名称占位
          Expanded(
            flex: 3,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 地图占位
          Expanded(
            flex: 2,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 人数占位
          SizedBox(
            width: 70,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // 时间占位
          SizedBox(
            width: 50,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // 延迟占位
          SizedBox(
            width: 55,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // 比分占位（非自定义分类）
          if (!isCustomCategory)
            SizedBox(
              width: 70,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          // 操作按钮占位
          const SizedBox(width: 100),
        ],
      ),
    );
  }

  /// 构建简约模式表格
  Widget _buildCompactTable(
    bool isDark,
    List<ExtendedServerItem> servers,
    bool isCustomCategory,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.gray200,
        ),
      ),
      child: Column(
        children: [
          // 表头
          _buildCompactTableHeader(isDark, isCustomCategory),
          // 数据行
          ...servers.asMap().entries.map((entry) {
            final index = entry.key;
            final server = entry.value;
            final isLast = index == servers.length - 1;
            return _buildCompactTableRow(
              isDark,
              server,
              isLast,
              isCustomCategory,
            );
          }),
        ],
      ),
    );
  }

  /// 构建表头
  Widget _buildCompactTableHeader(bool isDark, bool isCustomCategory) {
    final headerColor = isDark ? Colors.white38 : AppColors.gray400;
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.gray200,
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20), // 状态指示器占位
          Expanded(
            flex: 3,
            child: Text(
              '服务器名称',
              style: headerStyle.copyWith(color: headerColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('地图', style: headerStyle.copyWith(color: headerColor)),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '人数',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '时间',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              '延迟',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
          if (!isCustomCategory)
            SizedBox(
              width: 70,
              child: Text(
                '比分',
                style: headerStyle.copyWith(color: headerColor),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: 100,
            child: Text(
              '操作',
              style: headerStyle.copyWith(color: headerColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建数据行
  Widget _buildCompactTableRow(
    bool isDark,
    ExtendedServerItem server,
    bool isLast,
    bool isCustomCategory,
  ) {
    final data = server.serverData;
    final isOffline = server.isOffline;
    final isLoading = server.isLoading && data == null;
    final address =
        server.serverItem.address ?? server.serverItem.serverAddress;

    // 服务器名称
    final hostName = server.serverItem.getDisplayName(data?.hostName);

    // 地图名称 - 与卡片模式保持一致：有中文名时 "中文名 (英文名)"，否则只显示英文名
    final mapName = data?.map ?? '-';
    final mapLabel = server.mapInfo?.mapLabel;
    final chineseName = (mapLabel?.isNotEmpty == true) ? mapLabel : null;
    final displayMap = chineseName != null
        ? '$chineseName ($mapName)'
        : mapName;

    // 人数
    final players = data?.players ?? 0;
    final maxPlayers = data?.maxPlayers ?? 0;
    final loadRatio = maxPlayers > 0 ? players / maxPlayers : 0.0;

    // 运行时间
    final runtimeText = _getCompactRuntimeText(server);

    // 状态颜色
    Color statusColor;
    if (isOffline) {
      statusColor = AppColors.gray400;
    } else if (loadRatio >= 1.0) {
      statusColor = const Color(0xFFF44336);
    } else if (loadRatio >= 0.8) {
      statusColor = AppColors.orange;
    } else {
      statusColor = AppColors.green500;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOffline ? null : () => _showServerDetails(server),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.slate700
                          : AppColors.gray200,
                    ),
                  ),
          ),
          child: Row(
            children: [
              // 状态指示器
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isLoading ? Colors.transparent : statusColor,
                  shape: BoxShape.circle,
                  border: isLoading
                      ? Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1.5,
                        )
                      : null,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation(
                            isDark ? Colors.white38 : AppColors.gray400,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // 服务器名称（过长时水平滚动）
              Expanded(
                flex: 3,
                child: _CompactMarqueeText(
                  text: hostName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isOffline
                        ? (isDark ? Colors.white38 : AppColors.gray400)
                        : (isDark ? Colors.white : AppColors.gray800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 地图（过长时水平滚动）
              Expanded(
                flex: 2,
                child: _CompactMarqueeText(
                  text: displayMap,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOffline
                        ? (isDark ? Colors.white24 : AppColors.gray300)
                        : (isDark ? Colors.white60 : AppColors.gray500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 人数
              SizedBox(
                width: 70,
                child: _buildCompactPlayerCount(
                  isDark,
                  players,
                  maxPlayers,
                  isOffline,
                ),
              ),
              // 运行时间
              SizedBox(
                width: 50,
                child: Text(
                  runtimeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOffline
                        ? (isDark ? Colors.white24 : AppColors.gray300)
                        : (isDark ? Colors.white54 : AppColors.gray500),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 延迟
              SizedBox(width: 55, child: _buildCompactPing(isDark, server)),
              // 比分（非自定义分类才显示）
              if (!isCustomCategory)
                SizedBox(
                  width: 70,
                  child: _buildCompactScoreColumn(isDark, server),
                ),
              // 操作按钮
              SizedBox(
                width: 100,
                child: _buildCompactActionButtons(
                  isDark,
                  server,
                  address,
                  isOffline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建简约模式人数显示（与卡片模式颜色一致）
  Widget _buildCompactPlayerCount(
    bool isDark,
    int players,
    int maxPlayers,
    bool isOffline,
  ) {
    if (isOffline) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white24 : AppColors.gray300,
        ),
        textAlign: TextAlign.center,
      );
    }

    // 颜色逻辑与卡片模式一致
    Color primaryColor;
    if (players >= maxPlayers && maxPlayers > 0) {
      primaryColor = const Color(0xFFF44336); // 满人：红色
    } else if (players >= maxPlayers * 0.8 && maxPlayers > 0) {
      primaryColor = AppColors.orange; // 80%以上：橙色
    } else {
      primaryColor = AppColors.primary; // 正常：蓝色
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$players',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          TextSpan(
            text: '/$maxPlayers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white38 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取简约模式运行时间文本（与卡片模式单位一致）
  String _getCompactRuntimeText(ExtendedServerItem server) {
    if (server.isOffline) return '-';
    // API 数据源的自定义服务器有第三方接口提供的运行时间，照常显示；
    // 其余自定义服务器（A2S 模式）不显示运行时间。
    final isApiSourced = server.serverItem.dataSourceMode == 'api';
    if (server.serverItem.isCustom && !isApiSourced) return '-';

    final mapRuntime = server.mapRuntime;

    if (mapRuntime == null) {
      // API 服务器没有运行时间数据（接口未提供 map_changed_at）时直接显示 '-'，
      // 避免一直停留在加载态。官方服务器仍走异步获取，显示加载/错误态。
      if (isApiSourced) return '-';
      return server.mapRuntimeError ? '?' : '...';
    }

    // 使用 MapRuntimeUtils 计算实际运行时间并格式化（与卡片模式一致）
    final currentRuntime = MapRuntimeUtils.calculateCurrentRuntime(
      mapRuntime,
      server.mapRuntimeLastFetched,
    );

    if (currentRuntime <= 0) return '0分';
    return MapRuntimeUtils.formatRuntime(currentRuntime);
  }

  /// 构建简约模式比分列（独立显示）
  Widget _buildCompactScoreColumn(bool isDark, ExtendedServerItem server) {
    if (server.isOffline) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white24 : AppColors.gray300,
        ),
        textAlign: TextAlign.center,
      );
    }

    // 检查是否有有效比分
    final teamScores = server.teamScores;
    final hasValidScore =
        teamScores != null &&
        teamScores.ctScore != null &&
        teamScores.tScore != null &&
        (teamScores.ctScore! > 0 || teamScores.tScore! > 0);

    if (!hasValidScore) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : AppColors.gray400,
        ),
        textAlign: TextAlign.center,
      );
    }

    return _buildCompactScore(isDark, server, teamScores);
  }

  /// 构建简约模式操作按钮
  Widget _buildCompactActionButtons(
    bool isDark,
    ExtendedServerItem server,
    String? address,
    bool isOffline,
  ) {
    if (address == null || isOffline) {
      return const SizedBox.shrink();
    }

    final globalState = _statusService.state;

    // 检查挤服状态
    final isQueueing =
        globalState.type == OperationType.queueing &&
        globalState.status == OperationStatus.running;
    final isCurrentServerQueueing =
        isQueueing && globalState.serverAddress == address;
    final isOtherServerQueueing =
        isQueueing && globalState.serverAddress != address;

    // 检查连接状态
    final isConnecting =
        globalState.type == OperationType.connecting &&
        globalState.status == OperationStatus.running &&
        globalState.serverAddress == address;
    final isOtherServerBusy =
        (globalState.type == OperationType.connecting ||
            globalState.type == OperationType.launching) &&
        globalState.status == OperationStatus.running &&
        globalState.serverAddress != address;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 加入按钮
        _buildCompactIconButton(
          icon: Icons.play_arrow_rounded,
          tooltip: isConnecting ? '连接中...' : '加入',
          color: AppColors.blue500,
          isDisabled: isConnecting || isOtherServerBusy,
          isLoading: isConnecting,
          onTap: () => _handleCompactConnect(server, address),
        ),
        const SizedBox(width: 6),
        // 挤服按钮
        _buildCompactIconButton(
          icon: MdiIcons.accountGroup,
          tooltip: isCurrentServerQueueing ? '挤服中' : '挤服',
          color: isCurrentServerQueueing
              ? AppColors.green500
              : const Color(0xFFFF6E6E),
          isDisabled: isOtherServerQueueing,
          isActive: isCurrentServerQueueing,
          onTap: () => _handleCompactQueue(
            server,
            address,
            isCurrentServerQueueing,
            isOtherServerQueueing,
          ),
        ),
      ],
    );
  }

  /// 构建简约模式图标按钮
  Widget _buildCompactIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
    bool isLoading = false,
    bool isActive = false,
  }) {
    final effectiveColor = isDisabled ? color.withValues(alpha: 0.4) : color;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive
                  ? effectiveColor.withValues(alpha: 0.15)
                  : effectiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isActive
                    ? effectiveColor.withValues(alpha: 0.5)
                    : effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(effectiveColor),
                    ),
                  )
                : Icon(icon, size: 16, color: effectiveColor),
          ),
        ),
      ),
    );
  }

  /// 处理简约模式加入服务器
  Future<void> _handleCompactConnect(
    ExtendedServerItem server,
    String address,
  ) async {
    final serverName = server.serverItem.getDisplayName(
      server.serverData?.hostName,
    );
    final mapInfo = server.mapInfo;

    await _statusService.connectToServer(
      serverAddress: address,
      serverName: serverName,
      mapName: server.serverData?.map,
      mapNameCn: mapInfo?.mapLabel,
      mapBackground: mapInfo?.mapUrl,
      gameType: server.serverData?.gameType,
      appId: server.serverData?.appId,
    );

    if (mounted) {
      final state = _statusService.state;
      if (state.status == OperationStatus.failed && state.message != null) {
        ToastUtils.showError(context, state.message!);
      }
      setState(() {});
    }
  }

  /// 处理简约模式挤服
  void _handleCompactQueue(
    ExtendedServerItem server,
    String address,
    bool isCurrentServerQueueing,
    bool isOtherServerQueueing,
  ) {
    if (isOtherServerQueueing) {
      ToastUtils.showWarning(context, '正在挤服中，无法切换服务器');
      return;
    }

    // 打开挤服对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: QueueWindow(
          serverAddress: address,
          isCustomServer: server.serverItem.isCustom,
          initialServerInfo: server.serverData,
          initialMapInfo: server.mapInfo,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  /// 构建简约模式比分显示
  Widget _buildCompactScore(
    bool isDark,
    ExtendedServerItem server,
    TeamScores scores,
  ) {
    final mapName = server.serverData?.map ?? '';
    final isZombie = _isZombieMap(mapName);
    final isUnknown = scores.dataQuality == 'unknown';

    final Color leftColor;
    final Color rightColor;

    if (isUnknown) {
      leftColor = AppColors.gray400;
      rightColor = AppColors.gray400;
    } else if (isZombie) {
      leftColor = AppColors.green500;
      rightColor = AppColors.red500;
    } else {
      leftColor = AppColors.blue500;
      rightColor = const Color(0xFFEAB308);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${scores.ctScore}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: leftColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : AppColors.gray400,
            ),
          ),
        ),
        Text(
          '${scores.tScore}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: rightColor,
          ),
        ),
      ],
    );
  }

  /// 构建简约模式延迟显示
  Widget _buildCompactPing(bool isDark, ExtendedServerItem server) {
    final ping = server.pingInfo?.ping ?? server.serverData?.pingLatency;

    if (ping == null) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : AppColors.gray400,
        ),
        textAlign: TextAlign.center,
      );
    }

    Color pingColor;
    if (ping < 50) {
      pingColor = AppColors.green500;
    } else if (ping < 100) {
      pingColor = const Color(0xFFEAB308);
    } else {
      pingColor = const Color(0xFFF44336);
    }

    return Text(
      '${ping}ms',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: pingColor,
      ),
      textAlign: TextAlign.center,
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

/// 滚动文本组件 - 文本过长时自动水平滚动
class _CompactMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _CompactMarqueeText({required this.text, required this.style});

  @override
  State<_CompactMarqueeText> createState() => _CompactMarqueeTextState();
}

class _CompactMarqueeTextState extends State<_CompactMarqueeText> {
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
  void didUpdateWidget(_CompactMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController != null && _scrollController!.hasClients) {
        try {
          _scrollController!.jumpTo(0);
        } catch (_) {}
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
    final viewportWidth = renderObject is RenderBox
        ? renderObject.size.width
        : 0.0;
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

      try {
        await _scrollController!.animateTo(
          targetOffset,
          duration: Duration(
            milliseconds: (targetOffset * 30).toInt().clamp(1000, 5000),
          ),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;

      try {
        await _scrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } catch (_) {
        break;
      }

      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
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
