import 'package:equatable/equatable.dart';
import '../../../../core/models/server_models.dart';

class MapManageState extends Equatable {
  final bool isLoading;
  final bool isDeleting;
  final String? error;

  // 本地地图列表
  final List<LocalMapItem> localMaps;

  // 选中的地图 ID 集合（用于批量删除）
  final Set<String> selectedMapIds;

  // Steam 运行状态
  final bool isSteamRunning;

  // 搜索关键字
  final String searchQuery;
  // 过滤类型
  final String filterType;

  // 当前激活/预览的地图 ID
  final String? previewMapId;

  // 当前预览的地图详细信息（从 API 获取的译名和背景）
  final MapData? previewMapInfo;

  const MapManageState({
    this.isLoading = false,
    this.isDeleting = false,
    this.error,
    this.localMaps = const [],
    this.selectedMapIds = const {},
    this.isSteamRunning = false,
    this.searchQuery = '',
    this.filterType = '',
    this.previewMapId,
    this.previewMapInfo,
  });

  MapManageState copyWith({
    bool? isLoading,
    bool? isDeleting,
    String? error,
    bool clearError = false,
    List<LocalMapItem>? localMaps,
    Set<String>? selectedMapIds,
    bool? isSteamRunning,
    String? searchQuery,
    String? filterType,
    String? previewMapId,
    MapData? previewMapInfo,
    bool clearPreview = false,
    bool clearPreviewMapInfo = false,
  }) {
    return MapManageState(
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      localMaps: localMaps ?? this.localMaps,
      selectedMapIds: selectedMapIds ?? this.selectedMapIds,
      isSteamRunning: isSteamRunning ?? this.isSteamRunning,
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: filterType ?? this.filterType,
      previewMapId: clearPreview ? null : (previewMapId ?? this.previewMapId),
      previewMapInfo: clearPreview || clearPreviewMapInfo
          ? null
          : (previewMapInfo ?? this.previewMapInfo),
    );
  }

  /// 过滤和排序后的地图列表
  List<LocalMapItem> get displayMaps {
    var filtered = localMaps;

    // 按前缀过滤
    if (filterType.isNotEmpty) {
      filtered = filtered
          .where(
            (m) => m.title.toLowerCase().startsWith(filterType.toLowerCase()),
          )
          .toList();
    }

    // 按搜索关键字过滤
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        return m.title.toLowerCase().contains(q) || m.id.contains(q);
      }).toList();
    }

    // 排序：可以根据标题或更新时间等排序，这里默认按标题排序
    final sorted = List<LocalMapItem>.from(filtered);
    sorted.sort((a, b) => a.title.compareTo(b.title));
    return sorted;
  }

  @override
  List<Object?> get props => [
    isLoading,
    isDeleting,
    error,
    localMaps,
    selectedMapIds,
    isSteamRunning,
    searchQuery,
    filterType,
    previewMapId,
    previewMapInfo,
  ];
}

/// 本地创意工坊地图项
class LocalMapItem extends Equatable {
  final String id; // 创意工坊 ID
  final String title; // 从 publish_data.txt 读取
  final int timeUpdated; // 从 ACF 读取
  final int size; // 从 ACF 读取
  final String folderPath; // 地图在本地的完整文件夹路径

  const LocalMapItem({
    required this.id,
    required this.title,
    required this.timeUpdated,
    required this.size,
    required this.folderPath,
  });

  @override
  List<Object?> get props => [id, title, timeUpdated, size, folderPath];
}
