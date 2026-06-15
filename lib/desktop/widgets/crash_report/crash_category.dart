import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/services/crash_inspector/crash_inspector.dart';

/// 崩溃类别枚举，统一管理 key / label / icon 三者映射
///
/// `CrashSummary.categoryLabel` 是中文，`CrashReportListItem.category` 是
/// 英文 key（`gpu` / `tools` / `system` / `resource` / `code_exec` / `unknown`）。
/// 两边都映射到这个枚举，UI 层只跟枚举打交道。
enum CrashCategory {
  gpu(key: 'gpu', label: '显卡驱动'),
  tools(key: 'tools', label: 'Workshop 工具'),
  system(key: 'system', label: '系统组件'),
  resource(key: 'resource', label: '游戏资源'),
  codeExec(key: 'code_exec', label: '代码异常执行'),
  unknown(key: 'unknown', label: '未知');

  final String key;
  final String label;
  const CrashCategory({required this.key, required this.label});

  /// 从 key（如 `'gpu'`）映射回枚举。
  static CrashCategory fromKey(String? key) {
    if (key == null) return CrashCategory.unknown;
    return CrashCategory.values.firstWhere(
      (e) => e.key == key,
      orElse: () => CrashCategory.unknown,
    );
  }

  /// 从中文 label（`CrashSummary.categoryLabel`）反查回枚举。
  ///
  /// 等同于"category key"，避免在多处再写 `switch (label)`。
  static CrashCategory fromLabel(String? label) {
    if (label == null) return CrashCategory.unknown;
    return CrashCategory.values.firstWhere(
      (e) => e.label == label,
      orElse: () => CrashCategory.unknown,
    );
  }

  /// 从客户端解析得到的 [CrashSummary] 抽出枚举。
  static CrashCategory fromSummary(CrashSummary s) =>
      fromLabel(s.categoryLabel);

  IconData get icon {
    switch (this) {
      case CrashCategory.gpu:
        return MdiIcons.memory;
      case CrashCategory.tools:
        return MdiIcons.toolboxOutline;
      case CrashCategory.system:
        return MdiIcons.cogOutline;
      case CrashCategory.resource:
        return MdiIcons.fileSearchOutline;
      case CrashCategory.codeExec:
        return MdiIcons.skullOutline;
      case CrashCategory.unknown:
        return MdiIcons.helpCircleOutline;
    }
  }
}
