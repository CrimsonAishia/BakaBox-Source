import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// 图片内存解码尺寸
class MemCacheSize {
  final int? width;
  final int? height;
  const MemCacheSize({this.width, this.height});
}

/// 图片缓存与处理工具类
class ImageUtils {
  ImageUtils._();

  /// 为 B站 资源自动注入防盗链请求头
  static Map<String, String>? getBilibiliHeaders(
    String url, [
    Map<String, String>? baseHeaders,
  ]) {
    if (url.contains('hdslb.com') || url.contains('bilibili.com')) {
      return {
        ...?baseHeaders,
        'Referer': 'https://www.bilibili.com',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }
    return baseHeaders;
  }

  /// 将传入的 cacheKey 进行 MD5 哈希，避免作为本地文件路径时因为特殊字符导致 errno=3
  static String? generateSafeCacheKey(String? cacheKey) {
    if (cacheKey == null || cacheKey.isEmpty) return cacheKey;
    return md5.convert(utf8.encode(cacheKey)).toString();
  }

  /// 根据组件的物理宽高或父级约束，自动计算出最合适的解码尺寸以节省内存
  static MemCacheSize calculateMemCacheSize({
    required BuildContext context,
    BoxConstraints? constraints,
    double? width,
    double? height,
  }) {
    final dpr = View.of(context).devicePixelRatio;
    int? memWidth;
    int? memHeight;

    if (width != null && width.isFinite) {
      memWidth = (width * dpr).toInt();
    } else if (constraints != null &&
        constraints.maxWidth.isFinite &&
        constraints.maxWidth > 0) {
      memWidth = (constraints.maxWidth * dpr).toInt();
    }

    if (height != null && height.isFinite) {
      memHeight = (height * dpr).toInt();
    } else if (constraints != null &&
        constraints.maxHeight.isFinite &&
        constraints.maxHeight > 0) {
      memHeight = (constraints.maxHeight * dpr).toInt();
    }

    return MemCacheSize(width: memWidth, height: memHeight);
  }
}
