import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/queue_user.dart';
import '../../services/warmup_users_service.dart';
import '../../utils/log_service.dart';
import 'warmup_users_event.dart';
import 'warmup_users_state.dart';

/// 暖服用户状态管理（单例）
///
/// 管理用户列表、连接状态和动画触发
/// 订阅 WarmupUsersService 事件流，将服务事件转换为 Bloc 事件
///
/// 独立于窗口生命周期，窗口关闭后状态保持
class WarmupUsersBloc extends Bloc<WarmupUsersEvent, WarmupUsersState> {
  // 单例模式
  static WarmupUsersBloc? _instance;

  /// 获取单例实例
  static WarmupUsersBloc get instance {
    _instance ??= WarmupUsersBloc._internal(
      service: WarmupUsersService.instance,
    );
    return _instance!;
  }

  final WarmupUsersService _service;
  StreamSubscription<WarmupUsersServiceEvent>? _serviceSubscription;

  /// 待发送的 join 信息（连接成功后自动发送）
  WarmupUsersJoin? _pendingJoin;

  /// 最后一次成功发送的 join 信息（用于重连时自动重发）
  WarmupUsersJoin? _lastJoin;

  WarmupUsersBloc._internal({required WarmupUsersService service})
    : _service = service,
      super(WarmupUsersState.initial()) {
    // 注册事件处理器
    on<WarmupUsersConnect>(_onConnect);
    on<WarmupUsersDisconnect>(_onDisconnect);
    on<WarmupUsersJoin>(_onJoin);
    on<WarmupUsersLeave>(_onLeave);
    on<WarmupUsersSuccess>(_onSuccess);

    // 内部事件（来自 Service）
    on<WarmupUsersSynced>(_onSynced);
    on<WarmupUserJoined>(_onUserJoined);
    on<WarmupUserLeft>(_onUserLeft);
    on<WarmupUserSucceeded>(_onUserSucceeded);
    on<WarmupUsersError>(_onError);
    on<WarmupUsersConnectionChanged>(_onConnectionChanged);
    on<WarmupUsersClearAnimationTriggers>(_onClearAnimationTriggers);

    // 订阅服务事件流
    _subscribeToService();
  }

  /// 订阅 WarmupUsersService 事件流
  void _subscribeToService() {
    _serviceSubscription = _service.eventStream.listen((event) {
      switch (event) {
        case WarmupUsersSyncEvent():
          add(WarmupUsersSynced(users: event.users));
        case WarmupUserJoinedEvent():
          add(WarmupUserJoined(user: event.user));
        case WarmupUserLeftEvent():
          add(WarmupUserLeft(odId: event.odId, visitorId: event.visitorId));
        case WarmupUserSuccessEvent():
          add(WarmupUserSucceeded(odId: event.odId, visitorId: event.visitorId));
        case WarmupUsersErrorEvent():
          add(WarmupUsersError(error: event.error));
        case WarmupUsersConnectionStateEvent():
          add(WarmupUsersConnectionChanged(isConnected: event.isConnected));
      }
    });
  }

  // ============================================================================
  // Public Event Handlers (UI triggered)
  // ============================================================================

  /// 处理连接事件
  Future<void> _onConnect(
    WarmupUsersConnect event,
    Emitter<WarmupUsersState> emit,
  ) async {
    LogService.d('[WarmupUsersBloc] 连接到服务器: ${event.serverAddress}');

    emit(state.copyWith(isConnecting: true, clearError: true));

    await _service.connect(event.serverAddress);
  }

  /// 处理断开连接事件
  Future<void> _onDisconnect(
    WarmupUsersDisconnect event,
    Emitter<WarmupUsersState> emit,
  ) async {
    LogService.d('[WarmupUsersBloc] 断开连接');

    _lastJoin = null;
    _pendingJoin = null;

    await _service.disconnect();

    emit(
      state.copyWith(
        isConnected: false,
        isConnecting: false,
        users: const [],
        clearJoinedUserId: true,
        clearLeftUserId: true,
        clearSuccessUserId: true,
      ),
    );
  }

  /// 处理用户开始暖服事件
  void _onJoin(WarmupUsersJoin event, Emitter<WarmupUsersState> emit) {
    _lastJoin = event;

    if (!state.isConnected) {
      LogService.d('[WarmupUsersBloc] 未连接，保存 join 信息等待连接');
      _pendingJoin = event;
      return;
    }

    LogService.d('[WarmupUsersBloc] 发送 join, nickname: ${event.nickname}');
    _service.sendJoin(nickname: event.nickname);
  }

  /// 处理用户停止暖服事件
  void _onLeave(WarmupUsersLeave event, Emitter<WarmupUsersState> emit) {
    if (!_service.isConnected) {
      LogService.d('[WarmupUsersBloc] 未连接，跳过 leave');
      _lastJoin = null;
      _pendingJoin = null;
      return;
    }
    LogService.d('[WarmupUsersBloc] 发送 leave');
    _service.sendLeave();
    _lastJoin = null;
    _pendingJoin = null;
  }

  /// 处理用户暖服成功事件
  void _onSuccess(WarmupUsersSuccess event, Emitter<WarmupUsersState> emit) {
    LogService.d('[WarmupUsersBloc] 发送 success');
    _service.sendSuccess();
    _lastJoin = null;
    _pendingJoin = null;
  }

  // ============================================================================
  // Internal Event Handlers (from WarmupUsersService)
  // ============================================================================

  /// 处理全量同步事件
  void _onSynced(WarmupUsersSynced event, Emitter<WarmupUsersState> emit) {
    LogService.d('[WarmupUsersBloc] 同步用户列表: ${event.users.length} 人');

    final oldUserIds = state.users.map((u) => u.uniqueId).toSet();
    final newUsers = event.users
        .where((u) => !oldUserIds.contains(u.uniqueId))
        .toList();

    final newUserIds = event.users.map((u) => u.uniqueId).toSet();
    final leftUsers = state.users
        .where((u) => !newUserIds.contains(u.uniqueId))
        .toList();

    String? joinedUserId;
    final selfNewUser = newUsers.where((u) => u.isSelf).firstOrNull;
    if (selfNewUser != null) {
      joinedUserId = selfNewUser.uniqueId;
    } else if (state.users.isNotEmpty && newUsers.length == 1) {
      joinedUserId = newUsers.first.uniqueId;
    }

    String? leftUserId;
    QueueUser? leftUser;
    if (leftUsers.length == 1 && state.leftUserId == null) {
      leftUser = leftUsers.first;
      leftUserId = leftUser.uniqueId;
    }

    emit(
      state.copyWith(
        users: event.users,
        joinedUserId: joinedUserId,
        clearJoinedUserId: joinedUserId == null && state.joinedUserId == null,
        leftUserId: leftUserId,
        leftUser: leftUser,
        clearLeftUserId: leftUserId == null && state.leftUserId == null,
        clearSuccessUserId: state.successUserId == null,
      ),
    );
  }

  /// 处理用户加入事件
  void _onUserJoined(WarmupUserJoined event, Emitter<WarmupUsersState> emit) {
    final user = event.user;
    LogService.d(
      '[WarmupUsersBloc] 收到用户加入事件: ${user.uniqueId}',
    );

    final existingIndex = state.users.indexWhere(
      (u) => u.uniqueId == user.uniqueId,
    );

    if (existingIndex >= 0) {
      LogService.d('[WarmupUsersBloc] 用户已存在，忽略');
      return;
    }

    final updatedUsers = [...state.users, user];

    emit(
      state.copyWith(
        users: updatedUsers,
        joinedUserId: user.uniqueId,
      ),
    );
  }

  /// 处理用户离开事件
  void _onUserLeft(WarmupUserLeft event, Emitter<WarmupUsersState> emit) {
    final userId = event.odId.isNotEmpty ? event.odId : event.visitorId;
    LogService.d('[WarmupUsersBloc] 用户离开: $userId');

    final leavingUser = state.users
        .where((u) => u.uniqueId == userId)
        .firstOrNull;

    final updatedUsers = state.users
        .where((u) => u.uniqueId != userId)
        .toList();

    if (updatedUsers.length == state.users.length) {
      LogService.d('[WarmupUsersBloc] 用户不在列表中，忽略');
      return;
    }

    emit(
      state.copyWith(
        users: updatedUsers,
        leftUserId: userId,
        leftUser: leavingUser,
      ),
    );
  }

  /// 处理用户成功事件
  void _onUserSucceeded(
    WarmupUserSucceeded event,
    Emitter<WarmupUsersState> emit,
  ) {
    final userId = event.odId.isNotEmpty ? event.odId : event.visitorId;
    LogService.d('[WarmupUsersBloc] 用户成功: $userId');

    final successfulUser = state.users
        .where((u) => u.uniqueId == userId)
        .firstOrNull;

    final updatedUsers = state.users
        .where((u) => u.uniqueId != userId)
        .toList();

    emit(
      state.copyWith(
        users: updatedUsers,
        successUserId: userId,
        successUser: successfulUser,
      ),
    );
  }

  /// 处理错误事件
  void _onError(WarmupUsersError event, Emitter<WarmupUsersState> emit) {
    LogService.e('[WarmupUsersBloc] 错误: ${event.error}');

    emit(state.copyWith(error: event.error, isConnecting: false));
  }

  /// 处理连接状态变化事件
  void _onConnectionChanged(
    WarmupUsersConnectionChanged event,
    Emitter<WarmupUsersState> emit,
  ) {
    LogService.d('[WarmupUsersBloc] 连接状态变化: ${event.isConnected}');

    emit(state.copyWith(isConnected: event.isConnected, isConnecting: false));

    if (event.isConnected && _pendingJoin != null) {
      LogService.d('[WarmupUsersBloc] 连接成功，发送待处理的 join');
      final pending = _pendingJoin!;
      _pendingJoin = null;
      add(pending);
    } else if (event.isConnected && _lastJoin != null) {
      LogService.d('[WarmupUsersBloc] 重连成功，使用上次的 join 信息重新加入');
      _service.sendJoin(nickname: _lastJoin!.nickname);
    }
  }

  /// 处理清除动画触发标记事件
  void _onClearAnimationTriggers(
    WarmupUsersClearAnimationTriggers event,
    Emitter<WarmupUsersState> emit,
  ) {
    emit(
      state.copyWith(
        clearJoinedUserId: true,
        clearLeftUserId: true,
        clearSuccessUserId: true,
      ),
    );
  }

  /// 清除动画触发标记
  void clearAnimationTriggers() {
    add(const WarmupUsersClearAnimationTriggers());
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    return super.close();
  }
}
