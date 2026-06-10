abstract class CS2EngineEvent {}

class EvConnectInitiated extends CS2EngineEvent {
  final String target;
  EvConnectInitiated(this.target);
}

class EvSignonState extends CS2EngineEvent {
  final int state;
  final String stateName;

  /// 可选的服务器地址。
  ///
  /// 仅当事件来源于 "[Client] CL: Connected to 'addr'" 这类同时携带地址的
  /// 日志行时才有值；普通的 "Sign-on state: N" 行没有地址（为 null）。
  /// 用作 serverAddress 的兜底来源，防止 "Sending connect to" 行被漏读后
  /// 进服状态因缺少地址被误判为"主菜单背景"。
  final String? address;

  EvSignonState(this.state, this.stateName, {this.address});
}

class EvDisconnect extends CS2EngineEvent {
  final String reason;
  final bool isServerFull;
  EvDisconnect(this.reason, {this.isServerFull = false});

  /// 是否为"连接远程服务器失败"类断开（超时 / 被拒 / 建连失败）。
  ///
  /// 这类断开只可能发生在连接真实远程服务器的过程中，loopback（主菜单背景）
  /// 连接不会超时也不会被拒。因此即便当前处于 loopback 模式（旧服已断、新连
  /// 接的 "Sending connect to" 行尚未出现/被漏读），也必须将其判定为连接失败，
  /// 否则状态会一直卡在"连接中"。
  ///
  /// 反例（不算连接失败，属于正常/主动断开）：
  /// - NETWORK_DISCONNECT_DISCONNECT_BY_USER（用户主动断开）
  /// - NETWORK_DISCONNECT_LOOPDEACTIVATE / LOOPSHUTDOWN / SHUTDOWN（引擎切换 loopmode）
  bool get isConnectFailure {
    final r = reason.toUpperCase();
    return r.contains('TIMEDOUT') ||
        r.contains('TIMED_OUT') ||
        r.contains('REJECT') ||
        r.contains('CONNECT_REQUEST') ||
        r.contains('CONNECTION_FAILURE') ||
        r.contains('CONNECT_FAILED');
  }
}

class EvMainMenu extends CS2EngineEvent {}

class EvMapLoaded extends CS2EngineEvent {
  final String mapName;
  EvMapLoaded(this.mapName);
}
