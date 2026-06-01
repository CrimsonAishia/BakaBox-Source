import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import '../utils/storage_utils.dart';

/// 音频服务 - 管理应用音效播放
///
/// 提供以下功能：
/// - 挤服成功音效播放
/// - 暖服倒计时循环音效（播放→间隔→播放→间隔，自动根据音频时长计算）
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
  static const String _keyWarmupAudioVolume = 'warmup_audio_volume';
  static const String _keyWarmupAudioInterval = 'warmup_audio_interval';

  AudioPlayer? _audioPlayer;
  AudioPlayer? _warmupPlayer; // 暖服专用播放器，避免与挤服音效冲突
  StreamSubscription<void>? _warmupCompleteSubscription;
  Timer? _warmupIntervalTimer;
  bool _isWarmupLooping = false;

  double _volume = 0.8; // 默认音量 80%
  double _warmupVolume = 0.8; // 暖服倒计时音量 80%
  double _warmupInterval = 2.0; // 暖服音效播放间隔（秒）
  bool _isVolumeLoaded = false; // 音量配置是否已加载

  /// 当前音量 (0.0 - 1.0)
  double get volume => _volume;

  /// 暖服当前音量 (0.0 - 1.0)
  double get warmupVolume => _warmupVolume;

  /// 暖服音效播放间隔（秒）
  double get warmupInterval => _warmupInterval;

  /// 加载音量配置（不创建 AudioPlayer，节省内存）
  Future<void> initialize() async {
    if (_isVolumeLoaded) return;

    try {
      _volume = StorageUtils.getDouble(_keyAudioVolume) ?? 0.8;
      _warmupVolume = StorageUtils.getDouble(_keyWarmupAudioVolume) ?? 0.8;
      _warmupInterval = StorageUtils.getDouble(_keyWarmupAudioInterval) ?? 2.0;
      _isVolumeLoaded = true;
      LogService.d('音量配置已加载: 挤服=${(_volume * 100).toInt()}%, 暖服=${(_warmupVolume * 100).toInt()}%, 间隔=${_warmupInterval}s');
    } catch (e) {
      LogService.e('加载音量配置失败', e);
    }
  }

  /// 确保挤服 AudioPlayer 已创建（首次播放时调用）
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

  /// 确保暖服 AudioPlayer 已创建
  Future<void> _ensureWarmupPlayerCreated() async {
    if (_warmupPlayer != null) return;
    if (!PlatformUtils.isDesktopPlatform) return;

    try {
      _warmupPlayer = AudioPlayer();
      await _warmupPlayer!.setReleaseMode(ReleaseMode.stop);
      LogService.i('暖服 AudioPlayer 已创建');
    } catch (e) {
      LogService.e('创建暖服 AudioPlayer 失败', e);
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    try {
      await StorageUtils.setDouble(_keyAudioVolume, _volume);
      LogService.d('音量已设置: ${(_volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('保存音量设置失败', e);
    }
  }

  /// 设置暖服音量
  Future<void> setWarmupVolume(double volume) async {
    _warmupVolume = volume.clamp(0.0, 1.0);

    try {
      await StorageUtils.setDouble(_keyWarmupAudioVolume, _warmupVolume);
      LogService.d('暖服音量已设置: ${(_warmupVolume * 100).toInt()}%');
    } catch (e) {
      LogService.e('保存暖服音量设置失败', e);
    }
  }

  /// 设置暖服音效播放间隔（秒）
  Future<void> setWarmupInterval(double interval) async {
    _warmupInterval = interval.clamp(0.0, 10.0);

    try {
      await StorageUtils.setDouble(_keyWarmupAudioInterval, _warmupInterval);
      LogService.d('暖服音效间隔已设置: ${_warmupInterval}s');
    } catch (e) {
      LogService.e('保存暖服间隔设置失败', e);
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

  /// 测试暖服音效播放（单次）
  Future<bool> testWarmupSound() async {
    return await _playWarmupOnce();
  }

  /// 播放一次暖服倒计时音效（内部方法）
  Future<bool> _playWarmupOnce() async {
    if (_warmupVolume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;

    await _ensureWarmupPlayerCreated();
    if (_warmupPlayer == null) return false;

    try {
      await _warmupPlayer!.setVolume(_warmupVolume);
      await _warmupPlayer!.play(AssetSource('audio/warmup_countdown.mp3'));
      LogService.d('播放暖服倒计时音效');
      return true;
    } catch (e) {
      LogService.e('播放暖服音效失败', e);
      return false;
    }
  }

  /// 开始循环播放暖服倒计时音效
  ///
  /// 播放流程：播放音效 → 等待播放完毕 → 间隔 [warmupInterval] 秒 → 再次播放
  /// 自动根据音频文件实际时长计算，无需手动设定时长。
  /// 调用 [stopWarmupLoop] 停止循环。
  Future<bool> startWarmupLoop() async {
    if (_warmupVolume <= 0) return false;
    if (!PlatformUtils.isDesktopPlatform) return false;
    if (_isWarmupLooping) return true; // 已经在循环中

    await _ensureWarmupPlayerCreated();
    if (_warmupPlayer == null) return false;

    _isWarmupLooping = true;

    // 监听播放完成事件，完成后等待间隔再次播放
    _warmupCompleteSubscription?.cancel();
    _warmupCompleteSubscription =
        _warmupPlayer!.onPlayerComplete.listen((_) {
      if (!_isWarmupLooping) return;

      // 播放完毕，等待间隔后再次播放
      _warmupIntervalTimer?.cancel();
      _warmupIntervalTimer = Timer(
        Duration(milliseconds: (_warmupInterval * 1000).toInt()),
        () {
          if (_isWarmupLooping) {
            _playWarmupOnce();
          }
        },
      );
    });

    // 立即开始第一次播放
    LogService.d('开始暖服倒计时循环音效，间隔: ${_warmupInterval}s');
    return await _playWarmupOnce();
  }

  /// 停止暖服倒计时循环音效
  Future<void> stopWarmupLoop() async {
    _isWarmupLooping = false;
    _warmupIntervalTimer?.cancel();
    _warmupIntervalTimer = null;
    _warmupCompleteSubscription?.cancel();
    _warmupCompleteSubscription = null;

    try {
      await _warmupPlayer?.stop();
      LogService.d('暖服倒计时循环音效已停止');
    } catch (e) {
      LogService.e('停止暖服循环音效失败', e);
    }
  }

  /// 播放暖服倒计时音效（兼容旧调用，启动循环）
  Future<bool> playWarmupCountdownSound() async {
    return await startWarmupLoop();
  }

  /// 停止播放（停止所有音效）
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
      await stopWarmupLoop();
    } catch (e) {
      LogService.e('停止音效失败', e);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await stopWarmupLoop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      await _warmupPlayer?.dispose();
      _warmupPlayer = null;
      _isVolumeLoaded = false;
      LogService.i('音频服务已释放');
    } catch (e) {
      LogService.e('释放音频服务失败', e);
    }
  }
}
