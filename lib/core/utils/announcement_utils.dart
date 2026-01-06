import 'package:flutter/material.dart';
import '../models/announcement_models.dart';

/// 公告类型信息
class AnnouncementTypeInfo {
  final Color color;
  final IconData icon;
  final String label;

  const AnnouncementTypeInfo({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementTypeInfo &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          icon == other.icon &&
          label == other.label;

  @override
  int get hashCode => color.hashCode ^ icon.hashCode ^ label.hashCode;
}

/// 公告工具类
class AnnouncementUtils {
  AnnouncementUtils._();

  /// 已知的公告类型列表
  static const List<String> knownTypes = [
    'info',
    'success',
    'warning',
    'error',
    'maintenance',
  ];

  /// 获取公告类型信息（颜色、图标、标签）
  /// 
  /// [type] 公告类型：info, success, warning, error, maintenance
  /// 返回对应的类型信息，未知类型返回默认样式
  static AnnouncementTypeInfo getAnnouncementTypeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'info':
        return const AnnouncementTypeInfo(
          color: Color(0xFF2196F3),
          icon: Icons.info_outline,
          label: '通知',
        );
      case 'success':
        return const AnnouncementTypeInfo(
          color: Color(0xFF4CAF50),
          icon: Icons.check_circle_outline,
          label: '成功',
        );
      case 'warning':
        return const AnnouncementTypeInfo(
          color: Color(0xFFFF9800),
          icon: Icons.warning_amber_outlined,
          label: '警告',
        );
      case 'error':
        return const AnnouncementTypeInfo(
          color: Color(0xFFF44336),
          icon: Icons.error_outline,
          label: '错误',
        );
      case 'maintenance':
        return const AnnouncementTypeInfo(
          color: Color(0xFF9C27B0),
          icon: Icons.build_outlined,
          label: '维护',
        );
      default:
        // 未知类型返回默认样式
        return const AnnouncementTypeInfo(
          color: Color(0xFF607D8B),
          icon: Icons.article_outlined,
          label: '公告',
        );
    }
  }

  /// 格式化时间戳为相对时间
  /// 
  /// [timestamp] Unix 时间戳（秒）
  /// 返回相对时间字符串，如 "刚刚"、"5分钟前"、"2小时前"、"3天前"
  /// 无效时间戳返回 "未知时间"
  static String formatRelativeTime(int timestamp) {
    if (timestamp <= 0) {
      return '未知时间';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 未来时间
    if (difference.isNegative) {
      return '未知时间';
    }

    // 1分钟内
    if (difference.inMinutes < 1) {
      return '刚刚';
    }

    // 1小时内
    if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    }

    // 24小时内
    if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    }

    // 30天内
    if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    }

    // 12个月内
    final months = (difference.inDays / 30).floor();
    if (months < 12) {
      return '$months个月前';
    }

    // 超过12个月
    final years = (difference.inDays / 365).floor();
    return '$years年前';
  }

  /// 合并并排序公告列表
  /// 
  /// [active] 有效公告列表
  /// [sticky] 置顶公告列表
  /// 返回去重后的排序列表：置顶优先，然后按优先级降序，最后按创建时间降序
  static List<AnnouncementItem> mergeAndSortAnnouncements(
    List<AnnouncementItem> active,
    List<AnnouncementItem> sticky,
  ) {
    // 使用 Map 进行去重，以 ID 为键
    final Map<int, AnnouncementItem> uniqueMap = {};

    // 先添加 sticky 公告（它们可能有更新的状态）
    for (final item in sticky) {
      uniqueMap[item.id] = item;
    }

    // 再添加 active 公告（如果 ID 已存在则跳过）
    for (final item in active) {
      uniqueMap.putIfAbsent(item.id, () => item);
    }

    // 转换为列表并排序
    final result = uniqueMap.values.toList();
    
    result.sort((a, b) {
      // 1. 置顶优先（isSticky = true 排在前面）
      if (a.isSticky != b.isSticky) {
        return a.isSticky ? -1 : 1;
      }

      // 2. 优先级降序（数值大的排在前面）
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }

      // 3. 创建时间降序（新的排在前面）
      return b.createdAt.compareTo(a.createdAt);
    });

    return result;
  }
}
