import '../../../core/models/crash_report_models.dart';
import '../../../core/services/crash_inspector/crash_inspector.dart';
import 'crash_category.dart';

/// 详情视图的统一数据源，让 UI 层不必区分"远端 [CrashReportDetail]"
/// 和"本地 [CrashSummary]"。
///
/// 字段集合是两者的并集，针对没有的字段直接传 `null`。
class CrashDetailViewModel {
  /// 远端 id；`null` 代表本地 dump
  final int? remoteId;

  /// 用于"找同款"跳转，本地 dump 没有
  final String? signature;

  final CrashReportSeverity severity;
  final CrashCategory category;

  final String? crashModule;
  final String? exceptionCode; // 8 位 hex（不带 0x）
  final String? exceptionCodeName;
  final String headline;
  final String fileName;
  final int? fileSize;
  final DateTime dumpAt;

  final List<String> fatalStrings;
  final List<CrashReportResource> resources;
  final List<String> workshopIds;
  final List<CrashReportThirdParty> thirdPartyModules;
  final String fullReport;

  /// 远端独有
  final String? appVersion;
  final String? osVersion;
  final String? gpuVendor;
  final int similarCount;

  /// 本地独有
  final String? dumpPath;

  const CrashDetailViewModel({
    required this.remoteId,
    required this.signature,
    required this.severity,
    required this.category,
    required this.crashModule,
    required this.exceptionCode,
    required this.exceptionCodeName,
    required this.headline,
    required this.fileName,
    required this.fileSize,
    required this.dumpAt,
    required this.fatalStrings,
    required this.resources,
    required this.workshopIds,
    required this.thirdPartyModules,
    required this.fullReport,
    required this.appVersion,
    required this.osVersion,
    required this.gpuVendor,
    required this.similarCount,
    required this.dumpPath,
  });

  bool get isLocal => remoteId == null;

  factory CrashDetailViewModel.fromRemote(CrashReportDetail r) {
    return CrashDetailViewModel(
      remoteId: r.id,
      signature: r.signature,
      severity: r.severityEnum,
      category: CrashCategory.fromKey(r.category),
      crashModule: r.crashModule,
      exceptionCode: r.exceptionCode,
      exceptionCodeName: r.exceptionCodeName,
      headline: r.headline,
      fileName: r.fileName,
      fileSize: r.fileSize,
      dumpAt: r.dumpAt,
      fatalStrings: r.fatalStrings,
      resources: r.resources,
      workshopIds: r.workshopIds,
      thirdPartyModules: r.thirdPartyModules,
      fullReport: r.fullReport,
      appVersion: r.appVersion,
      osVersion: r.osVersion,
      gpuVendor: r.gpuVendor,
      similarCount: r.similarCount,
      dumpPath: null,
    );
  }

  factory CrashDetailViewModel.fromLocal(CrashSummary s) {
    return CrashDetailViewModel(
      remoteId: null,
      signature: null,
      severity: _convertSeverity(s.severity),
      category: CrashCategory.fromSummary(s),
      crashModule: s.crashModule,
      exceptionCode: s.exceptionCodeHex,
      exceptionCodeName: s.exceptionCodeName,
      headline: s.headline,
      fileName: s.fileName,
      fileSize: null,
      dumpAt: s.createdAt,
      fatalStrings: s.fatalStrings,
      resources: s.resources
          .map(
            (r) => CrashReportResource(
              kind: r.kindLabel,
              kindLabel: r.kindLabel,
              path: r.path,
              stackOffset: r.stackOffset,
            ),
          )
          .toList(),
      workshopIds: s.workshopIds,
      thirdPartyModules: s.thirdPartyModules
          .map(
            (e) => CrashReportThirdParty(
              name: e.name,
              label: e.label,
              advice: e.advice,
              severity: e.severity,
            ),
          )
          .toList(),
      fullReport: s.fullReport,
      appVersion: null,
      osVersion: null,
      gpuVendor: null,
      similarCount: 0,
      dumpPath: s.dumpPath,
    );
  }
}

CrashReportSeverity _convertSeverity(CrashSeverity s) {
  switch (s) {
    case CrashSeverity.high:
      return CrashReportSeverity.high;
    case CrashSeverity.medium:
      return CrashReportSeverity.medium;
    case CrashSeverity.low:
      return CrashReportSeverity.low;
  }
}
