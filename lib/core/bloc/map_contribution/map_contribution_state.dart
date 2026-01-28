import 'package:equatable/equatable.dart';
import '../../models/map_contribution_models.dart';

class MapContributionState extends Equatable {
  /// 名称贡献列表
  final List<MapContribution> nameContributions;
  
  /// 背景贡献列表
  final List<MapContribution> backgroundContributions;
  
  /// 是否正在加载名称贡献
  final bool isLoadingNames;
  
  /// 是否正在加载背景贡献
  final bool isLoadingBackgrounds;
  
  /// 是否正在提交
  final bool isSubmitting;
  
  /// 提交成功标识（用于显示 Toast 后清除）
  final bool submitSuccess;
  
  /// 删除成功标识（用于显示 Toast 后清除）
  final bool deleteSuccess;
  
  /// 错误信息
  final String? error;
  
  /// 当前地图名称
  final String? currentMapName;

  /// 所有地图列表（用于"全部地图" Tab）
  final List<MapInfo> allMaps;
  
  /// 我的地图贡献分组列表（用于"我的贡献" Tab）
  final List<MapContributionGroup> myMapGroups;
  
  /// 是否正在加载所有地图
  final bool isLoadingAllMaps;
  
  /// 是否正在加载我的地图贡献
  final bool isLoadingMyMaps;
  
  /// 所有地图总数
  final int allMapsTotal;
  
  /// 我的地图贡献总数
  final int myMapsTotal;
  
  /// 当前所有地图的请求参数（用于刷新）
  final MapListRequest? allMapsRequest;
  
  /// 当前我的地图贡献的请求参数（用于刷新）
  final MapContributionListRequest? myMapsRequest;

  const MapContributionState({
    this.nameContributions = const [],
    this.backgroundContributions = const [],
    this.isLoadingNames = false,
    this.isLoadingBackgrounds = false,
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.deleteSuccess = false,
    this.error,
    this.currentMapName,
    this.allMaps = const [],
    this.myMapGroups = const [],
    this.isLoadingAllMaps = false,
    this.isLoadingMyMaps = false,
    this.allMapsTotal = 0,
    this.myMapsTotal = 0,
    this.allMapsRequest,
    this.myMapsRequest,
  });

  /// 是否正在加载（任一列表）
  bool get isLoading => isLoadingNames || isLoadingBackgrounds || isLoadingAllMaps || isLoadingMyMaps;

  /// 名称列表是否为空
  bool get isNamesEmpty => nameContributions.isEmpty && !isLoadingNames;

  /// 背景列表是否为空
  bool get isBackgroundsEmpty => backgroundContributions.isEmpty && !isLoadingBackgrounds;
  
  /// 所有地图列表是否为空
  bool get isAllMapsEmpty => allMaps.isEmpty && !isLoadingAllMaps;
  
  /// 我的地图列表是否为空
  bool get isMyMapsEmpty => myMapGroups.isEmpty && !isLoadingMyMaps;
  
  /// 是否还有更多所有地图数据
  bool get hasMoreAllMaps => allMaps.length < allMapsTotal;
  
  /// 是否还有更多我的地图数据
  bool get hasMoreMyMaps => myMapGroups.length < myMapsTotal;

  MapContributionState copyWith({
    List<MapContribution>? nameContributions,
    List<MapContribution>? backgroundContributions,
    bool? isLoadingNames,
    bool? isLoadingBackgrounds,
    bool? isSubmitting,
    bool? submitSuccess,
    bool? deleteSuccess,
    String? error,
    bool clearError = false,
    String? currentMapName,
    List<MapInfo>? allMaps,
    List<MapContributionGroup>? myMapGroups,
    bool? isLoadingAllMaps,
    bool? isLoadingMyMaps,
    int? allMapsTotal,
    int? myMapsTotal,
    MapListRequest? allMapsRequest,
    MapContributionListRequest? myMapsRequest,
  }) {
    return MapContributionState(
      nameContributions: nameContributions ?? this.nameContributions,
      backgroundContributions: backgroundContributions ?? this.backgroundContributions,
      isLoadingNames: isLoadingNames ?? this.isLoadingNames,
      isLoadingBackgrounds: isLoadingBackgrounds ?? this.isLoadingBackgrounds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess: submitSuccess ?? false,
      deleteSuccess: deleteSuccess ?? false,
      error: clearError ? null : (error ?? this.error),
      currentMapName: currentMapName ?? this.currentMapName,
      allMaps: allMaps ?? this.allMaps,
      myMapGroups: myMapGroups ?? this.myMapGroups,
      isLoadingAllMaps: isLoadingAllMaps ?? this.isLoadingAllMaps,
      isLoadingMyMaps: isLoadingMyMaps ?? this.isLoadingMyMaps,
      allMapsTotal: allMapsTotal ?? this.allMapsTotal,
      myMapsTotal: myMapsTotal ?? this.myMapsTotal,
      allMapsRequest: allMapsRequest ?? this.allMapsRequest,
      myMapsRequest: myMapsRequest ?? this.myMapsRequest,
    );
  }

  @override
  List<Object?> get props => [
    nameContributions,
    backgroundContributions,
    isLoadingNames,
    isLoadingBackgrounds,
    isSubmitting,
    submitSuccess,
    deleteSuccess,
    error,
    currentMapName,
    allMaps,
    myMapGroups,
    isLoadingAllMaps,
    isLoadingMyMaps,
    allMapsTotal,
    myMapsTotal,
    allMapsRequest,
    myMapsRequest,
  ];
}
