import '../../../core/bloc/queue_users/queue_users_bloc.dart';
import '../../../core/bloc/queue_users/queue_users_state.dart';
import 'arena_activity_session.dart';

export 'arena_activity_session.dart' show QueueArenaUserPosition;

/// 挤服竞技场活动会话（单例）
///
/// 订阅 [QueueUsersBloc] 事件流，独立于窗口生命周期记录日志与竞技场状态。
/// 详见基类 [ArenaActivitySession] 说明。
class QueueArenaSession extends ArenaActivitySession {
  QueueArenaSession._();

  static final QueueArenaSession instance = QueueArenaSession._();

  ArenaUsersSnapshot _toSnapshot(QueueUsersState s) => ArenaUsersSnapshot(
    users: s.users,
    joinedUserId: s.joinedUserId,
    leftUserId: s.leftUserId,
    leftUser: s.leftUser,
    successUserId: s.successUserId,
    successUser: s.successUser,
  );

  @override
  ArenaUsersSnapshot get currentSnapshot =>
      _toSnapshot(QueueUsersBloc.instance.state);

  @override
  Stream<ArenaUsersSnapshot> get snapshotStream =>
      QueueUsersBloc.instance.stream.map(_toSnapshot);
}
