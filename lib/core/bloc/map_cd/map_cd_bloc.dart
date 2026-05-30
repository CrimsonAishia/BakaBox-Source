import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/map_cd_api.dart';
import '../../utils/log_service.dart';
import 'map_cd_event.dart';
import 'map_cd_state.dart';

/// 地图CD Bloc
///
/// 功能：
/// - 按需加载地图CD信息
/// - 客户端60秒缓存（与服务端一致）
/// - 避免重复请求
class MapCdBloc extends Bloc<MapCdEvent, MapCdState> {
  MapCdBloc() : super(const MapCdState()) {
    on<LoadMapCd>(_onLoadMapCd);
    on<ClearMapCdCache>(_onClearMapCdCache);
  }

  Future<void> _onLoadMapCd(LoadMapCd event, Emitter<MapCdState> emit) async {
    final mapName = event.mapName;

    // 如果缓存有效，直接返回
    if (state.isCacheValid(mapName)) {
      LogService.d('[MapCdBloc] 使用缓存: $mapName');
      return;
    }

    // 如果正在加载，避免重复请求
    if (state.isLoading(mapName)) {
      LogService.d('[MapCdBloc] 已在加载中，跳过: $mapName');
      return;
    }

    // 开始加载
    emit(
      state.copyWith(
        loadingMaps: {...state.loadingMaps, mapName},
        errorCache: {...state.errorCache}..remove(mapName),
      ),
    );

    try {
      LogService.d('[MapCdBloc] 请求地图CD: $mapName');
      final cdInfo = await MapCdApi.getMapCd(mapName);

      emit(
        state.copyWith(
          cdCache: {...state.cdCache, mapName: cdInfo},
          loadingMaps: {...state.loadingMaps}..remove(mapName),
          cacheTimestamps: {...state.cacheTimestamps, mapName: DateTime.now()},
        ),
      );

      if (cdInfo == null) {
        LogService.d('[MapCdBloc] 地图不存在: $mapName');
      } else {
        LogService.d('[MapCdBloc] 加载成功: $mapName, CD=${cdInfo.currentCd}');
      }
    } catch (e) {
      LogService.e('[MapCdBloc] 加载失败: $mapName', e);
      emit(
        state.copyWith(
          loadingMaps: {...state.loadingMaps}..remove(mapName),
          errorCache: {...state.errorCache, mapName: e.toString()},
        ),
      );
    }
  }

  Future<void> _onClearMapCdCache(
    ClearMapCdCache event,
    Emitter<MapCdState> emit,
  ) async {
    if (event.mapName == null) {
      // 清除所有缓存
      LogService.d('[MapCdBloc] 清除所有缓存');
      emit(const MapCdState());
    } else {
      // 清除指定地图的缓存
      LogService.d('[MapCdBloc] 清除缓存: ${event.mapName}');
      emit(
        state.copyWith(
          cdCache: {...state.cdCache}..remove(event.mapName),
          errorCache: {...state.errorCache}..remove(event.mapName),
          cacheTimestamps: {...state.cacheTimestamps}..remove(event.mapName),
        ),
      );
    }
  }
}
