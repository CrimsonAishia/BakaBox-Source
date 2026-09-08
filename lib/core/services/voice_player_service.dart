import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../api/env_config.dart';
import '../utils/app_directory_service.dart';
import '../utils/log_service.dart';

class VoicePlayerService {
  static final VoicePlayerService _instance = VoicePlayerService._internal();

  factory VoicePlayerService() => _instance;

  VoicePlayerService._internal();

  VideoPlayerController? _audioPlayer;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  /// The currently playing full URL
  final ValueNotifier<String?> currentPlayingUrl = ValueNotifier(null);

  /// The URL currently being loaded (downloading/preparing)
  final ValueNotifier<String?> currentLoadingUrl = ValueNotifier(null);

  /// The progress of the currently playing audio (0.0 to 1.0)
  final ValueNotifier<double> currentProgress = ValueNotifier(0.0);

  /// Cleans up and disposes the current player
  Future<void> _cleanupPlayer() async {
    if (_audioPlayer != null) {
      final playerToDispose = _audioPlayer;
      _audioPlayer = null;
      playerToDispose!.removeListener(_onPlayerStateChanged);
      try {
        await playerToDispose.pause();
        await playerToDispose.dispose();
      } catch (_) {}
    }
  }

  /// Stop current playback manually
  Future<void> stop() async {
    _cancelToken?.cancel('Stopped by user');
    _cancelToken = null;
    await _cleanupPlayer();
    currentPlayingUrl.value = null;
    currentLoadingUrl.value = null;
    currentProgress.value = 0.0;
  }

  void _onPlayerStateChanged() {
    if (_audioPlayer == null) return;

    final value = _audioPlayer!.value;

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

  Future<void> _prepareNewPlayer(File file) async {
    await _cleanupPlayer();
    _audioPlayer = VideoPlayerController.file(file);
    _audioPlayer!.addListener(_onPlayerStateChanged);
    await _audioPlayer!.initialize();

    if (_audioPlayer!.value.hasError) {
      throw Exception(
        'VideoPlayer 初始化失败: ${_audioPlayer!.value.errorDescription}',
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
    _cancelToken = CancelToken();

    try {
      // Handle caching
      final urlBytes = utf8.encode(fullUrl);
      final urlHash = md5.convert(urlBytes).toString();
      final ext = fullUrl.split('.').last.split('?').first;
      final safeExt = ext.isNotEmpty && ext.length <= 4 ? ext : 'mp3';
      final fileName = 'voice_$urlHash.$safeExt';

      final cacheDir = Directory(
        '${AppDirectoryService.cachePath}${Platform.pathSeparator}sounds',
      );
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final filePath = '${cacheDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await _prepareNewPlayer(file);
        currentPlayingUrl.value = fullUrl;
        await _audioPlayer!.play();
      } else {
        final tempFilePath = '$filePath.tmp';
        final tempFile = File(tempFilePath);

        try {
          await _dio.download(
            fullUrl,
            tempFile.path,
            cancelToken: _cancelToken,
          );
          await tempFile.rename(file.path);
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

        await _prepareNewPlayer(file);
        currentPlayingUrl.value = fullUrl;
        await _audioPlayer!.play();
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
  }
}
