import 'dart:io';

import '../services/server_category_service.dart';
import '../utils/log_service.dart';

/// 服务器地址映射服务
///
/// 管理 IP 地址到域名地址的映射，用于：
/// - 将 ConsoleLogService 返回的 IP 地址转换为域名地址
/// - 统一服务器标识，避免同一服务器因 IP 变化被识别为不同服务器
///
/// 单例模式，全局共享映射缓存
class ServerAddressMappingService {
  static final ServerAddressMappingService _instance =
      ServerAddressMappingService._internal();
  factory ServerAddressMappingService() => _instance;
  ServerAddressMappingService._internal();

  /// IP:Port -> Domain:Port 映射缓存
  final Map<String, String> _ipToDomainCache = {};

  /// 默认分类服务器的域名地址集合（isCustom == false 的分类）
  final Set<String> _defaultCategoryAddresses = {};

  /// 是否已加载
  bool _isLoaded = false;

  /// 是否正在加载
  bool _isLoading = false;

  /// 映射数量
  int get mappingCount => _ipToDomainCache.length;

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 加载服务器地址映射
  ///
  /// 从服务器列表获取所有服务器的域名地址，解析为 IP 后建立映射
  /// [force] 强制重新加载，即使已加载过
  Future<void> load({bool force = false}) async {
    if (_isLoaded && !force) return;
    if (_isLoading) return;

    _isLoading = true;

    try {
      _ipToDomainCache.clear();
      _defaultCategoryAddresses.clear();

      final categories = await ServerCategoryService.instance
          .getApiCategories();
      for (final category in categories) {
        for (final server in category.serverList) {
          final domainAddress = server.address;
          if (domainAddress == null || domainAddress.isEmpty) continue;

          final parts = domainAddress.split(':');
          if (parts.length != 2) continue;

          final host = parts[0];
          final port = parts[1];

          // 记录默认分类（非自定义）的服务器地址
          if (!category.isCustom) {
            _defaultCategoryAddresses.add(domainAddress);
          }

          try {
            final addresses = await InternetAddress.lookup(host);
            if (addresses.isNotEmpty) {
              final ip = addresses.first.address;
              final ipAddress = '$ip:$port';
              _ipToDomainCache[ipAddress] = domainAddress;
            }
          } catch (e) {
            // 如果是 IP 地址（DNS 解析失败），直接使用
            _ipToDomainCache[domainAddress] = domainAddress;
          }
        }
      }

      _isLoaded = true;
      LogService.d(
        '[AddressMapping] 地址映射加载完成，共 ${_ipToDomainCache.length} 条，默认分类服务器 ${_defaultCategoryAddresses.length} 个',
      );
    } catch (e) {
      LogService.e('[AddressMapping] 加载服务器地址映射失败', e);
    } finally {
      _isLoading = false;
    }
  }

  /// 获取域名地址
  ///
  /// 将 IP 地址转换为域名地址，如果没有映射则返回原地址
  /// [ipAddress] IP 地址，格式为 IP:Port
  String getDomainAddress(String ipAddress) {
    return _ipToDomainCache[ipAddress] ?? ipAddress;
  }

  /// 检查是否有映射
  bool hasMapping(String ipAddress) {
    return _ipToDomainCache.containsKey(ipAddress);
  }

  /// 运行期间补登映射（用于用户新增/编辑自定义服务器后立即使用的场景）
  ///
  /// [address] 域名地址（host:port），异步解析其 IP 后写入缓存
  /// 已存在的映射不重复解析（无论是 IP→domain 还是 domain→domain）
  Future<void> ensureMapping(String address) async {
    if (address.isEmpty) return;

    // 已经映射过的不重复解析
    if (_ipToDomainCache.containsKey(address) ||
        _ipToDomainCache.containsValue(address)) {
      return;
    }

    final parts = address.split(':');
    if (parts.length != 2) return;
    final host = parts[0];
    final port = parts[1];

    try {
      final addrs = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 2));
      if (addrs.isNotEmpty) {
        final ip = addrs.first.address;
        _ipToDomainCache['$ip:$port'] = address;
        LogService.d('[AddressMapping] 补登映射: $ip:$port → $address');
      }
    } catch (e) {
      // host 本身就是 IP 或 DNS 失败：缓存原值
      _ipToDomainCache[address] = address;
    }
  }

  /// 清除缓存
  void clear() {
    _ipToDomainCache.clear();
    _defaultCategoryAddresses.clear();
    _isLoaded = false;
  }

  /// 检查某个域名地址是否属于默认分类（非自定义）
  ///
  /// [domainAddress] 域名地址，格式为 host:port
  bool isDefaultCategoryServer(String domainAddress) {
    return _defaultCategoryAddresses.contains(domainAddress);
  }
}
