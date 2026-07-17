import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/server_api.dart';
import '../../../../core/services/game_path_service.dart';
import '../../../../core/utils/log_service.dart';
import '../../../../core/utils/native_process_utils.dart';
import '../../../../core/utils/vdf_parser.dart';
import 'map_manage_event.dart';
import 'map_manage_state.dart';

class MapManageBloc extends Bloc<MapManageEvent, MapManageState> {
  final ServerApi _api = ServerApi();

  MapManageBloc() : super(const MapManageState()) {
    on<ScanLocalMaps>(_onScanLocalMaps);
    on<FetchPreviewMapInfo>(_onFetchPreviewMapInfo);
    on<CheckSteamStatus>(_onCheckSteamStatus);
    on<ToggleMapSelection>(_onToggleMapSelection);
    on<SelectAllMaps>(_onSelectAllMaps);
    on<InvertSelection>(_onInvertSelection);
    on<SetFilter>(_onSetFilter);
    on<PreviewMap>(_onPreviewMap);
    on<DeleteSelectedMaps>(_onDeleteSelectedMaps);
    on<ClearMapManageError>((event, emit) => emit(state.copyWith(clearError: true)));
  }

  Future<void> _onScanLocalMaps(ScanLocalMaps event, Emitter<MapManageState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final steamPath = await GamePathService().getSteamPath();
      if (steamPath == null || steamPath.isEmpty) {
        emit(state.copyWith(isLoading: false, error: '未配置 Steam 路径，请在设置中配置。'));
        return;
      }

      final acfPath = '$steamPath\\steamapps\\workshop\\appworkshop_730.acf';
      final acfFile = File(acfPath);
      if (!await acfFile.exists()) {
        emit(state.copyWith(isLoading: false, error: '未找到 appworkshop_730.acf 文件，可能没有下载任何地图。'));
        return;
      }

      final content = await acfFile.readAsString();
      final editor = VdfEditor(content);
      
      final itemsNode = editor.findObjectNode(['AppWorkshop', 'WorkshopItemsInstalled']);
      if (itemsNode == null) {
        emit(state.copyWith(isLoading: false, localMaps: []));
        return;
      }

      final List<LocalMapItem> maps = [];
      final workshopPath = '$steamPath\\steamapps\\workshop\\content\\730';

      for (final prop in itemsNode.properties) {
        final mapId = prop.key.value;
        if (prop.value is VdfObjectNode) {
          final obj = prop.value as VdfObjectNode;
          int timeUpdated = 0;
          int size = 0;
          for (final innerProp in obj.properties) {
            if (innerProp.key.value == 'timeupdated' && innerProp.value is VdfStringNode) {
              timeUpdated = int.tryParse((innerProp.value as VdfStringNode).value) ?? 0;
            } else if (innerProp.key.value == 'size' && innerProp.value is VdfStringNode) {
              size = int.tryParse((innerProp.value as VdfStringNode).value) ?? 0;
            }
          }

          final mapFolder = '$workshopPath\\$mapId';
          final publishDataPath = '$mapFolder\\publish_data.txt';
          String title = mapId;
          final pdFile = File(publishDataPath);
          if (await pdFile.exists()) {
            try {
              final pdContent = await pdFile.readAsString();
              final pdEditor = VdfEditor(pdContent);
              final t = pdEditor.getStringValue(['publish_data', 'title']);
              if (t != null && t.isNotEmpty) {
                title = t;
              }
            } catch (e) {
              // 忽略单个文件的解析错误，使用默认标题（ID）
            }
          }

          maps.add(LocalMapItem(
            id: mapId,
            title: title,
            timeUpdated: timeUpdated,
            size: size,
            folderPath: mapFolder,
          ));
        }
      }

      emit(state.copyWith(
        isLoading: false,
        localMaps: maps,
      ));

      // 触发检查Steam状态
      add(CheckSteamStatus());

    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '扫描本地地图失败: $e'));
    }
  }

  Future<void> _onFetchPreviewMapInfo(FetchPreviewMapInfo event, Emitter<MapManageState> emit) async {
    try {
      LogService.d('Fetching map info for: ${event.mapName}');
      final info = await _api.getMapInfo(event.mapName);
      
      if (info != null) {
        LogService.d('Successfully fetched map info for: ${event.mapName}');
        emit(state.copyWith(previewMapInfo: info));
      } else {
        LogService.d('Map info API returned empty for: ${event.mapName}');
      }
    } catch (e) {
      LogService.e('Failed to fetch map info for ${event.mapName}: $e');
    }
  }

  Future<void> _onCheckSteamStatus(CheckSteamStatus event, Emitter<MapManageState> emit) async {
    final isRunning = NativeProcessUtils.isAnyProcessRunning(['steam.exe']);
    emit(state.copyWith(isSteamRunning: isRunning));
  }

  void _onToggleMapSelection(ToggleMapSelection event, Emitter<MapManageState> emit) {
    final newSelected = Set<String>.from(state.selectedMapIds);
    if (event.isSelected) {
      newSelected.add(event.mapId);
    } else {
      newSelected.remove(event.mapId);
    }
    emit(state.copyWith(selectedMapIds: newSelected));
  }

  void _onSelectAllMaps(SelectAllMaps event, Emitter<MapManageState> emit) {
    if (event.select) {
      final allIds = state.displayMaps.map((e) => e.id).toSet();
      emit(state.copyWith(selectedMapIds: allIds));
    } else {
      emit(state.copyWith(selectedMapIds: {}));
    }
  }

  void _onInvertSelection(InvertSelection event, Emitter<MapManageState> emit) {
    final allIds = state.displayMaps.map((e) => e.id).toSet();
    final newSelected = allIds.difference(state.selectedMapIds);
    emit(state.copyWith(selectedMapIds: newSelected));
  }

  void _onSetFilter(SetFilter event, Emitter<MapManageState> emit) {
    emit(state.copyWith(
      searchQuery: event.searchQuery,
      filterType: event.filterType,
    ));
  }

  void _onPreviewMap(PreviewMap event, Emitter<MapManageState> emit) {
    if (event.mapId == null) {
      emit(state.copyWith(clearPreview: true));
    } else {
      emit(state.copyWith(previewMapId: event.mapId, clearPreviewMapInfo: true));
      // Trigger fetch for preview map info
      final mapItem = state.localMaps.where((m) => m.id == event.mapId).firstOrNull;
      if (mapItem != null) {
        add(FetchPreviewMapInfo(mapItem.title));
      }
    }
  }

  Future<void> _onDeleteSelectedMaps(DeleteSelectedMaps event, Emitter<MapManageState> emit) async {
    if (state.selectedMapIds.isEmpty) return;
    
    // 再次检测Steam状态
    if (NativeProcessUtils.isAnyProcessRunning(['steam.exe'])) {
      emit(state.copyWith(error: 'Steam 正在运行，请先完全退出 Steam 后再进行地图管理操作。'));
      emit(state.copyWith(isSteamRunning: true));
      return;
    }

    emit(state.copyWith(isDeleting: true, clearError: true));

    try {
      final steamPath = await GamePathService().getSteamPath();
      if (steamPath == null) throw Exception('Steam 路径无效');

      final acfPath = '$steamPath\\steamapps\\workshop\\appworkshop_730.acf';
      final acfFile = File(acfPath);
      final content = await acfFile.readAsString();
      final editor = VdfEditor(content);

      bool acfModified = false;
      final List<String> failedMaps = [];

      for (final mapId in state.selectedMapIds) {
        final mapItem = state.localMaps.firstWhere((m) => m.id == mapId);
        final folder = Directory(mapItem.folderPath);
        
        try {
          // 删除文件夹
          if (await folder.exists()) {
            await folder.delete(recursive: true);
          }

          // 删除 ACF 节点 (仅在文件夹删除成功后执行)
          final deleted1 = editor.deleteProperty(['AppWorkshop', 'WorkshopItemsInstalled'], mapId);
          final deleted2 = editor.deleteProperty(['AppWorkshop', 'WorkshopItemDetails'], mapId);
          if (deleted1 || deleted2) {
            acfModified = true;
          }
        } catch (e) {
          // 如果该地图删除失败，记录下来，不中断其他地图的删除
          failedMaps.add('${mapItem.title} (ID: $mapId)');
        }
      }

      if (acfModified) {
        await acfFile.writeAsString(editor.toText());
      }

      // 重新扫描
      add(ScanLocalMaps());

      if (failedMaps.isNotEmpty) {
        emit(state.copyWith(
          isDeleting: false,
          error: '部分地图删除失败（可能文件被占用）:\n${failedMaps.join('\n')}',
        ));
      } else {
        // 清除选中和预览状态
        emit(state.copyWith(
          isDeleting: false,
          selectedMapIds: {},
          clearPreview: true,
        ));
      }
      
    } catch (e) {
      emit(state.copyWith(isDeleting: false, error: '删除失败: $e'));
    }
  }
}
