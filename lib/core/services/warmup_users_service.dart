import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/env_config.dart';
import '../constants/api_constants.dart';
import '../models/queue_user.dart';
import '../utils/log_service.dart';
import 'token_service.dart';

/// 暖服服务事件类型基类
sealed class WarmupUsersServiceEvent {}

/// 全量同步事件
class WarmupUsersSyncEvent extends WarmupUsersServiceEvent {
  final List<QueueUser> users;
  final int sequence;

  WarmupUsersSyncEvent({required this.users, required this.sequence});
}

/// 用户加入事件
class WarmupUserJoinedEvent extends WarmupUsersServiceEvent {
  final QueueUser user;
  final int sequence;

  WarmupUserJoinedEvent({required this.user, required this.sequence});
}

/// 用户离开事件
class WarmupUserLeftEvent extends WarmupUsersServiceEvent {
  final String odId;
  final String visitorId;
  final int sequence;

  WarmupUserLeftEvent({
    required this.odId,
    required this.visitorId,
    required this.sequence,
  });
}

/// 用户成功事件
class WarmupUserSuccessEvent extends WarmupUsersServiceEvent {
  final String odId;
  final String visitorId;
  final int sequence;

  WarmupUserSuccessEvent({
    required this.odId,
    required this.visitorId,
    required this.sequence,
  });
}

/// 错误事件
class WarmupUsersErrorEvent extends WarmupUsersServiceEvent {
  final String error;

  WarmupUsersErrorEvent({required this.error});
}

/// 连接状态变化事件
class WarmupUsersConnectionStateEvent extends WarmupUsersServiceEvent {
  final bool isConnected;

  WarmupUsersConnectionStateEvent({required this.isConnected});
}

/// 暖服 WebSocket 连接管理服务（单例）
///
/// 与 [QueueUsersServiceImpl] 完全独立，使用 `roomType=warmup`。
/// 根据后端房间隔离规则，queue 和 warmup 互不影响。
class WarmupUsersService {
  // 单例模式
  static final WarmupUsersService _instance = WarmupUsersService._internal();
  factory WarmupUsersService() => _instance;
  WarmupUsersService._internal();

  /// 获取单例实例
  static WarmupUsersService get instance => _instance;

  WebSocket? _webSocket;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final StreamController<WarmupUsersServiceEvent> _eventController =
      StreamController<WarmupUsersServiceEvent>.broadcast();

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

  /// 事件流，用于 Bloc 订阅
  Stream<WarmupUsersServiceEvent> get eventStream => _eventController.stream;

  /// 当前连接状态
  bool get isConnected => _isConnected;

  /// 安全地添加事件，避免在 controller 关闭后添加
  void _safeAddEvent(WarmupUsersServiceEvent event) {
    if (!_isDisposed) {
      _eventController.add(event);
    }
  }

  /// 连接到指定服务器的暖服 WebSocket
  Future<void> connect(String serverAddress) async {
    if (_isConnecting) {
      LogService.d('[WarmupUsersService] 正在连接中，忽略重复请求');
      return;
    }

    // 如果已连接到同一服务器，直接返回
    if (_isConnected && _currentServerAddress == serverAddress) {
      LogService.d('[WarmupUsersService] 已连接到相同服务器，忽略请求');
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
      // 构建 WebSocket URL（roomType=warmup）
      final wsUrl = _buildWebSocketUrl(_currentServerAddress!);
      LogService.d('[WarmupUsersService] 正在连接: $wsUrl');

      // 获取认证 headers
      final authHeaders = TokenService.instance.getAuthHeaders();
      LogService.d(
        '[WarmupUsersService] 认证状态: ${authHeaders.isNotEmpty ? '已登录' : '未登录'}',
      );

      _webSocket = await WebSocket.connect(wsUrl, headers: authHeaders).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket 连接超时');
        },
      );

      // 连接期间若已请求断开（disconnect 会把 _shouldReconnect 置 false 并清空地址），
      // 立即关闭刚建立的连接。否则会泄漏一个无人管理的 WebSocket，
      // 导致即使关闭面板也一直卡在暖服竞技场里。
      if (!_shouldReconnect || _currentServerAddress == null) {
        LogService.d('[WarmupUsersService] 连接期间已请求断开，立即关闭新建连接');
        try {
          await _webSocket!.close();
        } catch (_) {}
        _webSocket = null;
        _isConnecting = false;
        _isConnected = false;
        _safeAddEvent(WarmupUsersConnectionStateEvent(isConnected: false));
        return;
      }

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      LogService.d('[WarmupUsersService] 连接成功');
      _safeAddEvent(WarmupUsersConnectionStateEvent(isConnected: true));

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
      LogService.e('[WarmupUsersService] 连接失败', e);
      _safeAddEvent(WarmupUsersConnectionStateEvent(isConnected: false));
      _safeAddEvent(WarmupUsersErrorEvent(error: '连接失败: $e'));

      // 尝试重连
      _scheduleReconnect();
    }
  }

  String _buildWebSocketUrl(String serverAddress) {
    final baseUrl = EnvConfig.apiBaseUrl;
    // 将 http/https 转换为 ws/wss
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    final encodedAddress = Uri.encodeComponent(serverAddress);
    return '$wsBase${ApiConstants.serverUsersWsPath(encodedAddress, 'warmup')}';
  }

  void _onMessage(dynamic data) {
    try {
      final message = data is String ? data : utf8.decode(data as List<int>);
      final json = jsonDecode(message) as Map<String, dynamic>;
      final action = json['action'] as String?;

      LogService.d('[WarmupUsersService] 收到消息: $action');

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
          LogService.d('[WarmupUsersService] 收到 pong');
          break;
        case 'error':
          _handleErrorMessage(json);
          break;
        default:
          LogService.w('[WarmupUsersService] 未知消息类型: $action');
      }
    } catch (e) {
      LogService.e('[WarmupUsersService] 解析消息失败', e);
    }
  }

  void _handleSyncMessage(Map<String, dynamic> json) {
    try {
      final usersJson = json['users'] as List<dynamic>? ?? [];
      final sequence = json['sequence'] as int? ?? 0;

      final users = usersJson
          .map((u) => QueueUser.fromJson(u as Map<String, dynamic>))
          .toList();

      LogService.d('[WarmupUsersService] 同步用户列表: ${users.length} 人');
      _safeAddEvent(WarmupUsersSyncEvent(users: users, sequence: sequence));
    } catch (e) {
      LogService.e('[WarmupUsersService] 解析 sync 消息失败', e);
    }
  }

  void _handleJoinMessage(Map<String, dynamic> json) {
    try {
      final userJson = json['user'] as Map<String, dynamic>?;
      final sequence = json['sequence'] as int? ?? 0;

      if (userJson != null) {
        final user = QueueUser.fromJson(userJson);
        LogService.d('[WarmupUsersService] 用户加入: ${user.uniqueId}');
        _safeAddEvent(WarmupUserJoinedEvent(user: user, sequence: sequence));
      }
    } catch (e) {
      LogService.e('[WarmupUsersService] 解析 join 消息失败', e);
    }
  }

  void _handleLeaveMessage(Map<String, dynamic> json) {
    try {
      final odId = json['odId'] as String? ?? '';
      final visitorId = json['visitorId'] as String? ?? '';
      final sequence = json['sequence'] as int? ?? 0;

      LogService.d(
        '[WarmupUsersService] 用户离开: odId=$odId, visitorId=$visitorId',
      );
      _safeAddEvent(
        WarmupUserLeftEvent(
          odId: odId,
          visitorId: visitorId,
          sequence: sequence,
        ),
      );
    } catch (e) {
      LogService.e('[WarmupUsersService] 解析 leave 消息失败', e);
    }
  }

  void _handleSuccessMessage(Map<String, dynamic> json) {
    try {
      final odId = json['odId'] as String? ?? '';
      final visitorId = json['visitorId'] as String? ?? '';
      final sequence = json['sequence'] as int? ?? 0;

      LogService.d(
        '[WarmupUsersService] 用户成功: odId=$odId, visitorId=$visitorId',
      );
      _safeAddEvent(
        WarmupUserSuccessEvent(
          odId: odId,
          visitorId: visitorId,
          sequence: sequence,
        ),
      );
    } catch (e) {
      LogService.e('[WarmupUsersService] 解析 success 消息失败', e);
    }
  }

  void _handleErrorMessage(Map<String, dynamic> json) {
    final error = json['error'] as String? ?? 'unknown_error';
    LogService.e('[WarmupUsersService] 服务器错误: $error');

    final errorMessage = _getErrorMessage(error);
    _safeAddEvent(WarmupUsersErrorEvent(error: errorMessage));
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
    LogService.e('[WarmupUsersService] WebSocket 错误', error);
    _safeAddEvent(WarmupUsersErrorEvent(error: '连接错误: $error'));
  }

  void _onDone() {
    LogService.d('[WarmupUsersService] WebSocket 连接关闭');
    _cleanup();

    _safeAddEvent(WarmupUsersConnectionStateEvent(isConnected: false));

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _cleanup() {
    _isConnected = false;
    _isConnecting = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    unawaited(_socketSubscription?.cancel());
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
        LogService.d('[WarmupUsersService] 发送 ping');
      } catch (e) {
        LogService.e('[WarmupUsersService] 发送 ping 失败', e);
      }
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();

    final delay = _calculateReconnectDelay(_reconnectAttempts);
    _reconnectAttempts++;

    LogService.d(
      '[WarmupUsersService] 将在 ${delay}s 后重连 (第 $_reconnectAttempts 次)',
    );

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_shouldReconnect && !_isConnected && !_isConnecting) {
        _doConnect();
      }
    });
  }

  /// 计算重连延迟（秒）
  static int _calculateReconnectDelay(int attempts) {
    if (attempts < 0) return 1;
    final delay = 1 << attempts;
    return delay > _maxReconnectDelaySeconds
        ? _maxReconnectDelaySeconds
        : delay;
  }

  /// 断开连接
  Future<void> disconnect() async {
    LogService.d('[WarmupUsersService] 断开连接');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_webSocket != null) {
      try {
        await _webSocket!.close();
      } catch (e) {
        LogService.e('[WarmupUsersService] 关闭 WebSocket 失败', e);
      }
    }

    _cleanup();
    _currentServerAddress = null;
    _safeAddEvent(WarmupUsersConnectionStateEvent(isConnected: false));
  }

  /// 发送开始暖服消息
  void sendJoin({String? nickname}) {
    if (!_isConnected || _webSocket == null) {
      LogService.w('[WarmupUsersService] 未连接，无法发送 join');
      return;
    }

    try {
      final data = <String, dynamic>{'action': 'join'};
      if (nickname != null && nickname.isNotEmpty) {
        data['nickname'] = nickname;
      }
      _webSocket!.add(jsonEncode(data));
      LogService.d('[WarmupUsersService] 发送 join, nickname: $nickname');
    } catch (e) {
      LogService.e('[WarmupUsersService] 发送 join 失败', e);
    }
  }

  /// 发送停止暖服消息
  void sendLeave() {
    _sendAction('leave');
  }

  /// 发送暖服成功消息
  void sendSuccess() {
    _sendAction('success');
  }

  void _sendAction(String action) {
    if (!_isConnected || _webSocket == null) {
      LogService.w('[WarmupUsersService] 未连接，无法发送 $action');
      return;
    }

    try {
      _webSocket!.add(jsonEncode({'action': action}));
      LogService.d('[WarmupUsersService] 发送 $action');
    } catch (e) {
      LogService.e('[WarmupUsersService] 发送 $action 失败', e);
    }
  }

  /// 释放资源
  void dispose() {
    _isDisposed = true;
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    unawaited(_socketSubscription?.cancel());
    unawaited(_webSocket?.close());
    unawaited(_eventController.close());
  }
}
