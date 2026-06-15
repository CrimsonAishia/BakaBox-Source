// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CrashReportResource _$CrashReportResourceFromJson(Map<String, dynamic> json) =>
    CrashReportResource(
      kind: json['kind'] as String,
      kindLabel: json['kindLabel'] as String,
      path: json['path'] as String,
      stackOffset: (json['stackOffset'] as num).toInt(),
    );

Map<String, dynamic> _$CrashReportResourceToJson(
  CrashReportResource instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'kindLabel': instance.kindLabel,
  'path': instance.path,
  'stackOffset': instance.stackOffset,
};

CrashReportThirdParty _$CrashReportThirdPartyFromJson(
  Map<String, dynamic> json,
) => CrashReportThirdParty(
  name: json['name'] as String,
  label: json['label'] as String,
  advice: json['advice'] as String,
  severity: json['severity'] as String,
);

Map<String, dynamic> _$CrashReportThirdPartyToJson(
  CrashReportThirdParty instance,
) => <String, dynamic>{
  'name': instance.name,
  'label': instance.label,
  'advice': instance.advice,
  'severity': instance.severity,
};

CrashReportListItem _$CrashReportListItemFromJson(Map<String, dynamic> json) =>
    CrashReportListItem(
      id: (json['id'] as num).toInt(),
      signature: json['signature'] as String,
      severity: json['severity'] as String,
      category: json['category'] as String,
      categoryLabel: json['categoryLabel'] as String,
      crashModule: json['crashModule'] as String?,
      exceptionCode: json['exceptionCode'] as String?,
      exceptionCodeName: json['exceptionCodeName'] as String?,
      headline: json['headline'] as String,
      fileName: json['fileName'] as String,
      appVersion: json['appVersion'] as String?,
      osVersion: json['osVersion'] as String?,
      gpuVendor: json['gpuVendor'] as String?,
      similarCount: (json['similarCount'] as num?)?.toInt() ?? 0,
      dumpAt: const ServerTimeConverter().fromJson(json['dumpAt'] as String),
      createdAt: const ServerTimeConverter().fromJson(
        json['createdAt'] as String,
      ),
    );

Map<String, dynamic> _$CrashReportListItemToJson(
  CrashReportListItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'signature': instance.signature,
  'severity': instance.severity,
  'category': instance.category,
  'categoryLabel': instance.categoryLabel,
  'crashModule': instance.crashModule,
  'exceptionCode': instance.exceptionCode,
  'exceptionCodeName': instance.exceptionCodeName,
  'headline': instance.headline,
  'fileName': instance.fileName,
  'appVersion': instance.appVersion,
  'osVersion': instance.osVersion,
  'gpuVendor': instance.gpuVendor,
  'similarCount': instance.similarCount,
  'dumpAt': const ServerTimeConverter().toJson(instance.dumpAt),
  'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
};

CrashReportListResponse _$CrashReportListResponseFromJson(
  Map<String, dynamic> json,
) => CrashReportListResponse(
  total: (json['total'] as num).toInt(),
  items: (json['items'] as List<dynamic>)
      .map((e) => CrashReportListItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CrashReportListResponseToJson(
  CrashReportListResponse instance,
) => <String, dynamic>{'total': instance.total, 'items': instance.items};

CrashReportDetail _$CrashReportDetailFromJson(
  Map<String, dynamic> json,
) => CrashReportDetail(
  id: (json['id'] as num).toInt(),
  signature: json['signature'] as String,
  severity: json['severity'] as String,
  category: json['category'] as String,
  categoryLabel: json['categoryLabel'] as String,
  crashModule: json['crashModule'] as String?,
  exceptionCode: json['exceptionCode'] as String?,
  exceptionCodeName: json['exceptionCodeName'] as String?,
  headline: json['headline'] as String,
  fileName: json['fileName'] as String,
  fileSize: (json['fileSize'] as num?)?.toInt(),
  appVersion: json['appVersion'] as String?,
  osVersion: json['osVersion'] as String?,
  gpuVendor: json['gpuVendor'] as String?,
  similarCount: (json['similarCount'] as num?)?.toInt() ?? 0,
  fatalStrings:
      (json['fatalStrings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  resources:
      (json['resources'] as List<dynamic>?)
          ?.map((e) => CrashReportResource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  workshopIds:
      (json['workshopIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  thirdPartyModules:
      (json['thirdPartyModules'] as List<dynamic>?)
          ?.map(
            (e) => CrashReportThirdParty.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
  fullReport: json['fullReport'] as String,
  dumpAt: const ServerTimeConverter().fromJson(json['dumpAt'] as String),
  createdAt: const ServerTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$CrashReportDetailToJson(CrashReportDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'signature': instance.signature,
      'severity': instance.severity,
      'category': instance.category,
      'categoryLabel': instance.categoryLabel,
      'crashModule': instance.crashModule,
      'exceptionCode': instance.exceptionCode,
      'exceptionCodeName': instance.exceptionCodeName,
      'headline': instance.headline,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'appVersion': instance.appVersion,
      'osVersion': instance.osVersion,
      'gpuVendor': instance.gpuVendor,
      'similarCount': instance.similarCount,
      'fatalStrings': instance.fatalStrings,
      'resources': instance.resources,
      'workshopIds': instance.workshopIds,
      'thirdPartyModules': instance.thirdPartyModules,
      'fullReport': instance.fullReport,
      'dumpAt': const ServerTimeConverter().toJson(instance.dumpAt),
      'createdAt': const ServerTimeConverter().toJson(instance.createdAt),
    };

CrashReportStats _$CrashReportStatsFromJson(Map<String, dynamic> json) =>
    CrashReportStats(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      todayCount: (json['todayCount'] as num?)?.toInt() ?? 0,
      topModules:
          (json['topModules'] as List<dynamic>?)
              ?.map(
                (e) =>
                    CrashReportModuleStat.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      topThirdParty:
          (json['topThirdParty'] as List<dynamic>?)
              ?.map(
                (e) =>
                    CrashReportModuleStat.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );

Map<String, dynamic> _$CrashReportStatsToJson(CrashReportStats instance) =>
    <String, dynamic>{
      'totalCount': instance.totalCount,
      'todayCount': instance.todayCount,
      'topModules': instance.topModules,
      'topThirdParty': instance.topThirdParty,
    };

CrashReportModuleStat _$CrashReportModuleStatFromJson(
  Map<String, dynamic> json,
) => CrashReportModuleStat(
  name: json['name'] as String,
  count: (json['count'] as num?)?.toInt() ?? 0,
  label: json['label'] as String?,
);

Map<String, dynamic> _$CrashReportModuleStatToJson(
  CrashReportModuleStat instance,
) => <String, dynamic>{
  'name': instance.name,
  'count': instance.count,
  'label': instance.label,
};
