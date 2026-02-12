import 'dart:io';

import '../api/server_api.dart';
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

  final ServerApi _serverApi = ServerApi();

  /// IP:Port -> Domain:Port 映射缓存
  final Map<String, String> _ipToDomainCache = {};

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

      final categories = await _serverApi.getServerList();
      for (final category in categories) {
        for (final server in category.serverList) {
          final domainAddress = server.address;
          if (domainAddress == null || domainAddress.isEmpty) continue;

          final parts = domainAddress.split(':');
          if (parts.length != 2) continue;

          final host = parts[0];
          final port = parts[1];

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
        '[AddressMapping] 地址映射加载完成，共 ${_ipToDomainCache.length} 条',
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

  /// 清除缓存
  void clear() {
    _ipToDomainCache.clear();
    _isLoaded = false;
  }
}
