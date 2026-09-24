import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../api/env_config.dart';
import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';
import '../utils/platform_utils.dart';

class VoicePlayerService {
  static final VoicePlayerService _instance = VoicePlayerService._internal();

  factory VoicePlayerService() => _instance;

  VoicePlayerService._internal() {
    Future.microtask(_cleanOldCache);
    if (!PlatformUtils.isDesktopPlatform) {
      _initAudioPlayer();
    }
  }

  VideoPlayerController? _videoPlayer;
  AudioPlayer? _audioPlayer;
  Duration? _audioDuration;

  StreamSubscription? _audioPlayerStateSub;
  StreamSubscription? _audioPlayerPositionSub;
  StreamSubscription? _audioPlayerDurationSub;

  /// The currently playing full URL
  final ValueNotifier<String?> currentPlayingUrl = ValueNotifier(null);

  /// The URL currently being loaded (downloading/preparing)
  final ValueNotifier<String?> currentLoadingUrl = ValueNotifier(null);

  /// The progress of the currently playing audio (0.0 to 1.0)
  final ValueNotifier<double> currentProgress = ValueNotifier(0.0);

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );

    _audioPlayerStateSub = _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        currentPlayingUrl.value = null;
        currentLoadingUrl.value = null;
        currentProgress.value = 0.0;
      } else if (state == PlayerState.playing) {
        currentLoadingUrl.value = null;
      }
    });

    _audioPlayerDurationSub = _audioPlayer!.onDurationChanged.listen((
      duration,
    ) {
      _audioDuration = duration;
    });

    _audioPlayerPositionSub = _audioPlayer!.onPositionChanged.listen((
      position,
    ) {
      if (_audioDuration != null && _audioDuration!.inMilliseconds > 0) {
        currentProgress.value =
            position.inMilliseconds / _audioDuration!.inMilliseconds;
      }
    });
  }

  /// Cleans up and disposes the current player
  Future<void> _cleanupPlayer() async {
    if (_videoPlayer != null) {
      final playerToDispose = _videoPlayer;
      _videoPlayer = null;
      playerToDispose!.removeListener(_onVideoPlayerStateChanged);
      try {
        await playerToDispose.pause();
        await playerToDispose.dispose();
      } catch (_) {}
    }

    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
      } catch (_) {}
    }
  }

  /// Stop current playback manually
  Future<void> stop() async {
    await _cleanupPlayer();
    currentPlayingUrl.value = null;
    currentLoadingUrl.value = null;
    currentProgress.value = 0.0;
    _audioDuration = null;
  }

  void _onVideoPlayerStateChanged() {
    if (_videoPlayer == null) return;

    final value = _videoPlayer!.value;

    // Check for playback errors
    if (value.hasError) {
      currentPlayingUrl.value = null;
      currentLoadingUrl.value = null;
      currentProgress.value = 0.0;
      LogService.e('VideoPlayer 播放错误: ${value.errorDescription}');
      return;
    }

    // Update progress
    if (value.isInitialized && value.duration > Duration.zero) {
      currentProgress.value =
          value.position.inMilliseconds / value.duration.inMilliseconds;
    }

    // Check if finished playing
    if (value.isInitialized &&
        !value.isPlaying &&
        value.duration == value.position &&
        value.duration > Duration.zero) {
      currentPlayingUrl.value = null;
      currentLoadingUrl.value = null;
      currentProgress.value = 0.0;
    } else if (value.isInitialized && value.isPlaying) {
      currentLoadingUrl.value = null;
    }
  }

  Future<void> _prepareNewVideoPlayer(File file) async {
    await _cleanupPlayer();
    _videoPlayer = VideoPlayerController.file(file);
    _videoPlayer!.addListener(_onVideoPlayerStateChanged);
    await _videoPlayer!.initialize();

    if (_videoPlayer!.value.hasError) {
      throw Exception(
        'VideoPlayer 初始化失败: ${_videoPlayer!.value.errorDescription}',
      );
    }
  }

  /// Toggles playback for a specific relative or absolute URL
  Future<void> togglePlay(String rawUrl) async {
    final fullUrl = EnvConfig.getApiUrl(rawUrl);

    // If the requested URL is already playing, stop it.
    if (currentPlayingUrl.value == fullUrl) {
      await stop();
      return;
    }

    // If it's already loading, ignore click to prevent multiple downloads
    if (currentLoadingUrl.value == fullUrl) {
      return;
    }

    // Stop whatever is currently playing
    await stop();

    currentLoadingUrl.value = fullUrl;

    try {
      // Handle caching
      final urlBytes = utf8.encode(fullUrl);
      final urlHash = md5.convert(urlBytes).toString();

      final cacheDir = Directory(
        '${AppDirectoryService.cachePath}${Platform.pathSeparator}sounds',
      );
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // 先通过 hash 查找是否已有缓存文件
      File? targetFile;
      final prefix = 'voice_$urlHash.';
      try {
        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last;
            if (name.startsWith(prefix) && !name.endsWith('.tmp')) {
              targetFile = entity;
              break;
            }
          }
        }
      } catch (_) {}

      if (targetFile != null && await targetFile.exists()) {
        if ((await targetFile.length()) == 0) {
          // If the file is 0 bytes for some reason, delete it and download again
          await targetFile.delete();
          targetFile = null;
        } else {
          try {
            if (PlatformUtils.isDesktopPlatform) {
              await _prepareNewVideoPlayer(targetFile);
              currentPlayingUrl.value = fullUrl;
              await _videoPlayer!.play();
            } else {
              currentPlayingUrl.value = fullUrl;
              await _audioPlayer!.play(DeviceFileSource(targetFile.path));
            }
            return;
          } catch (e) {
            LogService.w('本地缓存文件损坏或无法播放，将重新下载: ${targetFile.path}', e);
            await targetFile.delete();
            targetFile = null;
            // Fall through to download again
          }
        }
      }

      final tempFilePath =
          '${cacheDir.path}${Platform.pathSeparator}voice_$urlHash.tmp';
      final tempFile = File(tempFilePath);

      try {
        final response = await ApiClient.instance.download(
          fullUrl,
          tempFile.path,
        );

        String ext = 'mp3';

        // 完全依靠 Content-Type 推断扩展名
        final contentType = response.headers.value('content-type');
        if (contentType != null) {
          final ct = contentType.toLowerCase();
          if (ct.contains('audio/ogg')) {
            ext = 'ogg';
          } else if (ct.contains('audio/opus')) {
            ext = 'opus';
          } else if (ct.contains('audio/mp4') || ct.contains('audio/x-m4a')) {
            ext = 'm4a';
          } else if (ct.contains('audio/mpeg')) {
            ext = 'mp3';
          } else if (ct.contains('audio/wav') || ct.contains('audio/x-wav')) {
            ext = 'wav';
          } else if (ct.contains('audio/aac')) {
            ext = 'aac';
          } else if (ct.contains('audio/webm')) {
            ext = 'webm';
          } else if (ct.contains('audio/amr')) {
            ext = 'amr';
          }
        }

        final finalFileName = 'voice_$urlHash.$ext';
        final finalFilePath =
            '${cacheDir.path}${Platform.pathSeparator}$finalFileName';
        targetFile = File(finalFilePath);

        await tempFile.rename(targetFile.path);
      } catch (downloadError) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        rethrow;
      }

      // 检查下载期间是否被其他语音播放操作打断
      if (currentLoadingUrl.value != fullUrl) {
        return;
      }

      if (PlatformUtils.isDesktopPlatform) {
        await _prepareNewVideoPlayer(targetFile);
        currentPlayingUrl.value = fullUrl;
        await _videoPlayer!.play();
      } else {
        currentPlayingUrl.value = fullUrl;
        await _audioPlayer!.play(DeviceFileSource(targetFile.path));
      }
    } catch (e) {
      LogService.e('播放语音失败: $fullUrl', e);
      currentLoadingUrl.value = null;
      currentPlayingUrl.value = null;
      rethrow; // allows UI to show error state if listening
    }
  }

  void dispose() {
    _cleanupPlayer();
    _audioPlayerStateSub?.cancel();
    _audioPlayerPositionSub?.cancel();
    _audioPlayerDurationSub?.cancel();
    _audioPlayer?.dispose();
  }

  /// Clean up cache folder: remove orphaned .tmp files, 0-byte files, and files older than 7 days
  Future<void> _cleanOldCache() async {
    try {
      final cacheDir = Directory(
        '${AppDirectoryService.cachePath}${Platform.pathSeparator}sounds',
      );
      if (!await cacheDir.exists()) return;

      final now = DateTime.now();
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();

          if (entity.path.endsWith('.tmp')) {
            // Only delete orphaned tmp files older than 1 day to avoid deleting active downloads
            if (now.difference(stat.modified).inDays > 1) {
              await entity.delete();
            }
            continue;
          }

          if (stat.size == 0) {
            await entity.delete();
            continue;
          }

          if (now.difference(stat.modified).inDays > 7) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      LogService.e('清理语音缓存失败', e);
    }
  }
}
