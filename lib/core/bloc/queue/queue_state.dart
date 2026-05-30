import 'package:equatable/equatable.dart';

import '../../models/server_models.dart';
import '../../services/status_window_service.dart';

/// 挤服状态枚举
enum QueueStatus {
  idle, // 空闲
  running, // 挤服中
  connecting, // 连接中
  waitingConsole, // 等待控制台确认
  success, // 成功加入
  paused, // 已暂停
}

/// 连接状态
enum QueueConnectionState {
  idle,
  connecting,
  loading,
  connected,
  failed,
  serverFull,
  timeout,
  cancelled,
}

/// 线程状态（UI 用）
enum QueueThreadStatus { idle, requesting, success, failed }

/// 挤服Bloc状态
class QueueBlocState extends Equatable {
  /// 挤服状态
  final QueueStatus status;

  /// 服务器信息
  final ServerInfo? serverInfo;

  /// 地图信息
  final MapData? mapInfo;

  /// 配置
  final QueueConfig config;

  /// 线程状态列表
  final List<QueueThreadStatus> threadStatuses;

  /// 连接状态
  final QueueConnectionState connectionState;

  /// 连接消息
  final String? connectionMessage;

  /// 游戏是否运行
  final bool isGameRunning;

  /// 是否正在启动游戏
  final bool isLaunchingGame;

  /// 启动游戏状态消息
  final String? launchMessage;

  /// 是否正在检查游戏
  final bool isCheckingGame;

  /// 错误信息
  final String? error;

  /// 是否已初始化
  final bool isInitialized;

  /// 服务器地址
  final String? serverAddress;

  /// 自定义服务器名称（通常是用户设置的备注名，如果没有则是官方名）
  final String? serverName;

  /// 是否为自定义服务器
  final bool isCustomServer;

  /// 是否需要手动启动 CSGO
  final bool needManualLaunch;

  const QueueBlocState({
    this.status = QueueStatus.idle,
    this.serverInfo,
    this.mapInfo,
    this.config = const QueueConfig(),
    this.threadStatuses = const [],
    this.connectionState = QueueConnectionState.idle,
    this.connectionMessage,
    this.isGameRunning = false,
    this.isLaunchingGame = false,
    this.launchMessage,
    this.isCheckingGame = false,
    this.error,
    this.isInitialized = false,
    this.serverAddress,
    this.serverName,
    this.isCustomServer = false,
    this.needManualLaunch = false,
  });

  /// 是否正在挤服
  bool get isQueueActive => status == QueueStatus.running;

  /// 是否正在连接
  bool get isConnecting =>
      status == QueueStatus.connecting || status == QueueStatus.waitingConsole;

  /// 是否成功加入
  bool get isJoinedSuccessfully => status == QueueStatus.success;

  /// 是否应该连接（玩家数小于目标人数）
  bool get shouldConnect {
    if (serverInfo == null || serverInfo!.maxPlayers == null) return false;
    // 如果服务器未启动完全也不加入
    if (serverInfo?.map == "graphics_settings") return false;
    return (serverInfo!.players ?? 0) < config.targetPlayers;
  }

  /// 当前玩家数
  int get currentPlayers => serverInfo?.players ?? 0;

  /// 最大玩家数
  int get maxPlayers => serverInfo?.maxPlayers ?? 0;

  QueueBlocState copyWith({
    QueueStatus? status,
    ServerInfo? serverInfo,
    MapData? mapInfo,
    QueueConfig? config,
    List<QueueThreadStatus>? threadStatuses,
    QueueConnectionState? connectionState,
    String? connectionMessage,
    bool? isGameRunning,
    bool? isLaunchingGame,
    String? launchMessage,
    bool? isCheckingGame,
    String? error,
    bool? isInitialized,
    String? serverAddress,
    String? serverName,
    bool? isCustomServer,
    bool? needManualLaunch,
  }) {
    return QueueBlocState(
      status: status ?? this.status,
      serverInfo: serverInfo ?? this.serverInfo,
      mapInfo: mapInfo ?? this.mapInfo,
      config: config ?? this.config,
      threadStatuses: threadStatuses ?? this.threadStatuses,
      connectionState: connectionState ?? this.connectionState,
      connectionMessage: connectionMessage,
      isGameRunning: isGameRunning ?? this.isGameRunning,
      isLaunchingGame: isLaunchingGame ?? this.isLaunchingGame,
      launchMessage: launchMessage,
      isCheckingGame: isCheckingGame ?? this.isCheckingGame,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
      serverAddress: serverAddress ?? this.serverAddress,
      serverName: serverName ?? this.serverName,
      isCustomServer: isCustomServer ?? this.isCustomServer,
      needManualLaunch: needManualLaunch ?? this.needManualLaunch,
    );
  }

  @override
  List<Object?> get props => [
    status,
    serverInfo,
    mapInfo,
    config,
    threadStatuses,
    connectionState,
    connectionMessage,
    isGameRunning,
    isLaunchingGame,
    launchMessage,
    isCheckingGame,
    error,
    isInitialized,
    serverAddress,
    serverName,
    isCustomServer,
    needManualLaunch,
  ];
}
