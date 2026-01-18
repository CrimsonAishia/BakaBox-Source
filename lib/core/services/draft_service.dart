import 'dart:async';
import 'dart:convert';
import '../utils/log_service.dart';
import '../utils/storage_utils.dart';

/// 草稿自动保存服务
/// 
/// 提供草稿的自动保存和恢复功能
class DraftService {
  /// 自动保存间隔（30秒）
  static const Duration autoSaveInterval = Duration(seconds: 30);
  
  /// 草稿存储键前缀
  static const String _draftKeyPrefix = 'draft_';
  
  /// 草稿时间戳键前缀
  static const String _draftTimestampPrefix = 'draft_timestamp_';
  
  /// 草稿过期时间（7天）
  static const Duration draftExpiration = Duration(days: 7);
  
  /// 自动保存定时器
  Timer? _autoSaveTimer;
  
  /// 当前草稿内容
  String? _currentContent;
  
  /// 当前已上传图片URL列表
  List<String>? _currentImageUrls;

  /// 开始自动保存
  /// 
  /// 参数:
  /// - [draftId]: 草稿唯一标识（如 'issue_create', 'comment_123'）
  /// - [getContent]: 获取当前内容的回调
  /// - [getImageUrls]: 获取当前图片URL列表的回调
  void startAutoSave({
    required String draftId,
    required String Function() getContent,
    required List<String> Function() getImageUrls,
  }) {
    // 取消之前的定时器
    _autoSaveTimer?.cancel();
    
    // 创建新的定时器
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (timer) async {
      final content = getContent();
      final imageUrls = getImageUrls();
      
      // 检查内容是否有变化
      if (content != _currentContent || !_listEquals(imageUrls, _currentImageUrls)) {
        _currentContent = content;
        _currentImageUrls = imageUrls;
        
        // 保存草稿
        await saveDraft(
          draftId: draftId,
          content: content,
          imageUrls: imageUrls,
        );
      }
    });
    
    LogService.i('草稿自动保存已启动: $draftId');
  }

  /// 停止自动保存
  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _currentContent = null;
    _currentImageUrls = null;
    
    LogService.i('草稿自动保存已停止');
  }

  /// 保存草稿
  /// 
  /// 参数:
  /// - [draftId]: 草稿唯一标识
  /// - [content]: 草稿内容
  /// - [imageUrls]: 已上传图片URL列表
  Future<void> saveDraft({
    required String draftId,
    required String content,
    required List<String> imageUrls,
  }) async {
    try {
      // 保存草稿数据
      final draftData = {
        'content': content,
        'imageUrls': imageUrls,
      };
      
      await StorageUtils.setString(
        '$_draftKeyPrefix$draftId',
        json.encode(draftData),
      );
      
      // 保存时间戳
      await StorageUtils.setInt(
        '$_draftTimestampPrefix$draftId',
        DateTime.now().millisecondsSinceEpoch,
      );
      
      LogService.d('草稿已保存: $draftId');
    } catch (e) {
      LogService.e('保存草稿失败', e);
    }
  }

  /// 恢复草稿
  /// 
  /// 参数:
  /// - [draftId]: 草稿唯一标识
  /// 
  /// 返回:
  /// - [DraftData?]: 草稿数据，如果不存在或已过期则返回 null
  Future<DraftData?> restoreDraft(String draftId) async {
    try {
      // 检查草稿是否存在
      final draftJson = StorageUtils.getString('$_draftKeyPrefix$draftId');
      if (draftJson == null) {
        return null;
      }
      
      // 检查草稿是否过期
      final timestamp = StorageUtils.getInt('$_draftTimestampPrefix$draftId');
      if (timestamp != null) {
        final draftTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        
        if (now.difference(draftTime) > draftExpiration) {
          // 草稿已过期，删除
          await deleteDraft(draftId);
          LogService.i('草稿已过期并删除: $draftId');
          return null;
        }
      }
      
      // 解析草稿数据
      final draftData = json.decode(draftJson) as Map<String, dynamic>;
      
      LogService.i('草稿已恢复: $draftId');
      
      return DraftData(
        content: draftData['content'] as String? ?? '',
        imageUrls: (draftData['imageUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        timestamp: timestamp != null 
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : null,
      );
    } catch (e) {
      LogService.e('恢复草稿失败', e);
      return null;
    }
  }

  /// 删除草稿
  /// 
  /// 参数:
  /// - [draftId]: 草稿唯一标识
  Future<void> deleteDraft(String draftId) async {
    try {
      await StorageUtils.remove('$_draftKeyPrefix$draftId');
      await StorageUtils.remove('$_draftTimestampPrefix$draftId');
      
      LogService.d('草稿已删除: $draftId');
    } catch (e) {
      LogService.e('删除草稿失败', e);
    }
  }

  /// 检查是否有草稿
  /// 
  /// 参数:
  /// - [draftId]: 草稿唯一标识
  /// 
  /// 返回:
  /// - [bool]: 是否存在有效的草稿
  Future<bool> hasDraft(String draftId) async {
    try {
      final draftJson = StorageUtils.getString('$_draftKeyPrefix$draftId');
      if (draftJson == null) {
        return false;
      }
      
      // 检查是否过期
      final timestamp = StorageUtils.getInt('$_draftTimestampPrefix$draftId');
      if (timestamp != null) {
        final draftTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        
        if (now.difference(draftTime) > draftExpiration) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      LogService.e('检查草稿失败', e);
      return false;
    }
  }

  /// 清理所有过期草稿
  Future<void> cleanupExpiredDrafts() async {
    try {
      final keys = StorageUtils.getKeys();
      
      final draftKeys = keys.where((key) => key.startsWith(_draftKeyPrefix));
      
      for (final key in draftKeys) {
        final draftId = key.substring(_draftKeyPrefix.length);
        final timestamp = StorageUtils.getInt('$_draftTimestampPrefix$draftId');
        
        if (timestamp != null) {
          final draftTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          
          if (now.difference(draftTime) > draftExpiration) {
            await deleteDraft(draftId);
            LogService.i('已清理过期草稿: $draftId');
          }
        }
      }
    } catch (e) {
      LogService.e('清理过期草稿失败', e);
    }
  }

  /// 比较两个列表是否相等
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    
    return true;
  }

  /// 释放资源
  void dispose() {
    stopAutoSave();
  }
}

/// 草稿数据
class DraftData {
  /// 草稿内容
  final String content;
  
  /// 已上传图片URL列表
  final List<String> imageUrls;
  
  /// 保存时间戳
  final DateTime? timestamp;

  const DraftData({
    required this.content,
    required this.imageUrls,
    this.timestamp,
  });

  @override
  String toString() {
    return 'DraftData(content: ${content.length} chars, images: ${imageUrls.length}, timestamp: $timestamp)';
  }
}
