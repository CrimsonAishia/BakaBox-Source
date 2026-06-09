import 'package:uuid/uuid.dart';

import 'log_service.dart';
import 'storage_utils.dart';

/// 设备ID工具类
///
/// 作用：为 Nakama `authenticateDevice` 提供一个**全局唯一且稳定**的设备标识。
///
/// ## 设计：纯随机 UUID + 本地持久化
///
/// 服务端（_nakama/config.yml）开启了 `single_socket` / `single_session`，
/// 二者都以「设备ID 派生出的 Nakama UUID」为键。这对设备ID提出两个硬性要求：
///
/// 1. **稳定**：重连/重启后保持不变，否则 single_socket 无法回收僵尸 socket
///    （正是当初开启 single_socket 要解决的「5539 sessions / 100 users」雪崩）。
/// 2. **唯一**：每个真实安装唯一，否则两个用户派生出同一个 UUID，
///    single_socket 会让他们互相挤掉线（本次修复的 bug）。
///
/// 历史方案用硬件 BIOS UUID / MachineGuid 作为设备ID，但它在**克隆虚拟机、
/// 磁盘镜像批量部署、确定性兜底（默认主机名+OS+核心数）**等场景会发生碰撞，
/// 违反要求 2，导致互挤。
///
/// 纯随机 UUIDv4（122 bit 随机）天然满足唯一性（碰撞概率可忽略），
/// 配合本地持久化满足稳定性，且符合 Nakama 官方对设备ID的推荐用法
/// （6~128 字符的稳定唯一串，从不要求真实硬件标识）。
///
/// ## 稳定性说明
///
/// 唯一风险是本地存储被清空后重新生成导致 ID 漂移。但需区分两类漂移：
/// - 「每次重连」生成新 ID（旧灾难）→ 已通过持久化彻底杜绝。
/// - 「存储被清空」（手动删除 storage 目录或带清理的卸载重装）→ 极罕见，
///   且新连接之间仍受 single_socket/single_session 去重，旧 socket 最多挂到
///   idle_timeout（180s）即被回收，不会雪崩。
///
/// 存储目录位于 我的文档/BakaBox/storage（桌面端），卸载重装通常保留，
/// 故绝大多数情况下 ID 终生不变。
class DeviceIdHelper {
  DeviceIdHelper._();

  static String? _cachedDeviceId;

  /// 持久化的设备ID存储键
  static const String _deviceIdStorageKey = 'persistent_device_id';

  /// 旧版本兜底ID存储键（用于平滑迁移老用户）
  static const String _legacyFallbackKey = 'fallback_device_id';

  static const Uuid _uuid = Uuid();

  /// 异步获取设备ID（全局唯一且稳定）
  ///
  /// 优先级：
  /// 1. 内存缓存
  /// 2. 已持久化的设备ID
  /// 3. 旧版本 fallback ID（平滑迁移，避免老用户 ID 漂移导致重连）
  /// 4. 生成新的随机 UUIDv4 并持久化
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    // 1+2. 读取已持久化的设备ID
    final persisted = _readStored(_deviceIdStorageKey);
    if (persisted != null) {
      _cachedDeviceId = persisted;
      LogService.d('[DeviceIdHelper] 使用持久化设备ID: ${_maskForLog(persisted)}');
      return persisted;
    }

    // 3. 迁移：复用旧版本已持久化的 fallback ID（老用户保持身份稳定）
    final legacy = _readStored(_legacyFallbackKey);
    if (legacy != null) {
      LogService.i('[DeviceIdHelper] 迁移旧版本设备ID: ${_maskForLog(legacy)}');
      _cachedDeviceId = legacy;
      await _persist(legacy);
      return legacy;
    }

    // 4. 生成新的随机 UUIDv4（全局唯一）并持久化
    final newId = _uuid.v4();
    _cachedDeviceId = newId;
    await _persist(newId);
    LogService.i('[DeviceIdHelper] 生成新设备ID: ${_maskForLog(newId)}');
    return newId;
  }

  /// 从存储读取字符串（容错：存储未就绪时返回 null）
  static String? _readStored(String key) {
    try {
      final value = StorageUtils.getString(key);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // StorageUtils 未初始化或读取失败
    }
    return null;
  }

  /// 持久化设备ID
  ///
  /// 等待写入完成后再返回，确保设备ID在用于认证前已落盘，
  /// 避免「首次启动后立即退出」导致下次启动重新生成 ID。
  ///
  /// 写入失败不影响本次返回（内存缓存已生效）；存储失败本身极罕见，
  /// 且不会触发 single_socket 雪崩（LobbyNakamaService 另有随机 UUID 安全网）。
  static Future<void> _persist(String deviceId) async {
    try {
      await StorageUtils.setString(_deviceIdStorageKey, deviceId);
      LogService.d('[DeviceIdHelper] 设备ID已持久化: ${_maskForLog(deviceId)}');
    } catch (e) {
      LogService.w('[DeviceIdHelper] 设备ID持久化失败: $e');
    }
  }

  /// 脱敏日志：只显示首尾各 4 字符
  static String _maskForLog(String id) {
    if (id.length < 9) return '****';
    return '${id.substring(0, 4)}****${id.substring(id.length - 4)}';
  }
}
