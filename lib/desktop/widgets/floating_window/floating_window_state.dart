/// 浮窗状态数据类 - 单一状态源
class FloatingWindowState {
  final String state;
  final String message;
  final String? subtitle;
  final int? currentPlayers;
  final int? targetPlayers;
  final List<String>? threadStatuses;
  final String? mapName;
  final String? mapNameCn;
  final String? mapBackground;
  final DateTime lastUpdate;

  const FloatingWindowState({
    this.state = 'idle',
    this.message = '',
    this.subtitle,
    this.currentPlayers,
    this.targetPlayers,
    this.threadStatuses,
    this.mapName,
    this.mapNameCn,
    this.mapBackground,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? const _DefaultDateTime();

  /// 是否为终态（成功/失败/超时/服务器满）
  bool get isTerminal => _isTerminalState(state);

  bool get isSuccess => state == 'success';
  bool get isFailed => state == 'failed' || state == 'timeout';
  bool get isServerFull => state == 'serverFull';
  bool get isLoading => state == 'loading';
  bool get isConnecting => state == 'connecting';
  bool get isLaunching => state == 'launching';
  bool get isQueueing => state == 'queueing';
  bool get isPaused => state == 'paused';
  bool get isIdle => state == 'idle';

  /// 获取显示用的地图名称（优先中文名）
  String get displayMapName {
    if (mapNameCn != null && mapNameCn!.isNotEmpty) {
      return mapNameCn!;
    }
    return mapName ?? '';
  }

  FloatingWindowState copyWith({
    String? state,
    String? message,
    String? subtitle,
    int? currentPlayers,
    int? targetPlayers,
    List<String>? threadStatuses,
    String? mapName,
    String? mapNameCn,
    String? mapBackground,
    DateTime? lastUpdate,
  }) {
    return FloatingWindowState(
      state: state ?? this.state,
      message: message ?? this.message,
      subtitle: subtitle ?? this.subtitle,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      targetPlayers: targetPlayers ?? this.targetPlayers,
      threadStatuses: threadStatuses ?? this.threadStatuses,
      mapName: mapName ?? this.mapName,
      mapNameCn: mapNameCn ?? this.mapNameCn,
      mapBackground: mapBackground ?? this.mapBackground,
      lastUpdate: lastUpdate ?? DateTime.now(),
    );
  }

  /// 从 Map 创建状态
  factory FloatingWindowState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const FloatingWindowState();
    }
    return FloatingWindowState(
      state: map['state'] as String? ?? 'idle',
      message: map['message'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      currentPlayers: map['currentPlayers'] as int?,
      targetPlayers: map['targetPlayers'] as int?,
      threadStatuses: (map['threadStatuses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      mapName: map['mapName'] as String?,
      mapNameCn: map['mapNameCn'] as String?,
      mapBackground: map['mapBackground'] as String?,
      lastUpdate: DateTime.now(),
    );
  }

  static bool _isTerminalState(String state) {
    return state == 'success' ||
        state == 'failed' ||
        state == 'timeout' ||
        state == 'serverFull';
  }

  @override
  String toString() {
    return 'FloatingWindowState(state: $state, message: $message)';
  }
}

/// 默认日期时间（用于 const 构造函数）
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}
