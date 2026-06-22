import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../api/crash_report_api.dart';
import '../utils/device_id_helper.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';
import 'app_info_service.dart';
import 'crash_inspector/crash_inspector.dart';
import 'cs2_crash_monitor_service.dart';

/// 自动匿名上传 CS2 崩溃报告.
///
/// 工作机制:
/// 1. 监听 [Cs2CrashMonitorService.crashStream], 每发现一份新崩溃就排队上传.
/// 2. 上传前根据 `signature + dumpAt + clientFingerprint` 做本地幂等去重,
///    避免重启后重复发同一份崩溃.
/// 3. 用户在设置里关闭"匿名上传 CS2 崩溃帮助分析"开关时, 整个上传链路停掉.
class CrashReportUploader {
  static final CrashReportUploader _instance = CrashReportUploader._internal();
  factory CrashReportUploader() => _instance;
  CrashReportUploader._internal();

  static const _settingsKey = 'crash_report_auto_upload_enabled';
  static const _seenKey = 'crash_report_uploaded_signatures';
  static const _seenCap = 200;

  final CrashReportApi _api = CrashReportApi();
  StreamSubscription<Cs2CrashDetectedEvent>? _subscription;
  bool _initialized = false;

  /// 用户设置：是否允许自动匿名上传.
  static bool get isEnabled =>
      StorageUtils.getBool(_settingsKey, defaultValue: true);

  static Future<void> setEnabled(bool value) async {
    await StorageUtils.setBool(_settingsKey, value);
  }

  /// 启动监听; 多次调用幂等.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _subscription = Cs2CrashMonitorService().crashStream.listen((event) {
      unawaited(_handleNewCrash(event.summary));
    });
    LogService.d('[CrashReportUploader] 已初始化');
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}

extension _CrashReportUploaderImpl on CrashReportUploader {
  Future<void> _handleNewCrash(CrashSummary summary) async {
    if (!CrashReportUploader.isEnabled) {
      LogService.d('[CrashReportUploader] 用户已关闭自动上传, 跳过');
      return;
    }
    try {
      final fingerprint = await _clientFingerprint();
      final signature = _signatureOf(summary);
      final dedupKey =
          '$fingerprint|$signature|'
          '${summary.createdAt.millisecondsSinceEpoch}';
      if (_isDuplicate(dedupKey)) {
        LogService.d('[CrashReportUploader] 命中本地幂等缓存, 跳过');
        return;
      }
      final body = _buildBody(
        summary: summary,
        signature: signature,
        clientFingerprint: fingerprint,
      );
      final id = await _api.uploadReport(body);
      if (id != null) {
        LogService.i('[CrashReportUploader] 上传成功 id=$id signature=$signature');
        await _markUploaded(dedupKey);
      }
    } catch (e) {
      LogService.w('[CrashReportUploader] 上传失败: $e');
    }
  }

  Future<String> _clientFingerprint() async {
    final deviceId = await DeviceIdHelper.getDeviceId();
    return sha256.convert(utf8.encode(deviceId)).toString();
  }

  String _signatureOf(CrashSummary s) {
    final topThirdHigh = s.thirdPartyModules
        .where((m) => m.severity == 'high')
        .map((m) => m.name.toLowerCase())
        .firstOrNull;
    final topResourceKind = s.resources.isNotEmpty
        ? s.resources.first.kindLabel
        : '';
    final raw = [
      _categoryKeyOf(s),
      s.crashModule ?? '',
      s.exceptionCodeHex ?? '',
      topThirdHigh ?? '',
      topResourceKind,
    ].join('|');
    return sha1.convert(utf8.encode(raw)).toString().substring(0, 20);
  }

  String _categoryKeyOf(CrashSummary s) {
    switch (s.categoryLabel) {
      case '显卡驱动':
        return 'gpu';
      case 'Workshop 工具':
        return 'tools';
      case '系统组件':
        return 'system';
      case '游戏资源':
        return 'resource';
      case '代码异常执行':
        return 'code_exec';
      default:
        return 'unknown';
    }
  }
}

extension _CrashReportUploaderDedup on CrashReportUploader {
  bool _isDuplicate(String key) {
    final list = StorageUtils.getStringList(
      CrashReportUploader._seenKey,
      defaultValue: const [],
    );
    return list.contains(key);
  }

  Future<void> _markUploaded(String key) async {
    final list = StorageUtils.getStringList(
      CrashReportUploader._seenKey,
      defaultValue: const [],
    );
    final updated = [...list, key];
    while (updated.length > CrashReportUploader._seenCap) {
      updated.removeAt(0);
    }
    await StorageUtils.setStringList(CrashReportUploader._seenKey, updated);
  }

  Map<String, dynamic> _buildBody({
    required CrashSummary summary,
    required String signature,
    required String clientFingerprint,
  }) {
    final categoryKey = _categoryKeyOf(summary);
    final dumpAt = _formatServerTime(summary.createdAt);
    return <String, dynamic>{
      'signature': signature,
      'severity': summary.severity.name,
      'category': categoryKey,
      'categoryLabel': summary.categoryLabel,
      if (summary.crashModule != null) 'crashModule': summary.crashModule,
      if (summary.exceptionCodeHex != null)
        'exceptionCode': summary.exceptionCodeHex,
      if (summary.exceptionCodeName != null)
        'exceptionCodeName': summary.exceptionCodeName,
      'headline': summary.headline,
      'fileName': summary.fileName,
      'fileSize': _safeFileSize(summary.dumpPath),
      'dumpAt': dumpAt,
      'appVersion': AppInfoService.instance.version,
      'osVersion': PlatformUtils.osVersion,
      'fatalStrings': summary.fatalStrings.take(10).toList(),
      'resources': summary.resources
          .take(30)
          .map(
            (r) => {
              'kind': r.kindLabel,
              'kindLabel': r.kindLabel,
              'path': r.path,
              'stackOffset': r.stackOffset,
            },
          )
          .toList(),
      'workshopIds': summary.workshopIds.take(32).toList(),
      'thirdPartyModules': summary.thirdPartyModules
          .map(
            (e) => {
              'name': e.name,
              'label': e.label,
              'advice': e.advice,
              'severity': e.severity,
            },
          )
          .toList(),
      'fullReport': _truncateReport(summary.fullReport),
      'clientFingerprint': clientFingerprint,
    };
  }

  int? _safeFileSize(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return null;
    }
  }

  String _truncateReport(String full) {
    const cap = 256 * 1024;
    if (full.length <= cap) return full;
    final head = full.substring(0, 64 * 1024);
    final tail = full.substring(full.length - 64 * 1024);
    return '$head\n\n[...truncated ${full.length - cap} chars...]\n\n$tail';
  }

  String _formatServerTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
