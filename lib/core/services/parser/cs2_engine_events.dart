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
}

class EvMainMenu extends CS2EngineEvent {}

class EvMapLoaded extends CS2EngineEvent {
  final String mapName;
  EvMapLoaded(this.mapName);
}
