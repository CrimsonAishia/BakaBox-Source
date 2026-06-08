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

class SettingsCheckPathsValidity extends SettingsEvent {}

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

class SettingsSetWarmupAudioVolume extends SettingsEvent {
  final double volume;
  const SettingsSetWarmupAudioVolume(this.volume);
  @override
  List<Object?> get props => [volume];
}

class SettingsTestWarmupAudio extends SettingsEvent {}

// 详细缓存管理事件
class SettingsLoadCacheDetails extends SettingsEvent {}

class SettingsClearCacheByType extends SettingsEvent {
  final CacheType cacheType;
  const SettingsClearCacheByType(this.cacheType);
  @override
  List<Object?> get props => [cacheType];
}

// 移动端缓存管理事件
class SettingsLoadMobileCacheDetails extends SettingsEvent {}

class SettingsClearMobileCacheByType extends SettingsEvent {
  final MobileCacheType cacheType;
  const SettingsClearMobileCacheByType(this.cacheType);
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

// 热身通知开关事件
class SettingsSetWarmupNotificationEnabled extends SettingsEvent {
  final bool enabled;
  const SettingsSetWarmupNotificationEnabled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

// 更新日志通知开关事件
class SettingsSetUpdateLogNotificationEnabled extends SettingsEvent {
  final bool enabled;
  const SettingsSetUpdateLogNotificationEnabled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

// 主窗口关闭行为设置事件
class SettingsSetAppExitBehavior extends SettingsEvent {
  final AppExitBehavior behavior;
  const SettingsSetAppExitBehavior(this.behavior);
  @override
  List<Object?> get props => [behavior];
}

// 服务器排序模式设置事件
class SettingsSetServerSortMode extends SettingsEvent {
  final ServerSortMode mode;
  const SettingsSetServerSortMode(this.mode);
  @override
  List<Object?> get props => [mode];
}

// 广播通知方式设置事件
class SettingsSetBroadcastNotificationType extends SettingsEvent {
  final BroadcastNotificationType notificationType;
  const SettingsSetBroadcastNotificationType(this.notificationType);
  @override
  List<Object?> get props => [notificationType];
}

// ==================== 黑名单管理事件 ====================

/// 加载黑名单列表
class SettingsLoadBlocklist extends SettingsEvent {}

/// 拉黑用户
class SettingsBlockUser extends SettingsEvent {
  final int userId;
  final String userName;
  const SettingsBlockUser({required this.userId, required this.userName});
  @override
  List<Object?> get props => [userId, userName];
}

/// 取消拉黑用户
class SettingsUnblockUser extends SettingsEvent {
  final int userId;
  const SettingsUnblockUser(this.userId);
  @override
  List<Object?> get props => [userId];
}

// ==================== 弱网模式 ====================

/// 切换弱网模式
class SettingsSetWeakNetworkMode extends SettingsEvent {
  final bool enabled;
  const SettingsSetWeakNetworkMode(this.enabled);
  @override
  List<Object?> get props => [enabled];
}
