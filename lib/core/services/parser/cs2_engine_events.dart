abstract class CS2EngineEvent {}

class EvConnectInitiated extends CS2EngineEvent {
  final String target;
  EvConnectInitiated(this.target);
}

class EvSignonState extends CS2EngineEvent {
  final int state;
  final String stateName;
  EvSignonState(this.state, this.stateName);
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
