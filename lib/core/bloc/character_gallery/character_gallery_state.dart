import 'package:equatable/equatable.dart';
import '../../models/character_models.dart';

enum LoadState { initial, loading, success, failure }

class CharacterGalleryState extends Equatable {
  // 列表状态
  final LoadState listLoadState;
  final List<CharacterListItem> characters;
  final int totalCount;
  final int currentPage;
  final bool hasMore;

  // 筛选条件
  final CharacterCategory? selectedCategory;
  final String? keyword;
  final String orderBy;
  final String sortBy; // '' = 默认排序, 'update' = 最近更新

  // 是否显示符卡评级视图
  final bool showSpellCardTierView;

  // 是否显示刀枪图鉴视图
  final bool showWeaponModelView;

  // 刀枪图鉴当前标签页 (0=刀模, 1=枪模)
  final int weaponModelTab;

  // 全部刀模/枪模列表状态
  final LoadState allWeaponModelsLoadState;
  final List<KnifeModel> allKnifeModels;
  final List<GunModel> allGunModels;
  final int allKnifeTotalCount;
  final int allGunTotalCount;
  final String? weaponModelKeyword;

  // 符卡评级列表状态
  final LoadState spellCardTierLoadState;
  final List<SpellCardTierGroup> spellCardTierGroups;
  final int spellCardTierTotalCount;
  final SpellCardType? spellCardTierFilter; // 符卡类型筛选

  // 详情状态
  final LoadState detailLoadState;
  final int? loadingCharacterId; // 正在加载的角色ID（用于卡片选中状态）
  final CharacterModel? selectedCharacter;
  final int? selectedSubModelId;
  final int previewPosition; // 0=front, 1=left, 2=right, 3=back, 4=hand, 5=leg

  // 符卡列表（根据子模型单独请求）
  final LoadState spellCardsLoadState;
  final List<SpellCard> spellCards;

  // 统一编辑状态
  final LoadState submitEditState;
  final String? submitEditError;

  // 我的编辑申请
  final LoadState myEditRequestsLoadState;
  final List<MyEditRequestItem> myEditRequests;
  final int myEditRequestsTotal;

  // 当前子模型的待审核状态
  final bool hasPendingRequest;
  final int? pendingRequestId;

  // 删除申请状态
  final LoadState deleteRequestState;
  final String? deleteRequestError;

  // 符卡评级视图中选中的符卡ID
  final int? selectedSpellCardId;

  // 符卡评级展开状态（key: tier字符串, value: 是否展开）
  final Set<String> expandedTiers;

  // 刀模/枪模状态
  final LoadState weaponModelsLoadState;
  final List<KnifeModel> knifeModels;
  final List<GunModel> gunModels;

  // 选中的刀枪模（用于详情显示）
  final int? selectedWeaponModelId;
  final bool selectedWeaponIsKnife; // true=刀模, false=枪模
  final int weaponPreviewPosition; // 0=front, 1=left, 2=right, 3=back, 4=hand
  final LoadState weaponDetailLoadState; // 刀枪模详情加载状态
  final KnifeModel? selectedKnifeModelDetail; // 刀模详情（通过 API 获取）
  final GunModel? selectedGunModelDetail; // 枪模详情（通过 API 获取）

  // 刀枪模专属角色信息（通过 API 获取）
  final LoadState weaponCharacterLoadState;
  final String? weaponCharacterThumbnailUrl;
  final AcquisitionInfo? weaponCharacterAcquisition;

  // 错误信息
  final String? error;

  const CharacterGalleryState({
    this.listLoadState = LoadState.initial,
    this.characters = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.hasMore = true,
    this.selectedCategory,
    this.keyword,
    this.orderBy = 'id ASC',
    this.sortBy = '',
    this.showSpellCardTierView = false,
    this.showWeaponModelView = false,
    this.weaponModelTab = 0,
    this.allWeaponModelsLoadState = LoadState.initial,
    this.allKnifeModels = const [],
    this.allGunModels = const [],
    this.allKnifeTotalCount = 0,
    this.allGunTotalCount = 0,
    this.weaponModelKeyword,
    this.spellCardTierLoadState = LoadState.initial,
    this.spellCardTierGroups = const [],
    this.spellCardTierTotalCount = 0,
    this.spellCardTierFilter,
    this.detailLoadState = LoadState.initial,
    this.loadingCharacterId,
    this.selectedCharacter,
    this.selectedSubModelId,
    this.previewPosition = 0,
    this.spellCardsLoadState = LoadState.initial,
    this.spellCards = const [],
    this.submitEditState = LoadState.initial,
    this.submitEditError,
    this.myEditRequestsLoadState = LoadState.initial,
    this.myEditRequests = const [],
    this.myEditRequestsTotal = 0,
    this.hasPendingRequest = false,
    this.pendingRequestId,
    this.deleteRequestState = LoadState.initial,
    this.deleteRequestError,
    this.selectedSpellCardId,
    this.expandedTiers = const {},
    this.weaponModelsLoadState = LoadState.initial,
    this.knifeModels = const [],
    this.gunModels = const [],
    this.selectedWeaponModelId,
    this.selectedWeaponIsKnife = true,
    this.weaponPreviewPosition = 0,
    this.weaponDetailLoadState = LoadState.initial,
    this.selectedKnifeModelDetail,
    this.selectedGunModelDetail,
    this.weaponCharacterLoadState = LoadState.initial,
    this.weaponCharacterThumbnailUrl,
    this.weaponCharacterAcquisition,
    this.error,
  });

  CharacterGalleryState copyWith({
    LoadState? listLoadState,
    List<CharacterListItem>? characters,
    int? totalCount,
    int? currentPage,
    bool? hasMore,
    CharacterCategory? selectedCategory,
    bool clearCategory = false,
    String? keyword,
    bool clearKeyword = false,
    String? orderBy,
    String? sortBy,
    bool? showSpellCardTierView,
    bool? showWeaponModelView,
    int? weaponModelTab,
    LoadState? allWeaponModelsLoadState,
    List<KnifeModel>? allKnifeModels,
    List<GunModel>? allGunModels,
    int? allKnifeTotalCount,
    int? allGunTotalCount,
    String? weaponModelKeyword,
    bool clearWeaponModelKeyword = false,
    LoadState? spellCardTierLoadState,
    List<SpellCardTierGroup>? spellCardTierGroups,
    int? spellCardTierTotalCount,
    SpellCardType? spellCardTierFilter,
    bool clearSpellCardTierFilter = false,
    LoadState? detailLoadState,
    int? loadingCharacterId,
    bool clearLoadingCharacterId = false,
    CharacterModel? selectedCharacter,
    bool clearSelectedCharacter = false,
    int? selectedSubModelId,
    bool clearSelectedSubModel = false,
    int? previewPosition,
    LoadState? spellCardsLoadState,
    List<SpellCard>? spellCards,
    LoadState? submitEditState,
    String? submitEditError,
    bool clearSubmitEditError = false,
    LoadState? myEditRequestsLoadState,
    List<MyEditRequestItem>? myEditRequests,
    int? myEditRequestsTotal,
    bool? hasPendingRequest,
    int? pendingRequestId,
    bool clearPendingRequest = false,
    LoadState? deleteRequestState,
    String? deleteRequestError,
    bool clearDeleteRequestError = false,
    int? selectedSpellCardId,
    bool clearSelectedSpellCardId = false,
    Set<String>? expandedTiers,
    LoadState? weaponModelsLoadState,
    List<KnifeModel>? knifeModels,
    List<GunModel>? gunModels,
    int? selectedWeaponModelId,
    bool clearSelectedWeaponModel = false,
    bool? selectedWeaponIsKnife,
    int? weaponPreviewPosition,
    LoadState? weaponDetailLoadState,
    KnifeModel? selectedKnifeModelDetail,
    GunModel? selectedGunModelDetail,
    LoadState? weaponCharacterLoadState,
    String? weaponCharacterThumbnailUrl,
    AcquisitionInfo? weaponCharacterAcquisition,
    bool clearWeaponCharacter = false,
    String? error,
  }) {
    return CharacterGalleryState(
      listLoadState: listLoadState ?? this.listLoadState,
      characters: characters ?? this.characters,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      keyword: clearKeyword ? null : (keyword ?? this.keyword),
      orderBy: orderBy ?? this.orderBy,
      sortBy: sortBy ?? this.sortBy,
      showSpellCardTierView:
          showSpellCardTierView ?? this.showSpellCardTierView,
      showWeaponModelView: showWeaponModelView ?? this.showWeaponModelView,
      weaponModelTab: weaponModelTab ?? this.weaponModelTab,
      allWeaponModelsLoadState:
          allWeaponModelsLoadState ?? this.allWeaponModelsLoadState,
      allKnifeModels: allKnifeModels ?? this.allKnifeModels,
      allGunModels: allGunModels ?? this.allGunModels,
      allKnifeTotalCount: allKnifeTotalCount ?? this.allKnifeTotalCount,
      allGunTotalCount: allGunTotalCount ?? this.allGunTotalCount,
      weaponModelKeyword: clearWeaponModelKeyword
          ? null
          : (weaponModelKeyword ?? this.weaponModelKeyword),
      spellCardTierLoadState:
          spellCardTierLoadState ?? this.spellCardTierLoadState,
      spellCardTierGroups: spellCardTierGroups ?? this.spellCardTierGroups,
      spellCardTierTotalCount:
          spellCardTierTotalCount ?? this.spellCardTierTotalCount,
      spellCardTierFilter: clearSpellCardTierFilter
          ? null
          : (spellCardTierFilter ?? this.spellCardTierFilter),
      detailLoadState: detailLoadState ?? this.detailLoadState,
      loadingCharacterId: clearLoadingCharacterId
          ? null
          : (loadingCharacterId ?? this.loadingCharacterId),
      selectedCharacter: clearSelectedCharacter
          ? null
          : (selectedCharacter ?? this.selectedCharacter),
      selectedSubModelId: clearSelectedSubModel
          ? null
          : (selectedSubModelId ?? this.selectedSubModelId),
      previewPosition: previewPosition ?? this.previewPosition,
      spellCardsLoadState: spellCardsLoadState ?? this.spellCardsLoadState,
      spellCards: spellCards ?? this.spellCards,
      submitEditState: submitEditState ?? this.submitEditState,
      submitEditError: clearSubmitEditError
          ? null
          : (submitEditError ?? this.submitEditError),
      myEditRequestsLoadState:
          myEditRequestsLoadState ?? this.myEditRequestsLoadState,
      myEditRequests: myEditRequests ?? this.myEditRequests,
      myEditRequestsTotal: myEditRequestsTotal ?? this.myEditRequestsTotal,
      hasPendingRequest: clearPendingRequest
          ? false
          : (hasPendingRequest ?? this.hasPendingRequest),
      pendingRequestId: clearPendingRequest
          ? null
          : (pendingRequestId ?? this.pendingRequestId),
      deleteRequestState: deleteRequestState ?? this.deleteRequestState,
      deleteRequestError: clearDeleteRequestError
          ? null
          : (deleteRequestError ?? this.deleteRequestError),
      selectedSpellCardId: clearSelectedSpellCardId
          ? null
          : (selectedSpellCardId ?? this.selectedSpellCardId),
      expandedTiers: expandedTiers ?? this.expandedTiers,
      weaponModelsLoadState:
          weaponModelsLoadState ?? this.weaponModelsLoadState,
      knifeModels: knifeModels ?? this.knifeModels,
      gunModels: gunModels ?? this.gunModels,
      selectedWeaponModelId: clearSelectedWeaponModel
          ? null
          : (selectedWeaponModelId ?? this.selectedWeaponModelId),
      selectedWeaponIsKnife:
          selectedWeaponIsKnife ?? this.selectedWeaponIsKnife,
      weaponPreviewPosition: clearSelectedWeaponModel
          ? 0
          : (weaponPreviewPosition ?? this.weaponPreviewPosition),
      weaponDetailLoadState: clearSelectedWeaponModel
          ? LoadState.initial
          : (weaponDetailLoadState ?? this.weaponDetailLoadState),
      selectedKnifeModelDetail: clearSelectedWeaponModel
          ? null
          : (selectedKnifeModelDetail ?? this.selectedKnifeModelDetail),
      selectedGunModelDetail: clearSelectedWeaponModel
          ? null
          : (selectedGunModelDetail ?? this.selectedGunModelDetail),
      weaponCharacterLoadState: clearWeaponCharacter
          ? LoadState.initial
          : (weaponCharacterLoadState ?? this.weaponCharacterLoadState),
      weaponCharacterThumbnailUrl: clearWeaponCharacter
          ? null
          : (weaponCharacterThumbnailUrl ?? this.weaponCharacterThumbnailUrl),
      weaponCharacterAcquisition: clearWeaponCharacter
          ? null
          : (weaponCharacterAcquisition ?? this.weaponCharacterAcquisition),
      error: error,
    );
  }

  /// 获取当前选中的子模型
  CharacterSubModel? get currentSubModel {
    if (selectedCharacter == null || selectedCharacter!.subModels == null) {
      return null;
    }
    final subModelId =
        selectedSubModelId ?? selectedCharacter!.defaultSubModelId;
    if (subModelId == null) return null;
    return selectedCharacter!.subModels!.firstWhere(
      (s) => s.id == subModelId,
      orElse: () => selectedCharacter!.subModels!.first,
    );
  }

  /// 获取当前预览图
  String? get currentPreviewImage {
    final preview = currentSubModel?.preview ?? selectedCharacter?.preview;
    if (preview == null) return null;
    return switch (previewPosition) {
      0 => preview.front,
      1 => preview.left,
      2 => preview.right,
      3 => preview.back,
      4 => preview.hand,
      5 => preview.leg,
      _ => preview.front,
    };
  }

  /// 获取当前选中的刀模（优先使用详情数据）
  KnifeModel? get selectedKnifeModel {
    if (selectedWeaponModelId == null || !selectedWeaponIsKnife) return null;
    // 优先使用详情 API 返回的数据
    if (selectedKnifeModelDetail != null) return selectedKnifeModelDetail;
    // 回退到列表数据
    return allKnifeModels.cast<KnifeModel?>().firstWhere(
      (k) => k?.id == selectedWeaponModelId,
      orElse: () => null,
    );
  }

  /// 获取当前选中的枪模（优先使用详情数据）
  GunModel? get selectedGunModel {
    if (selectedWeaponModelId == null || selectedWeaponIsKnife) return null;
    // 优先使用详情 API 返回的数据
    if (selectedGunModelDetail != null) return selectedGunModelDetail;
    // 回退到列表数据
    return allGunModels.cast<GunModel?>().firstWhere(
      (g) => g?.id == selectedWeaponModelId,
      orElse: () => null,
    );
  }

  /// 获取当前刀枪模的预览图
  String? get currentWeaponPreviewImage {
    final preview = selectedKnifeModel?.preview ?? selectedGunModel?.preview;
    if (preview == null) return null;
    return switch (weaponPreviewPosition) {
      0 => preview.front,
      1 => preview.left,
      2 => preview.right,
      3 => preview.back,
      4 => preview.hand,
      _ => preview.front,
    };
  }

  @override
  List<Object?> get props => [
    listLoadState,
    characters,
    totalCount,
    currentPage,
    hasMore,
    selectedCategory,
    keyword,
    orderBy,
    sortBy,
    showSpellCardTierView,
    showWeaponModelView,
    weaponModelTab,
    allWeaponModelsLoadState,
    allKnifeModels,
    allGunModels,
    allKnifeTotalCount,
    allGunTotalCount,
    weaponModelKeyword,
    spellCardTierLoadState,
    spellCardTierGroups,
    spellCardTierTotalCount,
    spellCardTierFilter,
    detailLoadState,
    loadingCharacterId,
    selectedCharacter,
    selectedSubModelId,
    previewPosition,
    spellCardsLoadState,
    spellCards,
    submitEditState,
    submitEditError,
    myEditRequestsLoadState,
    myEditRequests,
    myEditRequestsTotal,
    hasPendingRequest,
    pendingRequestId,
    deleteRequestState,
    deleteRequestError,
    selectedSpellCardId,
    expandedTiers,
    weaponModelsLoadState,
    knifeModels,
    gunModels,
    selectedWeaponModelId,
    selectedWeaponIsKnife,
    weaponPreviewPosition,
    weaponDetailLoadState,
    selectedKnifeModelDetail,
    selectedGunModelDetail,
    weaponCharacterLoadState,
    weaponCharacterThumbnailUrl,
    weaponCharacterAcquisition,
    error,
  ];
}
