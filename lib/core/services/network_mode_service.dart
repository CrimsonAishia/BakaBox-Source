import 'dart:async';

import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 网络模式服务（单例）
///
/// 弱网模式下：所有自动刷新和实时推送暂停，改为用户手动触发。
/// - 服务器列表 / 地图数据：不再自动轮询，需用户点击刷新
/// - Realtime 主推送（notifications / announcements / score.updates 等）：完全不启动
/// - 大厅 Lobby：不受影响（Protobuf 体积小）
/// - 挤服 / 暖服：不受影响
/// - 必要的会话验证、Token 刷新：不受影响
///
/// 各业务侧通过 [weakNetwork] 同步判断当前模式，
/// 通过 [changes] 监听切换事件做联动（启停定时器、订阅等）。
class NetworkModeService {
  NetworkModeService._();

  static final NetworkModeService instance = NetworkModeService._();

  /// 持久化 key
  static const String _storageKey = 'weak_network_mode';

  bool _weakNetwork = false;

  final StreamController<bool> _changeController =
      StreamController<bool>.broadcast();

  /// 当前是否处于弱网模式
  bool get weakNetwork => _weakNetwork;

  /// 弱网开关切换事件流
  Stream<bool> get changes => _changeController.stream;

  /// 从持久化存储加载初始值（应用启动时调用）
  void loadFromStorage() {
    try {
      _weakNetwork = StorageUtils.getBool(_storageKey, defaultValue: false);
      LogService.d('[NetworkMode] 加载弱网模式: $_weakNetwork');
    } catch (e) {
      LogService.e('[NetworkMode] 加载弱网模式失败', e);
      _weakNetwork = false;
    }
  }

  /// 切换弱网模式（持久化 + 广播事件）
  Future<void> setWeakNetwork(bool value) async {
    if (_weakNetwork == value) return;
    _weakNetwork = value;
    try {
      await StorageUtils.setBool(_storageKey, value);
    } catch (e) {
      LogService.e('[NetworkMode] 持久化弱网模式失败', e);
    }
    LogService.i('[NetworkMode] 弱网模式切换为: $value');
    if (!_changeController.isClosed) {
      _changeController.add(value);
    }
  }

  /// 应用退出时调用
  void dispose() {
    _changeController.close();
  }
}
