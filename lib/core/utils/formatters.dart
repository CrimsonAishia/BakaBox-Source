import 'package:intl/intl.dart';
import 'time_utils.dart';

class Formatters {
  static String formatDate(String dateString) {
    return TimeUtils.formatRelative(dateString);
  }

  static String formatDateTime(String dateString) {
    return TimeUtils.formatFull(dateString);
  }

  static String formatRelativeTime(DateTime dateTime) {
    return TimeUtils.formatDateTimeRelative(dateTime);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  static String formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  static String formatPlayerCount(int? players, int? maxPlayers) {
    if (players == null || maxPlayers == null) return 'N/A';
    return '$players/$maxPlayers';
  }

  static String formatPing(int? ping) {
    if (ping == null) return 'N/A';
    return '${ping}ms';
  }

  static String formatServerStatus(bool? isOnline) {
    if (isOnline == null) return '未知';
    return isOnline ? '在线' : '离线';
  }

  static String formatMapName(String? mapName) {
    if (mapName == null || mapName.isEmpty) return 'Unknown';
    return mapName.toLowerCase();
  }

  static String htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
