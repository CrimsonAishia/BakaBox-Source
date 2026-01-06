import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_service.dart';

/// 音频服务 - 管理应用音效播放
/// 
/// 提供以下功能：
/// - 挤服成功音效播放
/// - 音量控制
/// - 音量持久化存储
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static const String _keyAudioVolume = 'audio_volume';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _volume = 0.8; // 默认音量 80%
  bool _isInitialized = false;

  /// 当前音量 (0.0 - 1.0)
  double get volume => _volume;

  /// 初始化音频服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_keyAudioVolume) ?? 0.8;
      
      // 设置音频播放器
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      _isInitialized = true;
      LogService.i('音频服务已初始化，音量: ${(_volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('初始化音频服务失败', e);
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
    if (_volume <= 0) {
      LogService.d('音量为0，跳过播放');
      return false;
    }
    
    try {
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play(AssetSource('audio/queue_success.mp3'));
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
      await _audioPlayer.stop();
    } catch (e) {
      LogService.e('停止音效失败', e);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
      LogService.i('音频服务已释放');
    } catch (e) {
      LogService.e('释放音频服务失败', e);
    }
  }
}
