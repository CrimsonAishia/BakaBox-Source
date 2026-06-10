import 'dart:async';

import '../models/gsi_models.dart';
import '../utils/log_service.dart';
import 'console_log_service.dart';
import 'gsi_service.dart';
import 'server_address_mapping_service.dart';

/// 守护进程感知到的"用户当前所在位置"
enum GuardLocation {
  /// 在主菜单或未启动游戏
  notInGame,

  /// 在挤服目标服（无歧义）
  inTargetServer,

  /// 在非目标服（有明确地址证据）
  inOtherServer,

  /// 在游戏中但不知道是哪个服（仅 GSI 触发或 console 无地址）
  inUnknownServer,
}

/// 信号源：表明事件由谁触发
enum QueueGuardSource { consoleLog, gsi, heartbeat }

/// 守护进程的连接结局分类
enum ConnectionOutcome {
  /// 已确认进入目标服（或保守的 inUnknownServer）
  success,

  /// 明确"服务器已满"
  serverFull,

  /// 明确"连接被拒/认证失败"
  refused,

  /// 命令已发出，但既未确认成功也未明确失败（典型场景：超时、网络抖动）
  pending,
}

/// 守护进程事件（每次 location 状态变化时 emit）
class QueueGuardEvent {
  final QueueGuardSource source;
  final GuardLocation location;
  final String? consoleAddress;
  final String? gsiMapName;
  final DateTime timestamp;

  QueueGuardEvent({
    required this.source,
    required this.location,
    this.consoleAddress,
    this.gsiMapName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 挤服守护进程（单例）
///
/// 订阅 [ConsoleLogService] 和 [GsiService] 两路信号，统一判定用户当前
/// "是否在游戏中 + 在哪个服务器"，为挤服流程提供权威判定，避免：
/// - console.log 写入滞后导致的误重试
/// - 失败原因未严格分类
/// - 多线程冗余触发
///
/// 详见 `.kiro/specs/queue-guard/design.md`。
class QueueGuardService {
  static final QueueGuardService _instance = QueueGuardService._internal();
  factory QueueGuardService() => _instance;
  QueueGuardService._internal();

  StreamSubscription<ConsoleLogState>? _consoleSub;
  StreamSubscription<GsiGameState?>? _gsiSub;

  // 事件流
  final _eventController = StreamController<QueueGuardEvent>.broadcast();

  /// 守护进程事件流
  Stream<QueueGuardEvent> get events => _eventController.stream;

  // 挤服目标地址（外部通过 setTarget 设置）
  String? _targetAddress;

  /// 当前挤服目标地址（外部用于诊断）
  String? get targetAddress => _targetAddress;

  // 补登中标志
  bool _isEnsuringMapping = false;

  // 心跳定时器
  Timer? _heartbeatTimer;

  // 上次 emit 的 location，用于去重
  GuardLocation _lastEmittedLocation = GuardLocation.notInGame;

  bool _started = false;

  /// 是否已启动订阅
  bool get isStarted => _started;

  /// 启动守护进程：订阅两路 stream
  ///
  /// 应用启动时调用一次（通常在 GSI / ConsoleLogService 启动后）。
  void start() {
    if (_started) return;
    _started = true;

    _consoleSub?.cancel();
    _consoleSub = ConsoleLogService().stateStream.listen(
      (_) => _onSignal(QueueGuardSource.consoleLog),
      onError: (e, s) => LogService.e('[QueueGuard] console stream error', e),
    );

    _gsiSub?.cancel();
    _gsiSub = GsiService().stateStream.listen(
      (_) => _onSignal(QueueGuardSource.gsi),
      onError: (e, s) => LogService.e('[QueueGuard] gsi stream error', e),
    );

    LogService.i('[QueueGuard] 守护进程已启动');
  }

  /// 设置挤服目标地址（同步）
  ///
  /// DNS 已由 [ServerAddressMappingService.load] 在应用启动时完成。
  /// 若用户运行期间新增/编辑自定义服务器，调用 ensureMapping 异步补登。
  /// 补登期间 location getter 暂时返回保守的 inUnknownServer。
  void setTarget(String address) {
    _targetAddress = address;
    _isEnsuringMapping = true;
    // 异步补登映射（最多 2 秒），完成后清除标志
    ServerAddressMappingService()
        .ensureMapping(address)
        .whenComplete(() => _isEnsuringMapping = false);
  }

  /// 清除挤服目标
  void clearTarget() {
    _targetAddress = null;
    _isEnsuringMapping = false;
    _lastEmittedLocation = GuardLocation.notInGame;
  }

  /// 启动心跳兜底（挤服活跃期间调用）
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _onSignal(QueueGuardSource.heartbeat);
    });
    LogService.d('[QueueGuard] 心跳已启动 (3s)');
  }

  /// 停止心跳（挤服结束时调用）
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastEmittedLocation = GuardLocation.notInGame;
    LogService.d('[QueueGuard] 心跳已停止');
  }

  /// 当前判定的位置（合并 console + GSI 信号）
  GuardLocation get location {
    final consoleState = ConsoleLogService().currentState;
    final consoleInGame = consoleState.state == GameState.inGame;

    // 切服过渡态：console 处于 connecting/loading 时，引擎已 disconnect 旧服、
    // 还没真正进入新服，serverAddress 已经被更新为目标地址，但用户身体还在
    // 切服中。此时 GSI 的 cache 还可能残留旧服的 playing 帧（GSI 不会主动
    // push 一个"离开"事件），如果走 GSI 判定会被误判为 inUnknownServer，
    // 进而被守护回调当成 success。
    //
    // 明确把切服过渡态当成 notInGame，保证：
    // 1. 全局守护回调不会误触发 finalize
    // 2. _observeConnection 内部的 onSignal 把它当成 seenLeftOldServer=true
    //    而非直接 resolve(success)
    final consoleSwitching =
        consoleState.state == GameState.connecting ||
        consoleState.state == GameState.loading;
    if (consoleSwitching) {
      return GuardLocation.notInGame;
    }

    final gsi = GsiService().latestState;
    final gsiInGame = _isGsiInGame(gsi);

    if (!consoleInGame && !gsiInGame) return GuardLocation.notInGame;

    // 关键：只有 console 处于稳定 inGame 时，才信任 console.serverAddress
    if (consoleInGame) {
      final consoleAddr = consoleState.serverAddress;
      if (consoleAddr.isNotEmpty) {
        if (_addressMatches(consoleAddr)) {
          return GuardLocation.inTargetServer;
        }
        // 补登中地址比对结果不可信 → 保守 unknown
        if (_isEnsuringMapping) {
          return GuardLocation.inUnknownServer;
        }
        if (!ServerAddressMappingService().isLoaded) {
          return GuardLocation.inUnknownServer;
        }

        // DNS 解析失败兜底：如果目标是域名但控制台抓到的是 IPv4，
        // 且映射服务缓存中未收录此 IP，我们无法确定它是否是目标服。
        // 保守返回 inUnknownServer，防止被误判为 inOtherServer 导致无限将玩家从目标服中拉出重连。
        final target = _targetAddress;
        if (target != null) {
          final targetHost = target.split(':').first;
          final consoleHost = consoleAddr.split(':').first;
          final isConsoleIpv4 = RegExp(
            r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
          ).hasMatch(consoleHost);
          final isTargetDomain = targetHost.contains(RegExp(r'[a-zA-Z]'));

          if (isTargetDomain && isConsoleIpv4) {
            if (!ServerAddressMappingService().hasMapping(consoleAddr)) {
              return GuardLocation.inUnknownServer;
            }
          }
        }

        return GuardLocation.inOtherServer;
      }
      // console 说在游戏但地址未抓到（罕见）→ 走 unknown
      return GuardLocation.inUnknownServer;
    }

    // 仅 GSI 触发（用户没用 -condebug 启动 / console 还没追上）
    // 无法判别具体服务器
    return GuardLocation.inUnknownServer;
  }

  /// GSI 是否表明用户在游戏中（在某个服务器内打游戏）
  ///
  /// 严格判定：activity=playing + map.name 非空 + map.phase 在比赛阶段集合内。
  /// 这样可以排除 demo 回放、菜单残留、加载中等模糊状态。
  bool _isGsiInGame(GsiGameState? gsi) {
    if (gsi == null) return false;
    final activity = gsi.player?.activity;
    final mapName = gsi.map?.name;
    final phase = gsi.map?.phase;
    if (activity != 'playing') return false;
    if (mapName == null || mapName.isEmpty) return false;
    // 真比赛阶段才算 in game（与 design 3.3.1 对齐）
    // CS2 常见 phase: live, warmup, freezetime, over, intermission, gameover
    const validPhases = {
      'live',
      'warmup',
      'freezetime',
      'over',
      'intermission',
      'gameover',
    };
    if (phase == null || !validPhases.contains(phase)) return false;
    return true;
  }

  /// 比对 console 抓到的地址是否是挤服目标
  bool _addressMatches(String consoleAddress) {
    final target = _targetAddress;
    if (target == null || target.isEmpty) return false;
    if (consoleAddress.isEmpty) return false;

    // 用映射服务把 IP 反查成域名（如果命中），否则原样返回
    final normalized = ServerAddressMappingService().getDomainAddress(
      consoleAddress,
    );

    return normalized == target;
  }

  /// 判断用户当前是否已经"稳定地"在指定服务器内。
  ///
  /// 与 [location] 不同，本方法不依赖 [setTarget] 设置的目标地址，可供
  /// 「加入服务器」「暖服」等没有挂载守护进程的流程直接做入口预判。
  ///
  /// 采取严格判定，只有在以下全部满足时才返回 true：
  /// - console（-condebug）处于稳定的 [GameState.inGame]；
  /// - console 抓到了非空的服务器地址；
  /// - 地址映射已就绪，且归一化后的地址与 [targetAddress] 完全一致。
  ///
  /// 任何不确定情形（切服过渡、GSI-only、地址未抓到、映射未就绪）一律返回
  /// false，宁可漏判也不误判——避免把"在别的服/主菜单"错当成"已在目标服"。
  bool isStablyInServer(String targetAddress) {
    if (targetAddress.isEmpty) return false;

    final consoleState = ConsoleLogService().currentState;
    if (consoleState.state != GameState.inGame) return false;

    final consoleAddr = consoleState.serverAddress;
    if (consoleAddr.isEmpty) return false;

    if (!ServerAddressMappingService().isLoaded) return false;

    final normalized = ServerAddressMappingService().getDomainAddress(
      consoleAddr,
    );
    return normalized == targetAddress || consoleAddr == targetAddress;
  }

  /// 信号到达时的统一处理：判定 location，变化时 emit
  void _onSignal(QueueGuardSource source) {
    final current = location;
    if (current == _lastEmittedLocation) {
      // 心跳信号即使无变化也不打扰
      return;
    }
    _lastEmittedLocation = current;
    _emit(source, current);
  }

  void _emit(QueueGuardSource source, GuardLocation loc) {
    if (_eventController.isClosed) return;
    final consoleState = ConsoleLogService().currentState;
    final gsi = GsiService().latestState;
    _eventController.add(
      QueueGuardEvent(
        source: source,
        location: loc,
        consoleAddress: consoleState.serverAddress.isEmpty
            ? null
            : consoleState.serverAddress,
        gsiMapName: gsi?.map?.name,
      ),
    );
    LogService.d('[QueueGuard] emit: source=$source, location=$loc');
  }

  /// 销毁服务（一般不调用）
  Future<void> dispose() async {
    stopHeartbeat();
    await _consoleSub?.cancel();
    await _gsiSub?.cancel();
    await _eventController.close();
    _started = false;
  }
}
