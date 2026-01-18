import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 启动平台枚举
enum LaunchPlatformType {
  worldwide,  // 国际版 (Steam)
  perfect,    // 完美世界
}

/// 通知位置枚举
enum NotificationPositionType {
  topLeft,      // 左上角
  topCenter,    // 顶部居中
  topRight,     // 右上角
  centerLeft,   // 左侧居中
  center,       // 正中间
  centerRight,  // 右侧居中
  bottomLeft,   // 左下角
  bottomCenter, // 底部居中
  bottomRight,  // 右下角
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

/// 缓存类型枚举
enum CacheType {
  cacheFiles,       // 图片和临时文件缓存
  serverData,       // 服务器相关数据（列表、地图信息、自定义服务器、监控列表）
  appData,          // 应用数据（草稿、已读状态、游戏路径、主题、音量等）
  logs,             // 日志文件
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
  
  // 通知位置设置
  final NotificationPositionType notificationPosition;
  
  // 浮窗位置设置
  final NotificationPositionType floatingWindowPosition;

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
    this.notificationPosition = NotificationPositionType.topRight,
    this.floatingWindowPosition = NotificationPositionType.bottomRight,
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
      case ThemeMode.system: return '跟随系统';
      case ThemeMode.light: return '浅色模式';
      case ThemeMode.dark: return '深色模式';
    }
  }

  String get launchPlatformText {
    switch (launchPlatform) {
      case LaunchPlatformType.worldwide: return 'Steam平台';
      case LaunchPlatformType.perfect: return '完美平台';
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
    NotificationPositionType? notificationPosition,
    NotificationPositionType? floatingWindowPosition,
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
      isLoadingCacheDetails: isLoadingCacheDetails ?? this.isLoadingCacheDetails,
      notificationPosition: notificationPosition ?? this.notificationPosition,
      floatingWindowPosition: floatingWindowPosition ?? this.floatingWindowPosition,
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
    notificationPosition,
    floatingWindowPosition,
  ];
}
