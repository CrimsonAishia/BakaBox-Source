import '../services/custom_server_service.dart';
import '../services/server_category_service.dart';
import '../services/source_server_service.dart';

/// 服务器解析工具类
/// 用于在没有 ServerBloc 实例（如全局单例服务中）的场景下，通过地址全局解析服务器信息
class ServerResolverUtils {
  ServerResolverUtils._();

  /// 尝试根据地址全局解析服务器名称
  ///
  /// 优先搜索自定义分类（以获取用户的备注名），其次搜索 API 默认分类。
  /// [address] 目标服务器的 IP:Port 地址
  static Future<String?> resolveServerName(String address) async {
    try {
      String? bestHostName;

      // 1. 先尝试在自定义分类中找（主要为了获取用户可能设置的备注名）
      final customCategories = await CustomServerService.loadCustomCategories();
      for (final category in customCategories) {
        for (final server in category.serverList) {
          if (server.address == address || server.serverAddress == address) {
            // 如果有备注名，由于优先级最高，直接返回
            if (server.nickname != null && server.nickname!.isNotEmpty) {
              return server.nickname;
            }

            // 如果没有备注名，收集可能有缓存的主机名
            final hostName =
                server.serverData?['name'] as String? ??
                server.serverData?['hostName'] as String?;
            if (hostName != null && hostName.isNotEmpty) {
              bestHostName = hostName;
            }
          }
        }
      }

      // 2. 如果没能直接返回，继续在 API 默认分类中找（补充官方名称数据）
      final categories = await ServerCategoryService.instance
          .getApiCategories();
      for (final category in categories) {
        for (final server in category.serverList) {
          if (server.address == address || server.serverAddress == address) {
            final hostName =
                server.serverData?['name'] as String? ??
                server.serverData?['hostName'] as String?;
            if (hostName != null && hostName.isNotEmpty) {
              bestHostName = hostName;
            }
          }
        }
      }

      // 3. 如果依然没有找到名字，尝试通过 A2S 直接查询（因为官方 API 通常不提供主机名）
      if (bestHostName == null) {
        try {
          final parts = address.split(':');
          if (parts.length == 2) {
            final ip = parts[0];
            final port = int.tryParse(parts[1]);
            if (port != null) {
              final info = await SourceServerService.getServerInfo(
                ip,
                port,
                timeout: 2000,
              );
              if (info != null && info.name.isNotEmpty) {
                bestHostName = info.name;
              }
            }
          }
        } catch (e) {
          // A2S 查询失败忽略
        }
      }

      // 4. 返回最佳匹配结果（官方名/缓存名/A2S查询名），都没有则降级为地址
      return bestHostName ?? address;
    } catch (e) {
      // 解析失败不影响主流程
    }

    return null;
  }
}
