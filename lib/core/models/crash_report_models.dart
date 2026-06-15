import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/server_time_converter.dart';

part 'crash_report_models.g.dart';

/// 崩溃严重度（与 [CrashSeverity] 同义，单独定义避免桌面层依赖回流）
enum CrashReportSeverity {
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low;

  String get label => switch (this) {
    CrashReportSeverity.high => '严重',
    CrashReportSeverity.medium => '警告',
    CrashReportSeverity.low => '一般',
  };

  String get value => switch (this) {
    CrashReportSeverity.high => 'high',
    CrashReportSeverity.medium => 'medium',
    CrashReportSeverity.low => 'low',
  };

  static CrashReportSeverity parse(String? raw) =>
      CrashReportSeverity.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => CrashReportSeverity.low,
      );
}

/// 嫌疑资源（详情接口返回）
@JsonSerializable()
class CrashReportResource extends Equatable {
  final String kind;
  final String kindLabel;
  final String path;
  final int stackOffset;

  const CrashReportResource({
    required this.kind,
    required this.kindLabel,
    required this.path,
    required this.stackOffset,
  });

  factory CrashReportResource.fromJson(Map<String, dynamic> json) =>
      _$CrashReportResourceFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportResourceToJson(this);

  @override
  List<Object?> get props => [kind, kindLabel, path, stackOffset];
}

/// 第三方注入条目
@JsonSerializable()
class CrashReportThirdParty extends Equatable {
  final String name;
  final String label;
  final String advice;
  final String severity;

  const CrashReportThirdParty({
    required this.name,
    required this.label,
    required this.advice,
    required this.severity,
  });

  factory CrashReportThirdParty.fromJson(Map<String, dynamic> json) =>
      _$CrashReportThirdPartyFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportThirdPartyToJson(this);

  @override
  List<Object?> get props => [name, label, advice, severity];
}


/// 列表项（精简，不含用户维度）
@JsonSerializable()
class CrashReportListItem extends Equatable {
  final int id;
  final String signature;
  final String severity;
  final String category;
  final String categoryLabel;
  final String? crashModule;
  final String? exceptionCode;
  final String? exceptionCodeName;
  final String headline;
  final String fileName;
  final String? appVersion;
  final String? osVersion;
  final String? gpuVendor;
  @JsonKey(defaultValue: 0)
  final int similarCount;
  @ServerTimeConverter()
  final DateTime dumpAt;
  @ServerTimeConverter()
  final DateTime createdAt;

  const CrashReportListItem({
    required this.id,
    required this.signature,
    required this.severity,
    required this.category,
    required this.categoryLabel,
    this.crashModule,
    this.exceptionCode,
    this.exceptionCodeName,
    required this.headline,
    required this.fileName,
    this.appVersion,
    this.osVersion,
    this.gpuVendor,
    this.similarCount = 0,
    required this.dumpAt,
    required this.createdAt,
  });

  CrashReportSeverity get severityEnum =>
      CrashReportSeverity.parse(severity);

  factory CrashReportListItem.fromJson(Map<String, dynamic> json) =>
      _$CrashReportListItemFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportListItemToJson(this);

  @override
  List<Object?> get props => [
    id,
    signature,
    severity,
    category,
    categoryLabel,
    crashModule,
    exceptionCode,
    exceptionCodeName,
    headline,
    fileName,
    appVersion,
    osVersion,
    gpuVendor,
    similarCount,
    dumpAt,
    createdAt,
  ];
}

/// 列表响应
@JsonSerializable()
class CrashReportListResponse extends Equatable {
  final int total;
  final List<CrashReportListItem> items;

  const CrashReportListResponse({required this.total, required this.items});

  factory CrashReportListResponse.fromJson(Map<String, dynamic> json) =>
      _$CrashReportListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportListResponseToJson(this);

  @override
  List<Object?> get props => [total, items];
}


/// 详情（同样不含用户维度）
@JsonSerializable()
class CrashReportDetail extends Equatable {
  final int id;
  final String signature;
  final String severity;
  final String category;
  final String categoryLabel;
  final String? crashModule;
  final String? exceptionCode;
  final String? exceptionCodeName;
  final String headline;
  final String fileName;
  final int? fileSize;
  final String? appVersion;
  final String? osVersion;
  final String? gpuVendor;
  @JsonKey(defaultValue: 0)
  final int similarCount;
  @JsonKey(defaultValue: <String>[])
  final List<String> fatalStrings;
  @JsonKey(defaultValue: <CrashReportResource>[])
  final List<CrashReportResource> resources;
  @JsonKey(defaultValue: <String>[])
  final List<String> workshopIds;
  @JsonKey(defaultValue: <CrashReportThirdParty>[])
  final List<CrashReportThirdParty> thirdPartyModules;
  final String fullReport;
  @ServerTimeConverter()
  final DateTime dumpAt;
  @ServerTimeConverter()
  final DateTime createdAt;

  const CrashReportDetail({
    required this.id,
    required this.signature,
    required this.severity,
    required this.category,
    required this.categoryLabel,
    this.crashModule,
    this.exceptionCode,
    this.exceptionCodeName,
    required this.headline,
    required this.fileName,
    this.fileSize,
    this.appVersion,
    this.osVersion,
    this.gpuVendor,
    this.similarCount = 0,
    this.fatalStrings = const [],
    this.resources = const [],
    this.workshopIds = const [],
    this.thirdPartyModules = const [],
    required this.fullReport,
    required this.dumpAt,
    required this.createdAt,
  });

  CrashReportSeverity get severityEnum =>
      CrashReportSeverity.parse(severity);

  factory CrashReportDetail.fromJson(Map<String, dynamic> json) =>
      _$CrashReportDetailFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportDetailToJson(this);

  @override
  List<Object?> get props => [
    id,
    signature,
    severity,
    category,
    categoryLabel,
    crashModule,
    exceptionCode,
    exceptionCodeName,
    headline,
    fileName,
    fileSize,
    appVersion,
    osVersion,
    gpuVendor,
    similarCount,
    fatalStrings,
    resources,
    workshopIds,
    thirdPartyModules,
    fullReport,
    dumpAt,
    createdAt,
  ];
}


/// 社区聚合面板
@JsonSerializable()
class CrashReportStats extends Equatable {
  @JsonKey(defaultValue: 0)
  final int totalCount;
  @JsonKey(defaultValue: 0)
  final int todayCount;
  @JsonKey(defaultValue: <CrashReportModuleStat>[])
  final List<CrashReportModuleStat> topModules;
  @JsonKey(defaultValue: <CrashReportModuleStat>[])
  final List<CrashReportModuleStat> topThirdParty;

  const CrashReportStats({
    this.totalCount = 0,
    this.todayCount = 0,
    this.topModules = const [],
    this.topThirdParty = const [],
  });

  factory CrashReportStats.fromJson(Map<String, dynamic> json) =>
      _$CrashReportStatsFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportStatsToJson(this);

  @override
  List<Object?> get props => [
    totalCount,
    todayCount,
    topModules,
    topThirdParty,
  ];
}

@JsonSerializable()
class CrashReportModuleStat extends Equatable {
  final String name;
  @JsonKey(defaultValue: 0)
  final int count;
  final String? label;

  const CrashReportModuleStat({
    required this.name,
    required this.count,
    this.label,
  });

  factory CrashReportModuleStat.fromJson(Map<String, dynamic> json) =>
      _$CrashReportModuleStatFromJson(json);

  Map<String, dynamic> toJson() => _$CrashReportModuleStatToJson(this);

  @override
  List<Object?> get props => [name, count, label];
}
