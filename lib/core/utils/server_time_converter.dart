import 'package:json_annotation/json_annotation.dart';
import 'time_utils.dart';

/// 服务器时间转换器
/// 将服务器返回的北京时间（UTC+8）字符串转换为本地 DateTime
class ServerTimeConverter implements JsonConverter<DateTime, String> {
  const ServerTimeConverter();

  @override
  DateTime fromJson(String json) {
    final localTime = TimeUtils.parseServerTime(json);
    // 如果解析失败，回退到标准解析
    return localTime ?? DateTime.parse(json);
  }

  @override
  String toJson(DateTime object) {
    // 转换回服务器时间格式（北京时间）
    final utcTime = object.toUtc();
    final serverTime = utcTime.add(const Duration(hours: TimeUtils.serverTimezoneOffset));
    return '${serverTime.year}-${serverTime.month.toString().padLeft(2, '0')}-${serverTime.day.toString().padLeft(2, '0')} '
        '${serverTime.hour.toString().padLeft(2, '0')}:${serverTime.minute.toString().padLeft(2, '0')}:${serverTime.second.toString().padLeft(2, '0')}';
  }
}

/// 可空服务器时间转换器
class NullableServerTimeConverter implements JsonConverter<DateTime?, String?> {
  const NullableServerTimeConverter();

  @override
  DateTime? fromJson(String? json) {
    if (json == null || json.isEmpty) return null;
    return const ServerTimeConverter().fromJson(json);
  }

  @override
  String? toJson(DateTime? object) {
    if (object == null) return null;
    return const ServerTimeConverter().toJson(object);
  }
}
