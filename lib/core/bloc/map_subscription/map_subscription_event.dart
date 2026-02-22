part of 'map_subscription_bloc.dart';

/// 地图订阅事件
sealed class MapSubscriptionEvent extends Equatable {
  const MapSubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// 加载订阅列表
class MapSubscriptionLoad extends MapSubscriptionEvent {
  const MapSubscriptionLoad();
}

/// 加载可用分类列表
class MapSubscriptionLoadCategories extends MapSubscriptionEvent {
  const MapSubscriptionLoadCategories();
}

/// 添加地图订阅（含分类范围）
class MapSubscriptionAdd extends MapSubscriptionEvent {
  final String mapName;
  final String mapLabel;
  final String? mapBackground;
  final List<String> categoryNames;

  const MapSubscriptionAdd({
    required this.mapName,
    required this.mapLabel,
    this.mapBackground,
    this.categoryNames = const [],
  });

  @override
  List<Object?> get props => [mapName, mapLabel, mapBackground, categoryNames];
}

/// 移除地图订阅
class MapSubscriptionRemove extends MapSubscriptionEvent {
  final String mapName;

  const MapSubscriptionRemove({required this.mapName});

  @override
  List<Object?> get props => [mapName];
}

/// 更新全局分类范围
class MapSubscriptionUpdateScope extends MapSubscriptionEvent {
  final List<String> categoryNames;

  const MapSubscriptionUpdateScope({
    required this.categoryNames,
  });

  @override
  List<Object?> get props => [categoryNames];
}

/// 切换全局开关
class MapSubscriptionToggleGlobal extends MapSubscriptionEvent {
  final bool enabled;

  const MapSubscriptionToggleGlobal({required this.enabled});

  @override
  List<Object?> get props => [enabled];
}

/// 切换通知开关
class MapSubscriptionToggleNotification extends MapSubscriptionEvent {
  final bool enabled;

  const MapSubscriptionToggleNotification({required this.enabled});

  @override
  List<Object?> get props => [enabled];
}

/// 切换全局 TTS 开关
class MapSubscriptionToggleGlobalTts extends MapSubscriptionEvent {
  final bool enabled;

  const MapSubscriptionToggleGlobalTts({required this.enabled});

  @override
  List<Object?> get props => [enabled];
}

/// 搜索地图
class MapSubscriptionSearchMaps extends MapSubscriptionEvent {
  final String query;
  final bool loadMore;

  const MapSubscriptionSearchMaps({
    required this.query,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [query, loadMore];
}

/// 下载 TTS 模型（支持指定模型ID）
class MapSubscriptionDownloadTtsModel extends MapSubscriptionEvent {
  final String? modelId;
  /// 是否使用加速下载地址（国内镜像）
  final bool useAcceleration;

  const MapSubscriptionDownloadTtsModel({
    this.modelId,
    this.useAcceleration = false,
  });

  @override
  List<Object?> get props => [modelId, useAcceleration];
}

/// 取消下载 TTS 模型
class MapSubscriptionCancelTtsDownload extends MapSubscriptionEvent {
  const MapSubscriptionCancelTtsDownload();
}

/// 删除 TTS 模型（支持指定模型ID）
class MapSubscriptionDeleteTtsModel extends MapSubscriptionEvent {
  final String? modelId;

  const MapSubscriptionDeleteTtsModel({this.modelId});

  @override
  List<Object?> get props => [modelId];
}

/// TTS 下载进度更新（内部使用）
class MapSubscriptionTtsProgressUpdate extends MapSubscriptionEvent {
  final TtsDownloadProgress progress;

  const MapSubscriptionTtsProgressUpdate({required this.progress});

  @override
  List<Object?> get props => [progress];
}

/// 设置 TTS 音量
class MapSubscriptionSetTtsVolume extends MapSubscriptionEvent {
  final double volume;

  const MapSubscriptionSetTtsVolume({required this.volume});

  @override
  List<Object?> get props => [volume];
}

/// 设置 TTS 语速
class MapSubscriptionSetTtsSpeed extends MapSubscriptionEvent {
  final double speed;

  const MapSubscriptionSetTtsSpeed({required this.speed});

  @override
  List<Object?> get props => [speed];
}

/// 设置 TTS 说话人 ID
class MapSubscriptionSetTtsSpeakerId extends MapSubscriptionEvent {
  final int speakerId;

  const MapSubscriptionSetTtsSpeakerId({required this.speakerId});

  @override
  List<Object?> get props => [speakerId];
}

/// 选择 TTS 模型
class MapSubscriptionSelectTtsModel extends MapSubscriptionEvent {
  final String modelId;

  const MapSubscriptionSelectTtsModel({required this.modelId});

  @override
  List<Object?> get props => [modelId];
}

/// 导入本地 TTS 模型
class MapSubscriptionImportTtsModel extends MapSubscriptionEvent {
  final String sourcePath;
  final String modelId;

  const MapSubscriptionImportTtsModel({
    required this.sourcePath,
    required this.modelId,
  });

  @override
  List<Object?> get props => [sourcePath, modelId];
}

/// 测试 TTS 播报
class MapSubscriptionTestTts extends MapSubscriptionEvent {
  const MapSubscriptionTestTts();
}

/// 设置通知冷却时间
class MapSubscriptionSetCooldown extends MapSubscriptionEvent {
  final int seconds;

  const MapSubscriptionSetCooldown({required this.seconds});

  @override
  List<Object?> get props => [seconds];
}

/// TTS 测试阶段更新（内部使用）
class _MapSubscriptionTtsPhaseUpdate extends MapSubscriptionEvent {
  final String phase;

  const _MapSubscriptionTtsPhaseUpdate({required this.phase});

  @override
  List<Object?> get props => [phase];
}
