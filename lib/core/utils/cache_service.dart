import 'dart:convert';
import '../models/server_models.dart';
import '../constants/api_constants.dart';
import 'log_service.dart';
import 'storage_utils.dart';

class CacheService {
  static const String _serverListKey = 'cached_server_list';
  static const String _serverListTimestampKey = 'cached_server_list_timestamp';
  static const String _mapInfoKey = 'cached_map_info';
  static const String _mapInfoTimestampKey = 'cached_map_info_timestamp';

  static Future<void> cacheServerList(List<ServerCategory> serverList) async {
    try {
      final jsonString = json.encode(
        serverList.map((e) => e.toJson()).toList(),
      );
      await StorageUtils.setString(_serverListKey, jsonString);
      await StorageUtils.setInt(
        _serverListTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      LogService.d('服务器列表已缓存，共 ${serverList.length} 个分类');
    } catch (e) {
      LogService.e('缓存服务器列表失败: $e', e);
    }
  }

  static Future<List<ServerCategory>?> getCachedServerList() async {
    try {
      final jsonString = StorageUtils.getString(_serverListKey);
      final timestamp = StorageUtils.getInt(_serverListTimestampKey);

      if (jsonString == null || timestamp == null) {
        LogService.d('没有找到缓存的服务器列表');
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(cacheTime) > ApiConstants.serverListCacheDuration) {
        LogService.d('服务器列表缓存已过期');
        return null;
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final serverList = jsonList
          .map((json) => ServerCategory.fromJson(json as Map<String, dynamic>))
          .toList();

      LogService.i('从缓存获取服务器列表，共 ${serverList.length} 个分类');
      return serverList;
    } catch (e) {
      LogService.e('获取缓存服务器列表失败: $e', e);
      return null;
    }
  }

  static Future<void> clearServerListCache() async {
    try {
      await StorageUtils.remove(_serverListKey);
      await StorageUtils.remove(_serverListTimestampKey);
      LogService.i('服务器列表缓存已清除');
    } catch (e) {
      LogService.e('清除服务器列表缓存失败: $e', e);
    }
  }

  static Future<bool> isServerListCacheValid() async {
    try {
      final timestamp = StorageUtils.getInt(_serverListTimestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) <= ApiConstants.serverListCacheDuration;
    } catch (e) {
      LogService.e('检查服务器列表缓存状态失败: $e', e);
      return false;
    }
  }

  // ========== 地图信息缓存 ==========

  /// 缓存单个地图信息
  static Future<void> cacheMapInfo(String mapName, MapData mapData) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();

      // 获取现有缓存
      final existingData = await _getMapInfoCacheData();
      final existingTimestamps = await _getMapInfoTimestamps();

      // 更新缓存
      existingData[normalizedName] = mapData.toJson();
      existingTimestamps[normalizedName] =
          DateTime.now().millisecondsSinceEpoch;

      // 保存
      await StorageUtils.setString(_mapInfoKey, json.encode(existingData));
      await StorageUtils.setString(
        _mapInfoTimestampKey,
        json.encode(existingTimestamps),
      );
    } catch (e) {
      LogService.e('缓存地图信息失败 ($mapName): $e', e);
    }
  }

  /// 获取缓存的地图信息
  ///
  /// 缓存策略：
  /// - 图片数据永久缓存（不会过期删除）
  /// - 但会检查时间戳，超过1小时会触发后台更新检查
  /// - 返回 null 表示需要从 API 获取新数据
  static Future<MapData?> getCachedMapInfo(String mapName) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();

      final data = await _getMapInfoCacheData();
      final timestamps = await _getMapInfoTimestamps();

      if (!data.containsKey(normalizedName)) return null;

      // 检查时间戳，超过1小时返回 null 触发 API 更新
      // 但图片数据仍然保留在缓存中（永久缓存）
      final timestamp = timestamps[normalizedName];
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) >
            ApiConstants.mapInfoCacheDuration) {
          return null; // 触发 API 更新检查
        }
      }

      return MapData.fromJson(data[normalizedName] as Map<String, dynamic>);
    } catch (e) {
      LogService.e('获取缓存地图信息失败 ($mapName): $e', e);
      return null;
    }
  }

  /// 获取缓存的地图信息（忽略过期时间，用于 API 失败时的 fallback）
  static Future<MapData?> getCachedMapInfoIgnoreExpiry(String mapName) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();

      final data = await _getMapInfoCacheData();
      if (!data.containsKey(normalizedName)) return null;

      return MapData.fromJson(data[normalizedName] as Map<String, dynamic>);
    } catch (e) {
      LogService.e('获取缓存地图信息失败 ($mapName): $e', e);
      return null;
    }
  }

  /// 清除所有地图信息缓存
  static Future<void> clearMapInfoCache() async {
    try {
      await StorageUtils.remove(_mapInfoKey);
      await StorageUtils.remove(_mapInfoTimestampKey);
      LogService.i('地图信息缓存已清除');
    } catch (e) {
      LogService.e('清除地图信息缓存失败: $e', e);
    }
  }

  /// 清除单个地图的缓存
  static Future<void> clearMapInfoCacheForMap(String mapName) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();

      final data = await _getMapInfoCacheData();
      final timestamps = await _getMapInfoTimestamps();

      data.remove(normalizedName);
      timestamps.remove(normalizedName);

      await StorageUtils.setString(_mapInfoKey, json.encode(data));
      await StorageUtils.setString(
        _mapInfoTimestampKey,
        json.encode(timestamps),
      );
      LogService.i('地图信息缓存已清除: $mapName');
    } catch (e) {
      LogService.e('清除地图信息缓存失败 ($mapName): $e', e);
    }
  }

  static Future<Map<String, dynamic>> _getMapInfoCacheData() async {
    final jsonString = StorageUtils.getString(_mapInfoKey);
    if (jsonString == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(jsonString));
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, int>> _getMapInfoTimestamps() async {
    final jsonString = StorageUtils.getString(_mapInfoTimestampKey);
    if (jsonString == null) return {};
    try {
      return Map<String, int>.from(json.decode(jsonString));
    } catch (e) {
      return {};
    }
  }
}
