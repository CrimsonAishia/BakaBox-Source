// ============================================================
// STUB FILE - Private implementation not included in open source
// See: https://github.com/CrimsonAishia/BakaBox-Core (private)
// ============================================================

import '../models/character_models.dart';

class CharacterApi {
  Future<CharacterListResponse?> getCharacterList({
    int pageIndex = 1,
    int pageSize = 20,
    CharacterCategory? category,
    String? keyword,
    String? orderBy,
    String? sortBy,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<CharacterModel?> getCharacterDetail(int characterId) async {
    throw UnimplementedError('Stub');
  }

  Future<CharacterSubModel?> getSubModelDetail(int characterId, int subModelId) async {
    throw UnimplementedError('Stub');
  }

  Future<Map<SpellCardType, List<SpellCard>>?> getSpellCards(int characterId, {required int subModelId}) async {
    throw UnimplementedError('Stub');
  }

  Future<Map<ZombieSkillType, List<ZombieSkill>>?> getZombieSkills(int characterId) async {
    throw UnimplementedError('Stub');
  }

  Future<SubModelUnifiedEditResponse?> editSubModelUnified(
    int characterId,
    int subModelId,
    SubModelUnifiedEditRequest request,
  ) async {
    throw UnimplementedError('Stub');
  }

  Future<MyEditRequestListResponse?> getMyEditRequests({
    int pageIndex = 1,
    int pageSize = 20,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<ContentEditHistoryResponse?> getContentEditHistory({
    required EditTargetType targetType,
    required int targetId,
    int pageIndex = 1,
    int pageSize = 20,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<UnifiedEditHistoryResponse?> getUnifiedEditHistory({
    required int subModelId,
    int pageIndex = 1,
    int pageSize = 20,
  }) async {
    throw UnimplementedError('Stub');
  }

  Future<PendingRequestCheckResponse?> checkPendingRequest(int subModelId) async {
    throw UnimplementedError('Stub');
  }

  Future<EditRequestOperationResponse?> updateEditRequest(
    int requestId,
    SubModelUnifiedEditRequest request,
  ) async {
    throw UnimplementedError('Stub');
  }

  Future<EditRequestOperationResponse?> deleteEditRequest(int requestId) async {
    throw UnimplementedError('Stub');
  }

  Future<EditRequestDetailResponse?> getEditRequestDetail(int requestId) async {
    throw UnimplementedError('Stub');
  }

  Future<SpellCardTierListResponse?> getSpellCardTierList({SpellCardType? type, String? keyword, String? sortBy}) async {
    throw UnimplementedError('Stub');
  }

  Future<KnifeModelListResponse?> getCharacterKnifeModels(int characterId) async {
    throw UnimplementedError('Stub');
  }

  Future<GunModelListResponse?> getCharacterGunModels(int characterId) async {
    throw UnimplementedError('Stub');
  }

  Future<KnifeModelListResponse?> getUniversalKnifeModels() async {
    throw UnimplementedError('Stub');
  }

  Future<GunModelListResponse?> getUniversalGunModels() async {
    throw UnimplementedError('Stub');
  }

  Future<AllKnifeModelsResponse?> getAllKnifeModels({String? keyword}) async {
    throw UnimplementedError('Stub');
  }

  Future<AllGunModelsResponse?> getAllGunModels({String? keyword}) async {
    throw UnimplementedError('Stub');
  }

  Future<KnifeModel?> getKnifeModelDetail(int id) async {
    throw UnimplementedError('Stub');
  }

  Future<GunModel?> getGunModelDetail(int id) async {
    throw UnimplementedError('Stub');
  }
}
