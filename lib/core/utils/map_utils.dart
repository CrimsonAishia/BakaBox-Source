/// 地图相关的工具类
/// 处理地图名称到图片URL的映射
class MapUtils {
  MapUtils._();

  /// 默认地图背景图片路径
  static const String defaultMapBackground = 'assets/images/default-map-bg.jpg';

  /// 获取地图图片URL
  /// 
  /// [mapName] 地图名称
  /// [mapUrl] 从API获取的地图图片URL（可选）
  /// 
  /// 返回地图图片URL，如果没有则返回默认背景
  static String getMapImageUrl(String? mapName, {String? mapUrl}) {
    // 如果有API返回的URL，直接使用
    if (mapUrl != null && mapUrl.isNotEmpty) {
      return mapUrl;
    }
    
    // 如果没有地图名称，返回默认背景
    if (mapName == null || mapName.isEmpty) {
      return defaultMapBackground;
    }
    
    // 尝试从已知地图映射中获取
    final normalizedName = mapName.toLowerCase().trim();
    final knownUrl = _knownMapImages[normalizedName];
    if (knownUrl != null) {
      return knownUrl;
    }
    
    // 返回默认背景
    return defaultMapBackground;
  }

  /// 格式化地图名称显示
  /// 
  /// [mapName] 原始地图名称
  /// 
  /// 返回格式化后的地图名称（保持原始大小写）
  static String formatMapName(String? mapName) {
    if (mapName == null || mapName.isEmpty) {
      return '未知地图';
    }
    
    // 直接返回原始地图名称，不做任何格式化
    return mapName;
  }

  /// 获取地图显示名称
  /// 
  /// [mapName] 原始地图名称
  /// [mapLabel] 地图标签（可选）
  /// 
  /// 返回带标签的地图显示名称
  static String getMapDisplayName(String? mapName, {String? mapLabel}) {
    if (mapLabel != null && mapLabel.isNotEmpty) {
      return '$mapLabel (${mapName ?? "未知"})';
    }
    return formatMapName(mapName);
  }

  /// 检查是否为有效的地图图片URL
  static bool isValidMapImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    return url.startsWith('http://') || 
           url.startsWith('https://') || 
           url.startsWith('assets/');
  }

  /// 已知地图图片映射表
  /// 用于在API未返回图片时提供备用图片
  static const Map<String, String> _knownMapImages = {
    // 可以在这里添加已知地图的图片URL映射
    // 'ze_example_map': 'https://example.com/maps/ze_example_map.jpg',
  };
}
