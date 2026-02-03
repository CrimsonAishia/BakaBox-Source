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
  
  // 是否显示符卡梯队视图
  final bool showSpellCardTierView;
  
  // 符卡梯队列表状态
  final LoadState spellCardTierLoadState;
  final List<SpellCardTierGroup> spellCardTierGroups;
  final int spellCardTierTotalCount;
  final SpellCardType? spellCardTierFilter; // 符卡类型筛选
  
  // 详情状态
  final LoadState detailLoadState;
  final CharacterModel? selectedCharacter;
  final int? selectedSubModelId;
  final int previewPosition; // 0=front, 1=left, 2=right, 3=back
  
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
  
  // 符卡梯队视图中选中的符卡ID
  final int? selectedSpellCardId;
  
  // 符卡梯队展开状态（key: tier字符串, value: 是否展开）
  final Set<String> expandedTiers;
  
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
    this.showSpellCardTierView = false,
    this.spellCardTierLoadState = LoadState.initial,
    this.spellCardTierGroups = const [],
    this.spellCardTierTotalCount = 0,
    this.spellCardTierFilter,
    this.detailLoadState = LoadState.initial,
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
    bool? showSpellCardTierView,
    LoadState? spellCardTierLoadState,
    List<SpellCardTierGroup>? spellCardTierGroups,
    int? spellCardTierTotalCount,
    SpellCardType? spellCardTierFilter,
    bool clearSpellCardTierFilter = false,
    LoadState? detailLoadState,
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
    String? error,
  }) {
    return CharacterGalleryState(
      listLoadState: listLoadState ?? this.listLoadState,
      characters: characters ?? this.characters,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      keyword: clearKeyword ? null : (keyword ?? this.keyword),
      orderBy: orderBy ?? this.orderBy,
      showSpellCardTierView: showSpellCardTierView ?? this.showSpellCardTierView,
      spellCardTierLoadState: spellCardTierLoadState ?? this.spellCardTierLoadState,
      spellCardTierGroups: spellCardTierGroups ?? this.spellCardTierGroups,
      spellCardTierTotalCount: spellCardTierTotalCount ?? this.spellCardTierTotalCount,
      spellCardTierFilter: clearSpellCardTierFilter ? null : (spellCardTierFilter ?? this.spellCardTierFilter),
      detailLoadState: detailLoadState ?? this.detailLoadState,
      selectedCharacter: clearSelectedCharacter ? null : (selectedCharacter ?? this.selectedCharacter),
      selectedSubModelId: clearSelectedSubModel ? null : (selectedSubModelId ?? this.selectedSubModelId),
      previewPosition: previewPosition ?? this.previewPosition,
      spellCardsLoadState: spellCardsLoadState ?? this.spellCardsLoadState,
      spellCards: spellCards ?? this.spellCards,
      submitEditState: submitEditState ?? this.submitEditState,
      submitEditError: clearSubmitEditError ? null : (submitEditError ?? this.submitEditError),
      myEditRequestsLoadState: myEditRequestsLoadState ?? this.myEditRequestsLoadState,
      myEditRequests: myEditRequests ?? this.myEditRequests,
      myEditRequestsTotal: myEditRequestsTotal ?? this.myEditRequestsTotal,
      hasPendingRequest: clearPendingRequest ? false : (hasPendingRequest ?? this.hasPendingRequest),
      pendingRequestId: clearPendingRequest ? null : (pendingRequestId ?? this.pendingRequestId),
      deleteRequestState: deleteRequestState ?? this.deleteRequestState,
      deleteRequestError: clearDeleteRequestError ? null : (deleteRequestError ?? this.deleteRequestError),
      selectedSpellCardId: clearSelectedSpellCardId ? null : (selectedSpellCardId ?? this.selectedSpellCardId),
      expandedTiers: expandedTiers ?? this.expandedTiers,
      error: error,
    );
  }

  /// 获取当前选中的子模型
  CharacterSubModel? get currentSubModel {
    if (selectedCharacter == null || selectedCharacter!.subModels == null) {
      return null;
    }
    final subModelId = selectedSubModelId ?? selectedCharacter!.defaultSubModelId;
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
      _ => preview.front,
    };
  }

  @override
  List<Object?> get props => [
    listLoadState, characters, totalCount, currentPage, hasMore,
    selectedCategory, keyword, orderBy, showSpellCardTierView,
    spellCardTierLoadState, spellCardTierGroups, spellCardTierTotalCount,
    spellCardTierFilter, detailLoadState, selectedCharacter,
    selectedSubModelId, previewPosition, spellCardsLoadState, spellCards,
    submitEditState, submitEditError, myEditRequestsLoadState,
    myEditRequests, myEditRequestsTotal, hasPendingRequest, pendingRequestId,
    deleteRequestState, deleteRequestError, selectedSpellCardId, expandedTiers, error,
  ];
}
