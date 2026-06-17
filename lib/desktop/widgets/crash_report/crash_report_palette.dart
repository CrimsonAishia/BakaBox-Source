import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/crash_report_models.dart';

/// 崩溃严重度对应的颜色 / 图标 / 中文标签
class CrashReportPalette {
  final String label;
  final Color accent;
  final IconData icon;

  const CrashReportPalette({
    required this.label,
    required this.accent,
    required this.icon,
  });

  factory CrashReportPalette.of(CrashReportSeverity severity) {
    switch (severity) {
      case CrashReportSeverity.high:
        return const CrashReportPalette(
          label: '严重',
          accent: AppColors.red500,
          icon: Icons.report_gmailerrorred,
        );
      case CrashReportSeverity.medium:
        return CrashReportPalette(
          label: '警告',
          accent: AppColors.amber500,
          icon: MdiIcons.alert,
        );
      case CrashReportSeverity.low:
        return CrashReportPalette(
          label: '一般',
          accent: AppColors.blue500,
          icon: MdiIcons.informationOutline,
        );
    }
  }
}


/// 第三方注入严重度颜色
({Color color, String label}) crashThirdPartyPalette(String severity) {
  switch (severity) {
    case 'high':
      return (color: AppColors.red500, label: '严重');
    case 'benign':
      return (color: AppColors.emerald500, label: '正常');
    case 'medium':
    default:
      return (color: AppColors.amber500, label: '可疑');
  }
}
