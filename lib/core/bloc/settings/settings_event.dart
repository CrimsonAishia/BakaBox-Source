import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'settings_state.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsInit extends SettingsEvent {}

class SettingsSetThemeMode extends SettingsEvent {
  final ThemeMode themeMode;
  const SettingsSetThemeMode(this.themeMode);
  @override
  List<Object?> get props => [themeMode];
}

class SettingsToggleDarkMode extends SettingsEvent {}

class SettingsClearCache extends SettingsEvent {}

class SettingsRefreshCacheSize extends SettingsEvent {}

class SettingsCheckForUpdates extends SettingsEvent {}

class SettingsExportLogs extends SettingsEvent {}

// 游戏设置事件
class SettingsSetGamePath extends SettingsEvent {
  final String path;
  const SettingsSetGamePath(this.path);
  @override
  List<Object?> get props => [path];
}

class SettingsSetSteamPath extends SettingsEvent {
  final String path;
  const SettingsSetSteamPath(this.path);
  @override
  List<Object?> get props => [path];
}

class SettingsDetectGamePath extends SettingsEvent {}

class SettingsDetectSteamPath extends SettingsEvent {}

class SettingsSetLaunchPlatform extends SettingsEvent {
  final LaunchPlatformType platform;
  const SettingsSetLaunchPlatform(this.platform);
  @override
  List<Object?> get props => [platform];
}

class SettingsSetLaunchOptions extends SettingsEvent {
  final List<String> options;
  const SettingsSetLaunchOptions(this.options);
  @override
  List<Object?> get props => [options];
}

class SettingsAddLaunchOption extends SettingsEvent {
  final String option;
  const SettingsAddLaunchOption(this.option);
  @override
  List<Object?> get props => [option];
}

class SettingsRemoveLaunchOption extends SettingsEvent {
  final String option;
  const SettingsRemoveLaunchOption(this.option);
  @override
  List<Object?> get props => [option];
}

// 清除路径事件
class SettingsClearGamePath extends SettingsEvent {}

class SettingsClearSteamPath extends SettingsEvent {}

// 音效设置事件
class SettingsSetAudioVolume extends SettingsEvent {
  final double volume;
  const SettingsSetAudioVolume(this.volume);
  @override
  List<Object?> get props => [volume];
}

class SettingsTestAudio extends SettingsEvent {}

// 详细缓存管理事件
class SettingsLoadCacheDetails extends SettingsEvent {}

class SettingsClearCacheByType extends SettingsEvent {
  final CacheType cacheType;
  const SettingsClearCacheByType(this.cacheType);
  @override
  List<Object?> get props => [cacheType];
}

class SettingsClearAllCache extends SettingsEvent {}

class SettingsClearSelectedCache extends SettingsEvent {
  final List<CacheType> cacheTypes;
  const SettingsClearSelectedCache(this.cacheTypes);
  @override
  List<Object?> get props => [cacheTypes];
}

// 通知位置设置事件
class SettingsSetNotificationPosition extends SettingsEvent {
  final NotificationPositionType position;
  const SettingsSetNotificationPosition(this.position);
  @override
  List<Object?> get props => [position];
}

// 浮窗位置设置事件
class SettingsSetFloatingWindowPosition extends SettingsEvent {
  final NotificationPositionType position;
  const SettingsSetFloatingWindowPosition(this.position);
  @override
  List<Object?> get props => [position];
}
