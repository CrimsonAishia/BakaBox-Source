import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../api/playtime_api.dart';
import '../models/playtime_models.dart';
import '../utils/device_id_helper.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import 'auth_service.dart';
import 'console_log_service.dart';
import 'gsi_service.dart';
import 'scheduler_service.dart';

/// 游玩时长心跳上报服务（桌面端专属）
///
/// 详见 `docs/playtime-voting.md`。
///
/// 两路信号配合判定「有效游玩时长」，与 OBS 同源：
/// - **ConsoleLog（`-condebug` 控制台日志）= 在哪个服务器 / 哪张图**。
///   提供权威的 `serverAddress` / `mapName`，决定这段时长记到哪张图。
/// - **GSI = 此刻是否真的在游玩**。用玩家活跃度（`activity`）排除
///   「ConsoleLog 还以为在服务器、实际已退回主菜单」的滞后窗口，以及
///   挂在记分板 / 主菜单不动的情况。GSI 不可用（未配置 / 数据过期）时
///   退化为只信 ConsoleLog，保证没装 GSI 的用户也能正常累计。
///
/// 计时采用**采样累加**：每 [_sampleInterval] 采样一次，仅当"在服务器
/// 且 GSI 认为在游玩"时把这段间隔计入；菜单 / 旁观菜单 / 系统休眠都不计。
/// 累计到一定量或会话结束（换图 / 离服 / 停服）时，作为增量心跳上报。
class PlaytimeReportService {
  PlaytimeReportService._internal();
  static final PlaytimeReportService _instance =
      PlaytimeReportService._internal();
  factory PlaytimeReportService() => _instance;

  final PlaytimeApi _api = PlaytimeApi();
  final SchedulerService _scheduler = SchedulerService();
  static const String _taskId = 'playtime_heartbeat';

  /// 采样间隔：每隔这么久判断一次"现在是否在有效游玩"
  static const Duration _sampleInterval = Duration(seconds: 30);

  /// 单次采样能计入的最大秒数。
  /// 正常 ≈ 采样间隔；若定时器久未触发（系统休眠 / 卡顿）则裁剪到此值，
  /// 天然过滤掉休眠时间。
  static const int _maxSampleSeconds = 40;

  /// 累计达到该秒数就上报一次（≈ 1 分钟一个心跳）
  static const int _flushThresholdSeconds = 60;

  /// 单次心跳允许上报的最大秒数（后端侧安全阈）
  static const int _maxDeltaPerHeartbeat = 600;

  /// 状态变化通知（最近一次心跳后端返回的状态）
  final _statusController = StreamController<UserPlaytimeStatus>.broadcast();
  Stream<UserPlaytimeStatus> get statusStream => _statusController.stream;
  UserPlaytimeStatus? _latestStatus;
  UserPlaytimeStatus? get latestStatus => _latestStatus;

  bool _isStarted = false;
  StreamSubscription<ConsoleLogState>? _consoleLogSub;

  /// 当前所在服务器 / 地图（由 ConsoleLog 决定），未在服务器时为 null
  String? _sessionMapName;
  String? _sessionServerAddress;
  bool _inServer = false;

  /// 上次采样时刻，用于计算间隔
  DateTime? _lastSampleAt;

  /// 已计入、待上报的有效秒数（属于 _sessionMapName）
  int _accumulatedSeconds = 0;

  /// 上报失败暂存的秒数 + 对应地图，下次心跳合并补发
  int _pendingSeconds = 0;
  String? _pendingMapName;
  String? _pendingServerAddress;

  /// 启动服务（桌面端 app 启动时调用一次即可）
  Future<void> start() async {
    if (!PlatformUtils.isDesktopPlatform) {
      LogService.d('[Playtime] 非桌面端，跳过启动');
      return;
    }
    if (_isStarted) return;
    _isStarted = true;

    // 同步一次当前服务器状态
    _applyConsoleState(ConsoleLogService().currentState);
    _lastSampleAt = DateTime.now();

    _consoleLogSub = ConsoleLogService().stateStream.listen(_onConsoleLogState);

    // 采样定时器
    _scheduler.register(
      ScheduledTask(
        id: _taskId,
        name: '游玩时长采样',
        interval: _sampleInterval,
        callback: _onSample,
      ),
    );

    LogService.d('[Playtime] 心跳服务已启动');
  }

  /// 停止服务（一般 app 退出时调用，可不调用）
  Future<void> stop() async {
    if (!_isStarted) return;
    _isStarted = false;

    // 把最后一段采样补齐并上报
    _sample();
    await _flush(reason: 'stop');

    _scheduler.cancel(_taskId);
    await _consoleLogSub?.cancel();
    _consoleLogSub = null;
    _clearSession();
    _accumulatedSeconds = 0;
    _pendingSeconds = 0;
    _pendingMapName = null;
    _pendingServerAddress = null;

    LogService.d('[Playtime] 心跳服务已停止');
  }

  /// 主动拉取一次最新状态（不上报增量）
  ///
  /// 用于 `MapContributionDialog` 打开时，按地图维度刷新「您在本图玩了多久」。
  Future<UserPlaytimeStatus?> refreshStatus({String? mapName}) async {
    if (!AuthService.instance.isLoggedIn) return null;
    try {
      final status = await _api.getMyPlaytime(mapName: mapName);
      if (status != null) {
        // 不带 mapName 的拉取覆盖全局字段；带 mapName 的拉取只更新 currentMap
        if (mapName == null || _latestStatus == null) {
          _latestStatus = status;
        } else {
          _latestStatus = _latestStatus!.copyWith(
            totalSeconds: status.totalSeconds,
            validSeconds: status.validSeconds,
            todayValidSeconds: status.todayValidSeconds,
            canVote: status.canVote,
            voteThresholdSeconds: status.voteThresholdSeconds,
            currentMap: status.currentMap ?? _latestStatus!.currentMap,
          );
        }
        _statusController.add(_latestStatus!);
      }
      return status;
    } catch (e) {
      LogService.w('[Playtime] 拉取状态失败: $e');
      return null;
    }
  }


  void _onConsoleLogState(ConsoleLogState state) {
    final wasInServer = _inServer;
    final oldMap = _sessionMapName;

    // 状态切换前，先把到此刻为止的有效时长采样落袋
    _sample();

    final nowInServer = state.isInServer && state.serverAddress.isNotEmpty;
    final newMap = state.mapName.trim();

    // 离开服务器，或还在服务器但换了图 → 结算上一段（按旧图上报）
    final leftServer = wasInServer && !nowInServer;
    final changedMap =
        wasInServer &&
        nowInServer &&
        newMap.isNotEmpty &&
        newMap != oldMap;
    if (leftServer || changedMap) {
      _flush(reason: leftServer ? 'leave-server' : 'map-change').ignore();
    }

    _applyConsoleState(state);
  }

  /// 把 ConsoleLog 状态同步到本地会话字段
  void _applyConsoleState(ConsoleLogState state) {
    _inServer = state.isInServer && state.serverAddress.isNotEmpty;
    if (_inServer) {
      final m = state.mapName.trim();
      _sessionMapName = m.isNotEmpty ? m : null;
      _sessionServerAddress = state.serverAddress;
    } else {
      _sessionMapName = null;
      _sessionServerAddress = null;
    }
  }

  void _clearSession() {
    _inServer = false;
    _sessionMapName = null;
    _sessionServerAddress = null;
  }


  /// GSI 是否允许把当前这段时间计入。
  ///
  /// - GSI 不可用（未配置 / 服务没起 / 数据过期 90s）→ 退化为信任 ConsoleLog，返回 true
  /// - GSI 可用 → 必须不在主菜单且处于游玩态才计入
  bool _gsiAllowsCounting() {
    final gsi = GsiService();
    if (!gsi.isLive) return true; // 没有 GSI 信号，退回只信 ConsoleLog
    final state = gsi.latestState;
    if (state == null) return true;
    return state.isPlaying && !state.isInMenu;
  }


  Future<void> _onSample() async {
    _sample();
    // 攒够一个心跳量，或之前有失败残留，就上报
    if (_accumulatedSeconds + _pendingSeconds >= _flushThresholdSeconds) {
      await _flush(reason: 'tick');
    }
  }

  /// 采样一次：把距上次采样的间隔，在"有效游玩"时计入累计
  void _sample() {
    final now = DateTime.now();
    final last = _lastSampleAt;
    _lastSampleAt = now;
    if (last == null) return;

    var elapsed = now.difference(last).inSeconds;
    if (elapsed <= 0) return;
    if (elapsed > _maxSampleSeconds) {
      // 定时器久未触发（休眠 / 卡顿），裁剪掉这段，不计入
      elapsed = _maxSampleSeconds;
    }

    if (_inServer &&
        _sessionServerAddress != null &&
        AuthService.instance.isLoggedIn &&
        _gsiAllowsCounting()) {
      _accumulatedSeconds += elapsed;
    }
  }

  /// 上报累计的有效秒数
  ///
  /// 若存在「上次失败暂存的秒数」且其地图与当前会话地图不同，会分两次
  /// 上报，避免把新图的时长错算到旧图上。
  Future<void> _flush({required String reason}) async {
    if (!_isStarted) return;

    if (!AuthService.instance.isLoggedIn) {
      // 未登录：丢弃累计，避免补发给登录后的账号
      _accumulatedSeconds = 0;
      _pendingSeconds = 0;
      _pendingMapName = null;
      _pendingServerAddress = null;
      return;
    }

    // 先补发上次失败的残留（按它自己的地图）
    if (_pendingSeconds > 0) {
      final sameMap =
          _pendingMapName == _sessionMapName &&
          _pendingServerAddress == _sessionServerAddress;
      if (sameMap) {
        // 同图：并入当前累计一起发
        _accumulatedSeconds += _pendingSeconds;
        _pendingSeconds = 0;
        _pendingMapName = null;
        _pendingServerAddress = null;
      } else {
        // 异图：单独补发旧图
        await _send(
          seconds: _pendingSeconds,
          mapName: _pendingMapName,
          serverAddress: _pendingServerAddress,
          reason: '$reason-pending',
          isPending: true,
        );
      }
    }

    // 再发当前会话累计
    if (_accumulatedSeconds > 0) {
      final seconds = _accumulatedSeconds;
      _accumulatedSeconds = 0;
      await _send(
        seconds: seconds,
        mapName: _sessionMapName,
        serverAddress: _sessionServerAddress,
        reason: reason,
        isPending: false,
      );
    }
  }

  /// 实际发一次心跳；失败时把秒数与对应地图记入 pending
  Future<void> _send({
    required int seconds,
    required String? mapName,
    required String? serverAddress,
    required String reason,
    required bool isPending,
  }) async {
    var deltaSeconds = seconds;
    if (deltaSeconds <= 0) return;
    if (deltaSeconds > _maxDeltaPerHeartbeat) {
      LogService.w(
        '[Playtime] 本次增量 $deltaSeconds s 超过上限 '
        '$_maxDeltaPerHeartbeat s，已裁剪',
      );
      deltaSeconds = _maxDeltaPerHeartbeat;
    }

    try {
      final fingerprint = await _clientFingerprint();
      final status = await _api.heartbeat(
        deltaSeconds: deltaSeconds,
        gameType: 'cs2',
        clientFingerprint: fingerprint,
        mapName: mapName,
        serverAddress: serverAddress,
        clientReportedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      // 补发成功：清掉 pending
      if (isPending) {
        _pendingSeconds = 0;
        _pendingMapName = null;
        _pendingServerAddress = null;
      }
      if (status != null) {
        _latestStatus = status;
        _statusController.add(status);
      }
      LogService.d(
        '[Playtime] 心跳上报成功 reason=$reason delta=$deltaSeconds '
        'map=$mapName',
      );
    } catch (e) {
      // 失败：当前会话累计转入 pending（按本次地图）；补发失败则维持原 pending
      if (!isPending) {
        _pendingSeconds += deltaSeconds;
        _pendingMapName = mapName;
        _pendingServerAddress = serverAddress;
      }
      LogService.w('[Playtime] 心跳上报失败 reason=$reason: $e');
    }
  }

  /// 与崩溃上报共用的客户端指纹（hex sha256(deviceId)）
  Future<String> _clientFingerprint() async {
    final deviceId = await DeviceIdHelper.getDeviceId();
    return sha256.convert(utf8.encode(deviceId)).toString();
  }
}
