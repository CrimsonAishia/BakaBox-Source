import 'package:intl/intl.dart';

/// 时间工具类
/// 服务器返回的时间是北京时间（UTC+8），需要统一处理
class TimeUtils {
  /// 服务器时区偏移（北京时间 UTC+8）
  static const int serverTimezoneOffset = 8;

  /// 解析服务器返回的时间字符串
  /// 服务器返回的是北京时间（UTC+8），格式如 "2025-12-26 15:56:11"
  /// 返回的 DateTime 会根据用户本地时区进行转换
  static DateTime? parseServerTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;

    try {
      // 尝试手动解析，避免 DateTime.parse 的时区问题
      final parts = dateString.split(' ');
      if (parts.isEmpty) return null;

      final dateParts = parts[0].split('-');
      if (dateParts.length != 3) return null;

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      int hour = 0, minute = 0, second = 0;
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        if (timeParts.isNotEmpty) hour = int.parse(timeParts[0]);
        if (timeParts.length > 1) minute = int.parse(timeParts[1]);
        if (timeParts.length > 2) {
          // 处理可能带毫秒的情况 "15:56:11.123"
          final secondPart = timeParts[2].split('.')[0];
          second = int.parse(secondPart);
        }
      }

      // 创建 UTC+8 时间，然后转换为本地时间
      final serverTime = DateTime.utc(year, month, day, hour, minute, second);
      // 服务器时间是 UTC+8，所以需要减去8小时得到真正的 UTC 时间
      final utcTime = serverTime.subtract(const Duration(hours: serverTimezoneOffset));
      // 转换为用户本地时间
      return utcTime.toLocal();
    } catch (e) {
      // 如果手动解析失败，尝试标准解析
      try {
        return DateTime.parse(dateString).toLocal();
      } catch (e) {
        return null;
      }
    }
  }

  /// 格式化为相对时间（如：刚刚、5分钟前、昨天）
  static String formatRelative(String? dateString) {
    final date = parseServerTime(dateString);
    if (date == null) return dateString ?? '';

    final now = DateTime.now();
    final difference = now.difference(date);
    final timeStr = DateFormat('HH时mm分').format(date);

    if (difference.isNegative) {
      // 未来时间
      return DateFormat('yyyy年MM月dd日 HH时mm分').format(date);
    }

    // 使用日历日期比较，而不是时间差
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final daysDiff = today.difference(dateDay).inDays;

    if (daysDiff == 0) {
      // 今天
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return '刚刚';
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前（$timeStr）';
    }
    if (daysDiff == 1) return '昨天（$timeStr）';

    return DateFormat('yyyy年MM月dd日 HH时mm分').format(date);
  }

  /// 格式化为完整日期时间
  static String formatFull(String? dateString) {
    final date = parseServerTime(dateString);
    if (date == null) return dateString ?? '';
    return DateFormat('yyyy年MM月dd日 HH:mm:ss').format(date);
  }

  /// 格式化为日期时间（带星期）
  static String formatWithWeekday(String? dateString) {
    final date = parseServerTime(dateString);
    if (date == null) return dateString ?? '';

    final weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final weekDay = weekDays[date.weekday % 7];
    return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 $weekDay ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化为短日期
  static String formatShortDate(String? dateString) {
    final date = parseServerTime(dateString);
    if (date == null) return dateString ?? '';
    return DateFormat('MM-dd HH:mm').format(date);
  }

  /// 格式化为仅时间
  static String formatTimeOnly(String? dateString) {
    final date = parseServerTime(dateString);
    if (date == null) return dateString ?? '';
    return DateFormat('HH:mm:ss').format(date);
  }

  /// 计算两个时间字符串之间的时长
  static Duration? getDuration(String? startTime, String? endTime) {
    final start = parseServerTime(startTime);
    final end = parseServerTime(endTime);
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  /// 格式化时长
  static String formatDuration(Duration? duration) {
    if (duration == null) return '无数据';

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return hours > 0 ? '$days天$hours小时' : '$days天';
    } else if (hours > 0) {
      return minutes > 0 ? '$hours小时$minutes分钟' : '$hours小时';
    } else if (minutes > 0) {
      return '$minutes分钟';
    } else {
      return '< 1分钟';
    }
  }

  /// 格式化 DateTime 对象为相对时间
  static String formatDateTimeRelative(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) return '${(difference.inDays / 365).floor()}年前';
    if (difference.inDays > 30) return '${(difference.inDays / 30).floor()}个月前';
    if (difference.inDays > 0) return '${difference.inDays}天前';
    if (difference.inHours > 0) return '${difference.inHours}小时前';
    if (difference.inMinutes > 0) return '${difference.inMinutes}分钟前';
    return '刚刚';
  }
}
