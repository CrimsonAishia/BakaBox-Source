import 'package:equatable/equatable.dart';

import '../../models/server_models.dart';

/// 暖服状态枚举
enum WarmupStatus {
  idle, // 空闲
  warming, // 暖服中（等待人数达标）
  countdown, // 倒计时中
  launching, // 正在启动游戏/加入服务器
  success, // 成功加入
  paused, // 已暂停
}

/// 暖服配置
class WarmupConfig extends Equatable {
  final int targetPlayers;

  /// 是否显示原生浮动窗口（暖服悬浮窗）
  final bool showFloatingWindow;

  const WarmupConfig({this.targetPlayers = 20, this.showFloatingWindow = true});

  WarmupConfig copyWith({int? targetPlayers, bool? showFloatingWindow}) {
    return WarmupConfig(
      targetPlayers: targetPlayers ?? this.targetPlayers,
      showFloatingWindow: showFloatingWindow ?? this.showFloatingWindow,
    );
  }

  @override
  List<Object?> get props => [targetPlayers, showFloatingWindow];
}

/// 暖服 Bloc 状态
class WarmupBlocState extends Equatable {
  /// 暖服状态
  final WarmupStatus status;

  /// 服务器信息
  final ServerInfo? serverInfo;

  /// 地图信息
  final MapData? mapInfo;

  /// 配置
  final WarmupConfig config;

  /// 倒计时剩余秒数（60→0）
  final int countdownSeconds;

  /// 游戏是否运行
  final bool isGameRunning;

  /// 是否正在启动游戏
  final bool isLaunchingGame;

  /// 错误信息
  final String? error;

  /// 是否已初始化
  final bool isInitialized;

  /// 服务器地址
  final String? serverAddress;

  /// 自定义服务器名称
  final String? serverName;

  /// 是否为自定义服务器
  final bool isCustomServer;

  /// 是否需要手动启动
  final bool needManualLaunch;

  /// 暖服 WS 用户数（实时）
  final int warmupUsersCount;

  const WarmupBlocState({
    this.status = WarmupStatus.idle,
    this.serverInfo,
    this.mapInfo,
    this.config = const WarmupConfig(),
    this.countdownSeconds = 60,
    this.isGameRunning = false,
    this.isLaunchingGame = false,
    this.error,
    this.isInitialized = false,
    this.serverAddress,
    this.serverName,
    this.isCustomServer = false,
    this.needManualLaunch = false,
    this.warmupUsersCount = 0,
  });

  /// 是否正在暖服
  bool get isWarmupActive => status == WarmupStatus.warming;

  /// 是否正在倒计时
  bool get isCountdownActive => status == WarmupStatus.countdown;

  /// 是否正在启动中
  bool get isLaunching => status == WarmupStatus.launching;

  /// 有效总人数 = 服务器人数 + 暖服人数
  int get effectiveTotalPlayers {
    final serverPlayers = serverInfo?.players ?? 0;
    return serverPlayers + warmupUsersCount;
  }

  /// 服务器最大人数
  int get maxPlayers => serverInfo?.maxPlayers ?? 0;

  /// 暖服目标人数允许的最大值
  ///
  /// - 64 人服务器：固定上限 40 人
  /// - 其它服务器：服务器最大人数 × 0.6
  ///
  /// 获取不到服务器最大人数（说明服务器有问题）时不做兜底，只允许 1 人。
  int get maxTargetPlayers {
    final max = maxPlayers;
    if (max <= 0) return 1;
    if (max == 64) return 40;
    final limit = (max * 0.6).floor();
    return limit < 1 ? 1 : limit;
  }

  /// 实际生效的目标人数（受 maxTargetPlayers 限制），用于达标判断与显示
  int get effectiveTargetPlayers =>
      config.targetPlayers.clamp(1, maxTargetPlayers);

  /// 是否达到目标人数
  bool get hasReachedTarget => effectiveTotalPlayers >= effectiveTargetPlayers;

  WarmupBlocState copyWith({
    WarmupStatus? status,
    ServerInfo? serverInfo,
    MapData? mapInfo,
    bool clearMapInfo = false,
    WarmupConfig? config,
    int? countdownSeconds,
    bool? isGameRunning,
    bool? isLaunchingGame,
    String? error,
    bool? isInitialized,
    String? serverAddress,
    String? serverName,
    bool? isCustomServer,
    bool? needManualLaunch,
    int? warmupUsersCount,
  }) {
    return WarmupBlocState(
      status: status ?? this.status,
      serverInfo: serverInfo ?? this.serverInfo,
      mapInfo: clearMapInfo ? null : (mapInfo ?? this.mapInfo),
      config: config ?? this.config,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isGameRunning: isGameRunning ?? this.isGameRunning,
      isLaunchingGame: isLaunchingGame ?? this.isLaunchingGame,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
      serverAddress: serverAddress ?? this.serverAddress,
      serverName: serverName ?? this.serverName,
      isCustomServer: isCustomServer ?? this.isCustomServer,
      needManualLaunch: needManualLaunch ?? this.needManualLaunch,
      warmupUsersCount: warmupUsersCount ?? this.warmupUsersCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    serverInfo,
    mapInfo,
    config,
    countdownSeconds,
    isGameRunning,
    isLaunchingGame,
    error,
    isInitialized,
    serverAddress,
    serverName,
    isCustomServer,
    needManualLaunch,
    warmupUsersCount,
  ];
}
