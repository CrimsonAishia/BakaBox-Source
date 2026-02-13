import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/queue_users_service.dart';
import '../../utils/log_service.dart';
import 'queue_users_event.dart';
import 'queue_users_state.dart';

/// 挤服用户状态管理
///
/// 管理用户列表、连接状态和动画触发
/// 订阅 QueueUsersService 事件流，将服务事件转换为 Bloc 事件
class QueueUsersBloc extends Bloc<QueueUsersEvent, QueueUsersState> {
  final QueueUsersService _service;
  StreamSubscription<QueueUsersServiceEvent>? _serviceSubscription;
  
  /// 待发送的 join 信息（连接成功后自动发送）
  QueueUsersJoin? _pendingJoin;
  
  /// 最后一次成功发送的 join 信息（用于重连时自动重发）
  QueueUsersJoin? _lastJoin;

  QueueUsersBloc({required QueueUsersService service})
      : _service = service,
        super(QueueUsersState.initial()) {
    // 注册事件处理器
    on<QueueUsersConnect>(_onConnect);
    on<QueueUsersDisconnect>(_onDisconnect);
    on<QueueUsersJoin>(_onJoin);
    on<QueueUsersLeave>(_onLeave);
    on<QueueUsersSuccess>(_onSuccess);

    // 内部事件（来自 Service）
    on<QueueUsersSynced>(_onSynced);
    on<QueueUserJoined>(_onUserJoined);
    on<QueueUserLeft>(_onUserLeft);
    on<QueueUserSucceeded>(_onUserSucceeded);
    on<QueueUsersError>(_onError);
    on<QueueUsersConnectionChanged>(_onConnectionChanged);
    on<QueueUsersClearAnimationTriggers>(_onClearAnimationTriggers);

    // 订阅服务事件流
    _subscribeToService();
  }

  /// 订阅 QueueUsersService 事件流
  void _subscribeToService() {
    _serviceSubscription = _service.eventStream.listen((event) {
      switch (event) {
        case QueueUsersSyncEvent():
          add(QueueUsersSynced(users: event.users));
        case QueueUserJoinedEvent():
          add(QueueUserJoined(user: event.user));
        case QueueUserLeftEvent():
          add(QueueUserLeft(odId: event.odId, visitorId: event.visitorId));
        case QueueUserSuccessEvent():
          add(QueueUserSucceeded(odId: event.odId, visitorId: event.visitorId));
        case QueueUsersErrorEvent():
          add(QueueUsersError(error: event.error));
        case QueueUsersConnectionStateEvent():
          add(QueueUsersConnectionChanged(isConnected: event.isConnected));
      }
    });
  }

  // ============================================================================
  // Public Event Handlers (UI triggered)
  // ============================================================================

  /// 处理连接事件
  /// Requirements: 1.1
  Future<void> _onConnect(
    QueueUsersConnect event,
    Emitter<QueueUsersState> emit,
  ) async {
    LogService.d('[QueueUsersBloc] 连接到服务器: ${event.serverAddress}');

    emit(state.copyWith(
      isConnecting: true,
      clearError: true,
    ));

    await _service.connect(event.serverAddress);
  }

  /// 处理断开连接事件
  /// Requirements: 1.4
  Future<void> _onDisconnect(
    QueueUsersDisconnect event,
    Emitter<QueueUsersState> emit,
  ) async {
    LogService.d('[QueueUsersBloc] 断开连接');

    // 清除 join 信息，避免重连时错误地发送 join
    _lastJoin = null;
    _pendingJoin = null;

    await _service.disconnect();

    emit(state.copyWith(
      isConnected: false,
      isConnecting: false,
      users: const [],
      clearJoinedUserId: true,
      clearLeftUserId: true,
      clearSuccessUserId: true,
    ));
  }

  /// 处理用户开始挤服事件
  /// 服务器会在 sync 消息中返回当前用户（isSelf=true），不需要客户端手动添加
  void _onJoin(
    QueueUsersJoin event,
    Emitter<QueueUsersState> emit,
  ) {
    // 保存 join 信息，用于重连时自动重发
    _lastJoin = event;
    
    // 如果还没连接，保存 join 信息，等连接成功后再发送
    if (!state.isConnected) {
      LogService.d('[QueueUsersBloc] 未连接，保存 join 信息等待连接');
      _pendingJoin = event;
      return;
    }
    
    LogService.d('[QueueUsersBloc] 发送 join');
    _service.sendJoin();
    // 服务器会通过 sync 消息返回更新后的用户列表（包括自己）
  }

  /// 处理用户停止挤服事件
  /// 服务器会通过 sync 消息更新用户列表
  void _onLeave(
    QueueUsersLeave event,
    Emitter<QueueUsersState> emit,
  ) {
    LogService.d('[QueueUsersBloc] 发送 leave');
    _service.sendLeave();
    // 清除 lastJoin，停止挤服后不再自动重发
    _lastJoin = null;
    _pendingJoin = null;
    // 服务器会通过 sync 消息返回更新后的用户列表
  }

  /// 处理用户挤服成功事件
  void _onSuccess(
    QueueUsersSuccess event,
    Emitter<QueueUsersState> emit,
  ) {
    LogService.d('[QueueUsersBloc] 发送 success');
    _service.sendSuccess();
    // 挤服成功后清除 lastJoin，不再自动重发
    _lastJoin = null;
    _pendingJoin = null;
  }

  // ============================================================================
  // Internal Event Handlers (from QueueUsersService)
  // ============================================================================

  /// 处理全量同步事件
  /// 服务器会返回所有用户（包括自己，isSelf=true）
  void _onSynced(
    QueueUsersSynced event,
    Emitter<QueueUsersState> emit,
  ) {
    LogService.d('[QueueUsersBloc] 同步用户列表: ${event.users.length} 人');
    
    // 直接使用服务器返回的用户列表
    emit(state.copyWith(users: event.users));
  }

  /// 处理用户加入事件
  void _onUserJoined(
    QueueUserJoined event,
    Emitter<QueueUsersState> emit,
  ) {
    final user = event.user;
    LogService.d('[QueueUsersBloc] 收到用户加入事件: ${user.uniqueId}, nickname: ${user.nickname}');
    LogService.d('[QueueUsersBloc] 当前用户列表: ${state.users.map((u) => u.uniqueId).toList()}');

    // 检查用户是否已存在（避免重复添加）
    final existingIndex = state.users.indexWhere(
      (u) => u.uniqueId == user.uniqueId,
    );

    if (existingIndex >= 0) {
      LogService.d('[QueueUsersBloc] 用户已存在，忽略');
      return;
    }

    // 添加用户到列表，并设置动画触发标记
    final updatedUsers = [...state.users, user];
    LogService.d('[QueueUsersBloc] 添加用户后列表: ${updatedUsers.map((u) => u.uniqueId).toList()}');

    emit(state.copyWith(
      users: updatedUsers,
      joinedUserId: user.uniqueId,
      clearLeftUserId: true,
      clearSuccessUserId: true,
    ));
  }

  /// 处理用户离开事件
  void _onUserLeft(
    QueueUserLeft event,
    Emitter<QueueUsersState> emit,
  ) {
    final userId = event.odId.isNotEmpty ? event.odId : event.visitorId;
    LogService.d('[QueueUsersBloc] 用户离开: $userId');

    // 从列表中移除用户
    final updatedUsers = state.users.where(
      (u) => u.uniqueId != userId,
    ).toList();

    // 如果用户不在列表中，忽略
    if (updatedUsers.length == state.users.length) {
      LogService.d('[QueueUsersBloc] 用户不在列表中，忽略');
      return;
    }

    emit(state.copyWith(
      users: updatedUsers,
      leftUserId: userId,
      clearJoinedUserId: true,
      clearSuccessUserId: true,
    ));
  }

  /// 处理用户成功事件
  void _onUserSucceeded(
    QueueUserSucceeded event,
    Emitter<QueueUsersState> emit,
  ) {
    final userId = event.odId.isNotEmpty ? event.odId : event.visitorId;
    LogService.d('[QueueUsersBloc] 用户成功: $userId');

    // 从用户列表中移除成功的用户
    final updatedUsers = state.users.where((u) => u.uniqueId != userId).toList();
    
    // 设置成功动画触发标记
    emit(state.copyWith(
      users: updatedUsers,
      successUserId: userId,
      clearJoinedUserId: true,
      clearLeftUserId: true,
    ));
  }

  /// 处理错误事件
  void _onError(
    QueueUsersError event,
    Emitter<QueueUsersState> emit,
  ) {
    LogService.e('[QueueUsersBloc] 错误: ${event.error}');

    emit(state.copyWith(
      error: event.error,
      isConnecting: false,
    ));
  }

  /// 处理连接状态变化事件
  void _onConnectionChanged(
    QueueUsersConnectionChanged event,
    Emitter<QueueUsersState> emit,
  ) {
    LogService.d('[QueueUsersBloc] 连接状态变化: ${event.isConnected}');

    emit(state.copyWith(
      isConnected: event.isConnected,
      isConnecting: false,
    ));
    
    // 连接成功后，如果有待发送的 join，立即发送
    if (event.isConnected && _pendingJoin != null) {
      LogService.d('[QueueUsersBloc] 连接成功，发送待处理的 join');
      add(_pendingJoin!);
      _pendingJoin = null;
    } else if (event.isConnected && _lastJoin != null) {
      // 重连成功后，使用上次的 join 信息重新加入
      LogService.d('[QueueUsersBloc] 重连成功，使用上次的 join 信息重新加入');
      _service.sendJoin();
    }
  }

  /// 处理清除动画触发标记事件
  void _onClearAnimationTriggers(
    QueueUsersClearAnimationTriggers event,
    Emitter<QueueUsersState> emit,
  ) {
    emit(state.copyWith(
      clearJoinedUserId: true,
      clearLeftUserId: true,
      clearSuccessUserId: true,
    ));
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// 清除动画触发标记
  /// 
  /// UI 层在消费动画触发标记后应调用此方法清除标记
  void clearAnimationTriggers() {
    add(const QueueUsersClearAnimationTriggers());
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    return super.close();
  }
}
