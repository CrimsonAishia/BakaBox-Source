import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/map_subscription/map_subscription_bloc.dart';
import '../../../../core/models/map_subscription_models.dart';
import '../../../../core/models/server_models.dart';
import '../../../../core/services/custom_server_service.dart';
import '../../../../core/services/server_category_service.dart';
import '../../../../core/services/source_server_service.dart';
import '../../../../core/utils/storage_utils.dart';
import '../../../../core/constants/app_colors.dart';

/// 监控范围设置弹窗
///
/// 左右分栏布局：
/// - 左侧：分类列表
/// - 右侧：选中分类的服务器列表
class SubscriptionScopeDialog extends StatefulWidget {
  /// 地图订阅数据
  final MapSubscription subscription;

  const SubscriptionScopeDialog({super.key, required this.subscription});

  /// 显示弹窗
  static Future<void> show(
    BuildContext context, {
    required MapSubscription subscription,
  }) async {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<MapSubscriptionBloc>(),
        child: SubscriptionScopeDialog(subscription: subscription),
      ),
    );
  }

  @override
  State<SubscriptionScopeDialog> createState() =>
      _SubscriptionScopeDialogState();
}

class _SubscriptionScopeDialogState extends State<SubscriptionScopeDialog> {
  /// 所有分类数据（原始）
  List<ServerCategory> _allCategories = [];

  /// 服务器真实名称缓存（地址 -> 名称），通过 A2S 查询获取
  final Map<String, String> _serverRealNames = {};

  /// 正在查询的服务器地址集合
  final Set<String> _queryingServers = {};

  /// 是否正在加载
  bool _isLoading = true;

  /// 继承全局设置
  late bool _inheritGlobal;

  /// 已选择的服务器地址
  late Set<String> _selectedServers;

  /// 当前选中的分类（用于右侧面板显示）
  String? _activeCategory;

  /// 服务器搜索过滤
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  /// 根据服务器选择状态计算已选分类
  Set<String> get _selectedCategories {
    final result = <String>{};
    for (final category in _allCategories) {
      final categoryName = category.modelName ?? category.category ?? '';
      if (categoryName.isEmpty) continue;

      for (final server in category.serverList) {
        final addr = server.address ?? server.serverAddress ?? '';
        if (addr.isNotEmpty && _selectedServers.contains(addr)) {
          result.add(categoryName);
          break;
        }
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _inheritGlobal = widget.subscription.isAllCategories;
    _selectedServers = Set.from(widget.subscription.serverAddresses);
    _activeCategory = null;

    // 先加载本地缓存的 A2S 服务器名称，避免每次打开弹窗都重新查
    _loadCachedRealNames();

    // 加载数据
    _loadData();
  }

  Future<void> _loadCachedRealNames() async {
    final cachedData = StorageUtils.getString('a2s_server_names_cache');
    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedData);
        final now = DateTime.now().millisecondsSinceEpoch;
        final validNames = <String, String>{};
        bool needClean = false;

        for (final entry in decoded.entries) {
          final data = entry.value as Map<String, dynamic>;
          final name = data['name'] as String?;
          final time = data['time'] as int?;

          if (name != null && time != null) {
            // 缓存 4 小时 (4 * 60 * 60 * 1000 = 14400000)
            if (now - time < 14400000) {
              validNames[entry.key] = name;
            } else {
              needClean = true; // 有过期的，准备清理
            }
          }
        }
        _serverRealNames.addAll(validNames);
        if (needClean) {
          _saveCachedRealNames(); // 异步清理过期缓存
        }
      } catch (_) {
        // 如果遇到了旧版本（只有名字）的存储结构，直接丢弃，让其重新缓存即可
      }
    }
  }

  Future<void> _saveCachedRealNames() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dataToSave = <String, dynamic>{};
      _serverRealNames.forEach((key, value) {
        dataToSave[key] = {'name': value, 'time': now};
      });
      final encoded = jsonEncode(dataToSave);
      await StorageUtils.setString('a2s_server_names_cache', encoded);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      // 获取自定义分类
      final customCategories = await CustomServerService.loadCustomCategories();
      // 获取 API 分类
      final apiCategories = await ServerCategoryService.instance
          .getApiCategories();
      // 合并所有分类（自定义分类在前）
      _allCategories = [...customCategories, ...apiCategories];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // 在数据加载完成且 UI 更新后再异步查询服务器名称
        _queryServerNames();
      }
    } catch (e) {
      // 忽略错误，使用空列表
      _allCategories = [];
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 异步查询服务器真实名称（仅限没有备注名的服务器）
  Future<void> _queryServerNames() async {
    for (final category in _allCategories) {
      for (final server in category.serverList) {
        final address = server.address ?? server.serverAddress ?? '';
        if (address.isEmpty) continue;

        // 有备注名的服务器不进行查询
        if (server.nickname != null && server.nickname!.isNotEmpty) {
          continue;
        }

        // 避免重复查询或者已经有缓存的真实名称
        if (_serverRealNames.containsKey(address) ||
            _queryingServers.contains(address)) {
          continue;
        }

        _queryingServers.add(address);

        // 异步查询（所有没有备注名的服务器都查询，包括非自定义服务器）
        _fetchServerName(address);
      }
    }
  }

  Future<void> _fetchServerName(String address) async {
    try {
      final parts = address.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      final info = await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: 3000,
      );
      if (info != null && info.name.isNotEmpty && mounted) {
        setState(() {
          _serverRealNames[address] = info.name;
          _queryingServers.remove(address);
        });

        // 更新缓存（异步写入）
        _saveCachedRealNames();
      }
    } catch (e) {
      // 查询失败，忽略
    }

    if (mounted) {
      setState(() {
        _queryingServers.remove(address);
      });
    }
  }

  /// 获取服务器的显示名称
  String _getServerDisplayName(ServerItem server) {
    final address = server.address ?? server.serverAddress ?? '';

    // 有备注名直接返回
    if (server.nickname != null && server.nickname!.isNotEmpty) {
      return server.nickname!;
    }

    String? hostName;

    // 优先从缓存的 A2S 查询结果中获取名称（适用于所有服务器）
    if (_serverRealNames.containsKey(address)) {
      hostName = _serverRealNames[address];
    }

    // 非自定义服务器尝试从 serverData 中获取映射名称
    if (hostName == null && !server.isCustom) {
      try {
        if (server.serverData != null) {
          hostName = ServerInfo.fromJson(server.serverData!).hostName;
        }
      } catch (_) {}
    }

    return hostName ?? address;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _queryingServers.clear();
    super.dispose();
  }

  /// 获取全局分类设置
  List<String> get _globalCategories {
    return context.read<MapSubscriptionBloc>().state.globalCategories;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 520,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : Row(
                      children: [
                        // 左侧：分类列表
                        Expanded(flex: 3, child: _buildCategoryPanel()),
                        // 分隔线
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.gray200,
                        ),
                        // 右侧：服务器列表
                        Expanded(flex: 4, child: _buildServerPanel()),
                      ],
                    ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColors.indigo500,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            '正在加载数据...',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.indigo500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.indigo500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '监控范围设置',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subscription.mapLabel.isNotEmpty
                      ? widget.subscription.mapLabel
                      : widget.subscription.mapName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? Colors.white38 : AppColors.gray400,
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPanel() {
    final isAllGlobal = _globalCategories.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
                const SizedBox(width: 6),
                Text(
                  '分类',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : AppColors.gray700,
                  ),
                ),
                const Spacer(),
                if (_inheritGlobal)
                  _buildStatusBadge('继承全局', AppColors.indigo500)
                else if (_selectedCategories.isEmpty)
                  _buildStatusBadge('未选', AppColors.gray400)
                else
                  Text(
                    '${_selectedCategories.length} 个',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : AppColors.gray400,
                    ),
                  ),
              ],
            ),
          ),
          // 继承全局选项
          _buildInheritGlobalTile(isAllGlobal),
          const Divider(height: 1),
          // 分类列表
          Expanded(
            child: _allCategories.isEmpty
                ? Center(
                    child: Text(
                      '暂无可用分类',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white38
                            : AppColors.gray400,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _allCategories.length,
                    itemBuilder: (context, index) {
                      final category = _allCategories[index];
                      final categoryName =
                          category.modelName ?? category.category ?? '';
                      return _buildCategoryTile(
                        categoryName,
                        category.isCustom,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInheritGlobalTile(bool isAllGlobal) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _inheritGlobal = !_inheritGlobal;
            if (_inheritGlobal) {
              _selectedServers.clear();
              _activeCategory = null;
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _inheritGlobal
                ? AppColors.indigo500.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _inheritGlobal
                  ? AppColors.indigo500.withValues(alpha: 0.3)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.gray200),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _inheritGlobal
                      ? AppColors.indigo500
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _inheritGlobal
                        ? AppColors.indigo500
                        : (isDark ? Colors.white38 : AppColors.gray300),
                    width: 1.5,
                  ),
                ),
                child: _inheritGlobal
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继承全局设置',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _inheritGlobal
                            ? AppColors.indigo500
                            : (isDark ? Colors.white : AppColors.gray800),
                      ),
                    ),
                    Text(
                      isAllGlobal
                          ? '监控全部分类'
                          : '${_globalCategories.length} 个分类',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white38
                            : AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(String categoryName, bool isCustom) {
    final isSelected = _selectedCategories.contains(categoryName);
    final isActive = _activeCategory == categoryName;
    final serverCount = _getCategoryServerCount(categoryName);

    // 计算该分类的服务器选择状态（基于右侧已选服务器）
    final servers = _getServersForCategory(categoryName);
    final selectedServerCount = servers.where((s) {
      final addr = s.address ?? s.serverAddress ?? '';
      return addr.isNotEmpty && _selectedServers.contains(addr);
    }).length;

    // 复选框状态：由右侧服务器选择状态决定
    final bool isAllSelected =
        selectedServerCount == servers.length && servers.isNotEmpty;
    final bool isPartialSelected =
        selectedServerCount > 0 && selectedServerCount < servers.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_inheritGlobal) {
              _inheritGlobal = false;
            }
            // 点击分类只是激活（打开右侧面板查看服务器），不改变勾选状态
            _activeCategory = categoryName;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.indigo500.withValues(alpha: 0.15)
                : (isSelected
                      ? AppColors.indigo500.withValues(alpha: 0.08)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.indigo500.withValues(alpha: 0.4)
                  : (isSelected
                        ? AppColors.indigo500.withValues(alpha: 0.2)
                        : Colors.transparent),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: (isSelected || isPartialSelected)
                      ? AppColors.indigo500
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (isSelected || isPartialSelected)
                        ? AppColors.indigo500
                        : (isDark ? Colors.white38 : AppColors.gray300),
                    width: 1.5,
                  ),
                ),
                child: isAllSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : (isPartialSelected
                          ? const Icon(
                              Icons.remove_rounded,
                              size: 12,
                              color: Colors.white,
                            )
                          : null),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.indigo500
                              : (isDark
                                    ? Colors.white
                                    : AppColors.gray800),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '自',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: AppColors.amber500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.gray100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$serverCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : AppColors.gray500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCategoryServerCount(String categoryName) {
    for (final category in _allCategories) {
      final name = category.modelName ?? category.category ?? '';
      if (name == categoryName) {
        return category.serverList.length;
      }
    }
    return 0;
  }

  List<ServerItem> _getServersForCategory(String categoryName) {
    for (final category in _allCategories) {
      final name = category.modelName ?? category.category ?? '';
      if (name == categoryName) {
        return category.serverList;
      }
    }
    return [];
  }

  Widget _buildServerPanel() {
    // 如果继承全局，不显示服务器选择区域
    if (_inheritGlobal) {
      return _buildServerPanelInheritGlobal();
    }

    if (_activeCategory == null && _selectedCategories.isEmpty) {
      return _buildServerPanelEmpty();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.dns_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : AppColors.gray500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _activeCategory ?? '已选分类 (${_selectedCategories.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppColors.gray700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_selectedServers.length} 已选',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.indigo500,
                  ),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
              decoration: InputDecoration(
                hintText: '搜索服务器...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : AppColors.gray400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : AppColors.gray400,
                ),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: isDark
                              ? Colors.white38
                              : AppColors.gray400,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = '');
                        },
                        splashRadius: 12,
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.gray200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.indigo500,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          // 全选/清空按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildTextButton(
                  label: '全选',
                  color: AppColors.indigo500,
                  onTap: () {
                    setState(() {
                      for (final server in _getServersToShow()) {
                        final address =
                            server.address ?? server.serverAddress ?? '';
                        if (address.isNotEmpty) {
                          _selectedServers.add(address);
                        }
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildTextButton(
                  label: '清空',
                  color: isDark ? Colors.white54 : AppColors.gray500,
                  onTap: () {
                    setState(() {
                      for (final server in _getServersToShow()) {
                        final address =
                            server.address ?? server.serverAddress ?? '';
                        _selectedServers.remove(address);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 服务器列表
          Expanded(child: _buildServerList()),
        ],
      ),
    );
  }

  Widget _buildServerPanelInheritGlobal() {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.indigo500.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_rounded,
                size: 32,
                color: AppColors.indigo500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '继承全局设置',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.gray800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '将使用全局分类和服务器设置进行监控',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerPanelEmpty() {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 40,
              color: isDark ? Colors.white24 : AppColors.gray300,
            ),
            const SizedBox(height: 12),
            Text(
              '选择左侧分类',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : AppColors.gray400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击分类查看其服务器',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white24 : AppColors.gray300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  List<ServerItem> _getServersToShow() {
    if (_activeCategory != null) {
      return _getServersForCategory(_activeCategory!);
    } else if (_selectedCategories.isNotEmpty) {
      final result = <ServerItem>[];
      for (final categoryName in _selectedCategories) {
        result.addAll(_getServersForCategory(categoryName));
      }
      return result;
    }
    return [];
  }

  Widget _buildServerList() {
    final servers = _getServersToShow();

    final filteredServers = servers.where((server) {
      if (_searchText.isEmpty) return true;

      final address = server.address ?? server.serverAddress ?? '';
      final displayName = _getServerDisplayName(server);

      return displayName.toLowerCase().contains(_searchText) ||
          address.toLowerCase().contains(_searchText);
    }).toList();

    if (filteredServers.isEmpty) {
      return Center(
        child: Text(
          _searchText.isNotEmpty ? '未找到匹配的服务器' : '该分类暂无服务器',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : AppColors.gray400,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: filteredServers.length,
      itemBuilder: (context, index) {
        final server = filteredServers[index];
        final address = server.address ?? server.serverAddress ?? '';
        final displayName = _getServerDisplayName(server);
        final isSelected = _selectedServers.contains(address);
        // 如果没有备注名且正在查询中，显示加载状态
        final isQuerying =
            (server.nickname == null || server.nickname!.isEmpty) &&
            _queryingServers.contains(address);

        return _buildServerTile(address, displayName, isSelected, isQuerying);
      },
    );
  }

  Widget _buildServerTile(
    String address,
    String displayName,
    bool isSelected,
    bool isQuerying,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedServers.remove(address);
            } else {
              _selectedServers.add(address);
            }
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.indigo500.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.indigo500
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.indigo500
                        : (isDark ? Colors.white38 : AppColors.gray300),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isQuerying ? '加载中...' : displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isQuerying
                                  ? (isDark
                                        ? Colors.white38
                                        : AppColors.gray400)
                                  : (isSelected
                                        ? AppColors.indigo500
                                        : (isDark
                                              ? Colors.white
                                              : AppColors.gray800)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isQuerying) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: isDark
                                  ? Colors.white38
                                  : AppColors.gray400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white38
                            : AppColors.gray400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.gray200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              // 清理正在查询的服务器集合，避免内存泄漏
              _queryingServers.clear();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? Colors.white54
                  : AppColors.gray500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigo500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    final bloc = context.read<MapSubscriptionBloc>();

    // 计算最终的分类列表（根据服务器选择状态自动计算）
    List<String> categoryNames;
    List<String> serverAddresses;

    if (_inheritGlobal) {
      // 继承全局：空列表表示继承全局
      categoryNames = [];
      serverAddresses = [];
    } else {
      // 根据右侧服务器选择状态，自动计算哪些分类被选中了
      final selectedCategorySet = <String>{};
      for (final category in _allCategories) {
        final categoryName = category.modelName ?? category.category ?? '';
        if (categoryName.isEmpty) continue;

        // 检查该分类下是否有服务器被选中
        for (final server in category.serverList) {
          final addr = server.address ?? server.serverAddress ?? '';
          if (addr.isNotEmpty && _selectedServers.contains(addr)) {
            selectedCategorySet.add(categoryName);
            break;
          }
        }
      }
      categoryNames = selectedCategorySet.toList();
      serverAddresses = _selectedServers.toList();
    }

    // 更新分类范围
    bloc.add(
      MapSubscriptionUpdateSubscriptionScope(
        mapName: widget.subscription.mapName,
        categoryNames: categoryNames,
      ),
    );

    // 更新服务器范围
    bloc.add(
      MapSubscriptionUpdateSubscriptionServers(
        mapName: widget.subscription.mapName,
        serverAddresses: serverAddresses,
      ),
    );

    Navigator.of(context).pop();
  }
}
