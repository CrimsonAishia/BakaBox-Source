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
  
  /// 错误信息
  final String? error;
  
  /// 当前地图名称
  final String? currentMapName;

  const MapContributionState({
    this.nameContributions = const [],
    this.backgroundContributions = const [],
    this.isLoadingNames = false,
    this.isLoadingBackgrounds = false,
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.error,
    this.currentMapName,
  });

  /// 是否正在加载（任一列表）
  bool get isLoading => isLoadingNames || isLoadingBackgrounds;

  /// 名称列表是否为空
  bool get isNamesEmpty => nameContributions.isEmpty && !isLoadingNames;

  /// 背景列表是否为空
  bool get isBackgroundsEmpty => backgroundContributions.isEmpty && !isLoadingBackgrounds;

  MapContributionState copyWith({
    List<MapContribution>? nameContributions,
    List<MapContribution>? backgroundContributions,
    bool? isLoadingNames,
    bool? isLoadingBackgrounds,
    bool? isSubmitting,
    bool? submitSuccess,
    String? error,
    bool clearError = false,
    String? currentMapName,
  }) {
    return MapContributionState(
      nameContributions: nameContributions ?? this.nameContributions,
      backgroundContributions: backgroundContributions ?? this.backgroundContributions,
      isLoadingNames: isLoadingNames ?? this.isLoadingNames,
      isLoadingBackgrounds: isLoadingBackgrounds ?? this.isLoadingBackgrounds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess: submitSuccess ?? false,
      error: clearError ? null : (error ?? this.error),
      currentMapName: currentMapName ?? this.currentMapName,
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
    error,
    currentMapName,
  ];
}
