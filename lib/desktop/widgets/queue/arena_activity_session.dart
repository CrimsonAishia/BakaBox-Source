import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/models/queue_user.dart';
import 'queue_activity_log.dart';

/// 持久化的竞技场用户位置信息
///
/// 仅保存影响布局的静态信息，透明度/飞入进度等瞬时动画状态不持久化。
class QueueArenaUserPosition {
  /// 相对位置 0-1
  final double x;

  /// 相对位置 0-1
  final double y;

  /// 头像大小
  final double size;

  /// 漂浮动画相位
  final double floatPhase;

  /// 漂浮速度
  final double floatSpeed;

  const QueueArenaUserPosition({
    required this.x,
    required this.y,
    required this.size,
    required this.floatPhase,
    required this.floatSpeed,
  });
}

/// 用户事件快照
///
/// 把不同的 UsersState（挤服 / 暖服）归一化为统一结构，供基类记录日志。
class ArenaUsersSnapshot {
  final List<QueueUser> users;
  final String? joinedUserId;
  final String? leftUserId;
  final QueueUser? leftUser;
  final String? successUserId;
  final QueueUser? successUser;

  const ArenaUsersSnapshot({
    required this.users,
    this.joinedUserId,
    this.leftUserId,
    this.leftUser,
    this.successUserId,
    this.successUser,
  });
}

/// 缓存的用户信息（用于用户离开/成功时回显昵称）
class _CachedUserInfo {
  final String userName;
  final bool isSelf;

  const _CachedUserInfo({required this.userName, required this.isSelf});
}

/// 竞技场活动会话基类（挤服 / 暖服共用）
///
/// 独立于窗口生命周期：窗口关闭、最小化到后台再唤醒时保持，
/// 只有在重新开始或停止时才清空。
///
/// 关键点：本类直接订阅对应的 UsersBloc 事件流来记录活动日志，
/// 因此即使窗口已关闭（在后台运行），用户加入/离开/成功的日志
/// 也会持续记录，重新打开窗口即可看到完整日志，不会出现空档。
///
/// 同时解决：
/// 1. 活动日志与竞技场用户（含位置）在窗口重开后保持不丢失。
/// 2. 配合 [selfJoinLogged] 标记，保证"你加入了…"只记录一次且不漏记。
abstract class ArenaActivitySession extends ChangeNotifier {
  /// 活动日志最大条数（防止内存溢出）
  static const int _maxActivities = 100;

  /// 用户信息缓存最大条数
  static const int _maxCacheSize = 50;

  /// 当前会话关联的服务器地址（用于判断是否为同一会话的重开）
  String? serverAddress;

  /// 活动日志
  final List<QueueActivityItem> activities = [];

  /// 竞技场用户位置（key 为 user.uniqueId）
  final Map<String, QueueArenaUserPosition> positions = {};

  /// 是否已记录"你加入了…"
  bool selfJoinLogged = false;

  /// 用户信息缓存
  final Map<String, _CachedUserInfo> _userInfoCache = {};

  /// 用户事件流订阅（用于后台持续记录日志）
  StreamSubscription<ArenaUsersSnapshot>? _usersSubscription;

  /// 上一次处理过的快照（用于检测一次性触发标记的变化）
  ArenaUsersSnapshot? _prevSnapshot;

  // ==========================================================================
  // 子类需要实现：提供归一化后的当前状态与事件流
  // ==========================================================================

  /// 当前用户状态快照
  ArenaUsersSnapshot get currentSnapshot;

  /// 用户状态变化事件流（归一化后的快照）
  Stream<ArenaUsersSnapshot> get snapshotStream;

  /// 自己加入日志文案对应的动作名（仅用于区分，不影响逻辑）
  // 不需要额外文案，QueueActivityLog 内部用 isWarmup 区分。

  // ==========================================================================
  // 公共 API
  // ==========================================================================

  /// 当前是否有可用会话
  bool get hasSession => serverAddress != null;

  /// 是否为指定服务器的会话
  bool isForServer(String address) => serverAddress == address;

  /// 为新会话重置（每次点击"开始"时调用）
  ///
  /// 会清空旧日志/位置并开始订阅用户事件流，从而在后台也持续记录日志。
  void resetFor(String address) {
    serverAddress = address;
    activities.clear();
    positions.clear();
    _userInfoCache.clear();
    selfJoinLogged = false;
    _startListening();
    notifyListeners();
  }

  /// 清空会话（停止时调用）
  void clear() {
    _stopListening();
    serverAddress = null;
    activities.clear();
    positions.clear();
    _userInfoCache.clear();
    selfJoinLogged = false;
    notifyListeners();
  }

  /// 确保订阅已建立（用于会话已存在但订阅可能尚未建立的兜底场景）
  void ensureListening() {
    if (hasSession && _usersSubscription == null) {
      _startListening();
    }
  }

  // ==========================================================================
  // 事件流订阅与日志记录
  // ==========================================================================

  void _startListening() {
    _stopListening();
    _prevSnapshot = currentSnapshot;
    // 先处理一次当前状态（覆盖订阅建立前自己已在列表中的情况）
    _handleSnapshot(currentSnapshot);
    _usersSubscription = snapshotStream.listen(_handleSnapshot);
  }

  void _stopListening() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _prevSnapshot = null;
  }

  /// 处理用户状态变化，记录活动日志
  ///
  /// 只在一次性触发标记发生变化时记录，避免重复。
  void _handleSnapshot(ArenaUsersSnapshot curr) {
    final prev = _prevSnapshot;
    _prevSnapshot = curr;

    // 更新缓存（确保离开/成功时能回显昵称）
    _updateUserInfoCache(curr.users);

    var changed = false;

    // 兜底：保证"你加入了…"被记录一次（不依赖一次性的 joinedUserId 触发）
    if (!selfJoinLogged) {
      final self = curr.users.where((u) => u.isSelf).firstOrNull;
      if (self != null) {
        selfJoinLogged = true;
        _appendActivity(
          QueueActivityItem.fromUser(self, QueueActivityType.join),
        );
        changed = true;
      }
    }

    // 用户加入（自己的加入由上面的兜底统一处理）
    final joinedId = curr.joinedUserId;
    if (joinedId != null && joinedId != prev?.joinedUserId) {
      final user = curr.users.where((u) => u.uniqueId == joinedId).firstOrNull;
      if (user != null) {
        if (!user.isSelf) {
          _appendActivity(
            QueueActivityItem.fromUser(user, QueueActivityType.join),
          );
          changed = true;
        }
      } else {
        final cached = _getCachedUserInfo(joinedId);
        if (!cached.isSelf) {
          _appendActivity(
            QueueActivityItem(
              id: '${joinedId}_join_${DateTime.now().millisecondsSinceEpoch}',
              type: QueueActivityType.join,
              userName: cached.userName,
              isSelf: cached.isSelf,
              timestamp: DateTime.now(),
            ),
          );
          changed = true;
        }
      }
    }

    // 用户离开
    final leftId = curr.leftUserId;
    if (leftId != null && leftId != prev?.leftUserId) {
      final leftUser = curr.leftUser;
      if (leftUser != null) {
        _appendActivity(
          QueueActivityItem.fromUser(leftUser, QueueActivityType.leave),
        );
      } else {
        final cached = _getCachedUserInfo(leftId);
        _appendActivity(
          QueueActivityItem(
            id: '${leftId}_leave_${DateTime.now().millisecondsSinceEpoch}',
            type: QueueActivityType.leave,
            userName: cached.userName,
            isSelf: cached.isSelf,
            timestamp: DateTime.now(),
          ),
        );
      }
      changed = true;
    }

    // 用户成功进入服务器
    final successId = curr.successUserId;
    if (successId != null && successId != prev?.successUserId) {
      final successUser = curr.successUser;
      if (successUser != null) {
        _appendActivity(
          QueueActivityItem.fromUser(successUser, QueueActivityType.success),
        );
      } else {
        final cached = _getCachedUserInfo(successId);
        _appendActivity(
          QueueActivityItem(
            id: '${successId}_success_${DateTime.now().millisecondsSinceEpoch}',
            type: QueueActivityType.success,
            userName: cached.userName,
            isSelf: cached.isSelf,
            timestamp: DateTime.now(),
          ),
        );
      }
      changed = true;
    }

    if (changed) notifyListeners();
  }

  void _appendActivity(QueueActivityItem activity) {
    activities.add(activity);
    if (activities.length > _maxActivities) {
      activities.removeRange(0, activities.length - _maxActivities);
    }
  }

  void _updateUserInfoCache(List<QueueUser> users) {
    for (final user in users) {
      _userInfoCache[user.uniqueId] = _CachedUserInfo(
        userName: user.nickname ?? (user.isAnonymous ? '未登录用户' : '用户'),
        isSelf: user.isSelf,
      );
    }
    if (_userInfoCache.length > _maxCacheSize) {
      final keysToRemove = _userInfoCache.keys
          .take(_userInfoCache.length - _maxCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _userInfoCache.remove(key);
      }
    }
  }

  _CachedUserInfo _getCachedUserInfo(String uniqueId) {
    return _userInfoCache[uniqueId] ??
        const _CachedUserInfo(userName: '用户', isSelf: false);
  }
}

/// 为竞技场窗口内容 State 提供会话绑定的通用逻辑。
///
/// 负责：
/// - 进入页面时补建后台日志订阅（[ArenaActivitySession.ensureListening]）；
/// - 监听会话变化以刷新 UI；
/// - 离开页面时移除监听（但不清空会话数据，保证窗口重开后保持）。
mixin ArenaSessionBinding<T extends StatefulWidget> on State<T> {
  /// 子类提供对应的会话实例
  ArenaActivitySession get session;

  /// 活动日志（直接来自会话）
  List<QueueActivityItem> get activities => session.activities;

  /// 绑定会话：在 initState 中调用
  void bindSession() {
    // 如果操作已在后台进行但订阅尚未建立，补建订阅，保证后台日志不丢。
    session.ensureListening();
    session.addListener(_onSessionChanged);
  }

  /// 解绑会话：在 dispose 中调用（不清空会话数据）
  void unbindSession() {
    session.removeListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }
}
