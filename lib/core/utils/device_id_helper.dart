import 'dart:io';
import 'dart:math';

import 'log_service.dart';
import 'storage_utils.dart';

/// 设备ID工具类
///
/// 使用 PowerShell 直接获取 Windows BIOS UUID（避免调用 wmic 产生 CMD 窗口）：
/// - Android: AndroidId
/// - iOS: IdentifierForVendor
/// - Windows: BIOS UUID via PowerShell
/// - macOS: IOPlatformUUID
/// - Linux: BIOS UUID
/// - Web: UserAgent
/// - 卸载重装后ID保持不变
///
/// 虚拟机/沙箱兜底方案：
/// - 检测 BIOS UUID 占位符（如 VMware/VirtualBox 返回的 0000... / BBBB...）
/// - 占位符检测失败后，生成并持久化一个确定性随机 ID（基于机器名+OS+核心数种子）
/// - LobbyNakamaService 另有最终随机 UUIDv4 兜底作为安全网
class DeviceIdHelper {
  DeviceIdHelper._();

  static String? _cachedDeviceId;

  static const String _fallbackStorageKey = 'fallback_device_id';

  /// 虚拟机/沙箱环境常见的 BIOS UUID 占位符模式
  ///
  /// 这些模式在 VMware、VirtualBox、Hyper-V 等虚拟机中常见，
  /// 表示 BIOS 未正确报告真实 UUID，需要降级兜底。
  /// 只检测全 0、全 B、全 F 这些明显的人造占位符。
  static final _placeholderPatterns = [
    RegExp(
      r'^0{8}-0{4}-0{4}-0{4}-0{12}$',
      caseSensitive: false,
    ), // 00000000-0000-0000-0000-000000000000
    RegExp(
      r'^[Bb]{8}-[Bb]{4}-[Bb]{4}-[Bb]{4}-[Bb]{12}$',
    ), // BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB
    RegExp(
      r'^[Ff]{8}-[Ff]{4}-[Ff]{4}-[Ff]{4}-[Ff]{12}$',
    ), // FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF
  ];

  static final _random = Random();

  /// 判断给定 UUID 是否为虚拟机 BIOS 占位符
  static bool _isInvalidPlaceholder(String id) {
    final trimmed = id.trim().toUpperCase();
    for (final pattern in _placeholderPatterns) {
      if (pattern.hasMatch(trimmed)) {
        LogService.w('[DeviceIdHelper] 检测到无效占位符 UUID: ${_maskForLog(trimmed)}');
        return true;
      }
    }
    return false;
  }

  /// 脱敏日志：只显示 UUID 首尾各 4 字符
  static String _maskForLog(String id) {
    if (id.length < 9) return '****';
    return '${id.substring(0, 4)}****${id.substring(id.length - 4)}';
  }

  /// 生成确定性随机 ID
  ///
  /// 种子来源：机器名 + OS + 版本 + 核心数
  /// 相同硬件配置 → 相同种子 → 相同 ID（重启后仍稳定）
  /// 不依赖任何外部包，使用 Dart 内置 Random 伪随机生成器。
  static String _generateDeterministicId() {
    final seed = <String>[
      Platform.localHostname,
      Platform.operatingSystem,
      Platform.operatingSystemVersion,
      Platform.numberOfProcessors.toString(),
    ].join('|').hashCode;

    // 使用种子初始化 Random，保证相同硬件产生相同 ID
    final seededRandom = Random(seed);
    final hexDigits = '0123456789abcdef';
    final buffer = StringBuffer();

    for (var i = 0; i < 32; i++) {
      buffer.write(hexDigits[seededRandom.nextInt(16)]);
    }

    return buffer.toString();
  }

  /// 生成随机 ID（用于最外层确定性路径都失效的极端兜底）
  static String _generateRandomId() {
    final hexDigits = '0123456789abcdef';
    final parts = <String>[];
    parts.add(DateTime.now().microsecondsSinceEpoch.toRadixString(16));
    parts.add(Platform.numberOfProcessors.toString());
    parts.add(Platform.localHostname.hashCode.toRadixString(16));

    // 再追加 16 位纯随机，确保全局唯一
    final buffer = StringBuffer(parts.join());
    for (var i = 0; i < 16; i++) {
      buffer.write(hexDigits[_random.nextInt(16)]);
    }
    return buffer.toString().substring(0, 32);
  }

  /// 获取 fallback 设备ID
  ///
  /// 优先级：
  /// 1. 从本地存储读取已缓存的 fallback ID（保证重启后 ID 稳定）
  /// 2. 生成新的确定性 ID（基于机器名+OS+核心数种子）
  /// 3. 若确定性路径也失败，生成随机 ID（LobbyNakamaService 最终安全网）
  static String _getFallbackDeviceId() {
    // 尝试从 Hive 缓存读取（同步读取，Box 已打开时可用）
    try {
      final stored = StorageUtils.getString(_fallbackStorageKey);
      if (stored != null && stored.isNotEmpty) {
        LogService.d(
          '[DeviceIdHelper] 使用本地缓存的 fallback ID: ${_maskForLog(stored)}',
        );
        return stored;
      }
    } catch (_) {
      // StorageUtils 未初始化或读取失败，继续生成新的
    }

    String fallbackId;
    try {
      fallbackId = _generateDeterministicId();
      LogService.w('[DeviceIdHelper] 生成了确定性 fallback ID（seed: 机器名/OS/核心数）');
    } catch (e) {
      // 极不可能：所有确定性路径都失败
      fallbackId = _generateRandomId();
      LogService.e('[DeviceIdHelper] 确定性 ID 生成失败，使用随机兜底: $e');
    }

    // 异步写入缓存（不阻塞）
    StorageUtils.setString(_fallbackStorageKey, fallbackId)
        .then((_) {
          LogService.d(
            '[DeviceIdHelper] fallback ID 已持久化: ${_maskForLog(fallbackId)}',
          );
        })
        .catchError((e) {
          LogService.w('[DeviceIdHelper] fallback ID 持久化失败: $e');
        });

    return fallbackId;
  }

  /// 通过 PowerShell 获取 Windows BIOS UUID（无 CMD 窗口，无阻塞）
  ///
  /// 使用 runInShell: false 避免创建控制台窗口
  static Future<String?> _getWindowsDeviceIdViaPowerShell() async {
    if (!Platform.isWindows) return null;

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystemProduct).UUID',
      ], runInShell: false);

      if (result.exitCode == 0) {
        final uuid = (result.stdout as String).trim();
        if (uuid.isNotEmpty && uuid.length == 36) {
          LogService.d(
            '[DeviceIdHelper] PowerShell 获取到 UUID: ${_maskForLog(uuid)}',
          );
          return uuid;
        }
      }
    } catch (e) {
      LogService.w('[DeviceIdHelper] PowerShell 获取 UUID 失败: $e');
    }
    return null;
  }

  /// 通过注册表获取 Windows MachineGuid（兜底方案）
  static Future<String?> _getWindowsDeviceIdViaRegistry() async {
    if (!Platform.isWindows) return null;

    try {
      final result = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
      ], runInShell: false);

      if (result.exitCode == 0) {
        final output = (result.stdout as String);
        final match = RegExp(
          r'MachineGuid\s+REG_SZ\s+([a-fA-F0-9-]{36})',
        ).firstMatch(output);
        if (match != null) {
          final guid = match.group(1)!;
          LogService.d(
            '[DeviceIdHelper] 注册表获取到 MachineGuid: ${_maskForLog(guid)}',
          );
          return guid;
        }
      }
    } catch (e) {
      LogService.w('[DeviceIdHelper] 注册表获取 MachineGuid 失败: $e');
    }
    return null;
  }

  /// 通过 system_profiler 获取 macOS 硬件 UUID
  static Future<String?> _getMacOSDeviceId() async {
    if (!Platform.isMacOS) return null;

    try {
      final result = await Process.run('system_profiler', [
        'SPHardwareDataType',
      ], runInShell: false);

      if (result.exitCode == 0) {
        final output = (result.stdout as String);
        final match = RegExp(
          r'Hardware UUID:\s+([A-F0-9-]+)',
          caseSensitive: false,
        ).firstMatch(output);
        if (match != null) {
          final uuid = match.group(1)!;
          LogService.d(
            '[DeviceIdHelper] system_profiler 获取到 UUID: ${_maskForLog(uuid)}',
          );
          return uuid;
        }
      }
    } catch (e) {
      LogService.w('[DeviceIdHelper] system_profiler 获取 UUID 失败: $e');
    }
    return null;
  }

  /// 通过 dmidecode 获取 Linux BIOS UUID（需要 root 权限，降级处理）
  static Future<String?> _getLinuxDeviceId() async {
    if (!Platform.isLinux) return null;

    try {
      final result = await Process.run('dmidecode', [
        '-s',
        'system-uuid',
      ], runInShell: false);

      if (result.exitCode == 0) {
        final uuid = (result.stdout as String).trim();
        if (uuid.isNotEmpty && uuid.length >= 32) {
          LogService.d(
            '[DeviceIdHelper] dmidecode 获取到 UUID: ${_maskForLog(uuid)}',
          );
          return uuid;
        }
      }
    } catch (e) {
      LogService.w('[DeviceIdHelper] dmidecode 获取 UUID 失败: $e');
    }
    return null;
  }

  /// 异步获取设备ID
  ///
  /// 兜底层级：
  /// 1. Windows: PowerShell 获取 BIOS UUID → 注册表 MachineGuid 兜底
  /// 2. macOS: system_profiler 获取硬件 UUID
  /// 3. Linux: dmidecode 获取 system-uuid
  /// 4. 占位符过滤（虚拟机 BIOS UUID 检测）
  /// 5. 本地持久化 fallback ID（确定性，相同硬件重启后仍一致）
  /// 6. LobbyNakamaService 另有随机 UUIDv4 最终安全网
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    String? deviceId;

    // 根据平台获取设备 ID
    if (Platform.isWindows) {
      deviceId = await _getWindowsDeviceIdViaPowerShell();
      deviceId ??= await _getWindowsDeviceIdViaRegistry();
    } else if (Platform.isMacOS) {
      deviceId = await _getMacOSDeviceId();
    } else if (Platform.isLinux) {
      deviceId = await _getLinuxDeviceId();
    }

    // 如果系统级获取失败，启用 fallback 兜底方案
    if (deviceId == null || deviceId.isEmpty) {
      LogService.w('[DeviceIdHelper] 系统级设备ID获取失败，启用 fallback 兜底方案');
      final fallbackId = _getFallbackDeviceId();
      _cachedDeviceId = fallbackId;
      LogService.d(
        '[DeviceIdHelper] 设备ID (fallback): ${_maskForLog(fallbackId)}',
      );
      return fallbackId;
    }

    final trimmed = deviceId.trim();

    // 占位符检测：虚拟机等环境返回的无效 UUID
    if (_isInvalidPlaceholder(trimmed)) {
      LogService.w('[DeviceIdHelper] 检测到无效占位符 UUID，启用 fallback 兜底方案');
      final fallbackId = _getFallbackDeviceId();
      _cachedDeviceId = fallbackId;
      LogService.d(
        '[DeviceIdHelper] 设备ID (fallback): ${_maskForLog(fallbackId)}',
      );
      return fallbackId;
    }

    _cachedDeviceId = trimmed;
    LogService.d('[DeviceIdHelper] 设备ID (系统): ${_maskForLog(trimmed)}');
    return trimmed;
  }

  /// 同步获取缓存的设备ID
  ///
  /// 可能返回 null（如果尚未调用过 getDeviceId）
  static String? getCachedDeviceId() => _cachedDeviceId;

  /// 清除缓存的设备ID
  ///
  /// 通常不需要调用，仅用于测试或重置
  static void clearCache() {
    _cachedDeviceId = null;
  }
}
