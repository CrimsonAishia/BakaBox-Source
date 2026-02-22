import 'dart:async';

import '../api/score_api.dart';
import '../models/gsi_models.dart';
import '../utils/log_service.dart';
import 'console_log_service.dart';
import 'gsi_service.dart';
import 'server_address_mapping_service.dart';

/// 比分上传服务（桌面端专属）
///
/// 数据来源：
/// - 服务器地址：ConsoleLogService（解析 console.log）
/// - 比分数据：GsiService（GSI 实时数据）
/// - Steam ID：GsiService.provider.steamId
///
/// 核心功能：
/// - 监听 ConsoleLogService 获取服务器地址
/// - 监听 GsiService 获取比分和回合阶段
/// - 回合结束 + 比分变化 → 触发上传
/// - 3 秒防抖，失败静默忽略
class ScoreUploadService {
  // ==================== 单例模式 ====================
  static final ScoreUploadService _instance = ScoreUploadService._internal();
  factory ScoreUploadService() => _instance;
  ScoreUploadService._internal();

  // ==================== 依赖服务 ====================
  final ConsoleLogService _consoleLogService = ConsoleLogService();
  final GsiService _gsiService = GsiService();
  final ScoreApi _scoreApi = ScoreApi();
  final ServerAddressMappingService _addressMapping =
      ServerAddressMappingService();

  // ==================== 状态追踪 ====================
  /// 当前服务器 IP 地址（从 ConsoleLogService 获取）
  String? _currentServerAddress;

  /// 当前服务器域名地址（用于上传，IP 映射后的结果）
  String? _currentServerDomainAddress;

  /// 上次记录的地图名称
  String? _lastMapName;

  /// 上次记录的 CT 比分
  int? _lastCtScore;

  /// 上次记录的 T 比分
  int? _lastTScore;

  /// 上次上传时间（用于防抖和心跳）
  DateTime? _lastUploadTime;

  /// 心跳间隔（5分钟）
  static const Duration _heartbeatInterval = Duration(minutes: 5);

  // ==================== 订阅管理 ====================
  /// ConsoleLogService 状态订阅
  StreamSubscription<ConsoleLogState>? _consoleSubscription;

  /// GsiService 游戏状态订阅
  StreamSubscription<GsiGameState?>? _gsiSubscription;

  /// 服务是否已初始化
  bool _isInitialized = false;

  // ==================== 公开属性 ====================
  /// 服务是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前服务器地址（IP）
  String? get currentServerAddress => _currentServerAddress;

  /// 当前服务器域名地址
  String? get currentServerDomainAddress => _currentServerDomainAddress;

  /// 上次上传时间
  DateTime? get lastUploadTime => _lastUploadTime;

  // ==================== 公开方法 ====================

  /// 初始化服务
  ///
  /// 检查 GsiService 是否运行，如果未运行则记录警告并返回
  /// 加载 IP 到域名映射，订阅 ConsoleLogService 和 GsiService 的状态流
  Future<void> initialize() async {
    if (_isInitialized) {
      LogService.d('[ScoreUpload] 服务已初始化，跳过');
      return;
    }

    // 检查 GsiService 是否运行
    if (!_gsiService.isRunning) {
      LogService.w('[ScoreUpload] GsiService 未运行，跳过初始化');
      return;
    }

    LogService.i('[ScoreUpload] 初始化比分上传服务...');

    // 加载 IP 到域名映射
    await _addressMapping.load();

    // 订阅 ConsoleLogService 状态流
    _consoleSubscription = _consoleLogService.stateStream.listen(
      _onConsoleLogStateChanged,
      onError: (error) {
        LogService.e('[ScoreUpload] ConsoleLogService 订阅错误', error);
      },
    );

    // 订阅 GsiService 状态流
    _gsiSubscription = _gsiService.stateStream.listen(
      _onGsiStateChanged,
      onError: (error) {
        LogService.e('[ScoreUpload] GsiService 订阅错误', error);
      },
    );

    _isInitialized = true;
    LogService.i('[ScoreUpload] 比分上传服务初始化完成');
  }

  /// 释放资源
  ///
  /// 取消所有订阅，清理状态
  void dispose() {
    LogService.i('[ScoreUpload] 释放比分上传服务资源...');

    // 取消订阅
    _consoleSubscription?.cancel();
    _consoleSubscription = null;

    _gsiSubscription?.cancel();
    _gsiSubscription = null;

    // 重置状态
    _currentServerAddress = null;
    _currentServerDomainAddress = null;
    _lastMapName = null;
    _lastCtScore = null;
    _lastTScore = null;
    _lastUploadTime = null;
    _isInitialized = false;

    LogService.i('[ScoreUpload] 比分上传服务资源已释放');
  }

  // ==================== 私有方法 ====================

  /// 处理 ConsoleLogService 状态变化
  ///
  /// 根据 ConsoleLogState 的变化更新服务器地址状态：
  /// - 进入游戏时设置 currentServerAddress 和 domainAddress
  /// - 离开游戏时清除状态
  /// - 只支持已知服务器（有 IP 到域名映射的服务器）
  void _onConsoleLogStateChanged(ConsoleLogState state) {
    // 检查是否进入游戏且有服务器地址
    if (state.state == GameState.inGame && state.serverAddress.isNotEmpty) {
      // 检查是否切换了服务器
      final isNewServer = _currentServerAddress != state.serverAddress;
      
      // 设置当前服务器 IP 地址
      _currentServerAddress = state.serverAddress;

      // 检查是否为已知服务器（有 IP 到域名映射）
      if (_addressMapping.hasMapping(state.serverAddress)) {
        _currentServerDomainAddress =
            _addressMapping.getDomainAddress(state.serverAddress);
        LogService.d(
          '[ScoreUpload] 已知服务器: ${state.serverAddress} -> $_currentServerDomainAddress',
        );
      } else {
        // 未知服务器，不支持上传
        _currentServerDomainAddress = null;
        LogService.d(
          '[ScoreUpload] 未知服务器，跳过比分上传: ${state.serverAddress}',
        );
      }

      // 切换服务器时重置比分状态
      if (isNewServer) {
        _lastMapName = null;
        _lastCtScore = null;
        _lastTScore = null;
        _lastUploadTime = null;
        LogService.d('[ScoreUpload] 切换服务器，重置比分状态');
      }

      LogService.d(
        '[ScoreUpload] 进入服务器: $_currentServerAddress, 上传地址: $_currentServerDomainAddress',
      );
    } else if (state.state == GameState.mainMenu ||
        state.state == GameState.unknown) {
      // 离开服务器，清除状态
      if (_currentServerAddress != null) {
        LogService.d('[ScoreUpload] 离开服务器，清除地址状态');
      }
      _currentServerAddress = null;
      _currentServerDomainAddress = null;
      // 离开服务器时也重置比分状态
      _lastMapName = null;
      _lastCtScore = null;
      _lastTScore = null;
      _lastUploadTime = null;
    }
  }

  /// 处理 GsiService 状态变化
  ///
  /// 监听 GSI 数据流，在满足上传条件时触发比分上传：
  /// - 回合阶段变为 "over"
  /// - 比分发生变化
  /// - 比分不是 0:0（热身阶段）
  /// - 距离上次上传 >= 3 秒（防抖）
  /// - 当前在游戏中且有服务器地址
  /// 
  /// 心跳机制：
  /// - 距离上次上传超过 5 分钟时，重新发送当前比分作为心跳
  /// - 保持数据有效性，避免后端标记为 unknown
  void _onGsiStateChanged(GsiGameState? state) {
    if (state == null) return;

    final map = state.map;
    final round = state.round;
    final mapPhase = map?.phase;

    // 检查地图变化，重置比分记录
    if (map?.name != null && map!.name != _lastMapName) {
      LogService.d('[ScoreUpload] 地图变化: $_lastMapName -> ${map.name}，重置比分记录');
      _lastMapName = map.name;
      _lastCtScore = null;
      _lastTScore = null;
    }

    // 获取当前比分
    final ctScore = map?.teamCt?.score ?? 0;
    final tScore = map?.teamT?.score ?? 0;
    final currentPhase = round?.phase;
    final roundNumber = map?.round ?? 0;
    final mapName = map?.name ?? '';
    final steamId = state.provider?.steamId ?? '';

    // 检查是否应该上传（回合结束 + 比分变化）
    if (_shouldUpload(
      currentPhase: currentPhase,
      ctScore: ctScore,
      tScore: tScore,
      mapName: mapName,
    )) {
      // 触发上传
      _uploadScore(
        ctScore: ctScore,
        tScore: tScore,
        round: roundNumber,
        mapName: mapName,
        steamId: steamId,
      );

      // 更新记录
      _lastCtScore = ctScore;
      _lastTScore = tScore;
    }
    // 地图结束时也触发上传（gameover 阶段比分可能变化）
    else if (_shouldUploadOnGameOver(
      mapPhase: mapPhase,
      ctScore: ctScore,
      tScore: tScore,
    )) {
      LogService.d('[ScoreUpload] 地图结束，触发最终比分上传');
      _uploadScore(
        ctScore: ctScore,
        tScore: tScore,
        round: roundNumber,
        mapName: mapName,
        steamId: steamId,
      );

      // 更新记录
      _lastCtScore = ctScore;
      _lastTScore = tScore;
    }
    // 检查是否需要发送心跳（距离上次上传超过 5 分钟）
    else if (_shouldSendHeartbeat(ctScore: ctScore, tScore: tScore, mapName: mapName)) {
      LogService.d('[ScoreUpload] 触发心跳上传');
      _uploadScore(
        ctScore: ctScore,
        tScore: tScore,
        round: roundNumber,
        mapName: mapName,
        steamId: steamId,
        isHeartbeat: true,
      );
    }
  }

  /// 判断是否需要发送心跳
  /// 
  /// 心跳条件：
  /// 1. 在游戏中且有服务器地址
  /// 2. 有有效比分（非 0:0）
  /// 3. 距离上次上传超过 5 分钟
  bool _shouldSendHeartbeat({
    required int ctScore,
    required int tScore,
    required String mapName,
  }) {
    // 条件 1: 必须在游戏中
    final consoleState = _consoleLogService.currentState;
    if (consoleState.state != GameState.inGame) {
      return false;
    }

    // 条件 2: 服务器地址不能为空
    if (_currentServerDomainAddress == null ||
        _currentServerDomainAddress!.isEmpty) {
      return false;
    }

    // 条件 3: 比分不能是 0:0
    if (ctScore == 0 && tScore == 0) {
      return false;
    }

    // 条件 4: 距离上次上传超过 5 分钟
    if (_lastUploadTime == null) {
      return false;
    }
    
    final elapsed = DateTime.now().difference(_lastUploadTime!);
    return elapsed >= _heartbeatInterval;
  }

  /// 判断地图结束时是否应该上传比分
  ///
  /// 上传条件（全部满足）：
  /// 1. 地图阶段为 "gameover"
  /// 2. 比分发生变化（与上次记录不同）
  /// 3. 距离上次上传 >= 3 秒（防抖）
  /// 4. 服务器地址不为空
  bool _shouldUploadOnGameOver({
    required String? mapPhase,
    required int ctScore,
    required int tScore,
  }) {
    // 条件 1: 地图阶段必须是 "gameover"
    if (mapPhase != 'gameover') {
      return false;
    }

    // 条件 2: 比分必须发生变化
    final scoreChanged = ctScore != _lastCtScore || tScore != _lastTScore;
    if (!scoreChanged) {
      return false;
    }

    // 条件 3: 防抖检查（3 秒）
    if (_lastUploadTime != null) {
      final elapsed = DateTime.now().difference(_lastUploadTime!);
      if (elapsed.inSeconds < 3) {
        LogService.d('[ScoreUpload] 跳过 gameover 上传: 防抖中（${elapsed.inSeconds}s < 3s）');
        return false;
      }
    }

    // 条件 4: 服务器地址不能为空
    if (_currentServerDomainAddress == null ||
        _currentServerDomainAddress!.isEmpty) {
      LogService.d('[ScoreUpload] 跳过 gameover 上传: 服务器地址为空');
      return false;
    }

    return true;
  }

  /// 判断是否应该上传比分
  ///
  /// 上传条件（全部满足）：
  /// 1. 回合阶段变为 "over"
  /// 2. 比分发生变化（与上次记录不同）
  /// 3. 比分不是 0:0（排除热身阶段）
  /// 4. 距离上次上传 >= 3 秒（防抖）
  /// 5. 当前在游戏中（ConsoleLogState.state == inGame）
  /// 6. 服务器地址不为空
  bool _shouldUpload({
    required String? currentPhase,
    required int ctScore,
    required int tScore,
    required String mapName,
  }) {
    // 条件 1: 回合阶段必须是 "over"
    if (currentPhase != 'over') {
      return false;
    }

    // 条件 2: 比分必须发生变化
    final scoreChanged = ctScore != _lastCtScore || tScore != _lastTScore;
    if (!scoreChanged) {
      return false;
    }

    // 条件 3: 比分不能是 0:0（热身阶段）
    if (ctScore == 0 && tScore == 0) {
      LogService.d('[ScoreUpload] 跳过上传: 比分为 0:0（热身阶段）');
      return false;
    }

    // 条件 4: 防抖检查（3 秒）
    if (_lastUploadTime != null) {
      final elapsed = DateTime.now().difference(_lastUploadTime!);
      if (elapsed.inSeconds < 3) {
        LogService.d('[ScoreUpload] 跳过上传: 防抖中（${elapsed.inSeconds}s < 3s）');
        return false;
      }
    }

    // 条件 5: 必须在游戏中
    final consoleState = _consoleLogService.currentState;
    if (consoleState.state != GameState.inGame) {
      LogService.d('[ScoreUpload] 跳过上传: 不在游戏中（${consoleState.state}）');
      return false;
    }

    // 条件 6: 服务器地址不能为空
    if (_currentServerDomainAddress == null ||
        _currentServerDomainAddress!.isEmpty) {
      LogService.d('[ScoreUpload] 跳过上传: 服务器地址为空');
      return false;
    }

    return true;
  }

  /// 上传比分数据
  ///
  /// 静默处理所有错误，不抛出异常，不重试
  /// [isHeartbeat] 为 true 时表示心跳上传，用于保持数据有效性
  Future<void> _uploadScore({
    required int ctScore,
    required int tScore,
    required int round,
    required String mapName,
    required String steamId,
    bool isHeartbeat = false,
  }) async {
    // 验证必要参数
    if (_currentServerDomainAddress == null ||
        _currentServerDomainAddress!.isEmpty) {
      LogService.d('[ScoreUpload] 上传取消: 服务器地址为空');
      return;
    }

    if (steamId.isEmpty) {
      LogService.d('[ScoreUpload] 上传取消: Steam ID 为空');
      return;
    }

    if (mapName.isEmpty) {
      LogService.d('[ScoreUpload] 上传取消: 地图名称为空');
      return;
    }

    final uploadType = isHeartbeat ? '心跳' : '比分';
    LogService.i(
      '[ScoreUpload] 触发${uploadType}上传: $_currentServerDomainAddress, '
      '$ctScore:$tScore, round=$round, map=$mapName',
    );

    // 更新上传时间（在发起请求前更新，防止并发）
    _lastUploadTime = DateTime.now();

    try {
      // 调用 API 上传，静默处理错误
      final error = await _scoreApi.uploadScore(
        serverAddress: _currentServerDomainAddress!,
        steamId: steamId,
        ctScore: ctScore,
        tScore: tScore,
        round: round,
        mapName: mapName,
      );

      if (error != null) {
        // 上传失败，静默忽略，不重试
        LogService.d('[ScoreUpload] 上传失败（已忽略）: $error');
      } else {
        LogService.i('[ScoreUpload] 上传成功');
      }
    } catch (e) {
      // 捕获所有异常，静默忽略
      LogService.d('[ScoreUpload] 上传异常（已忽略）: $e');
    }
  }
}
