import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/env_config.dart';
import '../models/queue_user.dart';
import '../utils/log_service.dart';
import 'token_service.dart';

/// 服务事件类型基类
sealed class QueueUsersServiceEvent {}

/// 全量同步事件
class QueueUsersSyncEvent extends QueueUsersServiceEvent {
  final List<QueueUser> users;
  final int sequence;

  QueueUsersSyncEvent({required this.users, required this.sequence});
}

/// 用户加入事件
class QueueUserJoinedEvent extends QueueUsersServiceEvent {
  final QueueUser user;
  final int sequence;

  QueueUserJoinedEvent({required this.user, required this.sequence});
}

/// 用户离开事件
class QueueUserLeftEvent extends QueueUsersServiceEvent {
  final String odId;
  final String visitorId;
  final int sequence;

  QueueUserLeftEvent({
    required this.odId,
    required this.visitorId,
    required this.sequence,
  });
}

/// 用户成功事件
class QueueUserSuccessEvent extends QueueUsersServiceEvent {
  final String odId;
  final String visitorId;
  final int sequence;

  QueueUserSuccessEvent({
    required this.odId,
    required this.visitorId,
    required this.sequence,
  });
}

/// 错误事件
class QueueUsersErrorEvent extends QueueUsersServiceEvent {
  final String error;

  QueueUsersErrorEvent({required this.error});
}

/// 连接状态变化事件
class QueueUsersConnectionStateEvent extends QueueUsersServiceEvent {
  final bool isConnected;

  QueueUsersConnectionStateEvent({required this.isConnected});
}

/// WebSocket 连接管理服务
///
/// 负责与后端建立 WebSocket 连接，处理消息收发和心跳机制
abstract class QueueUsersService {
  /// 连接到指定服务器的挤服 WebSocket
  Future<void> connect(String serverAddress);

  /// 断开连接
  Future<void> disconnect();

  /// 发送开始挤服消息
  void sendJoin({String? nickname});

  /// 发送停止挤服消息
  void sendLeave();

  /// 发送挤服成功消息
  void sendSuccess();

  /// 事件流，用于 Bloc 订阅
  Stream<QueueUsersServiceEvent> get eventStream;

  /// 当前连接状态
  bool get isConnected;
}

/// QueueUsersService 的默认实现（单例）
///
/// 独立于窗口生命周期，窗口关闭后 WebSocket 连接保持
class QueueUsersServiceImpl implements QueueUsersService {
  // 单例模式
  static final QueueUsersServiceImpl _instance =
      QueueUsersServiceImpl._internal();
  factory QueueUsersServiceImpl() => _instance;
  QueueUsersServiceImpl._internal();

  /// 获取单例实例
  static QueueUsersServiceImpl get instance => _instance;

  WebSocket? _webSocket;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final StreamController<QueueUsersServiceEvent> _eventController =
      StreamController<QueueUsersServiceEvent>.broadcast();

  String? _currentServerAddress;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;

  /// 心跳间隔（秒）
  static const int _heartbeatIntervalSeconds = 30;

  /// 最大重连延迟（秒）
  static const int _maxReconnectDelaySeconds = 30;

  @override
  Stream<QueueUsersServiceEvent> get eventStream => _eventController.stream;

  @override
  bool get isConnected => _isConnected;

  /// 安全地添加事件，避免在 controller 关闭后添加
  void _safeAddEvent(QueueUsersServiceEvent event) {
    if (!_isDisposed) {
      _eventController.add(event);
    }
  }

  @override
  Future<void> connect(String serverAddress) async {
    if (_isConnecting) {
      LogService.d('[QueueUsersService] 正在连接中，忽略重复请求');
      return;
    }

    // 如果已连接到同一服务器，直接返回
    if (_isConnected && _currentServerAddress == serverAddress) {
      LogService.d('[QueueUsersService] 已连接到相同服务器，忽略请求');
      return;
    }

    // 如果连接到不同服务器，先断开
    if (_isConnected) {
      await disconnect();
    }

    _currentServerAddress = serverAddress;
    _shouldReconnect = true;
    _reconnectAttempts = 0;

    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_currentServerAddress == null) return;
    if (_isConnecting) return;

    _isConnecting = true;

    try {
      // 构建 WebSocket URL
      final wsUrl = _buildWebSocketUrl(_currentServerAddress!);
      LogService.d('[QueueUsersService] 正在连接: $wsUrl');

      // 获取认证 headers
      final authHeaders = TokenService.instance.getAuthHeaders();
      LogService.d(
        '[QueueUsersService] 认证状态: ${authHeaders.isNotEmpty ? '已登录' : '未登录'}',
      );

      _webSocket = await WebSocket.connect(wsUrl, headers: authHeaders).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket 连接超时');
        },
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      LogService.d('[QueueUsersService] 连接成功');
      _safeAddEvent(QueueUsersConnectionStateEvent(isConnected: true));

      // 开始监听消息
      _socketSubscription = _webSocket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // 启动心跳
      _startHeartbeat();
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      LogService.e('[QueueUsersService] 连接失败', e);
      _safeAddEvent(QueueUsersConnectionStateEvent(isConnected: false));
      _safeAddEvent(QueueUsersErrorEvent(error: '连接失败: $e'));

      // 尝试重连
      _scheduleReconnect();
    }
  }

  String _buildWebSocketUrl(String serverAddress) {
    final baseUrl = EnvConfig.apiBaseUrl;
    // 将 http/https 转换为 ws/wss
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    final encodedAddress = Uri.encodeComponent(serverAddress);
    return '$wsBase/api/stub$encodedAddress';
  }

  void _onMessage(dynamic data) {
    try {
      final message = data is String ? data : utf8.decode(data as List<int>);
      final json = jsonDecode(message) as Map<String, dynamic>;
      final action = json['action'] as String?;

      LogService.d('[QueueUsersService] 收到消息: $action');

      switch (action) {
        case 'sync':
          _handleSyncMessage(json);
          break;
        case 'join':
          _handleJoinMessage(json);
          break;
        case 'leave':
          _handleLeaveMessage(json);
          break;
        case 'success':
          _handleSuccessMessage(json);
          break;
        case 'pong':
          // 心跳响应，无需处理
          LogService.d('[QueueUsersService] 收到 pong');
          break;
        case 'error':
          _handleErrorMessage(json);
          break;
        default:
          LogService.w('[QueueUsersService] 未知消息类型: $action');
      }
    } catch (e) {
      LogService.e('[QueueUsersService] 解析消息失败', e);
    }
  }

  void _handleSyncMessage(Map<String, dynamic> json) {
    try {
      final usersJson = json['users'] as List<dynamic>? ?? [];
      final sequence = json['sequence'] as int? ?? 0;

      final users = usersJson
          .map((u) => QueueUser.fromJson(u as Map<String, dynamic>))
          .toList();

      LogService.d('[QueueUsersService] 同步用户列表: ${users.length} 人');
      _safeAddEvent(QueueUsersSyncEvent(users: users, sequence: sequence));
    } catch (e) {
      LogService.e('[QueueUsersService] 解析 sync 消息失败', e);
    }
  }

  void _handleJoinMessage(Map<String, dynamic> json) {
    try {
      final userJson = json['user'] as Map<String, dynamic>?;
      final sequence = json['sequence'] as int? ?? 0;

      if (userJson != null) {
        final user = QueueUser.fromJson(userJson);
        LogService.d('[QueueUsersService] 用户加入: ${user.uniqueId}');
        _safeAddEvent(QueueUserJoinedEvent(user: user, sequence: sequence));
      }
    } catch (e) {
      LogService.e('[QueueUsersService] 解析 join 消息失败', e);
    }
  }

  void _handleLeaveMessage(Map<String, dynamic> json) {
    try {
      final odId = json['odId'] as String? ?? '';
      final visitorId = json['visitorId'] as String? ?? '';
      final sequence = json['sequence'] as int? ?? 0;

      LogService.d(
        '[QueueUsersService] 用户离开: odId=$odId, visitorId=$visitorId',
      );
      _safeAddEvent(
        QueueUserLeftEvent(
          odId: odId,
          visitorId: visitorId,
          sequence: sequence,
        ),
      );
    } catch (e) {
      LogService.e('[QueueUsersService] 解析 leave 消息失败', e);
    }
  }

  void _handleSuccessMessage(Map<String, dynamic> json) {
    try {
      final odId = json['odId'] as String? ?? '';
      final visitorId = json['visitorId'] as String? ?? '';
      final sequence = json['sequence'] as int? ?? 0;

      LogService.d(
        '[QueueUsersService] 用户成功: odId=$odId, visitorId=$visitorId',
      );
      _safeAddEvent(
        QueueUserSuccessEvent(
          odId: odId,
          visitorId: visitorId,
          sequence: sequence,
        ),
      );
    } catch (e) {
      LogService.e('[QueueUsersService] 解析 success 消息失败', e);
    }
  }

  void _handleErrorMessage(Map<String, dynamic> json) {
    final error = json['error'] as String? ?? 'unknown_error';
    LogService.e('[QueueUsersService] 服务器错误: $error');

    // 转换错误码为用户友好的消息
    final errorMessage = _getErrorMessage(error);
    _safeAddEvent(QueueUsersErrorEvent(error: errorMessage));
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid_server_address':
        return '服务器地址无效';
      case 'too_many_connections':
        return '连接数已达上限';
      case 'kicked_by_new_connection':
        return '已在其他设备连接';
      default:
        return '未知错误: $errorCode';
    }
  }

  void _onError(dynamic error) {
    LogService.e('[QueueUsersService] WebSocket 错误', error);
    _safeAddEvent(QueueUsersErrorEvent(error: '连接错误: $error'));
  }

  void _onDone() {
    LogService.d('[QueueUsersService] WebSocket 连接关闭');
    _cleanup();

    _safeAddEvent(QueueUsersConnectionStateEvent(isConnected: false));

    // 如果应该重连，则尝试重连
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _cleanup() {
    _isConnected = false;
    _isConnecting = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _webSocket = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSeconds),
      (_) => _sendPing(),
    );
  }

  void _sendPing() {
    if (_isConnected && _webSocket != null) {
      try {
        _webSocket!.add(jsonEncode({'action': 'ping'}));
        LogService.d('[QueueUsersService] 发送 ping');
      } catch (e) {
        LogService.e('[QueueUsersService] 发送 ping 失败', e);
      }
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();

    // 计算重连延迟：min(2^attempts, maxDelay)
    final delay = calculateReconnectDelay(_reconnectAttempts);
    _reconnectAttempts++;

    LogService.d(
      '[QueueUsersService] 将在 ${delay}s 后重连 (第 $_reconnectAttempts 次)',
    );

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_shouldReconnect && !_isConnected && !_isConnecting) {
        _doConnect();
      }
    });
  }

  /// 计算重连延迟（秒）
  /// 使用指数退避策略：1s → 2s → 4s → 8s → 16s → 30s → 30s...
  static int calculateReconnectDelay(int attempts) {
    if (attempts < 0) return 1;
    // 2^attempts，但最小为 1，最大为 30
    final delay = 1 << attempts; // 等价于 pow(2, attempts)
    return delay > _maxReconnectDelaySeconds
        ? _maxReconnectDelaySeconds
        : delay;
  }

  @override
  Future<void> disconnect() async {
    LogService.d('[QueueUsersService] 断开连接');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_webSocket != null) {
      try {
        await _webSocket!.close();
      } catch (e) {
        LogService.e('[QueueUsersService] 关闭 WebSocket 失败', e);
      }
    }

    _cleanup();
    _currentServerAddress = null;
    _safeAddEvent(QueueUsersConnectionStateEvent(isConnected: false));
  }

  @override
  void sendJoin({String? nickname}) {
    if (!_isConnected || _webSocket == null) {
      LogService.w('[QueueUsersService] 未连接，无法发送 join');
      return;
    }

    try {
      final data = <String, dynamic>{'action': 'join'};
      if (nickname != null && nickname.isNotEmpty) {
        data['nickname'] = nickname;
      }
      _webSocket!.add(jsonEncode(data));
      LogService.d('[QueueUsersService] 发送 join, nickname: $nickname');
    } catch (e) {
      LogService.e('[QueueUsersService] 发送 join 失败', e);
    }
  }

  @override
  void sendLeave() {
    _sendAction('leave');
  }

  @override
  void sendSuccess() {
    _sendAction('success');
  }

  void _sendAction(String action) {
    if (!_isConnected || _webSocket == null) {
      LogService.w('[QueueUsersService] 未连接，无法发送 $action');
      return;
    }

    try {
      _webSocket!.add(jsonEncode({'action': action}));
      LogService.d('[QueueUsersService] 发送 $action');
    } catch (e) {
      LogService.e('[QueueUsersService] 发送 $action 失败', e);
    }
  }

  /// 释放资源
  void dispose() {
    _isDisposed = true;
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    _webSocket?.close();
    _eventController.close();
  }
}
