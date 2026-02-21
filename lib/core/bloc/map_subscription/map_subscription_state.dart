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

  /// 可用分类列表
  final List<String> availableCategories;

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

  /// 通知冷却时间（秒）
  final int cooldownSeconds;

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
    this.availableCategories = const [],
    this.isLoadingCategories = false,
    this.isTtsModelDownloaded = false,
    this.ttsDownloadStatus = TtsDownloadStatus.idle,
    this.ttsDownloadProgress = 0.0,
    this.ttsVolume = 0.8,
    this.ttsSpeed = 1.0,
    this.selectedTtsModelId = 'vits-zh-aishell3',
    this.cooldownSeconds = 60,
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
    List<String>? availableCategories,
    bool? isLoadingCategories,
    bool? isTtsModelDownloaded,
    TtsDownloadStatus? ttsDownloadStatus,
    double? ttsDownloadProgress,
    double? ttsVolume,
    double? ttsSpeed,
    String? selectedTtsModelId,
    int? cooldownSeconds,
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
      availableCategories: availableCategories ?? this.availableCategories,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isTtsModelDownloaded: isTtsModelDownloaded ?? this.isTtsModelDownloaded,
      ttsDownloadStatus: ttsDownloadStatus ?? this.ttsDownloadStatus,
      ttsDownloadProgress: ttsDownloadProgress ?? this.ttsDownloadProgress,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      selectedTtsModelId: selectedTtsModelId ?? this.selectedTtsModelId,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
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
    availableCategories,
    isLoadingCategories,
    isTtsModelDownloaded,
    ttsDownloadStatus,
    ttsDownloadProgress,
    ttsVolume,
    ttsSpeed,
    selectedTtsModelId,
    cooldownSeconds,
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
