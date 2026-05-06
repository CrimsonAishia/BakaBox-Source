import 'package:equatable/equatable.dart';

/// 地图CD事件
abstract class MapCdEvent extends Equatable {
  const MapCdEvent();

  @override
  List<Object?> get props => [];
}

/// 加载地图CD
class LoadMapCd extends MapCdEvent {
  final String mapName;

  const LoadMapCd(this.mapName);

  @override
  List<Object?> get props => [mapName];
}

/// 清除地图CD缓存
class ClearMapCdCache extends MapCdEvent {
  final String? mapName; // null表示清除所有缓存

  const ClearMapCdCache([this.mapName]);

  @override
  List<Object?> get props => [mapName];
}
