import 'package:hive_flutter/hive_flutter.dart';
import 'app_directory_service.dart';
import 'log_service.dart';

/// 通用存储工具类
///
/// 基于 Hive 的轻量级 NoSQL 数据库，替代 SharedPreferences
///
/// 特点：
/// - 自定义存储位置（我的文档/BakaBox/storage/）
/// - 高性能（比 SharedPreferences 快很多）
/// - 类型安全
/// - 支持复杂对象存储
/// - 懒加载（按需打开 Box）
///
/// 使用示例：
/// ```dart
/// // 初始化（应用启动时调用一次）
/// await StorageUtils.init();
///
/// // 存储数据
/// await StorageUtils.setString('game_path', '/path/to/game');
/// await StorageUtils.setInt('user_id', 123);
/// await StorageUtils.setBool('dark_mode', true);
/// await StorageUtils.setStringList('tags', ['tag1', 'tag2']);
///
/// // 读取数据
/// final gamePath = StorageUtils.getString('game_path');
/// final userId = StorageUtils.getInt('user_id');
/// final isDark = StorageUtils.getBool('dark_mode', defaultValue: false);
/// final tags = StorageUtils.getStringList('tags');
///
/// // 删除数据
/// await StorageUtils.remove('game_path');
///
/// // 清空所有数据
/// await StorageUtils.clear();
/// ```
class StorageUtils {
  StorageUtils._();

  static const String _defaultBoxName = 'app_storage';
  static bool _initialized = false;

  /// 初始化 Hive
  ///
  /// 必须在使用前调用，建议在 AppInitializer 中初始化
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // 设置存储路径到用户文档目录
      await Hive.initFlutter('${AppDirectoryService.basePath}/storage');

      // 打开默认 Box
      await Hive.openBox(_defaultBoxName);

      _initialized = true;
      LogService.d(
        '[StorageUtils] Hive 初始化成功，路径: ${AppDirectoryService.basePath}/storage',
      );
    } catch (e) {
      LogService.e('[StorageUtils] Hive 初始化失败', e);
      rethrow;
    }
  }

  /// 获取默认 Box
  static Box _getBox() {
    _checkInitialized();
    return Hive.box(_defaultBoxName);
  }

  // ========== 基础类型存储 ==========

  /// 存储字符串
  static Future<void> setString(String key, String value) async {
    await _getBox().put(key, value);
  }

  /// 获取字符串
  static String? getString(String key, {String? defaultValue}) {
    return _getBox().get(key, defaultValue: defaultValue) as String?;
  }

  /// 存储整数
  static Future<void> setInt(String key, int value) async {
    await _getBox().put(key, value);
  }

  /// 获取整数
  static int? getInt(String key, {int? defaultValue}) {
    return _getBox().get(key, defaultValue: defaultValue) as int?;
  }

  /// 存储布尔值
  static Future<void> setBool(String key, bool value) async {
    await _getBox().put(key, value);
  }

  /// 获取布尔值
  static bool getBool(String key, {bool defaultValue = false}) {
    return _getBox().get(key, defaultValue: defaultValue) as bool;
  }

  /// 存储浮点数
  static Future<void> setDouble(String key, double value) async {
    await _getBox().put(key, value);
  }

  /// 获取浮点数
  static double? getDouble(String key, {double? defaultValue}) {
    return _getBox().get(key, defaultValue: defaultValue) as double?;
  }

  /// 存储字符串列表
  static Future<void> setStringList(String key, List<String> value) async {
    await _getBox().put(key, value);
  }

  /// 获取字符串列表
  static List<String> getStringList(String key, {List<String>? defaultValue}) {
    final value = _getBox().get(key, defaultValue: defaultValue);
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return defaultValue ?? [];
  }

  /// 存储 Map
  static Future<void> setMap(String key, Map<String, dynamic> value) async {
    await _getBox().put(key, value);
  }

  /// 获取 Map
  static Map<String, dynamic>? getMap(
    String key, {
    Map<String, dynamic>? defaultValue,
  }) {
    final value = _getBox().get(key, defaultValue: defaultValue);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return defaultValue;
  }

  // ========== 通用操作 ==========

  /// 删除指定键
  static Future<void> remove(String key) async {
    await _getBox().delete(key);
  }

  /// 检查键是否存在
  static bool containsKey(String key) {
    return _getBox().containsKey(key);
  }

  /// 获取所有键
  static Iterable<String> getKeys() {
    return _getBox().keys.cast<String>();
  }

  /// 清空所有数据
  static Future<void> clear() async {
    await _getBox().clear();
    LogService.d('[StorageUtils] 所有存储数据已清空');
  }

  /// 获取存储项数量
  static int get length => _getBox().length;

  /// 获取所有数据（调试用）
  static Map<String, dynamic> getAll() {
    return Map<String, dynamic>.from(_getBox().toMap());
  }

  // ========== 高级功能 ==========

  /// 打开自定义 Box
  ///
  /// 用于隔离不同模块的数据
  ///
  /// 示例：
  /// ```dart
  /// final userBox = await StorageUtils.openBox('user_data');
  /// await userBox.put('username', 'Alice');
  /// ```
  static Future<Box> openBox(String boxName) async {
    _checkInitialized();
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return await Hive.openBox(boxName);
  }

  /// 关闭自定义 Box
  static Future<void> closeBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
    }
  }

  /// 删除自定义 Box（包括数据文件）
  static Future<void> deleteBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
    }
    await Hive.deleteBoxFromDisk(boxName);
  }

  /// 压缩数据库（释放空间）
  static Future<void> compact() async {
    await _getBox().compact();
    LogService.d('[StorageUtils] 数据库已压缩');
  }

  /// 获取存储大小（字节）
  static Future<int> getStorageSize() async {
    try {
      // Hive 没有直接获取大小的 API，需要通过文件系统
      // 这里返回估算值
      return _getBox().length * 100; // 粗略估算
    } catch (e) {
      LogService.e('[StorageUtils] 获取存储大小失败', e);
      return 0;
    }
  }

  // ========== 内部方法 ==========

  static void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'StorageUtils not initialized. Call StorageUtils.init() first.',
      );
    }
  }

  /// 关闭所有 Box（应用退出时调用）
  static Future<void> dispose() async {
    await Hive.close();
    _initialized = false;
    LogService.d('[StorageUtils] Hive 已关闭');
  }
}
