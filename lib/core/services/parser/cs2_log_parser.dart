import 'cs2_engine_events.dart';

class CS2LogParser {
  // [Client] Sending connect to 127.0.0.1:27015
  static final _regConnecting = RegExp(
    r'\[Client\]\s+Sending connect to\s+(.*)',
  );

  // Sign-on state: 5 (SIGNONSTATE_SPAWN)
  // Sign-on state: 6 (SIGNONSTATE_FULL)
  static final _regSignon = RegExp(r'Sign-on state:\s+(\d+)\s+\(([^)]+)\)');

  // Disconnect reason: NETWORK_DISCONNECT_REJECT_SERVERFULL
  // Or Disconnected from server: NETWORK_DISCONNECT_TIMEDOUT
  static final _regDisconnect = RegExp(
    r'(?:Disconnect reason:|Disconnected from server:)\s+([A-Z_]+)',
  );

  // ChangeGameUIState: INGAME -> CSGO_GAME_UI_STATE_MAINMENU
  // Or explicitly starting a loopback connection (main menu background)
  static final _regMainMenu = RegExp(
    r"ChangeGameUIState:.*->\s*CSGO_GAME_UI_STATE_MAINMENU|CCreateGameClientJob creating client connection to 'loopback'",
  );

  // Map: "de_dust2"
  static final _regLoadingMap = RegExp(r'\[Client\]\s+Map:\s+"([^"]+)"');

  // Alternative fallback for full
  static final _regServerFullFallback = RegExp(
    r'(?:[Ss]erver is full|[Nn]o free slots|SERVERFULL|REJECT_SERVERFULL)',
  );

  // Fully spawned and in-game markers
  static final _regSpawned = RegExp(
    r'\[Prediction\]\s+Added prediction for player|ChangeGameUIState:.*LOADINGSCREEN\s*->\s*CSGO_GAME_UI_STATE_INGAME',
  );

  // Connection established (but still loading)
  static final _regConnected = RegExp(
    r"\[Client\]\s+CL:\s+Connected to\s+'?([^']+)'?",
  );

  // [NetSteamConn] Opened Steam Net Connection on socket 'client' to <server-ip>:27016, connection #...
  // 仅匹配 client socket 且目标为真实 IP:port（排除 loopback / server socket）。
  // 这是"开始连接远程服务器"的最早可靠信号，用于在超时（Sending connect 行
  // 从未出现）场景下也能让状态机退出 loopback 模式。
  static final _regSocketOpened = RegExp(
    r"Opened Steam Net Connection on socket 'client' to\s+([\d.]+:\d+)",
  );

  static CS2EngineEvent? parse(String line) {
    if (line.isEmpty) return null;
    line = line.trim();

    final signonMatch = _regSignon.firstMatch(line);
    if (signonMatch != null) {
      return EvSignonState(
        int.parse(signonMatch.group(1)!),
        signonMatch.group(2)!,
      );
    }

    final discMatch = _regDisconnect.firstMatch(line);
    if (discMatch != null) {
      final reason = discMatch.group(1)!;
      return EvDisconnect(
        reason,
        isServerFull: reason == 'NETWORK_DISCONNECT_REJECT_SERVERFULL',
      );
    }

    if (_regServerFullFallback.hasMatch(line)) {
      return EvDisconnect('SERVERFULL', isServerFull: true);
    }

    final connMatch = _regConnecting.firstMatch(line);
    if (connMatch != null) {
      return EvConnectInitiated(connMatch.group(1)!);
    }

    final socketOpenedMatch = _regSocketOpened.firstMatch(line);
    if (socketOpenedMatch != null) {
      return EvConnectOpened(socketOpenedMatch.group(1)!.trim());
    }

    final mapMatch = _regLoadingMap.firstMatch(line);
    if (mapMatch != null) {
      return EvMapLoaded(mapMatch.group(1)!);
    }

    if (_regMainMenu.hasMatch(line)) {
      return EvMainMenu();
    }

    if (_regSpawned.hasMatch(line)) {
      return EvSignonState(5, 'SIGNONSTATE_SPAWN');
    }

    final connectedMatch = _regConnected.firstMatch(line);
    if (connectedMatch != null) {
      // "Connected to 'IP:port'" 同时携带地址，作为 serverAddress 的兜底来源
      final addr = connectedMatch.group(1)?.trim();
      return EvSignonState(
        2,
        'SIGNONSTATE_CONNECTED',
        address: (addr != null && addr.isNotEmpty) ? addr : null,
      );
    }

    return null;
  }
}
