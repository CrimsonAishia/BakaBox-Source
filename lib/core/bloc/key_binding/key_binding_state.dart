import 'package:equatable/equatable.dart';
import '../../models/key_config_models.dart';

/// 按键绑定状态
class KeyBindingState extends Equatable {
  /// 配置列表
  final List<KeyConfig> configs;
  
  /// 用户自己的配置列表
  final List<KeyConfig> myConfigs;
  
  /// 是否正在加载用户配置
  final bool isLoadingMyConfigs;
  
  /// 分类列表
  final List<KeyConfigCategory> categories;
  
  /// 是否正在加载配置列表
  final bool isLoading;
  
  /// 错误信息
  final String? error;
  
  /// 选中的配置
  final KeyConfig? selectedConfig;
  
  /// 当前按键绑定映射（标签名 -> 按键值）
  final Map<String, String> keyBindings;
  
  /// autoexec.cfg 文件内容
  final String? autoexecContent;
  
  /// 已应用的配置块列表
  final List<ConfigBlock> appliedConfigs;
  
  /// 分类筛选
  final int? categoryFilter;
  
  /// 搜索关键词
  final String? searchKeyword;
  
  /// 是否显示用户自己的配置
  final bool showMyConfigs;
  
  /// 是否正在发布配置
  final bool isPublishing;
  
  /// 是否正在保存文件
  final bool isSaving;
  
  /// 是否正在加载 autoexec.cfg
  final bool isLoadingAutoexec;
  
  /// 游戏路径是否已配置
  final bool hasGamePath;
  
  /// autoexec.cfg 文件是否存在
  final bool autoexecFileExists;
  
  /// 成功消息（用于显示操作成功提示）
  final String? successMessage;

  const KeyBindingState({
    this.configs = const [],
    this.myConfigs = const [],
    this.isLoadingMyConfigs = false,
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.selectedConfig,
    this.keyBindings = const {},
    this.autoexecContent,
    this.appliedConfigs = const [],
    this.categoryFilter,
    this.searchKeyword,
    this.showMyConfigs = false,
    this.isPublishing = false,
    this.isSaving = false,
    this.isLoadingAutoexec = false,
    this.hasGamePath = false,
    this.autoexecFileExists = false,
    this.successMessage,
  });

  /// 获取配置列表（已应用的置顶）
  /// 
  /// 注意：分类筛选和搜索关键词筛选由服务器端处理，
  /// 这里只负责将已应用的配置置顶显示
  List<KeyConfig> get filteredConfigs {
    // 已应用的配置置顶
    final appliedIds = appliedConfigs.map((c) => c.configId).toSet();
    final applied = configs.where((c) => appliedIds.contains(c.configId)).toList();
    final notApplied = configs.where((c) => !appliedIds.contains(c.configId)).toList();
    
    return [...applied, ...notApplied];
  }

  /// 获取用户配置列表（审核中的置顶）
  List<KeyConfig> get filteredMyConfigs {
    // 审核中的配置置顶
    final pending = myConfigs.where((c) => c.isPending).toList();
    final others = myConfigs.where((c) => !c.isPending).toList();
    
    return [...pending, ...others];
  }

  /// 检查配置是否已应用
  bool isConfigApplied(String configId) {
    return appliedConfigs.any((block) => block.configId == configId);
  }

  /// 获取已应用配置的按键绑定
  Map<String, String>? getAppliedKeyBindings(String configId) {
    final block = appliedConfigs.cast<ConfigBlock?>().firstWhere(
      (block) => block?.configId == configId,
      orElse: () => null,
    );
    return block?.keyBindings;
  }

  KeyBindingState copyWith({
    List<KeyConfig>? configs,
    List<KeyConfig>? myConfigs,
    bool? isLoadingMyConfigs,
    List<KeyConfigCategory>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
    KeyConfig? selectedConfig,
    bool clearSelectedConfig = false,
    Map<String, String>? keyBindings,
    String? autoexecContent,
    bool clearAutoexecContent = false,
    List<ConfigBlock>? appliedConfigs,
    int? categoryFilter,
    bool clearCategoryFilter = false,
    String? searchKeyword,
    bool clearSearchKeyword = false,
    bool? showMyConfigs,
    bool? isPublishing,
    bool? isSaving,
    bool? isLoadingAutoexec,
    bool? hasGamePath,
    bool? autoexecFileExists,
    String? successMessage,
    bool clearSuccessMessage = false,
  }) {
    return KeyBindingState(
      configs: configs ?? this.configs,
      myConfigs: myConfigs ?? this.myConfigs,
      isLoadingMyConfigs: isLoadingMyConfigs ?? this.isLoadingMyConfigs,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedConfig: clearSelectedConfig ? null : (selectedConfig ?? this.selectedConfig),
      keyBindings: keyBindings ?? this.keyBindings,
      autoexecContent: clearAutoexecContent ? null : (autoexecContent ?? this.autoexecContent),
      appliedConfigs: appliedConfigs ?? this.appliedConfigs,
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      searchKeyword: clearSearchKeyword ? null : (searchKeyword ?? this.searchKeyword),
      showMyConfigs: showMyConfigs ?? this.showMyConfigs,
      isPublishing: isPublishing ?? this.isPublishing,
      isSaving: isSaving ?? this.isSaving,
      isLoadingAutoexec: isLoadingAutoexec ?? this.isLoadingAutoexec,
      hasGamePath: hasGamePath ?? this.hasGamePath,
      autoexecFileExists: autoexecFileExists ?? this.autoexecFileExists,
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    configs,
    myConfigs,
    isLoadingMyConfigs,
    categories,
    isLoading,
    error,
    selectedConfig,
    keyBindings,
    autoexecContent,
    appliedConfigs,
    categoryFilter,
    searchKeyword,
    showMyConfigs,
    isPublishing,
    isSaving,
    isLoadingAutoexec,
    hasGamePath,
    autoexecFileExists,
    successMessage,
  ];
}
