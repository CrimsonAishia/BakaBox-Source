import 'package:flutter/material.dart';
import '../../../../core/models/server_models.dart';

/// 解析颜色字符串
Color parseColor(String hexColor) {
  try {
    if (hexColor.startsWith('#')) hexColor = hexColor.substring(1);
    if (hexColor.length == 6) {
      return Color(int.parse('FF$hexColor', radix: 16));
    } else if (hexColor.length == 8) {
      // 格式为 AARRGGBB (alpha 在前)
      String aa = hexColor.substring(0, 2);
      String rr = hexColor.substring(2, 4);
      String gg = hexColor.substring(4, 6);
      String bb = hexColor.substring(6, 8);
      return Color(int.parse('$aa$rr$gg$bb', radix: 16));
    }
  } catch (e) {
    debugPrint('Error parsing color: $hexColor');
  }
  return Colors.white;
}

/// 获取地图显示名称
String getMapDisplayName(ExtendedServerItem? server) {
  if (server == null) return '未知地图';
  final mapName = server.serverData?.map ?? '未知地图';
  if (server.mapInfo != null && server.mapInfo!.mapLabel.isNotEmpty) {
    return '${server.mapInfo!.mapLabel}($mapName)';
  }
  return mapName;
}
