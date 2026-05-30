import 'dart:convert';

import '../models/lobby_models.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';
import 'lobby_image_cache_service.dart';

/// 去掉 URL 后的鉴权参数，保留路径作为稳定 key。
/// 例如: https://cdn.example.com/sprite.png?token=abc&expires=123 → https://cdn.example.com/sprite.png
String _stripAuthParams(String url) {
  final qIndex = url.indexOf('?');
  if (qIndex < 0) return url;
  return url.substring(0, qIndex);
}

/// Lobby 素材 URL 缓存服务
///
/// 解决的问题：
/// - 后端下发的 CDN URL（spriteUrl、previewUrl、backgroundUrl）带有签名 token
/// - 这些 token 有时效性，重新连接后 URL 会变化
/// - 通过稳定的 key（spriteId、mapId）缓存 URL，下次直接使用缓存
///
/// 缓存策略：
/// - 使用 Hive 持久化存储，重启后保留
/// - 内存缓存提高查询效率
/// - 缓存映射关系而非原始 URL，便于后续更新
class LobbyAssetCacheService {
  LobbyAssetCacheService._();

  static final LobbyAssetCacheService instance = LobbyAssetCacheService._();

  static const String _spriteCacheKey = 'lobby_sprite_urls';
  static const String _mapCacheKey = 'lobby_map_urls';

  bool _initialized = false;

  /// 内存缓存：spriteId -> { spriteUrl, previewUrl }
  final Map<String, _SpriteUrlCache> _spriteMemoryCache = {};

  /// 内存缓存：mapId -> { backgroundUrl }
  final Map<String, _MapUrlCache> _mapMemoryCache = {};

  /// 初始化：从 Hive 加载缓存到内存
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 加载 sprite 缓存
      final spriteJson = StorageUtils.getString(_spriteCacheKey);
      if (spriteJson != null && spriteJson.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(spriteJson);
        for (final entry in data.entries) {
          _spriteMemoryCache[entry.key] = _SpriteUrlCache.fromJson(entry.value);
        }
        LogService.d(
          '[LobbyAssetCache] 已加载 ${_spriteMemoryCache.length} 个 sprite 缓存',
        );
      }

      // 加载 map 缓存
      final mapJson = StorageUtils.getString(_mapCacheKey);
      if (mapJson != null && mapJson.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(mapJson);
        for (final entry in data.entries) {
          _mapMemoryCache[entry.key] = _MapUrlCache.fromJson(entry.value);
        }
        LogService.d(
          '[LobbyAssetCache] 已加载 ${_mapMemoryCache.length} 个 map 缓存',
        );
      }

      _initialized = true;
    } catch (e) {
      LogService.e('[LobbyAssetCache] 初始化缓存失败', e);
      _initialized = true; // 避免重复尝试
    }
  }

  /// 获取 sprite 贴图 URL（优先返回缓存的稳定 URL）
  String? getSpriteUrl(String spriteId, {String? serverUrl}) {
    if (serverUrl == null || serverUrl.isEmpty) {
      return _spriteMemoryCache[spriteId]?.spriteUrl;
    }
    // 如果服务器 URL 和缓存 URL 不同（token 变了），使用服务器 URL
    final cached = _spriteMemoryCache[spriteId];
    if (cached == null) return serverUrl;
    if (cached.spriteUrl == serverUrl) return cached.spriteUrl;
    return serverUrl;
  }

  /// 获取 sprite 预览图 URL
  String? getPreviewUrl(String spriteId, {String? serverUrl}) {
    if (serverUrl == null || serverUrl.isEmpty) {
      return _spriteMemoryCache[spriteId]?.previewUrl;
    }
    final cached = _spriteMemoryCache[spriteId];
    if (cached == null) return serverUrl;
    if (cached.previewUrl == serverUrl) return cached.previewUrl;
    return serverUrl;
  }

  /// 获取地图背景 URL
  String? getBackgroundUrl(String mapId, {String? serverUrl}) {
    if (serverUrl == null || serverUrl.isEmpty) {
      return _mapMemoryCache[mapId]?.backgroundUrl;
    }
    final cached = _mapMemoryCache[mapId];
    if (cached == null) return serverUrl;
    if (cached.backgroundUrl == serverUrl) return cached.backgroundUrl;
    return serverUrl;
  }

  /// 缓存 sprites（角色贴图）
  ///
  /// 从 WebSocket assets 消息中提取并缓存所有 sprite URL。
  /// 比较时去掉鉴权参数，只比较路径部分，避免 token 变化导致误判为新素材。
  /// 同时触发图片下载到本地（使用原始带参 URL，确保图片有效期内下载）。
  Future<void> cacheSprites(List<LobbySprite> sprites) async {
    int updated = 0;
    int total = sprites.length;
    final rawUrlsToDownload = <String>[];

    for (final sprite in sprites) {
      if (sprite.id.isEmpty) continue;

      final stableSpriteUrl = sprite.spriteUrl != null
          ? _stripAuthParams(sprite.spriteUrl!)
          : null;
      final stablePreviewUrl = sprite.previewUrl != null
          ? _stripAuthParams(sprite.previewUrl!)
          : null;

      final existing = _spriteMemoryCache[sprite.id];
      // 用去掉鉴权参数后的稳定路径做比较
      if (existing == null ||
          existing.spriteUrl != stableSpriteUrl ||
          existing.previewUrl != stablePreviewUrl) {
        _spriteMemoryCache[sprite.id] = _SpriteUrlCache(
          spriteUrl: stableSpriteUrl,
          previewUrl: stablePreviewUrl,
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        );
        updated++;

        // 收集需要下载的原始 URL（带鉴权参数，确保图片有效期内下载）
        if (sprite.spriteUrl != null && sprite.spriteUrl!.isNotEmpty) {
          rawUrlsToDownload.add(sprite.spriteUrl!);
        }
        if (sprite.previewUrl != null && sprite.previewUrl!.isNotEmpty) {
          rawUrlsToDownload.add(sprite.previewUrl!);
        }
      }
    }

    if (updated > 0) {
      await _saveSpriteCache();
      LogService.d('[LobbyAssetCache] 缓存了 $updated/$total 个 sprite URL');

      // 触发图片下载到本地（使用原始 URL，后台执行不阻塞）
      _downloadImagesWithRawUrls(rawUrlsToDownload);
    }
  }

  /// 缓存地图背景
  /// 同时触发图片下载到本地（使用原始带参 URL，确保图片有效期内下载）。
  Future<void> cacheMap(LobbyMapConfig? mapConfig) async {
    if (mapConfig == null || mapConfig.mapId.isEmpty) return;

    final stableBackgroundUrl = mapConfig.backgroundUrl != null
        ? _stripAuthParams(mapConfig.backgroundUrl!)
        : null;
    final existing = _mapMemoryCache[mapConfig.mapId];

    if (existing == null || existing.backgroundUrl != stableBackgroundUrl) {
      _mapMemoryCache[mapConfig.mapId] = _MapUrlCache(
        backgroundUrl: stableBackgroundUrl,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );
      await _saveMapCache();
      LogService.d('[LobbyAssetCache] 缓存了地图背景: ${mapConfig.mapId}');

      // 触发图片下载到本地（使用原始 URL，后台执行不阻塞）
      if (mapConfig.backgroundUrl != null &&
          mapConfig.backgroundUrl!.isNotEmpty) {
        _downloadImagesWithRawUrls([mapConfig.backgroundUrl!]);
      }
    }
  }

  /// 后台下载图片到本地缓存
  ///
  /// 使用原始 URL 下载（带鉴权参数），确保图片有效期内完成下载。
  /// 下载成功后，存储时用稳定 URL（去掉鉴权参数）作为 key。
  Future<void> _downloadImagesWithRawUrls(List<String> rawUrls) async {
    if (rawUrls.isEmpty) return;
    try {
      await LobbyImageCacheService.instance.preDownloadImages(rawUrls);
    } catch (e) {
      LogService.e('[LobbyAssetCache] 下载图片失败', e);
    }
  }

  /// 从缓存构建 LobbySprite（用缓存的 URL 替换/补充传入的 sprites）
  ///
  /// 用于当服务器 URL 过期时，使用缓存的稳定 URL
  List<LobbySprite> mergeWithCache(List<LobbySprite> sprites) {
    return sprites.map((sprite) {
      final cached = _spriteMemoryCache[sprite.id];
      if (cached == null) return sprite;

      return LobbySprite(
        id: sprite.id,
        label: sprite.label,
        accentColor: sprite.accentColor,
        spriteUrl: sprite.spriteUrl ?? cached.spriteUrl,
        previewUrl: sprite.previewUrl ?? cached.previewUrl,
        isDefault: sprite.isDefault,
      );
    }).toList();
  }

  /// 从缓存构建 LobbyMapConfig
  LobbyMapConfig? mergeMapWithCache(LobbyMapConfig? mapConfig) {
    if (mapConfig == null || mapConfig.mapId.isEmpty) return mapConfig;

    final cached = _mapMemoryCache[mapConfig.mapId];
    if (cached == null) return mapConfig;

    return LobbyMapConfig(
      mapId: mapConfig.mapId,
      displayName: mapConfig.displayName,
      backgroundUrl: mapConfig.backgroundUrl ?? cached.backgroundUrl,
      width: mapConfig.width,
      height: mapConfig.height,
      walkableAreas: mapConfig.walkableAreas,
    );
  }

  /// 检查是否有缓存的 sprite
  bool hasSpriteCache(String spriteId) =>
      _spriteMemoryCache.containsKey(spriteId);

  /// 检查是否有缓存的 map 背景
  bool hasMapCache(String mapId) => _mapMemoryCache.containsKey(mapId);

  /// 获取缓存的 sprite 数量
  int get spriteCacheCount => _spriteMemoryCache.length;

  /// 获取缓存的 sprite ID 列表
  List<String> getCachedSpriteIds() => _spriteMemoryCache.keys.toList();

  /// 获取所有缓存的 map ID
  List<String> getCachedMapIds() => _mapMemoryCache.keys.toList();

  /// 获取缓存的 map ID（如果有），返回第一个
  String? getCachedMapId() {
    if (_mapMemoryCache.isEmpty) return null;
    return _mapMemoryCache.keys.first;
  }

  /// 根据 mapId 获取地图背景 URL（不带 serverUrl 参数的重载）
  String? getBackgroundUrlByMapId(String mapId) {
    return _mapMemoryCache[mapId]?.backgroundUrl;
  }

  /// 获取缓存的 map 数量
  int get mapCacheCount => _mapMemoryCache.length;

  /// 清除所有缓存
  Future<void> clearAll() async {
    _spriteMemoryCache.clear();
    _mapMemoryCache.clear();
    await StorageUtils.remove(_spriteCacheKey);
    await StorageUtils.remove(_mapCacheKey);
    LogService.i('[LobbyAssetCache] 已清除所有素材 URL 缓存');
  }

  /// 清除指定 sprite 的缓存
  Future<void> clearSpriteCache(String spriteId) async {
    if (_spriteMemoryCache.remove(spriteId) != null) {
      await _saveSpriteCache();
      LogService.d('[LobbyAssetCache] 已清除 sprite 缓存: $spriteId');
    }
  }

  /// 清除指定 map 的缓存
  Future<void> clearMapCache(String mapId) async {
    if (_mapMemoryCache.remove(mapId) != null) {
      await _saveMapCache();
      LogService.d('[LobbyAssetCache] 已清除 map 缓存: $mapId');
    }
  }

  Future<void> _saveSpriteCache() async {
    try {
      final data = <String, dynamic>{};
      for (final entry in _spriteMemoryCache.entries) {
        data[entry.key] = entry.value.toJson();
      }
      await StorageUtils.setString(_spriteCacheKey, json.encode(data));
    } catch (e) {
      LogService.e('[LobbyAssetCache] 保存 sprite 缓存失败', e);
    }
  }

  Future<void> _saveMapCache() async {
    try {
      final data = <String, dynamic>{};
      for (final entry in _mapMemoryCache.entries) {
        data[entry.key] = entry.value.toJson();
      }
      await StorageUtils.setString(_mapCacheKey, json.encode(data));
    } catch (e) {
      LogService.e('[LobbyAssetCache] 保存 map 缓存失败', e);
    }
  }
}

/// Sprite URL 缓存数据
class _SpriteUrlCache {
  final String? spriteUrl;
  final String? previewUrl;
  final int lastUpdated;

  const _SpriteUrlCache({
    this.spriteUrl,
    this.previewUrl,
    required this.lastUpdated,
  });

  factory _SpriteUrlCache.fromJson(Map<String, dynamic> json) {
    return _SpriteUrlCache(
      spriteUrl: json['spriteUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      lastUpdated: json['lastUpdated'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'spriteUrl': spriteUrl,
    'previewUrl': previewUrl,
    'lastUpdated': lastUpdated,
  };
}

/// Map URL 缓存数据
class _MapUrlCache {
  final String? backgroundUrl;
  final int lastUpdated;

  const _MapUrlCache({this.backgroundUrl, required this.lastUpdated});

  factory _MapUrlCache.fromJson(Map<String, dynamic> json) {
    return _MapUrlCache(
      backgroundUrl: json['backgroundUrl'] as String?,
      lastUpdated: json['lastUpdated'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'backgroundUrl': backgroundUrl,
    'lastUpdated': lastUpdated,
  };
}
