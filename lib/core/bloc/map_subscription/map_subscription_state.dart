part of 'map_subscription_bloc.dart';

/// 地图订阅状态
class MapSubscriptionState extends Equatable {
  /// 订阅列表
  final List<MapSubscription> subscriptions;

  /// 全局开关
  final bool isEnabled;

  /// 通知开关
  final bool isNotificationEnabled;

  /// 全局 TTS 开关
  final bool isTtsEnabled;

  /// 是否加载中
  final bool isLoading;

  /// 地图搜索结果
  final List<MapSearchResult> searchResults;

  /// 是否正在搜索
  final bool isSearching;

  /// 搜索结果总数
  final int searchTotalCount;

  /// 当前搜索页码
  final int searchPageIndex;

  /// 是否还有更多搜索结果
  final bool hasMoreSearchResults;

  /// 可用分类列表
  final List<String> availableCategories;

  /// 全局分类范围（空=全部分类，包括新增的）
  final List<String> globalCategories;

  /// 是否正在加载分类
  final bool isLoadingCategories;

  /// TTS 模型是否已下载（当前选中的）
  final bool isTtsModelDownloaded;

  /// TTS 模型下载状态
  final TtsDownloadStatus ttsDownloadStatus;

  /// TTS 模型下载进度
  final double ttsDownloadProgress;

  /// TTS 音量
  final double ttsVolume;

  /// TTS 语速
  final double ttsSpeed;

  /// 当前选中的 TTS 模型 ID
  final String selectedTtsModelId;

  /// 通知冷却时间（秒）- 同时也是监控刷新频率
  final int cooldownSeconds;

  /// TTS 测试播报中
  final bool isTtsTesting;

  /// TTS 测试阶段：generating（生成中）、playing（播报中）
  final String? ttsTestingPhase;

  /// 错误信息
  final String? error;

  const MapSubscriptionState({
    this.subscriptions = const [],
    this.isEnabled = false,
    this.isNotificationEnabled = true,
    this.isTtsEnabled = false,
    this.isLoading = false,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchTotalCount = 0,
    this.searchPageIndex = 1,
    this.hasMoreSearchResults = false,
    this.availableCategories = const [],
    this.globalCategories = const [],
    this.isLoadingCategories = false,
    this.isTtsModelDownloaded = false,
    this.ttsDownloadStatus = TtsDownloadStatus.idle,
    this.ttsDownloadProgress = 0.0,
    this.ttsVolume = 0.8,
    this.ttsSpeed = 1.0,
    this.selectedTtsModelId = 'vits-zh-aishell3',
    this.cooldownSeconds = 15,
    this.isTtsTesting = false,
    this.ttsTestingPhase,
    this.error,
  });

  MapSubscriptionState copyWith({
    List<MapSubscription>? subscriptions,
    bool? isEnabled,
    bool? isNotificationEnabled,
    bool? isTtsEnabled,
    bool? isLoading,
    List<MapSearchResult>? searchResults,
    bool? isSearching,
    int? searchTotalCount,
    int? searchPageIndex,
    bool? hasMoreSearchResults,
    List<String>? availableCategories,
    List<String>? globalCategories,
    bool? isLoadingCategories,
    bool? isTtsModelDownloaded,
    TtsDownloadStatus? ttsDownloadStatus,
    double? ttsDownloadProgress,
    double? ttsVolume,
    double? ttsSpeed,
    String? selectedTtsModelId,
    int? cooldownSeconds,
    bool? isTtsTesting,
    String? ttsTestingPhase,
    String? error,
  }) {
    return MapSubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      isEnabled: isEnabled ?? this.isEnabled,
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
      isTtsEnabled: isTtsEnabled ?? this.isTtsEnabled,
      isLoading: isLoading ?? this.isLoading,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchTotalCount: searchTotalCount ?? this.searchTotalCount,
      searchPageIndex: searchPageIndex ?? this.searchPageIndex,
      hasMoreSearchResults: hasMoreSearchResults ?? this.hasMoreSearchResults,
      availableCategories: availableCategories ?? this.availableCategories,
      globalCategories: globalCategories ?? this.globalCategories,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isTtsModelDownloaded: isTtsModelDownloaded ?? this.isTtsModelDownloaded,
      ttsDownloadStatus: ttsDownloadStatus ?? this.ttsDownloadStatus,
      ttsDownloadProgress: ttsDownloadProgress ?? this.ttsDownloadProgress,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      selectedTtsModelId: selectedTtsModelId ?? this.selectedTtsModelId,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      isTtsTesting: isTtsTesting ?? this.isTtsTesting,
      ttsTestingPhase: ttsTestingPhase,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    subscriptions,
    isEnabled,
    isNotificationEnabled,
    isTtsEnabled,
    isLoading,
    searchResults,
    isSearching,
    searchTotalCount,
    searchPageIndex,
    hasMoreSearchResults,
    availableCategories,
    globalCategories,
    isLoadingCategories,
    isTtsModelDownloaded,
    ttsDownloadStatus,
    ttsDownloadProgress,
    ttsVolume,
    ttsSpeed,
    selectedTtsModelId,
    cooldownSeconds,
    isTtsTesting,
    ttsTestingPhase,
    error,
  ];
}

/// 地图搜索结果
class MapSearchResult extends Equatable {
  final String mapName;
  final String mapLabel;
  final String? mapBackground;
  final bool isSubscribed;

  const MapSearchResult({
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.isSubscribed = false,
  });

  @override
  List<Object?> get props => [mapName, mapLabel, mapBackground, isSubscribed];
}
