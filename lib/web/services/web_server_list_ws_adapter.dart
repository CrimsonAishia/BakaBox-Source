import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart';
import 'dart:js_interop';

import '../../core/api/env_config.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/log_service.dart';
import '../models/web_server_list_models.dart';

sealed class WebServerListWsEvent {}

class WebServerListSnapshotEvent extends WebServerListWsEvent {
  final WebServerListData data;

  WebServerListSnapshotEvent(this.data);
}

class WebServerListConnectionChangedEvent extends WebServerListWsEvent {
  final bool isConnected;

  WebServerListConnectionChangedEvent(this.isConnected);
}

class WebServerListErrorEvent extends WebServerListWsEvent {
  final String message;

  WebServerListErrorEvent(this.message);
}

class WebServerListWsAdapter {
  WebServerListWsAdapter({
    String? wsUrl,
    this.category,
    this.intervalSeconds = 8,
    this.once = false,
  }) : _wsUrl =
           wsUrl ??
           _buildDefaultWsUrl(
             category: category,
             intervalSeconds: intervalSeconds,
             once: once,
           );

  final String? category;
  final int intervalSeconds;
  final bool once;
  final String _wsUrl;
  final StreamController<WebServerListWsEvent> _eventController =
      StreamController<WebServerListWsEvent>.broadcast();

  WebSocket? _socket;
  StreamSubscription<MessageEvent>? _messageSubscription;
  StreamSubscription<Event>? _openSubscription;
  StreamSubscription<Event>? _closeSubscription;
  StreamSubscription<Event>? _errorSubscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _manualDisconnect = false;
  bool _isConnected = false;

  Stream<WebServerListWsEvent> get events => _eventController.stream;

  bool get isConnected => _isConnected;

  void connect() {
    if (_disposed) {
      return;
    }
    if (_socket != null) {
      return;
    }

    _manualDisconnect = false;
    _reconnectTimer?.cancel();

    try {
      LogService.d('[WebServerListWsAdapter] connecting: $_wsUrl');
      final socket = WebSocket(_wsUrl);
      _socket = socket;

      _openSubscription = socket.onOpen.listen((_) {
        _isConnected = true;
        _safeAddEvent(WebServerListConnectionChangedEvent(true));
        LogService.i('[WebServerListWsAdapter] connected');
      });

      _messageSubscription = socket.onMessage.listen(_handleMessage);

      _closeSubscription = socket.onClose.listen((_) {
        LogService.w('[WebServerListWsAdapter] connection closed');
        _handleDisconnected(shouldReconnect: !_manualDisconnect);
      });

      _errorSubscription = socket.onError.listen((_) {
        LogService.e('[WebServerListWsAdapter] connection error');
        _safeAddEvent(WebServerListErrorEvent('WebSocket 连接失败'));
        _handleDisconnected(shouldReconnect: !_manualDisconnect);
      });
    } catch (error, stackTrace) {
      LogService.e(
        '[WebServerListWsAdapter] connect failed',
        error,
        stackTrace,
      );
      _safeAddEvent(WebServerListErrorEvent('WebSocket 初始化失败'));
      _handleDisconnected(shouldReconnect: true);
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _disposeSocket();
    if (_isConnected) {
      _isConnected = false;
      _safeAddEvent(WebServerListConnectionChangedEvent(false));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventController.close();
  }

  void _handleMessage(MessageEvent event) {
    try {
      final data = event.data?.dartify();

      if (data is! String) {
        LogService.w(
          '[WebServerListWsAdapter] unsupported message type: ${data.runtimeType}',
        );
        return;
      }

      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        LogService.w('[WebServerListWsAdapter] invalid message payload');
        return;
      }

      final type = decoded['type'] as String?;
      if (type != 'web_server_list_snapshot') {
        LogService.d('[WebServerListWsAdapter] ignored message type: $type');
        return;
      }

      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('payload 不是对象');
      }

      final snapshot = WebServerListData.fromJson(payload);
      _safeAddEvent(WebServerListSnapshotEvent(snapshot));
    } catch (error, stackTrace) {
      LogService.e(
        '[WebServerListWsAdapter] parse message failed',
        error,
        stackTrace,
      );
      _safeAddEvent(WebServerListErrorEvent('服务器列表数据解析失败'));
    }
  }

  void _handleDisconnected({required bool shouldReconnect}) {
    unawaited(_disposeSocket());
    if (_isConnected) {
      _isConnected = false;
      _safeAddEvent(WebServerListConnectionChangedEvent(false));
    }
    if (shouldReconnect && !_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_disposed || _manualDisconnect) {
        return;
      }
      connect();
    });
  }

  Future<void> _disposeSocket() async {
    await _messageSubscription?.cancel();
    await _openSubscription?.cancel();
    await _closeSubscription?.cancel();
    await _errorSubscription?.cancel();
    _messageSubscription = null;
    _openSubscription = null;
    _closeSubscription = null;
    _errorSubscription = null;

    final socket = _socket;
    _socket = null;
    socket?.close();
  }

  void _safeAddEvent(WebServerListWsEvent event) {
    if (!_disposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  static String _buildDefaultWsUrl({
    String? category,
    int intervalSeconds = 8,
    bool once = false,
  }) {
    final fallbackBaseUri = Uri.parse(EnvConfig.apiBaseUrl);
    final scheme = fallbackBaseUri.scheme == 'https' ? 'wss' : 'ws';
    final clampedIntervalSeconds = intervalSeconds.clamp(3, 30);
    final queryParameters = <String, String>{
      'intervalSeconds': clampedIntervalSeconds.toString(),
      'once': once.toString(),
    };
    if (category != null && category.isNotEmpty) {
      queryParameters['category'] = category;
    }

    return Uri(
      scheme: scheme,
      host: fallbackBaseUri.host,
      port: fallbackBaseUri.hasPort ? fallbackBaseUri.port : null,
      path: ApiConstants.webServerListWsPath,
      queryParameters: queryParameters,
    ).toString();
  }
}
