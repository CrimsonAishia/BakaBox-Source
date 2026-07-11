import 'dart:async';
import 'dart:convert';
import '../models/server_models.dart';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 自定义服务器管理服务
/// 负责保存和加载用户自定义的分类和服务器
class CustomServerService {
  static const String _customCategoriesKey = 'custom_server_categories';

  static Future<dynamic> _lock = Future.value();

  static Future<T> _synchronized<T>(Future<T> Function() action) async {
    final previousLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    try {
      await previousLock;
    } catch (_) {}

    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// 保存自定义分类列表
  static Future<void> saveCustomCategories(
    List<ServerCategory> categories,
  ) async {
    try {
      final jsonList = categories.map((c) => c.toJson()).toList();
      await StorageUtils.setString(_customCategoriesKey, jsonEncode(jsonList));
      LogService.d('保存自定义分类成功，共 ${categories.length} 个');
    } catch (e) {
      LogService.e('保存自定义分类失败: $e', e);
    }
  }

  /// 加载自定义分类列表
  static Future<List<ServerCategory>> loadCustomCategories() async {
    try {
      final jsonString = StorageUtils.getString(_customCategoriesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      final categories = jsonList
          .map((json) => ServerCategory.fromJson(json as Map<String, dynamic>))
          .toList();

      // 按照 sortOrder 排序（如果有的话）
      categories.sort((a, b) {
        final orderA = a.sortOrder ?? 0;
        final orderB = b.sortOrder ?? 0;
        return orderA.compareTo(orderB);
      });

      LogService.d('加载自定义分类成功，共 ${categories.length} 个');
      return categories;
    } catch (e) {
      LogService.e('加载自定义分类失败: $e', e);
      return [];
    }
  }

  /// 内部方法：不加锁的添加分类逻辑
  static Future<ServerCategory> _addCustomCategoryInternal(
    String categoryName, {
    bool isFromApi = false,
    String? sourceApiUrl,
    String? sourceApiCategoryName,
  }) async {
    final categories = await loadCustomCategories();

    // 检查是否已存在
    if (categories.any((c) => c.modelName == categoryName)) {
      throw Exception('分类 "$categoryName" 已存在');
    }

    // 设置 sortOrder 为当前列表末尾
    final newSortOrder = categories.isEmpty ? 0 : categories.length;

    final newCategory = ServerCategory(
      modelName: categoryName,
      category: categoryName,
      serverList: [],
      isCustom: true,
      sortOrder: newSortOrder,
      isFromApi: isFromApi,
      sourceApiUrl: sourceApiUrl,
      sourceApiCategoryName: sourceApiCategoryName,
    );

    categories.add(newCategory);
    await saveCustomCategories(categories);

    LogService.i('添加自定义分类: $categoryName');
    return newCategory;
  }

  /// 添加自定义分类
  static Future<ServerCategory> addCustomCategory(
    String categoryName, {
    bool isFromApi = false,
    String? sourceApiUrl,
    String? sourceApiCategoryName,
  }) {
    return _synchronized(
      () => _addCustomCategoryInternal(
        categoryName,
        isFromApi: isFromApi,
        sourceApiUrl: sourceApiUrl,
        sourceApiCategoryName: sourceApiCategoryName,
      ),
    );
  }

  /// 删除自定义分类
  static Future<void> deleteCustomCategory(String categoryName) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();
      categories.removeWhere((c) => c.modelName == categoryName);
      await saveCustomCategories(categories);
      LogService.i('删除自定义分类: $categoryName');
    });
  }

  /// 重命名自定义分类
  static Future<ServerCategory> renameCustomCategory(
    String oldName,
    String newName,
  ) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();

      final categoryIndex = categories.indexWhere(
        (c) => c.modelName == oldName,
      );
      if (categoryIndex == -1) {
        throw Exception('分类 "$oldName" 不存在');
      }

      // 检查新名称是否已存在
      if (oldName != newName && categories.any((c) => c.modelName == newName)) {
        throw Exception('分类 "$newName" 已存在');
      }

      final category = categories[categoryIndex];
      final updatedCategory = category.copyWith(
        modelName: newName,
        category: newName,
      );

      categories[categoryIndex] = updatedCategory;
      await saveCustomCategories(categories);

      LogService.i('重命名自定义分类: $oldName -> $newName');
      return updatedCategory;
    });
  }

  /// 添加服务器到指定分类
  static Future<ServerCategory> addServerToCategory(
    String categoryName,
    String serverAddress, {
    String? nickname,
  }) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();

      final categoryIndex = categories.indexWhere(
        (c) => c.modelName == categoryName,
      );
      if (categoryIndex == -1) {
        throw Exception('分类 "$categoryName" 不存在');
      }

      final category = categories[categoryIndex];

      // 检查服务器是否已存在
      if (category.serverList.any(
        (s) => (s.address ?? s.serverAddress) == serverAddress,
      )) {
        throw Exception('服务器已存在于该分类中');
      }

      final newServer = ServerItem(
        address: serverAddress,
        serverAddress: serverAddress,
        isCustom: true,
        nickname: nickname,
      );

      final updatedCategory = category.copyWith(
        serverList: [...category.serverList, newServer],
      );

      categories[categoryIndex] = updatedCategory;
      await saveCustomCategories(categories);

      LogService.i(
        '添加服务器 $serverAddress 到分类 $categoryName${nickname != null ? " (备注: $nickname)" : ""}',
      );
      return updatedCategory;
    });
  }

  /// 内部方法：批量添加服务器对象
  static Future<ServerCategory> _addServerItemsToCategoryInternal(
    String categoryName,
    List<ServerItem> serverItems, {
    bool isFromApi = false,
    String? sourceApiUrl,
    String? sourceApiCategoryName,
  }) async {
    final categories = await loadCustomCategories();

    final categoryIndex = categories.indexWhere(
      (c) => c.modelName == categoryName,
    );
    // 自动创建分类
    if (categoryIndex == -1) {
      await _addCustomCategoryInternal(
        categoryName,
        isFromApi: isFromApi,
        sourceApiUrl: sourceApiUrl,
        sourceApiCategoryName: sourceApiCategoryName,
      );
      // 重新加载并更新分类列表，因为已经创建了新分类
      return _addServerItemsToCategoryInternal(
        categoryName,
        serverItems,
        isFromApi: isFromApi,
        sourceApiUrl: sourceApiUrl,
        sourceApiCategoryName: sourceApiCategoryName,
      );
    }

    final category = categories[categoryIndex];
    final updatedServerList = List<ServerItem>.from(category.serverList);
    int addedCount = 0;

    for (final serverItem in serverItems) {
      final serverAddress = serverItem.address ?? serverItem.serverAddress;
      if (!updatedServerList.any(
        (s) => (s.address ?? s.serverAddress) == serverAddress,
      )) {
        updatedServerList.add(serverItem);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      final updatedCategory = category.copyWith(serverList: updatedServerList);
      categories[categoryIndex] = updatedCategory;
      await saveCustomCategories(categories);
      LogService.i('添加 $addedCount 个服务器对象到分类 $categoryName');
      return updatedCategory;
    }

    return category;
  }

  /// 添加完整的服务器对象列表到指定分类
  static Future<ServerCategory> addServerItemsToCategory(
    String categoryName,
    List<ServerItem> serverItems, {
    bool isFromApi = false,
    String? sourceApiUrl,
    String? sourceApiCategoryName,
  }) {
    return _synchronized(
      () => _addServerItemsToCategoryInternal(
        categoryName,
        serverItems,
        isFromApi: isFromApi,
        sourceApiUrl: sourceApiUrl,
        sourceApiCategoryName: sourceApiCategoryName,
      ),
    );
  }

  /// 从分类中批量删除服务器
  static Future<ServerCategory> deleteServersFromCategory(
    String categoryName,
    List<String> serverAddresses,
  ) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();

      final categoryIndex = categories.indexWhere(
        (c) => c.modelName == categoryName,
      );
      if (categoryIndex == -1) {
        throw Exception('分类 "$categoryName" 不存在');
      }

      final category = categories[categoryIndex];
      final addressesSet = serverAddresses.toSet();
      final updatedServerList = category.serverList
          .where((s) => !addressesSet.contains(s.address ?? s.serverAddress))
          .toList();

      if (updatedServerList.length != category.serverList.length) {
        final updatedCategory = category.copyWith(
          serverList: updatedServerList,
        );
        categories[categoryIndex] = updatedCategory;
        await saveCustomCategories(categories);

        LogService.i(
          '从分类 $categoryName 批量删除 ${category.serverList.length - updatedServerList.length} 个服务器',
        );
        return updatedCategory;
      }

      return category;
    });
  }

  /// 从分类中删除服务器
  static Future<ServerCategory> deleteServerFromCategory(
    String categoryName,
    String serverAddress,
  ) async {
    return deleteServersFromCategory(categoryName, [serverAddress]);
  }

  /// 编辑分类中的服务器地址
  static Future<ServerCategory> editServerInCategory(
    String categoryName,
    String oldServerAddress,
    String newServerAddress, {
    String? nickname,
  }) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();

      final categoryIndex = categories.indexWhere(
        (c) => c.modelName == categoryName,
      );
      if (categoryIndex == -1) {
        throw Exception('分类 "$categoryName" 不存在');
      }

      final category = categories[categoryIndex];

      // 如果地址变了，检查新地址是否已存在
      if (oldServerAddress != newServerAddress &&
          category.serverList.any(
            (s) => (s.address ?? s.serverAddress) == newServerAddress,
          )) {
        throw Exception('服务器地址已存在');
      }

      // 查找并更新服务器
      final serverIndex = category.serverList.indexWhere(
        (s) => (s.address ?? s.serverAddress) == oldServerAddress,
      );
      if (serverIndex == -1) {
        throw Exception('服务器 "$oldServerAddress" 不存在');
      }

      final updatedServerList = List<ServerItem>.from(category.serverList);
      updatedServerList[serverIndex] = ServerItem(
        address: newServerAddress,
        serverAddress: newServerAddress,
        isCustom: true,
        nickname: nickname,
      );

      final updatedCategory = category.copyWith(serverList: updatedServerList);
      categories[categoryIndex] = updatedCategory;
      await saveCustomCategories(categories);

      LogService.i(
        '编辑服务器: $oldServerAddress -> $newServerAddress${nickname != null ? " (备注: $nickname)" : ""} (分类: $categoryName)',
      );
      return updatedCategory;
    });
  }

  /// 重新排序分类中的服务器
  static Future<ServerCategory> reorderServersInCategory(
    String categoryName,
    int oldIndex,
    int newIndex,
  ) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();

      final categoryIndex = categories.indexWhere(
        (c) => c.modelName == categoryName,
      );
      if (categoryIndex == -1) {
        throw Exception('分类 "$categoryName" 不存在');
      }

      final category = categories[categoryIndex];

      if (oldIndex < 0 ||
          oldIndex >= category.serverList.length ||
          newIndex < 0 ||
          newIndex >= category.serverList.length) {
        throw Exception('索引超出范围');
      }

      final updatedServerList = List<ServerItem>.from(category.serverList);
      final item = updatedServerList.removeAt(oldIndex);
      updatedServerList.insert(newIndex, item);

      final updatedCategory = category.copyWith(serverList: updatedServerList);
      categories[categoryIndex] = updatedCategory;
      await saveCustomCategories(categories);

      LogService.i('重新排序服务器: $oldIndex -> $newIndex (分类: $categoryName)');
      return updatedCategory;
    });
  }

  /// 重新排序自定义分类
  static Future<void> reorderCategories(List<String> categoryNames) {
    return _synchronized(() async {
      final categories = await loadCustomCategories();

      // 根据传入的顺序重新排序
      final sortedCategories = <ServerCategory>[];
      for (var i = 0; i < categoryNames.length; i++) {
        final categoryName = categoryNames[i];
        final categoryIndex = categories.indexWhere(
          (c) => c.modelName == categoryName,
        );
        if (categoryIndex != -1) {
          final category = categories[categoryIndex];
          sortedCategories.add(category.copyWith(sortOrder: i));
        }
      }

      await saveCustomCategories(sortedCategories);
      LogService.i('重新排序分类: $categoryNames');
    });
  }

  /// 清除所有自定义数据
  static Future<void> clearAll() {
    return _synchronized(() async {
      await StorageUtils.remove(_customCategoriesKey);
      LogService.i('清除所有自定义分类和服务器');
    });
  }
}
