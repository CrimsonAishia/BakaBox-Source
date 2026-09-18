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
      final list = serverList.map((e) => e.toJson()).toList();
      await StorageUtils.setList(_serverListKey, list);
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
      final timestamp = StorageUtils.getInt(_serverListTimestampKey);
      if (timestamp == null) {
        LogService.d('没有找到缓存的服务器列表时间戳');
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(cacheTime) > ApiConstants.serverListCacheDuration) {
        LogService.d('服务器列表缓存已过期');
        return null;
      }

      final rawList = StorageUtils.getList(_serverListKey);
      if (rawList != null) {
        final serverList = rawList.map((e) {
          // Hive 中存储的 Map 可能是 Map<dynamic, dynamic>
          final map = Map<String, dynamic>.from(e as Map);
          return ServerCategory.fromJson(map);
        }).toList();
        LogService.i('从缓存获取服务器列表，共 ${serverList.length} 个分类');
        return serverList;
      }

      // 兼容旧版的 String 读取
      // TODO: (旧版兼容) 未来版本如果确认所有老用户都已迁移到 setList 格式，可删除此分支。
      final jsonString = StorageUtils.getString(_serverListKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final serverList = jsonList
            .map(
              (json) => ServerCategory.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        // 顺手将其转为新格式存储
        cacheServerList(serverList);
        LogService.i('从旧版缓存获取服务器列表并迁移，共 ${serverList.length} 个分类');
        return serverList;
      }

      return null;
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


  static const String _mapDataPrefix = 'map_info_data_';
  static const String _mapTsPrefix = 'map_info_ts_';

  /// 缓存单个地图信息
  static Future<void> cacheMapInfo(String mapName, MapData mapData) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();

      // 直接存入独立的 Key，避免巨型 Map 序列化
      await StorageUtils.setMap(
        '$_mapDataPrefix$normalizedName',
        mapData.toJson(),
      );
      await StorageUtils.setInt(
        '$_mapTsPrefix$normalizedName',
        DateTime.now().millisecondsSinceEpoch,
      );

      // 清理旧版巨型缓存垃圾（如果存在）
      _cleanupLegacyCache();
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

      final dataMap = StorageUtils.getMap('$_mapDataPrefix$normalizedName');
      if (dataMap == null) return null;

      // 检查时间戳，超过1小时返回 null 触发 API 更新
      // 但图片数据仍然保留在缓存中（永久缓存）
      final timestamp = StorageUtils.getInt('$_mapTsPrefix$normalizedName');
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) >
            ApiConstants.mapInfoCacheDuration) {
          return null; // 触发 API 更新检查
        }
      }

      return MapData.fromJson(dataMap);
    } catch (e) {
      LogService.e('获取缓存地图信息失败 ($mapName): $e', e);
      return null;
    }
  }

  /// 获取缓存的地图信息（忽略过期时间，用于 API 失败时的 fallback）
  static Future<MapData?> getCachedMapInfoIgnoreExpiry(String mapName) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();
      final dataMap = StorageUtils.getMap('$_mapDataPrefix$normalizedName');
      if (dataMap == null) return null;

      return MapData.fromJson(dataMap);
    } catch (e) {
      LogService.e('获取缓存地图信息失败 ($mapName): $e', e);
      return null;
    }
  }

  /// 清除所有地图信息缓存
  static Future<void> clearMapInfoCache() async {
    try {
      final keysToRemove = StorageUtils.getKeys()
          .where(
            (k) => k.startsWith(_mapDataPrefix) || k.startsWith(_mapTsPrefix),
          )
          .toList();

      for (var key in keysToRemove) {
        await StorageUtils.remove(key);
      }
      LogService.i('地图信息缓存已清除 (共 ${keysToRemove.length ~/ 2} 张地图)');
    } catch (e) {
      LogService.e('清除地图信息缓存失败: $e', e);
    }
  }

  /// 温和失效所有地图信息缓存：把时间戳标记为过期（下次读取会触发 API 刷新），
  /// 但**保留缓存的地图数据**，供 API 失败时兜底。
  static Future<void> invalidateAllMapInfoTimestamps() async {
    try {
      final tsKeys = StorageUtils.getKeys()
          .where((k) => k.startsWith(_mapTsPrefix))
          .toList();
      if (tsKeys.isEmpty) return;

      // 全部置为 0（纪元），使 getCachedMapInfo 判定为过期并触发刷新
      for (var key in tsKeys) {
        await StorageUtils.setInt(key, 0);
      }
      LogService.i('地图信息缓存已标记为过期（保留数据兜底）');
    } catch (e) {
      LogService.e('标记地图信息缓存过期失败: $e', e);
    }
  }

  /// 清除单个地图的缓存
  static Future<void> clearMapInfoCacheForMap(String mapName) async {
    try {
      final normalizedName = mapName.toLowerCase().trim();

      await StorageUtils.remove('$_mapDataPrefix$normalizedName');
      await StorageUtils.remove('$_mapTsPrefix$normalizedName');

      LogService.i('地图信息缓存已清除: $mapName');
    } catch (e) {
      LogService.e('清除地图信息缓存失败 ($mapName): $e', e);
    }
  }

  /// 清理旧版本的巨型 Map 缓存垃圾（向下兼容，无感迁移）
  /// TODO: (旧版兼容) 未来版本如果确认所有老用户都已完成迁移，可删除此兼容清理代码。
  static bool _legacyCleaned = false;
  static Future<void> _cleanupLegacyCache() async {
    if (_legacyCleaned) return;
    try {
      if (StorageUtils.containsKey(_mapInfoKey)) {
        await StorageUtils.remove(_mapInfoKey);
        await StorageUtils.remove(_mapInfoTimestampKey);
        LogService.i('已清理旧版巨型地图缓存垃圾释放空间');
      }
      _legacyCleaned = true;
    } catch (_) {}
  }
}
