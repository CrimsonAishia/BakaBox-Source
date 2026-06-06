// CS2 mdmp 崩溃分析对外门面.
//
// 把 analyzer + report 包装成一组 UI 友好的数据结构, 供监控服务和弹窗使用.

import 'dart:io';
import 'dart:isolate';

import 'analyzer.dart' as cs2_analyzer;
import 'report.dart';

/// 崩溃严重程度 - 用于弹窗高亮提示用户.
enum CrashSeverity {
  /// 高危: 第三方注入 / 已知会引发 CS2 崩溃 (RTSS 等)
  high,

  /// 资源 / 渲染等内部子系统问题
  medium,

  /// 系统 / GPU 驱动 / 未知
  low,
}

/// 第三方模块条目 (展示用).
class CrashThirdPartyEntry {
  final String name;
  final String label;
  final String advice;
  final String severity; // high / medium / benign

  const CrashThirdPartyEntry({
    required this.name,
    required this.label,
    required this.advice,
    required this.severity,
  });
}

/// 嫌疑资源条目 (展示用).
class CrashResourceEntry {
  final String path;
  final String kindLabel;
  final int stackOffset; // < 0 表示寄存器命中
  const CrashResourceEntry({
    required this.path,
    required this.kindLabel,
    required this.stackOffset,
  });
}

/// 崩溃分析的精简摘要.
class CrashSummary {
  /// 原始 mdmp 文件路径.
  final String dumpPath;

  /// 文件名 (不含路径).
  final String fileName;

  /// 文件创建时间 (本地).
  final DateTime createdAt;

  /// 整体严重程度.
  final CrashSeverity severity;

  /// 崩溃类别中文名 (资源/逻辑、GPU/驱动、系统/异常处理 …).
  final String categoryLabel;

  /// 崩溃所在模块 (例如 client.dll). 为空表示不在已加载模块.
  final String? crashModule;

  /// 异常码描述 (例如 "EXCEPTION_ACCESS_VIOLATION (空指针/已释放/越界)").
  final String? exceptionCodeName;

  /// 16 进制异常码 (不带 0x).
  final String? exceptionCodeHex;

  /// 一句话定位文字 (例如 "崩溃在 client.dll, 资源加载相关").
  final String headline;

  /// 致命错误关键字符串 (最多前 3 条).
  final List<String> fatalStrings;

  /// 嫌疑资源 (前 6 条, 已按栈深度排序).
  final List<CrashResourceEntry> resources;

  /// Workshop VPK 订阅 ID 列表.
  final List<String> workshopIds;

  /// 第三方注入模块 (排序: 高危 -> 可疑 -> 良性).
  final List<CrashThirdPartyEntry> thirdPartyModules;

  /// 完整文本报告 (复制 / 全文查看用).
  final String fullReport;

  CrashSummary({
    required this.dumpPath,
    required this.fileName,
    required this.createdAt,
    required this.severity,
    required this.categoryLabel,
    required this.crashModule,
    required this.exceptionCodeName,
    required this.exceptionCodeHex,
    required this.headline,
    required this.fatalStrings,
    required this.resources,
    required this.workshopIds,
    required this.thirdPartyModules,
    required this.fullReport,
  });
}

/// CS2 崩溃文件分析门面 (无状态, 静态调用即可).
class CrashInspector {
  CrashInspector._();

  /// 分析单个 mdmp 文件, 返回 UI 摘要; 失败抛异常.
  ///
  /// 解析与渲染统一在后台 isolate 内完成 - mdmp 文件可达数十 MB,
  /// 直接读+解析容易卡住 UI 线程.
  static Future<CrashSummary> analyze(String dumpPath) async {
    final bundle = await Isolate.run<_AnalyzeBundle>(() {
      final result = cs2_analyzer.analyze(dumpPath);
      final fullReport = renderToString(result, verbose: false);
      return _AnalyzeBundle(result, fullReport);
    });
    return _toSummary(dumpPath, bundle.result, bundle.fullReport);
  }

  static CrashSummary _toSummary(
    String dumpPath,
    Map<String, dynamic> r,
    String fullReport,
  ) {
    final file = File(dumpPath);
    DateTime created;
    try {
      created = file.statSync().modified;
    } catch (_) {
      created = DateTime.now();
    }
    final fileName = (r['file'] as String?) ?? _basenameOf(dumpPath);

    if (r['ok'] != true) {
      return CrashSummary(
        dumpPath: dumpPath,
        fileName: fileName,
        createdAt: created,
        severity: CrashSeverity.low,
        categoryLabel: '解析失败',
        crashModule: null,
        exceptionCodeName: null,
        exceptionCodeHex: null,
        headline: r['error']?.toString() ?? '无法解析此崩溃文件',
        fatalStrings: const [],
        resources: const [],
        workshopIds: const [],
        thirdPartyModules: const [],
        fullReport: fullReport,
      );
    }

    final exc = r['exception'] as Map<String, dynamic>?;
    final crashModule = r['crash_module'] as Map<String, dynamic>?;
    final crashModuleName = crashModule?['name'] as String?;
    final cat = r['crash_category'] as String?;

    final categoryLabel = _categoryLabel(cat);
    final headline = _headline(cat, crashModuleName);

    // 第三方模块
    final tpRaw = (r['third_party_modules'] as List?) ?? const [];
    final thirdParties = tpRaw
        .cast<Map<String, dynamic>>()
        .map((m) => CrashThirdPartyEntry(
              name: m['name']?.toString() ?? '',
              label: m['label']?.toString() ?? '',
              advice: m['advice']?.toString() ?? '',
              severity: m['sev']?.toString() ?? 'medium',
            ))
        .toList()
      ..sort((a, b) {
        const order = {'high': 0, 'medium': 1, 'benign': 2};
        return (order[a.severity] ?? 1).compareTo(order[b.severity] ?? 1);
      });

    // 致命错误
    final fatals = ((r['fatal_strings'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((m) => (m['text'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    // 嫌疑资源 (按栈深度排序, 取前 6)
    final resourcesRaw = ((r['resources'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) {
        final oa = (a['stack_offset'] as int? ?? -1);
        final ob = (b['stack_offset'] as int? ?? -1);
        // 寄存器命中 (-1) 优先级最高, 其次按栈深度由浅到深
        if (oa < 0 && ob < 0) return 0;
        if (oa < 0) return -1;
        if (ob < 0) return 1;
        return oa.compareTo(ob);
      });

    final kindLabelMap = _kindLabels;
    final resources = resourcesRaw.take(6).map((m) {
      final kind = (m['kind'] as String?) ?? 'other';
      return CrashResourceEntry(
        path: (m['path'] as String?) ?? '',
        kindLabel: kindLabelMap[kind] ?? kind,
        stackOffset: (m['stack_offset'] as int?) ?? -1,
      );
    }).toList();

    // Workshop VPK
    final workshopIds = ((r['workshop_vpks'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((m) => (m['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    // 严重程度 (有任意高危第三方 -> high; 资源/工具 -> medium; 其它 -> low)
    final hasHighThird =
        thirdParties.any((e) => e.severity == 'high');
    CrashSeverity severity;
    if (hasHighThird) {
      severity = CrashSeverity.high;
    } else if (cat == 'resource' || cat == 'tools' || cat == 'code_exec') {
      severity = CrashSeverity.medium;
    } else {
      severity = CrashSeverity.low;
    }

    String? excCodeHex;
    final excCode = exc?['code'] as int?;
    if (excCode != null) {
      excCodeHex = excCode.toRadixString(16).toUpperCase().padLeft(8, '0');
    }

    return CrashSummary(
      dumpPath: dumpPath,
      fileName: fileName,
      createdAt: created,
      severity: severity,
      categoryLabel: categoryLabel,
      crashModule: crashModuleName,
      exceptionCodeName: exc?['code_name'] as String?,
      exceptionCodeHex: excCodeHex,
      headline: headline,
      fatalStrings: fatals,
      resources: resources,
      workshopIds: workshopIds,
      thirdPartyModules: thirdParties,
      fullReport: fullReport,
    );
  }

  static String _categoryLabel(String? cat) {
    switch (cat) {
      case 'gpu':
        return '显卡驱动';
      case 'tools':
        return 'Workshop 工具';
      case 'system':
        return '系统组件';
      case 'resource':
        return '游戏资源';
      case 'code_exec':
        return '代码异常执行';
      default:
        return '未知';
    }
  }

  static String _headline(String? cat, String? crashModule) {
    switch (cat) {
      case 'gpu':
        return '多与显卡驱动或硬件相关';
      case 'tools':
        return 'Workshop 工具崩溃，与游玩本身无关';
      case 'system':
        return '上层抛出的异常被系统接住';
      case 'resource':
        return '疑似资源加载或渲染问题';
      case 'code_exec':
        return '跳转到非法地址，常见于第三方注入或内存损坏';
      default:
        return '具体原因待排查';
    }
  }

  static String _basenameOf(String p) {
    var idx = -1;
    for (var i = p.length - 1; i >= 0; i--) {
      final c = p[i];
      if (c == '/' || c == '\\') {
        idx = i;
        break;
      }
    }
    return idx >= 0 ? p.substring(idx + 1) : p;
  }

  // 与 rules.dart 中 kindLabel 同步; 仅用于摘要展示.
  static const Map<String, String> _kindLabels = {
    'vmdl': '模型', 'vmdl_c': '模型',
    'vmap': '地图', 'vmap_c': '地图',
    'vmat': '材质', 'vmat_c': '材质',
    'vtex_c': '贴图',
    'vpcf': '粒子', 'vpcf_c': '粒子',
    'vsnd': '声音', 'vsnd_c': '声音',
    'vsndevts': '声音事件', 'vsndevts_c': '声音事件',
    'vanim_c': '动画',
    'vrman_c': '资源清单',
    'vwnod': '地图世界节点', 'vwnod_c': '地图世界节点',
    'vphys': '物理碰撞', 'vphys_c': '物理碰撞',
    'vnmgraph_c': '导航网格',
    'vpk': 'VPK 包',
    'other': '其他',
  };
}


/// 跨 isolate 传输的解析中间产物.
class _AnalyzeBundle {
  final Map<String, dynamic> result;
  final String fullReport;
  _AnalyzeBundle(this.result, this.fullReport);
}
