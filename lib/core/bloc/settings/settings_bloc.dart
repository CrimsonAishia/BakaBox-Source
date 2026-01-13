import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import '../../utils/cache_service.dart';
import '../../utils/app_directory_service.dart';
import '../../utils/platform_utils.dart';
import '../../utils/image_cache_manager.dart';
import '../../api/server_api.dart';
import '../../services/game_launcher_service.dart';
import '../../services/game_path_service.dart';
import '../../services/audio_service.dart';
import '../../services/notification_window_service.dart';
import '../../services/announcement_read_service.dart';
import '../../services/custom_server_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String _keyGamePath = 'game_path';
  static const String _keySteamPath = 'steam_path';
  static const String _keyLaunchPlatform = 'launch_platform';
  static const String _keyLaunchOptions = 'launch_options';
  static const String _keyNotificationPosition = 'notification_position';
  static const String _keyFloatingWindowPosition = 'floating_window_position';

  final AudioService _audioService = AudioService();
  final GamePathService _gamePathService = GamePathService();

  SettingsBloc() : super(const SettingsState()) {
    on<SettingsInit>(_onInit);
    on<SettingsSetThemeMode>(_onSetThemeMode);
    on<SettingsToggleDarkMode>(_onToggleDarkMode);
    on<SettingsClearCache>(_onClearCache);
    on<SettingsRefreshCacheSize>(_onRefreshCacheSize);
    on<SettingsCheckForUpdates>(_onCheckForUpdates);
    on<SettingsExportLogs>(_onExportLogs);
    // 游戏设置事件
    on<SettingsSetGamePath>(_onSetGamePath);
    on<SettingsSetSteamPath>(_onSetSteamPath);
    on<SettingsDetectGamePath>(_onDetectGamePath);
    on<SettingsDetectSteamPath>(_onDetectSteamPath);
    on<SettingsSetLaunchPlatform>(_onSetLaunchPlatform);
    on<SettingsSetLaunchOptions>(_onSetLaunchOptions);
    on<SettingsAddLaunchOption>(_onAddLaunchOption);
    on<SettingsRemoveLaunchOption>(_onRemoveLaunchOption);
    on<SettingsClearGamePath>(_onClearGamePath);
    on<SettingsClearSteamPath>(_onClearSteamPath);
    // 音效设置事件
    on<SettingsSetAudioVolume>(_onSetAudioVolume);
    on<SettingsTestAudio>(_onTestAudio);
    // 详细缓存管理事件
    on<SettingsLoadCacheDetails>(_onLoadCacheDetails);
    on<SettingsClearCacheByType>(_onClearCacheByType);
    on<SettingsClearAllCache>(_onClearAllCache);
    on<SettingsClearSelectedCache>(_onClearSelectedCache);
    // 窗口位置设置事件
    on<SettingsSetNotificationPosition>(_onSetNotificationPosition);
    on<SettingsSetFloatingWindowPosition>(_onSetFloatingWindowPosition);
  }

  Future<void> _onInit(SettingsInit event, Emitter<SettingsState> emit) async {
    if (state.appVersion.isEmpty) {
      await _loadAppInfo(emit);
      await _loadPreferences(emit);
      await _loadGameSettings(emit);
      await _loadAudioSettings(emit);
      await _calculateCacheSize(emit);
    }
  }

  Future<void> _loadAppInfo(Emitter<SettingsState> emit) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      emit(state.copyWith(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      ));
    } catch (e) {
      LogService.e('加载应用信息失败', e);
    }
  }

  Future<void> _loadPreferences(Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
      final notificationPositionIndex = prefs.getInt(_keyNotificationPosition) ?? NotificationPositionType.topRight.index;
      final floatingWindowPositionIndex = prefs.getInt(_keyFloatingWindowPosition) ?? NotificationPositionType.bottomRight.index;
      final notificationPosition = NotificationPositionType.values[notificationPositionIndex];
      final floatingWindowPosition = NotificationPositionType.values[floatingWindowPositionIndex];
      
      // 同步通知位置到 NotificationWindowService
      if (PlatformUtils.isDesktopPlatform) {
        NotificationWindowService().setNotificationPosition(notificationPosition);
      }
      
      emit(state.copyWith(
        themeMode: ThemeMode.values[themeModeIndex],
        notificationPosition: notificationPosition,
        floatingWindowPosition: floatingWindowPosition,
      ));
    } catch (e) {
      LogService.e('加载偏好设置失败', e);
    }
  }

  Future<void> _loadGameSettings(Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final gamePath = prefs.getString(_keyGamePath);
      final steamPath = prefs.getString(_keySteamPath);
      final platformStr = prefs.getString(_keyLaunchPlatform);
      final launchOptions = prefs.getStringList(_keyLaunchOptions) ?? [];
      
      LaunchPlatformType platform = LaunchPlatformType.worldwide;
      if (platformStr == 'perfect') {
        platform = LaunchPlatformType.perfect;
      }
      
      emit(state.copyWith(
        gamePath: gamePath,
        steamPath: steamPath,
        launchPlatform: platform,
        launchOptions: launchOptions,
      ));
      
      LogService.d('游戏设置已加载: gamePath=$gamePath, steamPath=$steamPath, platform=$platformStr');
    } catch (e) {
      LogService.e('加载游戏设置失败', e);
    }
  }

  Future<void> _calculateCacheSize(Emitter<SettingsState> emit) async {
    try {
      int totalSize = 0;
      
      if (PlatformUtils.isDesktopPlatform) {
        // 桌面端：使用 AppDirectoryService 的缓存目录
        final cacheDir = Directory(AppDirectoryService.cachePath);
        totalSize = await _calculateDirectorySize(cacheDir);
      } else {
        // 移动端：使用系统临时目录
        final cacheDir = await getTemporaryDirectory();
        totalSize = await _calculateDirectorySize(cacheDir);
      }
      
      emit(state.copyWith(cacheSize: _formatBytes(totalSize)));
    } catch (e) {
      emit(state.copyWith(cacheSize: '无法计算'));
      LogService.e('计算缓存大小失败', e);
    }
  }

  Future<int> _calculateDirectorySize(Directory directory) async {
    int size = 0;
    try {
      if (directory.existsSync()) {
        await for (var entity in directory.list(recursive: true, followLinks: false)) {
          try {
            if (entity is File) {
              size += await entity.length();
            }
          } catch (e) {
            // 忽略单个文件的访问错误，继续计算其他文件
            LogService.d('无法访问文件: ${entity.path}');
          }
        }
      }
    } catch (e) {
      // 目录遍历失败时记录但不抛出异常
      LogService.d('目录遍历失败: ${directory.path}, 错误: $e');
    }
    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _onSetThemeMode(SettingsSetThemeMode event, Emitter<SettingsState> emit) async {
    try {
      emit(state.copyWith(themeMode: event.themeMode));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', event.themeMode.index);
      LogService.i('主题模式已设置为: ${state.currentThemeModeText}');
    } catch (e) {
      LogService.e('设置主题模式失败', e);
    }
  }

  Future<void> _onToggleDarkMode(SettingsToggleDarkMode event, Emitter<SettingsState> emit) async {
    try {
      ThemeMode newMode;
      switch (state.themeMode) {
        case ThemeMode.system: newMode = ThemeMode.light; break;
        case ThemeMode.light: newMode = ThemeMode.dark; break;
        case ThemeMode.dark: newMode = ThemeMode.system; break;
      }
      emit(state.copyWith(themeMode: newMode));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', newMode.index);
      LogService.i('主题模式已切换为: ${state.currentThemeModeText}');
    } catch (e) {
      LogService.e('切换主题模式失败', e);
    }
  }

  Future<void> _onClearCache(SettingsClearCache event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 清理图片缓存
      await AppImageCacheManager.clearCache();
      
      // 根据平台选择缓存目录
      Directory cacheDir;
      if (PlatformUtils.isDesktopPlatform) {
        cacheDir = Directory(AppDirectoryService.cachePath);
      } else {
        cacheDir = await getTemporaryDirectory();
      }
      
      if (cacheDir.existsSync()) {
        await for (var entity in cacheDir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            LogService.d('删除缓存项失败: ${entity.path}');
          }
        }
      }
      
      // 清理服务器列表缓存
      await CacheService.clearServerListCache();
      
      // 清理地图信息缓存
      await CacheService.clearMapInfoCache();
      final serverApi = ServerApi();
      serverApi.clearMapInfoCache();
      
      // 清理偏好设置中的缓存数据
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs.getKeys().where((key) => 
        (key.contains('cache') || key.contains('temp')) &&
        !key.contains('theme') && !key.contains('path') && 
        !key.contains('platform') && !key.contains('options')
      ).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      await _calculateCacheSize(emit);
      LogService.i('缓存清理完成');
    } catch (e) {
      LogService.e('清理缓存失败', e);
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onRefreshCacheSize(SettingsRefreshCacheSize event, Emitter<SettingsState> emit) async {
    await _calculateCacheSize(emit);
  }

  Future<void> _onCheckForUpdates(SettingsCheckForUpdates event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isCheckingUpdate: true));
    try {
      LogService.i('开始检查更新');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      LogService.e('设置检查更新失败', e);
    } finally {
      emit(state.copyWith(isCheckingUpdate: false));
    }
  }

  Future<void> _onExportLogs(SettingsExportLogs event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final logDir = await LogService.getLogDirectory();
      if (logDir != null) {
        LogService.i('日志目录: $logDir');
        // 刷新日志缓冲区
        await LogService.flush();
      }
    } catch (e) {
      LogService.e('导出日志失败', e);
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  // ==================== 游戏设置事件处理 ====================

  Future<void> _onSetGamePath(SettingsSetGamePath event, Emitter<SettingsState> emit) async {
    try {
      // 使用 GamePathService 验证路径
      final validationResult = await _gamePathService.validateGamePath(event.path);
      if (!validationResult.isValid) {
        emit(state.copyWith(
          gamePathError: validationResult.error,
        ));
        LogService.w('游戏路径验证失败: ${validationResult.error}');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGamePath, event.path);
      emit(state.copyWith(
        gamePath: event.path,
        gamePathError: null,
      ));
      
      // 同步到 GameLauncherService
      await GameLauncherService().setGamePath(event.path);
      LogService.i('游戏路径已设置: ${event.path}');
    } catch (e) {
      LogService.e('设置游戏路径失败', e);
      emit(state.copyWith(gamePathError: ErrorUtils.getErrorMessage(e, defaultMessage: '设置游戏路径失败')));
    }
  }

  Future<void> _onSetSteamPath(SettingsSetSteamPath event, Emitter<SettingsState> emit) async {
    try {
      // 使用 GamePathService 验证路径
      final validationResult = await _gamePathService.validateSteamPath(event.path);
      if (!validationResult.isValid) {
        emit(state.copyWith(
          steamPathError: validationResult.error,
        ));
        LogService.w('Steam路径验证失败: ${validationResult.error}');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySteamPath, event.path);
      emit(state.copyWith(
        steamPath: event.path,
        steamPathError: null,
      ));
      
      // 同步到 GameLauncherService
      await GameLauncherService().setSteamPath(event.path);
      LogService.i('Steam路径已设置: ${event.path}');
    } catch (e) {
      LogService.e('设置Steam路径失败', e);
      emit(state.copyWith(steamPathError: ErrorUtils.getErrorMessage(e, defaultMessage: '设置Steam路径失败')));
    }
  }

  Future<void> _onDetectGamePath(SettingsDetectGamePath event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isDetectingPath: true, gamePathError: null));
    try {
      final gamePath = await _gamePathService.detectGamePath();
      if (gamePath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyGamePath, gamePath);
        emit(state.copyWith(
          gamePath: gamePath, 
          isDetectingPath: false,
          gamePathError: null,
        ));
        
        // 同步到 GameLauncherService
        await GameLauncherService().setGamePath(gamePath);
        LogService.i('自动检测到游戏路径: $gamePath');
      } else {
        emit(state.copyWith(
          isDetectingPath: false,
          gamePathError: '未能自动检测到游戏路径，请手动选择',
        ));
        LogService.w('未能自动检测到游戏路径');
      }
    } catch (e) {
      emit(state.copyWith(
        isDetectingPath: false,
        gamePathError: ErrorUtils.getErrorMessage(e, defaultMessage: '检测游戏路径失败'),
      ));
      LogService.e('检测游戏路径失败', e);
    }
  }

  Future<void> _onDetectSteamPath(SettingsDetectSteamPath event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isDetectingPath: true, steamPathError: null));
    try {
      final steamPath = await _gamePathService.detectSteamPath();
      if (steamPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keySteamPath, steamPath);
        emit(state.copyWith(
          steamPath: steamPath, 
          isDetectingPath: false,
          steamPathError: null,
        ));
        
        // 同步到 GameLauncherService
        await GameLauncherService().setSteamPath(steamPath);
        LogService.i('自动检测到Steam路径: $steamPath');
      } else {
        emit(state.copyWith(
          isDetectingPath: false,
          steamPathError: '未能自动检测到Steam路径，请手动选择',
        ));
        LogService.w('未能自动检测到Steam路径');
      }
    } catch (e) {
      emit(state.copyWith(
        isDetectingPath: false,
        steamPathError: ErrorUtils.getErrorMessage(e, defaultMessage: '检测Steam路径失败'),
      ));
      LogService.e('检测Steam路径失败', e);
    }
  }

  Future<void> _onSetLaunchPlatform(SettingsSetLaunchPlatform event, Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final platformStr = event.platform == LaunchPlatformType.perfect ? 'perfect' : 'worldwide';
      await prefs.setString(_keyLaunchPlatform, platformStr);
      emit(state.copyWith(launchPlatform: event.platform));
      
      // 同步到 GameLauncherService
      final launchPlatform = event.platform == LaunchPlatformType.perfect 
          ? LaunchPlatform.perfect 
          : LaunchPlatform.worldwide;
      await GameLauncherService().setLaunchPlatform(launchPlatform);
      LogService.i('启动平台已设置: $platformStr');
    } catch (e) {
      LogService.e('设置启动平台失败', e);
    }
  }

  Future<void> _onSetLaunchOptions(SettingsSetLaunchOptions event, Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyLaunchOptions, event.options);
      emit(state.copyWith(launchOptions: event.options));
      
      // 同步到 GameLauncherService
      await GameLauncherService().setLaunchOptions(event.options);
      LogService.i('启动选项已设置: ${event.options.join(" ")}');
    } catch (e) {
      LogService.e('设置启动选项失败', e);
    }
  }

  Future<void> _onAddLaunchOption(SettingsAddLaunchOption event, Emitter<SettingsState> emit) async {
    try {
      final newOptions = List<String>.from(state.launchOptions);
      if (!newOptions.contains(event.option)) {
        newOptions.add(event.option);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_keyLaunchOptions, newOptions);
        emit(state.copyWith(launchOptions: newOptions));
        
        // 同步到 GameLauncherService
        await GameLauncherService().setLaunchOptions(newOptions);
        LogService.i('添加启动选项: ${event.option}');
      }
    } catch (e) {
      LogService.e('添加启动选项失败', e);
    }
  }

  Future<void> _onRemoveLaunchOption(SettingsRemoveLaunchOption event, Emitter<SettingsState> emit) async {
    try {
      final newOptions = List<String>.from(state.launchOptions);
      newOptions.remove(event.option);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyLaunchOptions, newOptions);
      emit(state.copyWith(launchOptions: newOptions));
      
      // 同步到 GameLauncherService
      await GameLauncherService().setLaunchOptions(newOptions);
      LogService.i('移除启动选项: ${event.option}');
    } catch (e) {
      LogService.e('移除启动选项失败', e);
    }
  }

  Future<void> _onClearGamePath(SettingsClearGamePath event, Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGamePath);
      emit(state.copyWith(
        gamePath: '',
        gamePathError: null,
      ));
      LogService.i('游戏路径已清除');
    } catch (e) {
      LogService.e('清除游戏路径失败', e);
    }
  }

  Future<void> _onClearSteamPath(SettingsClearSteamPath event, Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySteamPath);
      emit(state.copyWith(
        steamPath: '',
        steamPathError: null,
      ));
      LogService.i('Steam路径已清除');
    } catch (e) {
      LogService.e('清除Steam路径失败', e);
    }
  }

  // ==================== 音效设置事件处理 ====================

  Future<void> _loadAudioSettings(Emitter<SettingsState> emit) async {
    try {
      await _audioService.initialize();
      emit(state.copyWith(audioVolume: _audioService.volume));
      LogService.d('音效设置已加载: volume=${_audioService.volume}');
    } catch (e) {
      LogService.e('加载音效设置失败', e);
    }
  }

  Future<void> _onSetAudioVolume(SettingsSetAudioVolume event, Emitter<SettingsState> emit) async {
    try {
      await _audioService.setVolume(event.volume);
      emit(state.copyWith(audioVolume: event.volume));
      LogService.d('音量已设置: ${(event.volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('设置音量失败', e);
    }
  }

  Future<void> _onTestAudio(SettingsTestAudio event, Emitter<SettingsState> emit) async {
    try {
      await _audioService.testSound();
      LogService.d('测试音效播放');
    } catch (e) {
      LogService.e('测试音效失败', e);
    }
  }

  // ==================== 详细缓存管理事件处理 ====================

  Future<void> _onLoadCacheDetails(SettingsLoadCacheDetails event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoadingCacheDetails: true));
    try {
      final cacheDetails = await _calculateDetailedCacheInfo();
      emit(state.copyWith(
        cacheDetails: cacheDetails,
        isLoadingCacheDetails: false,
      ));
      LogService.d('缓存详情已加载，共 ${cacheDetails.length} 个类别');
    } catch (e) {
      LogService.e('加载缓存详情失败', e);
      emit(state.copyWith(isLoadingCacheDetails: false));
    }
  }

  Future<void> _onClearCacheByType(SettingsClearCacheByType event, Emitter<SettingsState> emit) async {
    // 更新状态显示正在清理
    final updatedDetails = state.cacheDetails.map((item) {
      if (item.type == event.cacheType) {
        return item.copyWith(isClearing: true);
      }
      return item;
    }).toList();
    emit(state.copyWith(cacheDetails: updatedDetails));

    try {
      await _clearCacheByType(event.cacheType);
      
      // 重新计算缓存大小
      final newCacheDetails = await _calculateDetailedCacheInfo();
      await _calculateCacheSize(emit);
      emit(state.copyWith(cacheDetails: newCacheDetails));
      
      LogService.i('已清除缓存类型: ${event.cacheType.name}');
    } catch (e) {
      LogService.e('清除缓存失败', e);
      // 恢复状态
      final restoredDetails = state.cacheDetails.map((item) {
        if (item.type == event.cacheType) {
          return item.copyWith(isClearing: false);
        }
        return item;
      }).toList();
      emit(state.copyWith(cacheDetails: restoredDetails));
    }
  }

  Future<void> _onClearAllCache(SettingsClearAllCache event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 清除所有类型的缓存
      for (final cacheType in CacheType.values) {
        await _clearCacheByType(cacheType);
      }
      
      // 重新计算缓存大小
      final newCacheDetails = await _calculateDetailedCacheInfo();
      await _calculateCacheSize(emit);
      emit(state.copyWith(
        cacheDetails: newCacheDetails,
        isLoading: false,
      ));
      
      LogService.i('所有缓存已清除');
    } catch (e) {
      LogService.e('清除所有缓存失败', e);
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onClearSelectedCache(SettingsClearSelectedCache event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 清除选中类型的缓存
      for (final cacheType in event.cacheTypes) {
        await _clearCacheByType(cacheType);
      }
      
      // 重新计算缓存大小
      final newCacheDetails = await _calculateDetailedCacheInfo();
      await _calculateCacheSize(emit);
      emit(state.copyWith(
        cacheDetails: newCacheDetails,
        isLoading: false,
      ));
      
      LogService.i('已清除选中的 ${event.cacheTypes.length} 种缓存');
    } catch (e) {
      LogService.e('清除选中缓存失败', e);
      emit(state.copyWith(isLoading: false));
    }
  }

  /// 计算详细缓存信息
  Future<List<CacheItemInfo>> _calculateDetailedCacheInfo() async {
    final List<CacheItemInfo> details = [];

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. 图片和临时文件缓存
      int cacheFilesSize = 0;
      if (PlatformUtils.isDesktopPlatform) {
        final cacheDir = Directory(AppDirectoryService.cachePath);
        if (await cacheDir.exists()) {
          cacheFilesSize = await _calculateDirectorySize(cacheDir);
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        cacheFilesSize = await _calculateDirectorySize(tempDir);
        
        final appDir = await getApplicationSupportDirectory();
        final imageCacheDir = Directory('${appDir.path}/image_cache');
        if (await imageCacheDir.exists()) {
          cacheFilesSize += await _calculateDirectorySize(imageCacheDir);
        }
      }
      details.add(CacheItemInfo(
        type: CacheType.cacheFiles,
        name: '图片缓存',
        description: '临时文件和图片缓存',
        sizeInBytes: cacheFilesSize,
      ));

      // 2. 服务器相关数据（列表、地图信息、自定义服务器、监控列表）
      int serverDataSize = 0;
      serverDataSize += prefs.getString('cached_server_list')?.length ?? 0;
      serverDataSize += prefs.getString('cached_map_info')?.length ?? 0;
      serverDataSize += prefs.getString('custom_server_categories')?.length ?? 0;
      final monitoredData = prefs.getStringList('monitored_servers');
      if (monitoredData != null) {
        for (final item in monitoredData) {
          serverDataSize += item.length;
        }
      }
      details.add(CacheItemInfo(
        type: CacheType.serverData,
        name: '服务器数据',
        description: '服务器列表、地图、自定义配置等',
        sizeInBytes: serverDataSize,
      ));

      // 3. 用户数据（草稿、公告已读状态）
      int userDataSize = 0;
      final draftKeys = prefs.getKeys().where((key) => key.startsWith('draft_')).toList();
      for (final key in draftKeys) {
        final value = prefs.getString(key);
        if (value != null) userDataSize += value.length;
      }
      userDataSize += prefs.getString('announcement_read_ids')?.length ?? 0;
      details.add(CacheItemInfo(
        type: CacheType.userData,
        name: '用户数据',
        description: '草稿、已读状态等',
        sizeInBytes: userDataSize,
      ));

      // 4. 日志文件
      int logsSize = 0;
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (await logsDir.exists()) {
        logsSize = await _calculateDirectorySize(logsDir);
      }
      details.add(CacheItemInfo(
        type: CacheType.logs,
        name: '日志文件',
        description: '应用运行日志',
        sizeInBytes: logsSize,
      ));

    } catch (e) {
      LogService.e('计算详细缓存信息失败', e);
    }

    return details;
  }

  /// 根据类型清除缓存
  Future<void> _clearCacheByType(CacheType cacheType) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (cacheType) {
      case CacheType.cacheFiles:
        await AppImageCacheManager.clearCache();
        if (PlatformUtils.isDesktopPlatform) {
          final cacheDir = Directory(AppDirectoryService.cachePath);
          if (await cacheDir.exists()) {
            await for (var entity in cacheDir.list()) {
              try {
                if (entity is File) {
                  await entity.delete();
                } else if (entity is Directory) {
                  await entity.delete(recursive: true);
                }
              } catch (e) {
                LogService.d('删除缓存文件失败: ${entity.path}');
              }
            }
          }
        } else {
          final tempDir = await getTemporaryDirectory();
          if (tempDir.existsSync()) {
            await for (var entity in tempDir.list()) {
              try {
                if (entity is File) {
                  await entity.delete();
                } else if (entity is Directory) {
                  await entity.delete(recursive: true);
                }
              } catch (e) {
                LogService.d('删除临时文件失败: ${entity.path}');
              }
            }
          }
          final appDir = await getApplicationSupportDirectory();
          final imageCacheDir = Directory('${appDir.path}/image_cache');
          if (await imageCacheDir.exists()) {
            await imageCacheDir.delete(recursive: true);
          }
        }
        break;

      case CacheType.serverData:
        await CacheService.clearServerListCache();
        await CacheService.clearMapInfoCache();
        final serverApi = ServerApi();
        serverApi.clearMapInfoCache();
        await CustomServerService.clearAll();
        await prefs.remove('monitored_servers');
        break;

      case CacheType.userData:
        final draftKeys = prefs.getKeys().where((key) => key.startsWith('draft_')).toList();
        for (final key in draftKeys) {
          await prefs.remove(key);
        }
        final announcementService = AnnouncementReadService();
        await announcementService.clearReadStatus();
        break;

      case CacheType.logs:
        await LogService.clearLogs();
        break;
    }
  }

  // ==================== 通知位置设置事件处理 ====================

  Future<void> _onSetNotificationPosition(SettingsSetNotificationPosition event, Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyNotificationPosition, event.position.index);
      emit(state.copyWith(notificationPosition: event.position));
      
      // 同步到 NotificationWindowService
      NotificationWindowService().setNotificationPosition(event.position);
      
      LogService.i('通知位置已设置: ${event.position.displayName}');
    } catch (e) {
      LogService.e('设置通知位置失败', e);
    }
  }

  // ==================== 浮窗位置设置事件处理 ====================

  Future<void> _onSetFloatingWindowPosition(SettingsSetFloatingWindowPosition event, Emitter<SettingsState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyFloatingWindowPosition, event.position.index);
      emit(state.copyWith(floatingWindowPosition: event.position));
      
      // TODO: 同步到 FloatingWindowService（如果需要）
      
      LogService.i('浮窗位置已设置: ${event.position.displayName}');
    } catch (e) {
      LogService.e('设置浮窗位置失败', e);
    }
  }
}
