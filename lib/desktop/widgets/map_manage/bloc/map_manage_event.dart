import 'package:equatable/equatable.dart';

abstract class MapManageEvent extends Equatable {
  const MapManageEvent();

  @override
  List<Object?> get props => [];
}

/// 扫描本地地图
class ScanLocalMaps extends MapManageEvent {}

/// 获取预览地图的信息
class FetchPreviewMapInfo extends MapManageEvent {
  final String mapName;
  const FetchPreviewMapInfo(this.mapName);

  @override
  List<Object?> get props => [mapName];
}

/// 定期检测Steam状态
class CheckSteamStatus extends MapManageEvent {}

/// 选择地图
class ToggleMapSelection extends MapManageEvent {
  final String mapId;
  final bool isSelected;
  const ToggleMapSelection(this.mapId, this.isSelected);

  @override
  List<Object?> get props => [mapId, isSelected];
}

/// 全选/反选
class SelectAllMaps extends MapManageEvent {
  final bool select;
  const SelectAllMaps(this.select);

  @override
  List<Object?> get props => [select];
}

class InvertSelection extends MapManageEvent {}

/// 设置搜索/过滤条件
class SetFilter extends MapManageEvent {
  final String? searchQuery;
  final String? filterType;
  const SetFilter({this.searchQuery, this.filterType});

  @override
  List<Object?> get props => [searchQuery, filterType];
}

/// 预览地图
class PreviewMap extends MapManageEvent {
  final String? mapId;
  const PreviewMap(this.mapId);

  @override
  List<Object?> get props => [mapId];
}

/// 删除选中地图
class DeleteSelectedMaps extends MapManageEvent {}

class ClearMapManageError extends MapManageEvent {}
