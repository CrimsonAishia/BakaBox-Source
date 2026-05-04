import 'package:equatable/equatable.dart';
import '../../models/server_models.dart';

/// 加载阶段枚举
enum LoadingPhase {
  idle, // 空闲状态
  loadingA2S, // 正在获取 A2S 数据
  completed, // A2S 加载完成（可以隐藏遮罩）
}

class ServerState extends Equatable {
  final List<ServerCategory> serverCategories;
  final bool isLoading;
  final String? error;
  final String? successMessage; // 操作成功消息
  final ServerCategory? selectedCategory;
  final List<ExtendedServerItem> servers;
  final bool isLoadingServers;
  final bool isPaused;
  final Map<String, int> categoryOnlineCounts;
  final Set<String> loadingCategories;
  final bool isLoadingOnlineCounts;
  final bool hasEverLoadedOnlineCounts;
  final int countdownResetKey; // 倒计时重置信号，每次需要重置时递增
  final bool isCountdownActive; // 倒计时是否激活
  final Set<String> refreshingMaps; // 正在刷新缓存的服务器地址集合
  final int selectedTabIndex; // 当前选中的 tab 索引（0=默认分类，1=自定义分类）
  final bool needCsgoLegacy; // 是否需要安装 CSGO Legacy
  final bool needManualLaunch; // 是否需要手动启动 CSGO
  final DateTime? lastRefreshTime; // 最后一次刷新时间
  final LoadingPhase loadingPhase; // 当前加载阶段
  final DateTime? loadingStartTime; // 加载开始时间（用于计算倒计时）
  /// 待应用的新分类列表（定时检测到变化后暂存，等用户确认后再应用）
  final List<ServerCategory>? pendingCategories;

  const ServerState({
    this.serverCategories = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.selectedCategory,
    this.servers = const [],
    this.isLoadingServers = false,
    this.isPaused = false,
    this.categoryOnlineCounts = const {},
    this.loadingCategories = const {},
    this.isLoadingOnlineCounts = false,
    this.hasEverLoadedOnlineCounts = false,
    this.countdownResetKey = 0,
    this.isCountdownActive = false,
    this.refreshingMaps = const {},
    this.selectedTabIndex = 0,
    this.needCsgoLegacy = false,
    this.needManualLaunch = false,
    this.lastRefreshTime,
    this.loadingPhase = LoadingPhase.idle,
    this.loadingStartTime,
    this.pendingCategories,
  });

  ServerState copyWith({
    List<ServerCategory>? serverCategories,
    bool? isLoading,
    String? error,
    String? successMessage,
    ServerCategory? selectedCategory,
    bool clearSelectedCategory = false,
    List<ExtendedServerItem>? servers,
    bool? isLoadingServers,
    bool? isPaused,
    Map<String, int>? categoryOnlineCounts,
    Set<String>? loadingCategories,
    bool? isLoadingOnlineCounts,
    bool? hasEverLoadedOnlineCounts,
    int? countdownResetKey,
    bool? isCountdownActive,
    Set<String>? refreshingMaps,
    int? selectedTabIndex,
    bool? needCsgoLegacy,
    bool? needManualLaunch,
    DateTime? lastRefreshTime,
    LoadingPhase? loadingPhase,
    DateTime? loadingStartTime,
    Object? pendingCategories = _sentinel,
    bool clearPendingCategories = false,
  }) {
    return ServerState(
      serverCategories: serverCategories ?? this.serverCategories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      servers: servers ?? this.servers,
      isLoadingServers: isLoadingServers ?? this.isLoadingServers,
      isPaused: isPaused ?? this.isPaused,
      categoryOnlineCounts: categoryOnlineCounts ?? this.categoryOnlineCounts,
      loadingCategories: loadingCategories ?? this.loadingCategories,
      isLoadingOnlineCounts:
          isLoadingOnlineCounts ?? this.isLoadingOnlineCounts,
      hasEverLoadedOnlineCounts:
          hasEverLoadedOnlineCounts ?? this.hasEverLoadedOnlineCounts,
      countdownResetKey: countdownResetKey ?? this.countdownResetKey,
      isCountdownActive: isCountdownActive ?? this.isCountdownActive,
      refreshingMaps: refreshingMaps ?? this.refreshingMaps,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      needCsgoLegacy: needCsgoLegacy ?? this.needCsgoLegacy,
      needManualLaunch: needManualLaunch ?? this.needManualLaunch,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
      loadingPhase: loadingPhase ?? this.loadingPhase,
      loadingStartTime: loadingStartTime ?? this.loadingStartTime,
      pendingCategories: clearPendingCategories
          ? null
          : identical(pendingCategories, _sentinel)
          ? this.pendingCategories
          : pendingCategories as List<ServerCategory>?,
    );
  }

  bool isCategoryLoading(String categoryName) =>
      loadingCategories.contains(categoryName);
  int getCategoryOnlineCount(String categoryName) =>
      categoryOnlineCounts[categoryName] ?? 0;
  bool hasCategoryOnlineCount(String categoryName) =>
      categoryOnlineCounts.containsKey(categoryName);
  bool isMapRefreshing(String address) => refreshingMaps.contains(address);

  /// 获取当前 tab 下的分类列表
  List<ServerCategory> get filteredCategories {
    if (selectedTabIndex == 0) {
      // 默认分类 tab：显示所有 API 分类
      return serverCategories.where((c) => !c.isCustom).toList();
    } else {
      // 自定义分类 tab：显示所有自定义分类
      return serverCategories.where((c) => c.isCustom).toList();
    }
  }

  @override
  List<Object?> get props => [
    serverCategories,
    isLoading,
    error,
    successMessage,
    selectedCategory,
    servers,
    isLoadingServers,
    isPaused,
    categoryOnlineCounts,
    loadingCategories,
    isLoadingOnlineCounts,
    hasEverLoadedOnlineCounts,
    countdownResetKey,
    isCountdownActive,
    refreshingMaps,
    selectedTabIndex,
    needCsgoLegacy,
    needManualLaunch,
    lastRefreshTime,
    loadingPhase,
    loadingStartTime,
    pendingCategories,
  ];
}

const Object _sentinel = Object();
