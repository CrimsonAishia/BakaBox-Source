import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 启动平台枚举
enum LaunchPlatformType {
  worldwide, // 国际版 (Steam)
  perfect, // 完美世界
}

/// 通知位置枚举
enum NotificationPositionType {
  topLeft, // 左上角
  topCenter, // 顶部居中
  topRight, // 右上角
  centerLeft, // 左侧居中
  center, // 正中间
  centerRight, // 右侧居中
  bottomLeft, // 左下角
  bottomCenter, // 底部居中
  bottomRight, // 右下角
}

/// 通知位置扩展
extension NotificationPositionTypeExtension on NotificationPositionType {
  String get displayName {
    switch (this) {
      case NotificationPositionType.topLeft:
        return '左上角';
      case NotificationPositionType.topCenter:
        return '顶部居中';
      case NotificationPositionType.topRight:
        return '右上角';
      case NotificationPositionType.centerLeft:
        return '左侧居中';
      case NotificationPositionType.center:
        return '正中间';
      case NotificationPositionType.centerRight:
        return '右侧居中';
      case NotificationPositionType.bottomLeft:
        return '左下角';
      case NotificationPositionType.bottomCenter:
        return '底部居中';
      case NotificationPositionType.bottomRight:
        return '右下角';
    }
  }
}

/// 关闭主窗口时的行为
enum AppExitBehavior {
  ask, // 每次询问
  exit, // 直接退出程序
  minimizeToTray, // 最小化到系统托盘
}

/// 关闭行为扩展
extension AppExitBehaviorExtension on AppExitBehavior {
  String get displayName {
    switch (this) {
      case AppExitBehavior.ask:
        return '每次询问';
      case AppExitBehavior.exit:
        return '直接退出程序';
      case AppExitBehavior.minimizeToTray:
        return '隐藏到系统托盘';
    }
  }

  String get description {
    switch (this) {
      case AppExitBehavior.ask:
        return '关闭窗口时弹出确认对话框，由您决定如何处理。';
      case AppExitBehavior.exit:
        return '关闭窗口时直接退出 BakaBox。';
      case AppExitBehavior.minimizeToTray:
        return '关闭窗口时隐藏到系统托盘，可从托盘图标恢复。';
    }
  }
}

/// 服务器排序模式
enum ServerSortMode {
  manual, // 手动排序（用户通过长按拖动调整顺序）
  pinOnline, // 置顶在线服务器（自动将在线服务器排到前面）
}

/// 服务器排序模式扩展
extension ServerSortModeExtension on ServerSortMode {
  String get displayName {
    switch (this) {
      case ServerSortMode.manual:
        return '手动排序';
      case ServerSortMode.pinOnline:
        return '置顶在线服务器';
    }
  }

  String get description {
    switch (this) {
      case ServerSortMode.manual:
        return '通过长按拖动调整服务器顺序';
      case ServerSortMode.pinOnline:
        return '在线服务器自动排在前面，离线服务器自动排在后面';
    }
  }
}

/// 广播通知方式枚举
enum BroadcastNotificationType {
  software, // 软件内通知（浮窗）
  system, // 系统通知
  disabled, // 关闭广播通知
}

/// 广播通知方式扩展
extension BroadcastNotificationTypeExtension on BroadcastNotificationType {
  String get displayName {
    switch (this) {
      case BroadcastNotificationType.software:
        return '软件通知';
      case BroadcastNotificationType.system:
        return '系统通知';
      case BroadcastNotificationType.disabled:
        return '关闭';
    }
  }

  String get description {
    switch (this) {
      case BroadcastNotificationType.software:
        return '在软件内以浮窗形式显示广播消息';
      case BroadcastNotificationType.system:
        return '使用系统通知栏显示广播消息（即使软件在后台也能收到）';
      case BroadcastNotificationType.disabled:
        return '不显示任何广播通知，浮动窗口和系统通知均关闭';
    }
  }
}

/// 缓存类型枚举
enum CacheType {
  cacheFiles, // 图片和临时文件缓存
  serverData, // 服务器相关数据（列表、地图信息、自定义服务器、监控列表）
  appData, // 应用数据（草稿、已读状态、游戏路径、主题、音量等）
  logs, // 日志文件
}

/// 移动端缓存类型枚举
enum MobileCacheType {
  serverImages, // 服务器背景图片（可清理）
  serverData, // 服务器列表、地图信息等（可清理）
  logs, // 日志文件（可清理）
  lobbyImages, // 大厅背景/角色图片（只读，不可清理）
}

/// 移动端缓存项信息
class MobileCacheItemInfo extends Equatable {
  final MobileCacheType type;
  final String name;
  final String description;
  final int sizeInBytes;
  final bool canClear;
  final bool isClearing;

  const MobileCacheItemInfo({
    required this.type,
    required this.name,
    required this.description,
    this.sizeInBytes = 0,
    this.canClear = true,
    this.isClearing = false,
  });

  String get formattedSize {
    if (sizeInBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (sizeInBytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(sizeInBytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  MobileCacheItemInfo copyWith({
    MobileCacheType? type,
    String? name,
    String? description,
    int? sizeInBytes,
    bool? canClear,
    bool? isClearing,
  }) {
    return MobileCacheItemInfo(
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      canClear: canClear ?? this.canClear,
      isClearing: isClearing ?? this.isClearing,
    );
  }

  @override
  List<Object?> get props => [
    type,
    name,
    description,
    sizeInBytes,
    canClear,
    isClearing,
  ];
}

/// 缓存项信息
class CacheItemInfo extends Equatable {
  final CacheType type;
  final String name;
  final String description;
  final int sizeInBytes;
  final bool isClearing;

  const CacheItemInfo({
    required this.type,
    required this.name,
    required this.description,
    this.sizeInBytes = 0,
    this.isClearing = false,
  });

  String get formattedSize {
    if (sizeInBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (sizeInBytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(sizeInBytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  CacheItemInfo copyWith({
    CacheType? type,
    String? name,
    String? description,
    int? sizeInBytes,
    bool? isClearing,
  }) {
    return CacheItemInfo(
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      isClearing: isClearing ?? this.isClearing,
    );
  }

  @override
  List<Object?> get props => [type, name, description, sizeInBytes, isClearing];
}

class SettingsState extends Equatable {
  final String appVersion;
  final String buildNumber;
  final String cacheSize;
  final ThemeMode themeMode;
  final bool isLoading;
  final bool isCheckingUpdate;

  // 游戏设置
  final String? gamePath;
  final String? steamPath;
  final LaunchPlatformType launchPlatform;
  final List<String> launchOptions;
  final bool isDetectingPath;

  // 路径错误信息
  final String? gamePathError;
  final String? steamPathError;

  // 音效设置
  final double audioVolume;

  // 详细缓存信息
  final List<CacheItemInfo> cacheDetails;
  final bool isLoadingCacheDetails;

  // 移动端缓存详情
  final List<MobileCacheItemInfo> mobileCacheDetails;
  final bool isLoadingMobileCacheDetails;

  // 通知位置设置
  final NotificationPositionType notificationPosition;

  // 浮窗位置设置
  final NotificationPositionType floatingWindowPosition;

  // 是否需要重启应用（清理应用数据后需要重启）
  final bool needsRestart;

  // 热身通知开关
  final bool warmupNotificationEnabled;

  // 更新日志通知开关
  final bool updateLogNotificationEnabled;

  // 主窗口关闭行为
  final AppExitBehavior appExitBehavior;

  // 服务器排序模式
  final ServerSortMode serverSortMode;

  // 广播通知方式
  final BroadcastNotificationType broadcastNotificationType;

  const SettingsState({
    this.appVersion = '',
    this.buildNumber = '',
    this.cacheSize = '计算中...',
    this.themeMode = ThemeMode.system,
    this.isLoading = false,
    this.isCheckingUpdate = false,
    this.gamePath,
    this.steamPath,
    this.launchPlatform = LaunchPlatformType.worldwide,
    this.launchOptions = const [],
    this.isDetectingPath = false,
    this.gamePathError,
    this.steamPathError,
    this.audioVolume = 0.8,
    this.cacheDetails = const [],
    this.isLoadingCacheDetails = false,
    this.mobileCacheDetails = const [],
    this.isLoadingMobileCacheDetails = false,
    this.notificationPosition = NotificationPositionType.topRight,
    this.floatingWindowPosition = NotificationPositionType.bottomRight,
    this.needsRestart = false,
    this.warmupNotificationEnabled = true,
    this.updateLogNotificationEnabled = true,
    this.appExitBehavior = AppExitBehavior.ask,
    this.serverSortMode = ServerSortMode.manual,
    this.broadcastNotificationType = BroadcastNotificationType.software,
  });

  /// 获取总缓存大小（字节）
  int get totalCacheSizeInBytes {
    return cacheDetails.fold(0, (sum, item) => sum + item.sizeInBytes);
  }

  /// 获取格式化的总缓存大小
  String get formattedTotalCacheSize {
    final bytes = totalCacheSizeInBytes;
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  bool get isDarkMode => themeMode == ThemeMode.dark;

  String get currentThemeModeText {
    switch (themeMode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  String get launchPlatformText {
    switch (launchPlatform) {
      case LaunchPlatformType.worldwide:
        return 'Steam平台';
      case LaunchPlatformType.perfect:
        return '完美平台';
    }
  }

  bool get hasGamePath => gamePath != null && gamePath!.isNotEmpty;
  bool get hasSteamPath => steamPath != null && steamPath!.isNotEmpty;

  SettingsState copyWith({
    String? appVersion,
    String? buildNumber,
    String? cacheSize,
    ThemeMode? themeMode,
    bool? isLoading,
    bool? isCheckingUpdate,
    String? gamePath,
    String? steamPath,
    LaunchPlatformType? launchPlatform,
    List<String>? launchOptions,
    bool? isDetectingPath,
    String? gamePathError,
    String? steamPathError,
    double? audioVolume,
    List<CacheItemInfo>? cacheDetails,
    bool? isLoadingCacheDetails,
    List<MobileCacheItemInfo>? mobileCacheDetails,
    bool? isLoadingMobileCacheDetails,
    NotificationPositionType? notificationPosition,
    NotificationPositionType? floatingWindowPosition,
    bool? needsRestart,
    bool? warmupNotificationEnabled,
    bool? updateLogNotificationEnabled,
    AppExitBehavior? appExitBehavior,
    ServerSortMode? serverSortMode,
    BroadcastNotificationType? broadcastNotificationType,
  }) {
    return SettingsState(
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      cacheSize: cacheSize ?? this.cacheSize,
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
      isCheckingUpdate: isCheckingUpdate ?? this.isCheckingUpdate,
      gamePath: gamePath ?? this.gamePath,
      steamPath: steamPath ?? this.steamPath,
      launchPlatform: launchPlatform ?? this.launchPlatform,
      launchOptions: launchOptions ?? this.launchOptions,
      isDetectingPath: isDetectingPath ?? this.isDetectingPath,
      gamePathError: gamePathError,
      steamPathError: steamPathError,
      audioVolume: audioVolume ?? this.audioVolume,
      cacheDetails: cacheDetails ?? this.cacheDetails,
      isLoadingCacheDetails:
          isLoadingCacheDetails ?? this.isLoadingCacheDetails,
      mobileCacheDetails: mobileCacheDetails ?? this.mobileCacheDetails,
      isLoadingMobileCacheDetails:
          isLoadingMobileCacheDetails ?? this.isLoadingMobileCacheDetails,
      notificationPosition: notificationPosition ?? this.notificationPosition,
      floatingWindowPosition:
          floatingWindowPosition ?? this.floatingWindowPosition,
      needsRestart: needsRestart ?? this.needsRestart,
      warmupNotificationEnabled:
          warmupNotificationEnabled ?? this.warmupNotificationEnabled,
      updateLogNotificationEnabled:
          updateLogNotificationEnabled ?? this.updateLogNotificationEnabled,
      appExitBehavior: appExitBehavior ?? this.appExitBehavior,
      serverSortMode: serverSortMode ?? this.serverSortMode,
      broadcastNotificationType: broadcastNotificationType ?? this.broadcastNotificationType,
    );
  }

  @override
  List<Object?> get props => [
    appVersion,
    buildNumber,
    cacheSize,
    themeMode,
    isLoading,
    isCheckingUpdate,
    gamePath,
    steamPath,
    launchPlatform,
    launchOptions,
    isDetectingPath,
    gamePathError,
    steamPathError,
    audioVolume,
    cacheDetails,
    isLoadingCacheDetails,
    mobileCacheDetails,
    isLoadingMobileCacheDetails,
    notificationPosition,
    floatingWindowPosition,
    needsRestart,
    warmupNotificationEnabled,
    updateLogNotificationEnabled,
    appExitBehavior,
    serverSortMode,
    broadcastNotificationType,
  ];
}
