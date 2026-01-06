import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_models.dart';
import '../utils/log_service.dart';

/// 自定义服务器管理服务
/// 负责保存和加载用户自定义的分类和服务器
class CustomServerService {
  static const String _customCategoriesKey = 'custom_server_categories';
  
  /// 保存自定义分类列表
  static Future<void> saveCustomCategories(List<ServerCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = categories.map((c) => c.toJson()).toList();
      await prefs.setString(_customCategoriesKey, jsonEncode(jsonList));
      LogService.d('保存自定义分类成功，共 ${categories.length} 个');
    } catch (e) {
      LogService.e('保存自定义分类失败: $e', e);
    }
  }
  
  /// 加载自定义分类列表
  static Future<List<ServerCategory>> loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_customCategoriesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final jsonList = jsonDecode(jsonString) as List;
      final categories = jsonList
          .map((json) => ServerCategory.fromJson(json as Map<String, dynamic>))
          .toList();
      
      LogService.d('加载自定义分类成功，共 ${categories.length} 个');
      return categories;
    } catch (e) {
      LogService.e('加载自定义分类失败: $e', e);
      return [];
    }
  }
  
  /// 添加自定义分类
  static Future<ServerCategory> addCustomCategory(String categoryName) async {
    final categories = await loadCustomCategories();
    
    // 检查是否已存在
    if (categories.any((c) => c.modelName == categoryName)) {
      throw Exception('分类 "$categoryName" 已存在');
    }
    
    final newCategory = ServerCategory(
      modelName: categoryName,
      category: categoryName,
      serverList: [],
      isCustom: true,
    );
    
    categories.add(newCategory);
    await saveCustomCategories(categories);
    
    LogService.i('添加自定义分类: $categoryName');
    return newCategory;
  }
  
  /// 删除自定义分类
  static Future<void> deleteCustomCategory(String categoryName) async {
    final categories = await loadCustomCategories();
    categories.removeWhere((c) => c.modelName == categoryName);
    await saveCustomCategories(categories);
    LogService.i('删除自定义分类: $categoryName');
  }
  
  /// 添加服务器到指定分类
  static Future<ServerCategory> addServerToCategory(
    String categoryName,
    String serverAddress,
  ) async {
    final categories = await loadCustomCategories();
    
    final categoryIndex = categories.indexWhere((c) => c.modelName == categoryName);
    if (categoryIndex == -1) {
      throw Exception('分类 "$categoryName" 不存在');
    }
    
    final category = categories[categoryIndex];
    
    // 检查服务器是否已存在
    if (category.serverList.any((s) => 
        (s.address ?? s.serverAddress) == serverAddress)) {
      throw Exception('服务器已存在于该分类中');
    }
    
    final newServer = ServerItem(
      address: serverAddress,
      serverAddress: serverAddress,
      isCustom: true,
    );
    
    final updatedCategory = category.copyWith(
      serverList: [...category.serverList, newServer],
    );
    
    categories[categoryIndex] = updatedCategory;
    await saveCustomCategories(categories);
    
    LogService.i('添加服务器 $serverAddress 到分类 $categoryName');
    return updatedCategory;
  }
  
  /// 从分类中删除服务器
  static Future<ServerCategory> deleteServerFromCategory(
    String categoryName,
    String serverAddress,
  ) async {
    final categories = await loadCustomCategories();
    
    final categoryIndex = categories.indexWhere((c) => c.modelName == categoryName);
    if (categoryIndex == -1) {
      throw Exception('分类 "$categoryName" 不存在');
    }
    
    final category = categories[categoryIndex];
    final updatedServerList = category.serverList
        .where((s) => (s.address ?? s.serverAddress) != serverAddress)
        .toList();
    
    final updatedCategory = category.copyWith(serverList: updatedServerList);
    categories[categoryIndex] = updatedCategory;
    await saveCustomCategories(categories);
    
    LogService.i('从分类 $categoryName 删除服务器 $serverAddress');
    return updatedCategory;
  }
  
  /// 清除所有自定义数据
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customCategoriesKey);
    LogService.i('清除所有自定义分类和服务器');
  }
}
