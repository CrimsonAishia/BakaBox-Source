import '../../../core/bloc/warmup_users/warmup_users_bloc.dart';
import '../../../core/bloc/warmup_users/warmup_users_state.dart';
import '../queue/arena_activity_session.dart';

/// 暖服竞技场活动会话（单例）
///
/// 订阅 [WarmupUsersBloc] 事件流，独立于窗口生命周期记录日志与竞技场状态。
/// 详见基类 [ArenaActivitySession] 说明。
class WarmupArenaSession extends ArenaActivitySession {
  WarmupArenaSession._();

  static final WarmupArenaSession instance = WarmupArenaSession._();

  ArenaUsersSnapshot _toSnapshot(WarmupUsersState s) => ArenaUsersSnapshot(
    users: s.users,
    joinedUserId: s.joinedUserId,
    leftUserId: s.leftUserId,
    leftUser: s.leftUser,
    successUserId: s.successUserId,
    successUser: s.successUser,
  );

  @override
  ArenaUsersSnapshot get currentSnapshot =>
      _toSnapshot(WarmupUsersBloc.instance.state);

  @override
  Stream<ArenaUsersSnapshot> get snapshotStream =>
      WarmupUsersBloc.instance.stream.map(_toSnapshot);
}
