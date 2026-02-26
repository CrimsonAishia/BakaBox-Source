import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/character_api.dart';
import '../../models/character_models.dart';
import '../../utils/log_service.dart';
import 'character_gallery_event.dart';
import 'character_gallery_state.dart';

class CharacterGalleryBloc
    extends Bloc<CharacterGalleryEvent, CharacterGalleryState> {
  final CharacterApi _api = CharacterApi();
  static const int _pageSize = 20;
  
  // 用于取消过期的详情加载请求
  int _currentDetailRequestId = 0;

  CharacterGalleryBloc() : super(const CharacterGalleryState()) {
    on<LoadCharacters>(_onLoadCharacters);
    on<LoadMoreCharacters>(_onLoadMoreCharacters);
    on<LoadCharacterDetail>(_onLoadCharacterDetail);
    on<SelectSubModel>(_onSelectSubModel);
    on<LoadSpellCards>(_onLoadSpellCards);
    on<ChangePreviewPosition>(_onChangePreviewPosition);
    on<ChangeCategory>(_onChangeCategory);
    on<SearchCharacters>(_onSearchCharacters);
    on<ClearSelectedCharacter>(_onClearSelectedCharacter);
    on<SubmitUnifiedEdit>(_onSubmitUnifiedEdit);
    on<LoadMyEditRequests>(_onLoadMyEditRequests);
    on<CheckPendingRequest>(_onCheckPendingRequest);
    on<DeleteEditRequest>(_onDeleteEditRequest);
    on<ClearPendingRequest>(_onClearPendingRequest);
    on<UpdateEditRequest>(_onUpdateEditRequest);
    on<LoadSpellCardTierList>(_onLoadSpellCardTierList);
    on<NavigateToCharacterFromSpellCard>(_onNavigateToCharacterFromSpellCard);
    on<ToggleTierExpanded>(_onToggleTierExpanded);
    on<LoadCharacterWeaponModels>(_onLoadCharacterWeaponModels);
    on<LoadAllWeaponModels>(_onLoadAllWeaponModels);
    on<ChangeWeaponModelTab>(_onChangeWeaponModelTab);
    on<SelectWeaponModel>(_onSelectWeaponModel);
    on<ClearSelectedWeaponModel>(_onClearSelectedWeaponModel);
    on<ChangeWeaponPreviewPosition>(_onChangeWeaponPreviewPosition);
    on<NavigateToWeaponModel>(_onNavigateToWeaponModel);
    on<LoadCharacterDetailInWeaponView>(_onLoadCharacterDetailInWeaponView);
    on<LoadWeaponModelDetailInCharacterView>(_onLoadWeaponModelDetailInCharacterView);
  }

  Future<void> _onLoadCharacters(
    LoadCharacters event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    final newCategory = event.category;
    final newKeyword = event.keyword;
    final newOrderBy = event.orderBy ?? state.orderBy;

    emit(
      state.copyWith(
        listLoadState: LoadState.loading,
        currentPage: 1,
        characters: [],
        selectedCategory: newCategory,
        clearCategory: event.category == null && state.selectedCategory != null,
        keyword: newKeyword,
        clearKeyword: event.keyword == null,
        orderBy: newOrderBy,
      ),
    );

    try {
      final response = await _api.getCharacterList(
        pageIndex: 1,
        pageSize: _pageSize,
        category: newCategory,
        keyword: newKeyword,
        orderBy: newOrderBy,
      );

      if (response != null) {
        emit(
          state.copyWith(
            listLoadState: LoadState.success,
            characters: response.list,
            totalCount: response.total,
            currentPage: 1,
            hasMore: response.list.length < response.total,
          ),
        );
      } else {
        emit(
          state.copyWith(listLoadState: LoadState.failure, error: '获取角色列表失败'),
        );
      }
    } catch (e) {
      LogService.e('加载角色列表失败: $e', e);
      emit(
        state.copyWith(listLoadState: LoadState.failure, error: '加载失败，请稍后重试'),
      );
    }
  }

  Future<void> _onLoadMoreCharacters(
    LoadMoreCharacters event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    if (!state.hasMore || state.listLoadState == LoadState.loading) return;

    final nextPage = state.currentPage + 1;
    // 保存当前的筛选条件，用于验证请求返回时条件是否已改变
    final requestCategory = state.selectedCategory;
    final requestKeyword = state.keyword;
    final requestOrderBy = state.orderBy;

    // 立即设置加载状态，防止重复请求
    emit(state.copyWith(listLoadState: LoadState.loading));

    try {
      final response = await _api.getCharacterList(
        pageIndex: nextPage,
        pageSize: _pageSize,
        category: requestCategory,
        keyword: requestKeyword,
        orderBy: requestOrderBy,
      );

      if (response != null) {
        // 验证筛选条件是否已改变（用户可能在请求期间切换了分类/搜索）
        if (state.selectedCategory == requestCategory &&
            state.keyword == requestKeyword &&
            state.orderBy == requestOrderBy) {
          final allCharacters = [...state.characters, ...response.list];
          emit(
            state.copyWith(
              listLoadState: LoadState.success,
              characters: allCharacters,
              currentPage: nextPage,
              hasMore: allCharacters.length < response.total,
            ),
          );
        } else {
          // 筛选条件已改变，丢弃这个结果，恢复状态
          emit(state.copyWith(listLoadState: LoadState.success));
        }
      } else {
        // 请求失败，恢复状态
        emit(state.copyWith(listLoadState: LoadState.success));
      }
    } catch (e) {
      LogService.e('加载更多角色失败: $e', e);
      // 发生错误，恢复状态以允许重试
      emit(state.copyWith(listLoadState: LoadState.success));
    }
  }

  Future<void> _onLoadCharacterDetail(
    LoadCharacterDetail event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    // 递增请求 ID，用于取消过期请求
    final requestId = ++_currentDetailRequestId;
    
    emit(
      state.copyWith(
        detailLoadState: LoadState.loading,
        loadingCharacterId: event.characterId, // 立即设置正在加载的角色ID，用于卡片选中状态
        previewPosition: 0,
        clearSelectedCharacter: true, // 清除旧角色数据，避免闪烁
        clearSelectedSubModel: true,
        spellCards: [],
        spellCardsLoadState: LoadState.initial,
        clearPendingRequest: true, // 切换角色时清除待审核状态
        weaponModelsLoadState: LoadState.initial,
        knifeModels: [],
        gunModels: [],
        // 关闭刀枪图鉴视图和符卡评级视图
        showWeaponModelView: false,
        showSpellCardTierView: false,
        clearSelectedWeaponModel: true,
        clearWeaponCharacter: true,
      ),
    );

    try {
      final results = await Future.wait([
        _api.getCharacterDetail(event.characterId),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);

      // 检查请求是否已过期（用户点击了其他角色）
      if (requestId != _currentDetailRequestId) {
        return; // 忽略过期的请求结果
      }

      final character = results[0] as CharacterModel?;

      if (character != null) {
        int? defaultSubModelId = character.defaultSubModelId;
        if (defaultSubModelId == null &&
            character.subModels != null &&
            character.subModels!.isNotEmpty) {
          final defaultSubModel = character.subModels!.firstWhere(
            (s) => s.isDefault,
            orElse: () => character.subModels!.first,
          );
          defaultSubModelId = defaultSubModel.id;
        }

        // 更新列表中对应角色的浏览量 +1
        final updatedCharacters = state.characters.map((c) {
          if (c.id == event.characterId) {
            return CharacterListItem(
              id: c.id,
              name: c.name,
              nameEn: c.nameEn,
              category: c.category,
              thumbnailUrl: c.thumbnailUrl,
              acquisition: c.acquisition,
              viewCount: c.viewCount + 1,
              hasSpellCards: c.hasSpellCards,
              hasZombieSkills: c.hasZombieSkills,
              subModelCount: c.subModelCount,
            );
          }
          return c;
        }).toList();

        emit(
          state.copyWith(
            detailLoadState: LoadState.success,
            selectedCharacter: character,
            selectedSubModelId: defaultSubModelId,
            characters: updatedCharacters,
          ),
        );

        // 检查待审核状态
        if (defaultSubModelId != null) {
          add(CheckPendingRequest(defaultSubModelId));
        }

        if (character.category == CharacterCategory.touhou &&
            defaultSubModelId != null) {
          add(
            LoadSpellCards(
              characterId: character.id,
              subModelId: defaultSubModelId,
            ),
          );
        }

        // 加载角色专属刀模/枪模
        add(LoadCharacterWeaponModels(character.id));
      } else {
        emit(
          state.copyWith(detailLoadState: LoadState.failure, error: '获取角色详情失败'),
        );
      }
    } catch (e) {
      LogService.e('加载角色详情失败: $e', e);
      emit(
        state.copyWith(detailLoadState: LoadState.failure, error: '加载失败，请稍后重试'),
      );
    }
  }

  Future<void> _onSelectSubModel(
    SelectSubModel event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    final character = state.selectedCharacter;
    if (character == null) return;

    emit(
      state.copyWith(
        selectedSubModelId: event.subModelId,
        previewPosition: 0,
        clearPendingRequest: true, // 切换子模型时清除待审核状态
      ),
    );

    // 检查新子模型的待审核状态
    add(CheckPendingRequest(event.subModelId));

    final currentSubModel = character.subModels?.firstWhere(
      (s) => s.id == event.subModelId,
      orElse: () => character.subModels!.first,
    );

    if (currentSubModel?.preview == null) {
      try {
        final subModelDetail = await _api.getSubModelDetail(
          character.id,
          event.subModelId,
        );
        if (subModelDetail != null && subModelDetail.preview != null) {
          final updatedSubModels = character.subModels?.map((s) {
            if (s.id == event.subModelId) {
              return CharacterSubModel(
                id: s.id,
                characterId: s.characterId,
                name: s.name,
                type: s.type,
                description: subModelDetail.description ?? s.description,
                thumbnailUrl: s.thumbnailUrl,
                preview: subModelDetail.preview,
                glbModelUrl: subModelDetail.glbModelUrl ?? s.glbModelUrl,
                acquisition: subModelDetail.acquisition ?? s.acquisition,
                isDefault: s.isDefault,
                sortOrder: s.sortOrder,
              );
            }
            return s;
          }).toList();

          if (updatedSubModels != null) {
            final updatedCharacter = CharacterModel(
              id: character.id,
              name: character.name,
              nameEn: character.nameEn,
              category: character.category,
              description: character.description,
              thumbnailUrl: character.thumbnailUrl,
              preview: character.preview,
              glbModelUrl: character.glbModelUrl,
              acquisition: character.acquisition,
              subModels: updatedSubModels,
              defaultSubModelId: character.defaultSubModelId,
              spellCards: character.spellCards,
              zombieSkills: character.zombieSkills,
              createdAt: character.createdAt,
              viewCount: character.viewCount,
              contributorCount: character.contributorCount,
            );

            emit(state.copyWith(selectedCharacter: updatedCharacter));
          }
        }
      } catch (e) {
        LogService.e('加载子模型详情失败: $e', e);
      }
    }

    if (character.category == CharacterCategory.touhou) {
      add(
        LoadSpellCards(characterId: character.id, subModelId: event.subModelId),
      );
    }
  }

  Future<void> _onLoadSpellCards(
    LoadSpellCards event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(state.copyWith(spellCardsLoadState: LoadState.loading));

    try {
      final result = await _api.getSpellCards(
        event.characterId,
        subModelId: event.subModelId,
      );

      if (result != null) {
        final allSpellCards = <SpellCard>[
          ...result[SpellCardType.normal] ?? [],
          ...result[SpellCardType.ultimate] ?? [],
          ...result[SpellCardType.passive] ?? [],
        ];
        emit(
          state.copyWith(
            spellCardsLoadState: LoadState.success,
            spellCards: allSpellCards,
          ),
        );
      } else {
        emit(
          state.copyWith(
            spellCardsLoadState: LoadState.failure,
            error: '获取符卡列表失败',
          ),
        );
      }
    } catch (e) {
      LogService.e('加载符卡列表失败: $e', e);
      emit(
        state.copyWith(spellCardsLoadState: LoadState.failure, error: '加载符卡失败'),
      );
    }
  }

  void _onChangePreviewPosition(
    ChangePreviewPosition event,
    Emitter<CharacterGalleryState> emit,
  ) {
    emit(state.copyWith(previewPosition: event.position));
  }

  void _onChangeCategory(
    ChangeCategory event,
    Emitter<CharacterGalleryState> emit,
  ) {
    // 切换分类时退出符卡评级视图和刀枪图鉴视图
    if (state.showSpellCardTierView || state.showWeaponModelView) {
      emit(state.copyWith(
        showSpellCardTierView: false,
        showWeaponModelView: false,
      ));
    }
    add(
      LoadCharacters(
        category: event.category,
        keyword: state.keyword,
        orderBy: state.orderBy,
      ),
    );
  }

  void _onSearchCharacters(
    SearchCharacters event,
    Emitter<CharacterGalleryState> emit,
  ) {
    // 如果当前是符卡评级视图，搜索符卡
    if (state.showSpellCardTierView) {
      add(
        LoadSpellCardTierList(
          type: state.spellCardTierFilter,
          keyword: event.keyword.isEmpty ? null : event.keyword,
        ),
      );
      return;
    }

    // 如果当前是刀枪图鉴视图，搜索刀枪
    if (state.showWeaponModelView) {
      add(LoadAllWeaponModels(
        keyword: event.keyword.isEmpty ? null : event.keyword,
        tabIndex: state.weaponModelTab,
      ));
      return;
    }

    // 否则搜索角色
    if (event.keyword.isEmpty) {
      add(
        LoadCharacters(
          category: state.selectedCategory,
          orderBy: state.orderBy,
        ),
      );
    } else {
      add(
        LoadCharacters(
          keyword: event.keyword,
          category: state.selectedCategory,
          orderBy: state.orderBy,
        ),
      );
    }
  }

  void _onClearSelectedCharacter(
    ClearSelectedCharacter event,
    Emitter<CharacterGalleryState> emit,
  ) {
    emit(
      state.copyWith(
        clearSelectedCharacter: true,
        detailLoadState: LoadState.initial,
      ),
    );
  }

  Future<void> _onSubmitUnifiedEdit(
    SubmitUnifiedEdit event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(
      state.copyWith(
        submitEditState: LoadState.loading,
        clearSubmitEditError: true,
      ),
    );

    try {
      // 构建符卡编辑数据
      SpellCardsEditData? spellCardsData;
      if (event.spellCardCreates != null ||
          event.spellCardUpdates != null ||
          event.spellCardDeletes != null) {
        spellCardsData = SpellCardsEditData(
          creates: event.spellCardCreates,
          updates: event.spellCardUpdates,
          deletes: event.spellCardDeletes,
        );
      }

      // 构建僵尸技能编辑数据
      ZombieSkillsEditData? zombieSkillsData;
      if (event.zombieSkillCreates != null ||
          event.zombieSkillUpdates != null ||
          event.zombieSkillDeletes != null) {
        zombieSkillsData = ZombieSkillsEditData(
          creates: event.zombieSkillCreates,
          updates: event.zombieSkillUpdates,
          deletes: event.zombieSkillDeletes,
        );
      }

      final request = SubModelUnifiedEditRequest(
        editReason: event.editReason,
        description: event.description,
        acquisition: event.acquisition,
        spellCards: spellCardsData,
        zombieSkills: zombieSkillsData,
        previewImages: event.previewImages,
      );

      final response = await _api.editSubModelUnified(
        event.characterId,
        event.subModelId,
        request,
      );

      if (response != null) {
        emit(state.copyWith(submitEditState: LoadState.success));
        // 刷新角色详情
        add(LoadCharacterDetail(event.characterId));
      } else {
        emit(
          state.copyWith(
            submitEditState: LoadState.failure,
            submitEditError: '提交编辑失败',
          ),
        );
      }
    } catch (e) {
      LogService.e('提交编辑失败: $e', e);
      emit(
        state.copyWith(
          submitEditState: LoadState.failure,
          submitEditError: '提交失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> _onLoadMyEditRequests(
    LoadMyEditRequests event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(state.copyWith(myEditRequestsLoadState: LoadState.loading));

    try {
      final response = await _api.getMyEditRequests(
        pageIndex: event.pageIndex,
        pageSize: event.pageSize,
      );

      if (response != null) {
        emit(
          state.copyWith(
            myEditRequestsLoadState: LoadState.success,
            myEditRequests: response.items,
            myEditRequestsTotal: response.total,
          ),
        );
      } else {
        emit(
          state.copyWith(
            myEditRequestsLoadState: LoadState.failure,
            error: '获取编辑申请失败',
          ),
        );
      }
    } catch (e) {
      LogService.e('加载编辑申请失败: $e', e);
      emit(
        state.copyWith(
          myEditRequestsLoadState: LoadState.failure,
          error: '加载失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> _onCheckPendingRequest(
    CheckPendingRequest event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    try {
      final response = await _api.checkPendingRequest(event.subModelId);
      if (response != null) {
        if (response.hasPending) {
          emit(
            state.copyWith(
              hasPendingRequest: true,
              pendingRequestId: response.requestId,
            ),
          );
        } else {
          // 没有待审核申请时，清除状态
          emit(state.copyWith(clearPendingRequest: true));
        }
      }
    } catch (e) {
      LogService.e('检查待审核状态失败: $e', e);
      // 失败时不影响主流程，静默处理
    }
  }

  Future<void> _onDeleteEditRequest(
    DeleteEditRequest event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(
      state.copyWith(
        deleteRequestState: LoadState.loading,
        clearDeleteRequestError: true,
      ),
    );

    try {
      final response = await _api.deleteEditRequest(event.requestId);
      if (response != null && response.success) {
        emit(
          state.copyWith(
            deleteRequestState: LoadState.success,
            clearPendingRequest: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            deleteRequestState: LoadState.failure,
            deleteRequestError: '撤销申请失败',
          ),
        );
      }
    } catch (e) {
      LogService.e('删除编辑申请失败: $e', e);
      emit(
        state.copyWith(
          deleteRequestState: LoadState.failure,
          deleteRequestError: '撤销失败，请稍后重试',
        ),
      );
    }
  }

  void _onClearPendingRequest(
    ClearPendingRequest event,
    Emitter<CharacterGalleryState> emit,
  ) {
    emit(state.copyWith(clearPendingRequest: true));
  }

  Future<void> _onUpdateEditRequest(
    UpdateEditRequest event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(
      state.copyWith(
        submitEditState: LoadState.loading,
        clearSubmitEditError: true,
      ),
    );

    try {
      // 构建符卡编辑数据
      SpellCardsEditData? spellCardsData;
      if (event.spellCardCreates != null ||
          event.spellCardUpdates != null ||
          event.spellCardDeletes != null) {
        spellCardsData = SpellCardsEditData(
          creates: event.spellCardCreates,
          updates: event.spellCardUpdates,
          deletes: event.spellCardDeletes,
        );
      }

      // 构建僵尸技能编辑数据
      ZombieSkillsEditData? zombieSkillsData;
      if (event.zombieSkillCreates != null ||
          event.zombieSkillUpdates != null ||
          event.zombieSkillDeletes != null) {
        zombieSkillsData = ZombieSkillsEditData(
          creates: event.zombieSkillCreates,
          updates: event.zombieSkillUpdates,
          deletes: event.zombieSkillDeletes,
        );
      }

      final request = SubModelUnifiedEditRequest(
        editReason: event.editReason,
        description: event.description,
        acquisition: event.acquisition,
        spellCards: spellCardsData,
        zombieSkills: zombieSkillsData,
        previewImages: event.previewImages,
      );

      final response = await _api.updateEditRequest(event.requestId, request);

      if (response != null && response.success) {
        emit(state.copyWith(submitEditState: LoadState.success));
        // 修改成功后，重新检查待审核状态（申请仍然存在，只是内容变了）
        final subModelId = state.selectedSubModelId;
        if (subModelId != null) {
          add(CheckPendingRequest(subModelId));
        }
      } else {
        emit(
          state.copyWith(
            submitEditState: LoadState.failure,
            submitEditError: '修改申请失败',
          ),
        );
      }
    } catch (e) {
      LogService.e('修改编辑申请失败: $e', e);
      emit(
        state.copyWith(
          submitEditState: LoadState.failure,
          submitEditError: '修改失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> _onLoadSpellCardTierList(
    LoadSpellCardTierList event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(
      state.copyWith(
        showSpellCardTierView: true,
        showWeaponModelView: false, // 关闭刀枪图鉴视图
        spellCardTierLoadState: LoadState.loading,
        spellCardTierFilter: event.type,
        clearSpellCardTierFilter: event.type == null,
        clearCategory: true,
        clearSelectedCharacter: true,
        clearSelectedWeaponModel: true, // 清除选中的刀枪模
        clearWeaponCharacter: true, // 清除角色信息
      ),
    );

    try {
      final response = await _api.getSpellCardTierList(
        type: event.type,
        keyword: event.keyword,
      );
      if (response != null) {
        // 默认展开第一个评级
        final initialExpandedTiers = <String>{};
        if (response.tiers.isNotEmpty) {
          initialExpandedTiers.add(response.tiers.first.tier);
        }

        emit(
          state.copyWith(
            spellCardTierLoadState: LoadState.success,
            spellCardTierGroups: response.tiers,
            spellCardTierTotalCount: response.totalCount,
            expandedTiers: initialExpandedTiers,
          ),
        );
      } else {
        emit(
          state.copyWith(
            spellCardTierLoadState: LoadState.failure,
            error: '获取符卡评级列表失败',
          ),
        );
      }
    } catch (e) {
      LogService.e('加载符卡评级列表失败: $e', e);
      emit(
        state.copyWith(
          spellCardTierLoadState: LoadState.failure,
          error: '加载失败，请稍后重试',
        ),
      );
    }
  }

  Future<void> _onNavigateToCharacterFromSpellCard(
    NavigateToCharacterFromSpellCard event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    // 保持符卡评级视图，只在右侧加载角色详情，并记录选中的符卡ID
    emit(
      state.copyWith(
        selectedSpellCardId: event.spellCardId,
        detailLoadState: LoadState.loading,
        previewPosition: 0,
        clearSelectedSubModel: true,
        spellCards: [],
        spellCardsLoadState: LoadState.initial,
        clearPendingRequest: true,
      ),
    );

    try {
      final results = await Future.wait([
        _api.getCharacterDetail(event.characterId),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);

      final character = results[0] as CharacterModel?;

      if (character != null) {
        // 优先使用传入的 subModelId，否则使用默认子模型
        int? targetSubModelId = event.subModelId;
        if (targetSubModelId == null) {
          targetSubModelId = character.defaultSubModelId;
          if (targetSubModelId == null &&
              character.subModels != null &&
              character.subModels!.isNotEmpty) {
            final defaultSubModel = character.subModels!.firstWhere(
              (s) => s.isDefault,
              orElse: () => character.subModels!.first,
            );
            targetSubModelId = defaultSubModel.id;
          }
        }

        emit(
          state.copyWith(
            detailLoadState: LoadState.success,
            selectedCharacter: character,
            selectedSubModelId: targetSubModelId,
          ),
        );

        // 如果有指定子模型，需要加载子模型详情以获取预览图
        if (event.subModelId != null && character.subModels != null) {
          final targetSubModel = character.subModels!.firstWhere(
            (s) => s.id == event.subModelId,
            orElse: () => character.subModels!.first,
          );
          // 如果子模型没有预览图，需要单独请求
          if (targetSubModel.preview == null) {
            try {
              final subModelDetail = await _api.getSubModelDetail(
                character.id,
                event.subModelId!,
              );
              if (subModelDetail != null && subModelDetail.preview != null) {
                final updatedSubModels = character.subModels!.map((s) {
                  if (s.id == event.subModelId) {
                    return CharacterSubModel(
                      id: s.id,
                      characterId: s.characterId,
                      name: s.name,
                      type: s.type,
                      description: subModelDetail.description ?? s.description,
                      thumbnailUrl: s.thumbnailUrl,
                      preview: subModelDetail.preview,
                      glbModelUrl: subModelDetail.glbModelUrl ?? s.glbModelUrl,
                      acquisition: subModelDetail.acquisition ?? s.acquisition,
                      isDefault: s.isDefault,
                      sortOrder: s.sortOrder,
                    );
                  }
                  return s;
                }).toList();

                final updatedCharacter = CharacterModel(
                  id: character.id,
                  name: character.name,
                  nameEn: character.nameEn,
                  category: character.category,
                  description: character.description,
                  thumbnailUrl: character.thumbnailUrl,
                  preview: character.preview,
                  glbModelUrl: character.glbModelUrl,
                  acquisition: character.acquisition,
                  subModels: updatedSubModels,
                  defaultSubModelId: character.defaultSubModelId,
                  spellCards: character.spellCards,
                  zombieSkills: character.zombieSkills,
                  createdAt: character.createdAt,
                  viewCount: character.viewCount,
                  contributorCount: character.contributorCount,
                );

                emit(state.copyWith(selectedCharacter: updatedCharacter));
              }
            } catch (e) {
              LogService.e('加载子模型详情失败: $e', e);
            }
          }
        }

        // 检查待审核状态
        if (targetSubModelId != null) {
          add(CheckPendingRequest(targetSubModelId));
        }

        if (character.category == CharacterCategory.touhou &&
            targetSubModelId != null) {
          add(
            LoadSpellCards(
              characterId: character.id,
              subModelId: targetSubModelId,
            ),
          );
        }
      } else {
        emit(
          state.copyWith(detailLoadState: LoadState.failure, error: '获取角色详情失败'),
        );
      }
    } catch (e) {
      LogService.e('加载角色详情失败: $e', e);
      emit(
        state.copyWith(detailLoadState: LoadState.failure, error: '加载失败，请稍后重试'),
      );
    }
  }

  void _onToggleTierExpanded(
    ToggleTierExpanded event,
    Emitter<CharacterGalleryState> emit,
  ) {
    // 只允许展开一个评级
    if (state.expandedTiers.contains(event.tier)) {
      // 当前已展开，点击则收起
      emit(state.copyWith(expandedTiers: <String>{}));
    } else {
      // 展开新的评级（自动收起其他）
      emit(state.copyWith(expandedTiers: {event.tier}));
    }
  }

  Future<void> _onLoadCharacterWeaponModels(
    LoadCharacterWeaponModels event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    emit(state.copyWith(weaponModelsLoadState: LoadState.loading));

    try {
      final results = await Future.wait([
        _api.getCharacterKnifeModels(event.characterId),
        _api.getCharacterGunModels(event.characterId),
      ]);

      final knifeResponse = results[0] as KnifeModelListResponse?;
      final gunResponse = results[1] as GunModelListResponse?;

      emit(
        state.copyWith(
          weaponModelsLoadState: LoadState.success,
          knifeModels: knifeResponse?.items ?? [],
          gunModels: gunResponse?.items ?? [],
        ),
      );
    } catch (e) {
      LogService.e('加载刀模/枪模失败: $e', e);
      emit(
        state.copyWith(
          weaponModelsLoadState: LoadState.failure,
          knifeModels: [],
          gunModels: [],
        ),
      );
    }
  }

  Future<void> _onLoadAllWeaponModels(
    LoadAllWeaponModels event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    final tabIndex = event.tabIndex ?? state.weaponModelTab;
    
    emit(state.copyWith(
      showWeaponModelView: true,
      showSpellCardTierView: false,
      allWeaponModelsLoadState: LoadState.loading,
      weaponModelTab: tabIndex,
      weaponModelKeyword: event.keyword,
      clearWeaponModelKeyword: event.keyword == null,
      clearCategory: true,
      clearSelectedCharacter: true,
      clearSelectedSpellCardId: true, // 清除选中的符卡
      clearSelectedWeaponModel: true, // 清除选中的刀枪模，避免搜索后右侧显示不在列表中的项
      clearWeaponCharacter: true,
    ));

    try {
      if (tabIndex == 0) {
        // 加载刀模
        final response = await _api.getAllKnifeModels(keyword: event.keyword);
        if (response != null) {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.success,
            allKnifeModels: response.items,
            allKnifeTotalCount: response.totalCount,
          ));
        } else {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.failure,
            error: '获取刀模列表失败',
          ));
        }
      } else {
        // 加载枪模
        final response = await _api.getAllGunModels(keyword: event.keyword);
        if (response != null) {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.success,
            allGunModels: response.items,
            allGunTotalCount: response.totalCount,
          ));
        } else {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.failure,
            error: '获取枪模列表失败',
          ));
        }
      }
    } catch (e) {
      LogService.e('加载刀枪图鉴失败: $e', e);
      emit(state.copyWith(
        allWeaponModelsLoadState: LoadState.failure,
        error: '加载失败，请稍后重试',
      ));
    }
  }

  void _onChangeWeaponModelTab(
    ChangeWeaponModelTab event,
    Emitter<CharacterGalleryState> emit,
  ) {
    if (event.tabIndex == state.weaponModelTab) return;
    // 切换标签页时清除选中状态并重新加载对应列表
    emit(state.copyWith(
      clearSelectedWeaponModel: true,
    ));
    add(LoadAllWeaponModels(
      keyword: state.weaponModelKeyword,
      tabIndex: event.tabIndex,
    ));
  }

  Future<void> _onSelectWeaponModel(
    SelectWeaponModel event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    // 先设置加载状态，清除之前的角色信息和选中的角色详情
    emit(state.copyWith(
      selectedWeaponModelId: event.id,
      selectedWeaponIsKnife: event.isKnife,
      weaponDetailLoadState: LoadState.loading,
      weaponPreviewPosition: 0, // 重置预览位置
      clearWeaponCharacter: true,
      clearSelectedCharacter: true, // 清除角色详情，以便显示刀枪模详情
    ));

    try {
      // 调用详情 API 获取完整数据
      KnifeModel? knifeDetail;
      GunModel? gunDetail;
      int? characterId;

      final results = await Future.wait([
        event.isKnife
            ? _api.getKnifeModelDetail(event.id)
            : _api.getGunModelDetail(event.id),
        Future.delayed(const Duration(milliseconds: 400)), // 最小加载时间
      ]);

      if (event.isKnife) {
        knifeDetail = results[0] as KnifeModel?;
        characterId = knifeDetail?.characterId;
      } else {
        gunDetail = results[0] as GunModel?;
        characterId = gunDetail?.characterId;
      }

      // 更新详情数据
      emit(state.copyWith(
        selectedKnifeModelDetail: knifeDetail,
        selectedGunModelDetail: gunDetail,
      ));

      // 如果有专属角色，获取角色信息
      if (characterId != null) {
        emit(state.copyWith(weaponCharacterLoadState: LoadState.loading));
        try {
          final character = await _api.getCharacterDetail(characterId);
          if (character != null) {
            // 获取默认子模型的缩略图
            final defaultSubModel = character.subModels?.firstWhere(
              (s) => s.isDefault,
              orElse: () => character.subModels!.first,
            );
            emit(state.copyWith(
              weaponDetailLoadState: LoadState.success,
              weaponCharacterLoadState: LoadState.success,
              weaponCharacterThumbnailUrl: defaultSubModel?.thumbnailUrl ?? character.thumbnailUrl,
              weaponCharacterAcquisition: character.acquisition,
            ));
          } else {
            emit(state.copyWith(
              weaponDetailLoadState: LoadState.success,
              weaponCharacterLoadState: LoadState.failure,
            ));
          }
        } catch (e) {
          LogService.e('获取刀枪模专属角色信息失败: $e', e);
          emit(state.copyWith(
            weaponDetailLoadState: LoadState.success,
            weaponCharacterLoadState: LoadState.failure,
          ));
        }
      } else {
        // 没有专属角色
        emit(state.copyWith(weaponDetailLoadState: LoadState.success));
      }
    } catch (e) {
      LogService.e('获取刀枪模详情失败: $e', e);
      emit(state.copyWith(
        weaponDetailLoadState: LoadState.failure,
        error: '获取详情失败',
      ));
    }
  }

  void _onClearSelectedWeaponModel(
    ClearSelectedWeaponModel event,
    Emitter<CharacterGalleryState> emit,
  ) {
    emit(state.copyWith(clearSelectedWeaponModel: true));
  }

  void _onChangeWeaponPreviewPosition(
    ChangeWeaponPreviewPosition event,
    Emitter<CharacterGalleryState> emit,
  ) {
    emit(state.copyWith(weaponPreviewPosition: event.position));
  }

  Future<void> _onNavigateToWeaponModel(
    NavigateToWeaponModel event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    // 切换到刀枪图鉴视图，并选中指定的刀枪模
    final tabIndex = event.isKnife ? 0 : 1;
    
    emit(state.copyWith(
      showWeaponModelView: true,
      showSpellCardTierView: false,
      allWeaponModelsLoadState: LoadState.loading,
      weaponModelTab: tabIndex,
      clearWeaponModelKeyword: true,
      clearCategory: true,
      clearSelectedCharacter: true,
      selectedWeaponModelId: event.id,
      selectedWeaponIsKnife: event.isKnife,
      weaponPreviewPosition: 0,
    ));

    try {
      if (event.isKnife) {
        final response = await _api.getAllKnifeModels();
        if (response != null) {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.success,
            allKnifeModels: response.items,
            allKnifeTotalCount: response.totalCount,
          ));
        } else {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.failure,
            error: '获取刀模列表失败',
          ));
        }
      } else {
        final response = await _api.getAllGunModels();
        if (response != null) {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.success,
            allGunModels: response.items,
            allGunTotalCount: response.totalCount,
          ));
        } else {
          emit(state.copyWith(
            allWeaponModelsLoadState: LoadState.failure,
            error: '获取枪模列表失败',
          ));
        }
      }
    } catch (e) {
      LogService.e('加载刀枪图鉴失败: $e', e);
      emit(state.copyWith(
        allWeaponModelsLoadState: LoadState.failure,
        error: '加载失败，请稍后重试',
      ));
    }
  }

  /// 在刀枪图鉴视图中加载角色详情（保持左侧列表不变，只切换右侧详情面板）
  Future<void> _onLoadCharacterDetailInWeaponView(
    LoadCharacterDetailInWeaponView event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    // 清除选中的刀枪模，开始加载角色详情
    emit(state.copyWith(
      detailLoadState: LoadState.loading,
      loadingCharacterId: event.characterId,
      previewPosition: 0,
      clearSelectedCharacter: true,
      clearSelectedSubModel: true,
      clearSelectedWeaponModel: true,
      clearWeaponCharacter: true,
      spellCards: [],
      spellCardsLoadState: LoadState.initial,
      clearPendingRequest: true,
      // 保持刀枪图鉴视图不变
      // showWeaponModelView 不改变
    ));

    try {
      final results = await Future.wait([
        _api.getCharacterDetail(event.characterId),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);

      final character = results[0] as CharacterModel?;

      if (character != null) {
        int? defaultSubModelId = character.defaultSubModelId;
        if (defaultSubModelId == null &&
            character.subModels != null &&
            character.subModels!.isNotEmpty) {
          final defaultSubModel = character.subModels!.firstWhere(
            (s) => s.isDefault,
            orElse: () => character.subModels!.first,
          );
          defaultSubModelId = defaultSubModel.id;
        }

        emit(state.copyWith(
          detailLoadState: LoadState.success,
          selectedCharacter: character,
          selectedSubModelId: defaultSubModelId,
        ));

        // 检查待审核状态
        if (defaultSubModelId != null) {
          add(CheckPendingRequest(defaultSubModelId));
        }

        if (character.category == CharacterCategory.touhou &&
            defaultSubModelId != null) {
          add(LoadSpellCards(
            characterId: character.id,
            subModelId: defaultSubModelId,
          ));
        }

        // 加载角色专属刀模/枪模
        add(LoadCharacterWeaponModels(character.id));
      } else {
        emit(state.copyWith(
          detailLoadState: LoadState.failure,
          error: '获取角色详情失败',
        ));
      }
    } catch (e) {
      LogService.e('加载角色详情失败: $e', e);
      emit(state.copyWith(
        detailLoadState: LoadState.failure,
        error: '加载失败，请稍后重试',
      ));
    }
  }

  /// 在角色图鉴视图中加载刀枪模详情（保持左侧列表不变，只切换右侧详情面板）
  Future<void> _onLoadWeaponModelDetailInCharacterView(
    LoadWeaponModelDetailInCharacterView event,
    Emitter<CharacterGalleryState> emit,
  ) async {
    // 清除选中的角色，开始加载刀枪模详情
    emit(state.copyWith(
      selectedWeaponModelId: event.id,
      selectedWeaponIsKnife: event.isKnife,
      weaponDetailLoadState: LoadState.loading,
      weaponPreviewPosition: 0,
      clearSelectedCharacter: true,
      clearSelectedSubModel: true,
      clearWeaponCharacter: true,
      spellCards: [],
      spellCardsLoadState: LoadState.initial,
      clearPendingRequest: true,
      // 保持角色图鉴视图不变
      // showWeaponModelView 不改变
    ));

    try {
      // 调用详情 API 获取完整数据
      KnifeModel? knifeDetail;
      GunModel? gunDetail;
      int? characterId;

      final results = await Future.wait([
        event.isKnife
            ? _api.getKnifeModelDetail(event.id)
            : _api.getGunModelDetail(event.id),
        Future.delayed(const Duration(milliseconds: 400)),
      ]);

      if (event.isKnife) {
        knifeDetail = results[0] as KnifeModel?;
        characterId = knifeDetail?.characterId;
      } else {
        gunDetail = results[0] as GunModel?;
        characterId = gunDetail?.characterId;
      }

      // 更新详情数据
      emit(state.copyWith(
        selectedKnifeModelDetail: knifeDetail,
        selectedGunModelDetail: gunDetail,
      ));

      // 如果有专属角色，获取角色信息
      if (characterId != null) {
        emit(state.copyWith(weaponCharacterLoadState: LoadState.loading));
        try {
          final character = await _api.getCharacterDetail(characterId);
          if (character != null) {
            final defaultSubModel = character.subModels?.firstWhere(
              (s) => s.isDefault,
              orElse: () => character.subModels!.first,
            );
            emit(state.copyWith(
              weaponDetailLoadState: LoadState.success,
              weaponCharacterLoadState: LoadState.success,
              weaponCharacterThumbnailUrl: defaultSubModel?.thumbnailUrl ?? character.thumbnailUrl,
              weaponCharacterAcquisition: character.acquisition,
            ));
          } else {
            emit(state.copyWith(
              weaponDetailLoadState: LoadState.success,
              weaponCharacterLoadState: LoadState.failure,
            ));
          }
        } catch (e) {
          LogService.e('获取刀枪模专属角色信息失败: $e', e);
          emit(state.copyWith(
            weaponDetailLoadState: LoadState.success,
            weaponCharacterLoadState: LoadState.failure,
          ));
        }
      } else {
        emit(state.copyWith(weaponDetailLoadState: LoadState.success));
      }
    } catch (e) {
      LogService.e('加载刀枪模详情失败: $e', e);
      emit(state.copyWith(
        weaponDetailLoadState: LoadState.failure,
        error: '加载失败，请稍后重试',
      ));
    }
  }
}
