import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';

/// 音频服务 - 管理应用音效播放
/// 
/// 提供以下功能：
/// - 挤服成功音效播放
/// - 音量控制
/// - 音量持久化存储
/// 
/// 注意：
/// - 此服务仅在桌面端有效，移动端调用会直接返回
/// - AudioPlayer 延迟初始化，首次播放时才创建，节省内存
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static const String _keyAudioVolume = 'audio_volume';
  
  AudioPlayer? _audioPlayer;
  double _volume = 0.8; // 默认音量 80%
  bool _isVolumeLoaded = false; // 音量配置是否已加载

  /// 当前音量 (0.0 - 1.0)
  double get volume => _volume;

  /// 加载音量配置（不创建 AudioPlayer，节省内存）
  Future<void> initialize() async {
    if (_isVolumeLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_keyAudioVolume) ?? 0.8;
      _isVolumeLoaded = true;
      LogService.d('音量配置已加载: ${(_volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('加载音量配置失败', e);
    }
  }
  
  /// 确保 AudioPlayer 已创建（首次播放时调用）
  Future<void> _ensurePlayerCreated() async {
    if (_audioPlayer != null) return;
    if (!PlatformUtils.isDesktopPlatform) return;
    
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      LogService.i('AudioPlayer 已创建');
    } catch (e) {
      LogService.e('创建 AudioPlayer 失败', e);
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyAudioVolume, _volume);
      LogService.d('音量已设置: ${(_volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('保存音量设置失败', e);
    }
  }

  /// 播放挤服成功音效
  Future<bool> playQueueSuccessSound() async {
    if (_volume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;
    
    // 延迟创建 AudioPlayer，首次播放时才初始化
    await _ensurePlayerCreated();
    if (_audioPlayer == null) return false;
    
    try {
      await _audioPlayer!.setVolume(_volume);
      await _audioPlayer!.play(AssetSource('audio/queue_success.mp3'));
      LogService.d('播放挤服成功音效');
      return true;
    } catch (e) {
      LogService.e('播放音效失败', e);
      return false;
    }
  }

  /// 测试音效播放
  Future<bool> testSound() async {
    return await playQueueSuccessSound();
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      LogService.e('停止音效失败', e);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      _isVolumeLoaded = false;
      LogService.i('音频服务已释放');
    } catch (e) {
      LogService.e('释放音频服务失败', e);
    }
  }
}
