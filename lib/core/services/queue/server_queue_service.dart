import 'dart:async';
import 'dart:math';

import '../../api/server_api.dart';
import '../../models/server_models.dart';
import '../../utils/log_service.dart';
import '../source_server_service.dart';

enum ThreadStatus { idle, requesting, success, failed }

class QueueConfig {
  final int targetPlayers;
  final int threadCount;
  final bool enableAutoRetry;
  final bool isDonator;

  const QueueConfig({
    this.targetPlayers = 60,
    this.threadCount = 3,
    this.enableAutoRetry = false,
    this.isDonator = false,
  });

  QueueConfig copyWith({
    int? targetPlayers,
    int? threadCount,
    bool? enableAutoRetry,
    bool? isDonator,
  }) {
    return QueueConfig(
      targetPlayers: targetPlayers ?? this.targetPlayers,
      threadCount: threadCount ?? this.threadCount,
      enableAutoRetry: enableAutoRetry ?? this.enableAutoRetry,
      isDonator: isDonator ?? this.isDonator,
    );
  }
}

class QueueState {
  final bool isQueueRunning;
  final List<ThreadStatus> threadStatuses;
  final ServerInfo? serverInfo;
  final MapData? mapInfo;

  QueueState({
    required this.isQueueRunning,
    required this.threadStatuses,
    this.serverInfo,
    this.mapInfo,
  });
}

typedef OnSlotFound = void Function(ServerInfo info, MapData? mapData);

class ServerQueueService {
  static final ServerQueueService _instance = ServerQueueService._internal();
  factory ServerQueueService() => _instance;
  ServerQueueService._internal();

  final ServerApi _serverApi = ServerApi();

  bool _isQueueRunning = false;
  bool _isThreadsRunning = false;
  bool _isFetching = false;
  final Set<int> _activeThreadIds = {};

  int _consecutiveFailures = 0;
  double _backoffMultiplier = 1.0;
  DateTime? _lastSuccessTime;
  String? _lastMapName;

  QueueConfig _config = const QueueConfig();
  List<ThreadStatus> _threadStatuses = [];
  String _targetServer = '';
  ServerInfo? _lastServerInfo;
  MapData? _lastMapInfo;

  OnSlotFound? _onSlotFound;
  void Function(QueueState)? _onStateUpdate;

  void startQueue({
    required String serverAddress,
    required QueueConfig config,
    required OnSlotFound onSlotFound,
    void Function(QueueState)? onStateUpdate,
  }) {
    _targetServer = serverAddress;
    _config = config;
    _onSlotFound = onSlotFound;
    _onStateUpdate = onStateUpdate;

    _threadStatuses = List.filled(config.threadCount, ThreadStatus.idle);

    _isQueueRunning = true;
    _isThreadsRunning = false;
    _isFetching = false;
    _activeThreadIds.clear();
    _consecutiveFailures = 0;
    _backoffMultiplier = 1.0;
    _lastSuccessTime = null;

    _notifyState();
    _scheduleNextFetch();
  }

  void pauseQueue() {
    _isQueueRunning = false;
    _isThreadsRunning = false;
    _isFetching = false;
    _activeThreadIds.clear();
    _notifyState();
  }

  void resumeQueue() {
    if (_targetServer.isEmpty) return;
    _isQueueRunning = true;
    _isThreadsRunning = false;
    _notifyState();
    _scheduleNextFetch();
  }

  void _notifyState() {
    _onStateUpdate?.call(
      QueueState(
        isQueueRunning: _isQueueRunning,
        threadStatuses: List.from(_threadStatuses),
        serverInfo: _lastServerInfo,
        mapInfo: _lastMapInfo,
      ),
    );
  }

  void _scheduleNextFetch() {
    if (!_isQueueRunning || _isThreadsRunning) return;

    _isThreadsRunning = true;
    _activeThreadIds.clear();

    for (int i = 0; i < _config.threadCount; i++) {
      final threadId = DateTime.now().millisecondsSinceEpoch + i;
      _activeThreadIds.add(threadId);
      final delay = i * 500;

      Future.delayed(Duration(milliseconds: delay), () {
        if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
          _startThreadWorkLoop(i, threadId);
        }
      });
    }
  }

  Future<void> _startThreadWorkLoop(int threadIndex, int threadId) async {
    if (!_isQueueRunning || !_activeThreadIds.contains(threadId)) return;

    try {
      _updateThreadStatus(threadIndex, ThreadStatus.requesting);

      await _fetchServerInfo();

      _updateThreadStatus(threadIndex, ThreadStatus.success);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_threadStatuses.length > threadIndex &&
            _threadStatuses[threadIndex] == ThreadStatus.success) {
          _updateThreadStatus(threadIndex, ThreadStatus.idle);
        }
      });
    } catch (e) {
      _updateThreadStatus(threadIndex, ThreadStatus.failed);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_threadStatuses.length > threadIndex &&
            _threadStatuses[threadIndex] == ThreadStatus.failed) {
          _updateThreadStatus(threadIndex, ThreadStatus.idle);
        }
      });
    }

    final nextInterval = _calculateNextInterval(threadIndex);

    if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
      Future.delayed(Duration(milliseconds: nextInterval), () {
        if (_isQueueRunning && _activeThreadIds.contains(threadId)) {
          _startThreadWorkLoop(threadIndex, threadId);
        }
      });
    }
  }

  Future<void> _fetchServerInfo() async {
    if (_isFetching) return;

    try {
      _isFetching = true;
      final parts = _targetServer.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final sourceInfo = await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: 5000,
      );

      if (sourceInfo != null) {
        final serverInfo = ServerInfo(
          hostName: sourceInfo.name,
          map: sourceInfo.map,
          players: sourceInfo.players,
          maxPlayers: sourceInfo.maxPlayers,
          pingLatency: sourceInfo.ping,
          gameType: sourceInfo.gameType,
          appId: sourceInfo.appId,
        );

        MapData? mapInfo = _lastMapInfo;

        if (sourceInfo.map != _lastMapName) {
          try {
            mapInfo = await _serverApi.getMapInfo(sourceInfo.map, address: _targetServer);
          } catch (e) {
            LogService.d('[ServerQueueService] 获取地图信息失败: $e');
          }
          _lastMapName = sourceInfo.map;
        }

        _consecutiveFailures = 0;
        _backoffMultiplier = 1.0;
        _lastSuccessTime = DateTime.now();

        _lastServerInfo = serverInfo;
        _lastMapInfo = mapInfo;

        _notifyState();

        if (serverInfo.players! <= _config.targetPlayers) {
          // Found slot!
          _isQueueRunning = false;
          _isThreadsRunning = false;
          _activeThreadIds.clear();

          _onSlotFound?.call(serverInfo, mapInfo);
        }
      }
    } catch (e) {
      LogService.e('[ServerQueueService] 获取服务器信息失败', e);
      _consecutiveFailures++;
      _backoffMultiplier = min(_backoffMultiplier * 1.5, 5.0);

      if (_consecutiveFailures >= 10 && _isQueueRunning) {
        LogService.w('[ServerQueueService] 网络不稳定，暂停挤服');
        pauseQueue();
      }
    } finally {
      _isFetching = false;
    }
  }

  void _updateThreadStatus(int index, ThreadStatus status) {
    if (index >= 0 && index < _threadStatuses.length) {
      _threadStatuses[index] = status;
      _notifyState();
    }
  }

  int _calculateNextInterval(int threadIndex) {
    int baseInterval = max(600, 350);

    if (_consecutiveFailures > 15) {
      baseInterval = min((baseInterval * 1.6).toInt(), 1200);
    } else if (_consecutiveFailures > 10) {
      baseInterval = min((baseInterval * 1.3).toInt(), 1000);
    } else if (_consecutiveFailures > 5) {
      baseInterval = min((baseInterval * 1.1).toInt(), 800);
    }

    final threadOffset = threadIndex * 150;
    baseInterval = max(baseInterval - threadOffset, 350);

    if (_lastSuccessTime != null &&
        DateTime.now().difference(_lastSuccessTime!).inMilliseconds < 10000) {
      baseInterval = max((baseInterval * 0.8).toInt(), 350);
    }

    return max(min(baseInterval, 1200), 350);
  }
}
