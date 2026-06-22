import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/error_utils.dart';
import '../../utils/log_service.dart';
import '../../utils/cache_service.dart';
import '../../utils/app_directory_service.dart';
import '../../utils/platform_utils.dart';
import '../../utils/storage_utils.dart';
import '../../services/disk_image_cache_service.dart';
import '../../services/network_mode_service.dart';
import '../../services/realtime_service.dart';
import '../../services/realtime/realtime_map_info_invalidator.dart';
import '../../api/server_api.dart';
import '../../api/guide_api.dart';
import '../../services/game_launcher_service.dart';
import '../../services/game_path_service.dart';
import '../../services/audio_service.dart';
import '../../services/notification_window_service.dart';
import '../../services/announcement_read_service.dart';
import '../../services/custom_server_service.dart';
import '../../services/warmup_monitor_service.dart';
import '../../services/update_log_monitor_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String _keyGamePath = 'game_path';
  static const String _keySteamPath = 'steam_path';
  static const String _keyLaunchPlatform = 'launch_platform';
  static const String _keyLaunchOptions = 'launch_options';
  static const String _keyNotificationPosition = 'notification_position';
  static const String _keyFloatingWindowPosition = 'floating_window_position';
  static const String _keyWarmupNotificationEnabled =
      'warmup_notification_enabled';
  static const String _keyUpdateLogNotificationEnabled =
      'update_log_notification_enabled';
  static const String _keyAppExitBehavior = 'app_exit_behavior';
  static const String _keyServerSortMode = 'server_sort_mode';
  static const String _keyBroadcastNotificationType =
      'broadcast_notification_type';

  final AudioService _audioService = AudioService();
  final GamePathService _gamePathService = GamePathService();
  final GameLauncherService _gameLauncherService = GameLauncherService();
  StreamSubscription<PathValidationResult>? _pathInvalidSubscription;

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
    on<SettingsCheckPathsValidity>(_onCheckPathsValidity);
    on<SettingsSetLaunchPlatform>(_onSetLaunchPlatform);
    on<SettingsSetLaunchOptions>(_onSetLaunchOptions);
    on<SettingsAddLaunchOption>(_onAddLaunchOption);
    on<SettingsRemoveLaunchOption>(_onRemoveLaunchOption);
    on<SettingsClearGamePath>(_onClearGamePath);
    on<SettingsClearSteamPath>(_onClearSteamPath);
    // 音效设置事件
    on<SettingsSetAudioVolume>(_onSetAudioVolume);
    on<SettingsTestAudio>(_onTestAudio);
    on<SettingsSetWarmupAudioVolume>(_onSetWarmupAudioVolume);
    on<SettingsTestWarmupAudio>(_onTestWarmupAudio);
    // 详细缓存管理事件
    on<SettingsLoadCacheDetails>(_onLoadCacheDetails);
    on<SettingsClearCacheByType>(_onClearCacheByType);
    on<SettingsClearAllCache>(_onClearAllCache);
    on<SettingsClearSelectedCache>(_onClearSelectedCache);
    // 移动端缓存管理事件
    on<SettingsLoadMobileCacheDetails>(_onLoadMobileCacheDetails);
    on<SettingsClearMobileCacheByType>(_onClearMobileCacheByType);
    // 窗口位置设置事件
    on<SettingsSetNotificationPosition>(_onSetNotificationPosition);
    on<SettingsSetFloatingWindowPosition>(_onSetFloatingWindowPosition);
    // 热身通知开关事件
    on<SettingsSetWarmupNotificationEnabled>(_onSetWarmupNotificationEnabled);
    // 更新日志通知开关事件
    on<SettingsSetUpdateLogNotificationEnabled>(
      _onSetUpdateLogNotificationEnabled,
    );
    on<SettingsSetAppExitBehavior>(_onSetAppExitBehavior);
    on<SettingsSetServerSortMode>(_onSetServerSortMode);
    on<SettingsSetBroadcastNotificationType>(_onSetBroadcastNotificationType);
    // 黑名单管理事件
    on<SettingsLoadBlocklist>(_onLoadBlocklist);
    on<SettingsBlockUser>(_onBlockUser);
    on<SettingsUnblockUser>(_onUnblockUser);
    // 弱网模式事件
    on<SettingsSetWeakNetworkMode>(_onSetWeakNetworkMode);
  }

  Future<void> _onInit(SettingsInit event, Emitter<SettingsState> emit) async {
    if (state.appVersion.isEmpty) {
      await _loadAppInfo(emit);
      await _loadPreferences(emit);
      await _loadGameSettings(emit);
      await _loadAudioSettings(emit);
      await _calculateCacheSize(emit);
    } else {
      // 即使已初始化，也重新加载游戏设置（可能在 OOBE 中设置了路径）
      await _loadGameSettings(emit);
    }

    // 初始化完成后检查路径是否失效
    add(SettingsCheckPathsValidity());

    // 监听底层服务主动发出的路径失效事件
    // 注意：state.isPathInvalidated 已经为 true 时跳过，避免与 verifyCurrentPaths
    // 内部的 _pathInvalidController.add 形成自激反馈循环（SettingsCheckPathsValidity
    // -> verifyCurrentPaths -> 流再次发射 -> 又触发 SettingsCheckPathsValidity）。
    _pathInvalidSubscription ??= _gamePathService.onPathInvalidStream.listen((
      result,
    ) {
      if (!result.isValid && !state.isPathInvalidated) {
        add(SettingsCheckPathsValidity());
      }
    });
  }

  @override
  Future<void> close() {
    _pathInvalidSubscription?.cancel();
    return super.close();
  }

  Future<void> _loadAppInfo(Emitter<SettingsState> emit) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      emit(
        state.copyWith(
          appVersion: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
        ),
      );
    } catch (e) {
      LogService.e('加载应用信息失败', e);
    }
  }

  Future<void> _loadPreferences(Emitter<SettingsState> emit) async {
    try {
      final themeModeIndex = StorageUtils.getInt('theme_mode') ?? 0;
      final notificationPositionIndex =
          StorageUtils.getInt(_keyNotificationPosition) ??
          NotificationPositionType.topRight.index;
      final floatingWindowPositionIndex =
          StorageUtils.getInt(_keyFloatingWindowPosition) ??
          NotificationPositionType.bottomRight.index;
      final warmupNotificationEnabled = StorageUtils.getBool(
        _keyWarmupNotificationEnabled,
        defaultValue: true,
      );
      final updateLogNotificationEnabled = StorageUtils.getBool(
        _keyUpdateLogNotificationEnabled,
        defaultValue: true,
      );
      final appExitBehaviorIndex =
          StorageUtils.getInt(_keyAppExitBehavior) ?? AppExitBehavior.ask.index;
      final serverSortModeIndex =
          StorageUtils.getInt(_keyServerSortMode) ??
          ServerSortMode.manual.index;
      final broadcastNotificationTypeIndex =
          StorageUtils.getInt(_keyBroadcastNotificationType) ??
          BroadcastNotificationType.software.index;
      // 弱网模式：直接从 NetworkModeService 读取（启动时已 loadFromStorage）
      final weakNetworkMode = NetworkModeService.instance.weakNetwork;
      final notificationPosition =
          NotificationPositionType.values[notificationPositionIndex];
      final floatingWindowPosition =
          NotificationPositionType.values[floatingWindowPositionIndex];
      final appExitBehavior = AppExitBehavior.values[appExitBehaviorIndex];
      final serverSortMode = ServerSortMode.values[serverSortModeIndex];
      final broadcastNotificationType =
          BroadcastNotificationType.values[broadcastNotificationTypeIndex.clamp(
            0,
            BroadcastNotificationType.values.length - 1,
          )];

      // 同步通知位置到 NotificationWindowService
      if (PlatformUtils.isDesktopPlatform) {
        NotificationWindowService().setNotificationPosition(
          notificationPosition,
        );
        // 同步热身通知开关到 WarmupMonitorService
        WarmupMonitorService().setEnabled(warmupNotificationEnabled);
        // 同步更新日志通知开关到 UpdateLogMonitorService
        UpdateLogMonitorService().setEnabled(updateLogNotificationEnabled);
      }

      emit(
        state.copyWith(
          themeMode: ThemeMode.values[themeModeIndex],
          notificationPosition: notificationPosition,
          floatingWindowPosition: floatingWindowPosition,
          warmupNotificationEnabled: warmupNotificationEnabled,
          updateLogNotificationEnabled: updateLogNotificationEnabled,
          appExitBehavior: appExitBehavior,
          serverSortMode: serverSortMode,
          broadcastNotificationType: broadcastNotificationType,
          weakNetworkMode: weakNetworkMode,
        ),
      );
    } catch (e) {
      LogService.e('加载偏好设置失败', e);
    }
  }

  Future<void> _loadGameSettings(Emitter<SettingsState> emit) async {
    try {
      final gamePath = StorageUtils.getString(_keyGamePath);
      final steamPath = StorageUtils.getString(_keySteamPath);
      final platformStr = StorageUtils.getString(_keyLaunchPlatform);
      final launchOptions = StorageUtils.getStringList(_keyLaunchOptions);

      LaunchPlatformType platform = LaunchPlatformType.worldwide;
      if (platformStr == 'perfect') {
        platform = LaunchPlatformType.perfect;
      }

      emit(
        state.copyWith(
          gamePath: gamePath,
          steamPath: steamPath,
          launchPlatform: platform,
          launchOptions: launchOptions,
        ),
      );

      LogService.d(
        '游戏设置已加载: gamePath=$gamePath, steamPath=$steamPath, platform=$platformStr',
      );
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
        // 移动端：统计 AppDirectoryService 缓存目录（包含 lobby_images、images 等）
        final appCacheDir = Directory(AppDirectoryService.cachePath);
        totalSize += await _calculateDirectorySize(appCacheDir);

        // 同时统计系统临时目录
        final tempDir = await getTemporaryDirectory();
        totalSize += await _calculateDirectorySize(tempDir);
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
        await for (var entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
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

  Future<void> _onSetThemeMode(
    SettingsSetThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      emit(state.copyWith(themeMode: event.themeMode));
      await StorageUtils.setInt('theme_mode', event.themeMode.index);
      LogService.d('主题模式已设置为: ${state.currentThemeModeText}');
    } catch (e) {
      LogService.e('设置主题模式失败', e);
    }
  }

  Future<void> _onToggleDarkMode(
    SettingsToggleDarkMode event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      ThemeMode newMode;
      switch (state.themeMode) {
        case ThemeMode.system:
          newMode = ThemeMode.light;
          break;
        case ThemeMode.light:
          newMode = ThemeMode.dark;
          break;
        case ThemeMode.dark:
          newMode = ThemeMode.system;
          break;
      }
      emit(state.copyWith(themeMode: newMode));
      await StorageUtils.setInt('theme_mode', newMode.index);
      LogService.d('主题模式已切换为: ${state.currentThemeModeText}');
    } catch (e) {
      LogService.e('切换主题模式失败', e);
    }
  }

  Future<void> _onClearCache(
    SettingsClearCache event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 清理磁盘图片缓存
      await DiskImageCacheService.instance.clearCache();

      // 根据平台选择缓存目录
      if (PlatformUtils.isDesktopPlatform) {
        final cacheDir = Directory(AppDirectoryService.cachePath);
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
      } else {
        // 移动端：清理 AppDirectoryService 缓存目录（lobby_images、images 等）
        final appCacheDir = Directory(AppDirectoryService.cachePath);
        if (appCacheDir.existsSync()) {
          await for (var entity in appCacheDir.list()) {
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
        // 同时清理系统临时目录
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
      }

      // 清理服务器列表缓存
      await CacheService.clearServerListCache();

      // 清理地图信息缓存
      await CacheService.clearMapInfoCache();
      final serverApi = ServerApi();
      serverApi.clearMapInfoCache();

      // 清理存储中的缓存数据
      final keysToRemove = StorageUtils.getKeys()
          .where(
            (key) =>
                (key.contains('cache') || key.contains('temp')) &&
                !key.contains('theme') &&
                !key.contains('path') &&
                !key.contains('platform') &&
                !key.contains('options'),
          )
          .toList();
      for (final key in keysToRemove) {
        await StorageUtils.remove(key);
      }

      await _calculateCacheSize(emit);
      LogService.d('缓存清理完成');
    } catch (e) {
      LogService.e('清理缓存失败', e);
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onRefreshCacheSize(
    SettingsRefreshCacheSize event,
    Emitter<SettingsState> emit,
  ) async {
    await _calculateCacheSize(emit);
  }

  Future<void> _onCheckForUpdates(
    SettingsCheckForUpdates event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isCheckingUpdate: true));
    try {
      LogService.d('开始检查更新');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      LogService.e('设置检查更新失败', e);
    } finally {
      emit(state.copyWith(isCheckingUpdate: false));
    }
  }

  Future<void> _onExportLogs(
    SettingsExportLogs event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final logDir = await LogService.getLogDirectory();
      if (logDir != null) {
        LogService.d('日志目录: $logDir');
        // 刷新日志缓冲区
        await LogService.flush();
      }
    } catch (e) {
      LogService.e('导出日志失败', e);
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCheckPathsValidity(
    SettingsCheckPathsValidity event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // 分别检查两条路径，避免一次返回只能反映一项
      final gameValid = await _gamePathService.isGamePathStillValid();
      final steamValid = await _gamePathService.isSteamPathStillValid();
      final anyInvalid = !gameValid || !steamValid;

      if (anyInvalid) {
        // 拼接精确的失效信息
        final messages = <String>[];
        if (!gameValid) messages.add('游戏路径已失效');
        if (!steamValid) messages.add('Steam 路径已失效');

        emit(
          state.copyWith(
            isPathInvalidated: true,
            isGamePathInvalid: !gameValid,
            isSteamPathInvalid: !steamValid,
            pathValidationMessage: messages.join('；'),
          ),
        );
        LogService.w(
          '检测到已配置的路径失效: gameValid=$gameValid, steamValid=$steamValid',
        );
      } else {
        // 全部有效：清除失效标记
        if (state.isPathInvalidated ||
            state.isGamePathInvalid ||
            state.isSteamPathInvalid) {
          emit(
            state.copyWith(
              isPathInvalidated: false,
              isGamePathInvalid: false,
              isSteamPathInvalid: false,
              pathValidationMessage: null,
            ),
          );
        }
      }
    } catch (e) {
      LogService.e('检查路径有效性时出错', e);
    }
  }


  Future<void> _onSetGamePath(
    SettingsSetGamePath event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // 使用 GamePathService 验证路径
      final validationResult = await _gamePathService.validateGamePath(
        event.path,
      );
      if (!validationResult.isValid) {
        emit(state.copyWith(gamePathError: validationResult.error));
        LogService.w('游戏路径验证失败: ${validationResult.error}');
        return;
      }

      await StorageUtils.setString(_keyGamePath, event.path);
      emit(state.copyWith(gamePath: event.path, gamePathError: null));

      // 同步到 GameLauncherService
      await GameLauncherService().setGamePath(event.path);
      LogService.d('游戏路径已设置: ${event.path}');

      // 重新整体校验：仅当所有已配置的路径都有效时，才会清除 isPathInvalidated
      add(SettingsCheckPathsValidity());
    } catch (e) {
      LogService.e('设置游戏路径失败', e);
      emit(
        state.copyWith(
          gamePathError: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '设置游戏路径失败',
          ),
        ),
      );
    }
  }

  Future<void> _onSetSteamPath(
    SettingsSetSteamPath event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // 使用 GamePathService 验证路径
      final validationResult = await _gamePathService.validateSteamPath(
        event.path,
      );
      if (!validationResult.isValid) {
        emit(state.copyWith(steamPathError: validationResult.error));
        LogService.w('Steam路径验证失败: ${validationResult.error}');
        return;
      }

      await StorageUtils.setString(_keySteamPath, event.path);
      emit(state.copyWith(steamPath: event.path, steamPathError: null));

      // 同步到 GameLauncherService
      await GameLauncherService().setSteamPath(event.path);
      LogService.d('Steam路径已设置: ${event.path}');

      // 重新整体校验：仅当所有已配置的路径都有效时，才会清除 isPathInvalidated
      add(SettingsCheckPathsValidity());
    } catch (e) {
      LogService.e('设置Steam路径失败', e);
      emit(
        state.copyWith(
          steamPathError: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '设置Steam路径失败',
          ),
        ),
      );
    }
  }

  Future<void> _onDetectGamePath(
    SettingsDetectGamePath event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isDetectingPath: true, gamePathError: null));
    try {
      // 使用 GameLauncherService 的智能检测（基于注册表和进程）
      final gamePath = await _gameLauncherService.detectGamePath();
      if (gamePath != null) {
        await StorageUtils.setString(_keyGamePath, gamePath);
        emit(
          state.copyWith(
            gamePath: gamePath,
            isDetectingPath: false,
            gamePathError: null,
          ),
        );

        // 同步到 GameLauncherService
        await _gameLauncherService.setGamePath(gamePath);
        LogService.d('自动检测到游戏路径: $gamePath');

        // 重新整体校验，可能关闭失效弹窗
        add(SettingsCheckPathsValidity());
      } else {
        emit(
          state.copyWith(
            isDetectingPath: false,
            gamePathError: '未能自动检测到游戏路径，请手动选择',
          ),
        );
        LogService.w('未能自动检测到游戏路径');
      }
    } catch (e) {
      emit(
        state.copyWith(
          isDetectingPath: false,
          gamePathError: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '检测游戏路径失败',
          ),
        ),
      );
      LogService.e('检测游戏路径失败', e);
    }
  }

  Future<void> _onDetectSteamPath(
    SettingsDetectSteamPath event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isDetectingPath: true, steamPathError: null));
    try {
      // 使用 GameLauncherService 的智能检测（基于注册表和进程）
      final steamPath = await _gameLauncherService.detectSteamPath();
      if (steamPath != null) {
        await StorageUtils.setString(_keySteamPath, steamPath);
        emit(
          state.copyWith(
            steamPath: steamPath,
            isDetectingPath: false,
            steamPathError: null,
          ),
        );

        // 同步到 GameLauncherService
        await _gameLauncherService.setSteamPath(steamPath);
        LogService.d('自动检测到Steam路径: $steamPath');

        // 重新整体校验，可能关闭失效弹窗
        add(SettingsCheckPathsValidity());
      } else {
        emit(
          state.copyWith(
            isDetectingPath: false,
            steamPathError: '未能自动检测到Steam路径，请手动选择',
          ),
        );
        LogService.w('未能自动检测到Steam路径');
      }
    } catch (e) {
      emit(
        state.copyWith(
          isDetectingPath: false,
          steamPathError: ErrorUtils.getErrorMessage(
            e,
            defaultMessage: '检测Steam路径失败',
          ),
        ),
      );
      LogService.e('检测Steam路径失败', e);
    }
  }

  Future<void> _onSetLaunchPlatform(
    SettingsSetLaunchPlatform event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final platformStr = event.platform == LaunchPlatformType.perfect
          ? 'perfect'
          : 'worldwide';
      await StorageUtils.setString(_keyLaunchPlatform, platformStr);
      emit(state.copyWith(launchPlatform: event.platform));

      // 同步到 GameLauncherService
      final launchPlatform = event.platform == LaunchPlatformType.perfect
          ? LaunchPlatform.perfect
          : LaunchPlatform.worldwide;
      await GameLauncherService().setLaunchPlatform(launchPlatform);
      LogService.d('启动平台已设置: $platformStr');
    } catch (e) {
      LogService.e('设置启动平台失败', e);
    }
  }

  Future<void> _onSetLaunchOptions(
    SettingsSetLaunchOptions event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setStringList(_keyLaunchOptions, event.options);
      emit(state.copyWith(launchOptions: event.options));

      // 同步到 GameLauncherService
      await GameLauncherService().setLaunchOptions(event.options);
      LogService.d('启动选项已设置: ${event.options.join(" ")}');
    } catch (e) {
      LogService.e('设置启动选项失败', e);
    }
  }

  Future<void> _onAddLaunchOption(
    SettingsAddLaunchOption event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final newOptions = List<String>.from(state.launchOptions);
      if (!newOptions.contains(event.option)) {
        newOptions.add(event.option);

        await StorageUtils.setStringList(_keyLaunchOptions, newOptions);
        emit(state.copyWith(launchOptions: newOptions));

        // 同步到 GameLauncherService
        await GameLauncherService().setLaunchOptions(newOptions);
        LogService.d('添加启动选项: ${event.option}');
      }
    } catch (e) {
      LogService.e('添加启动选项失败', e);
    }
  }

  Future<void> _onRemoveLaunchOption(
    SettingsRemoveLaunchOption event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final newOptions = List<String>.from(state.launchOptions);
      newOptions.remove(event.option);

      await StorageUtils.setStringList(_keyLaunchOptions, newOptions);
      emit(state.copyWith(launchOptions: newOptions));

      // 同步到 GameLauncherService
      await GameLauncherService().setLaunchOptions(newOptions);
      LogService.d('移除启动选项: ${event.option}');
    } catch (e) {
      LogService.e('移除启动选项失败', e);
    }
  }

  Future<void> _onClearGamePath(
    SettingsClearGamePath event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.remove(_keyGamePath);
      emit(state.copyWith(gamePath: '', gamePathError: null));
      // 重置 GameLauncherService 的检测缓存，避免之后重新检测时返回陈旧的 null 结果
      _gameLauncherService.resetPathCache();
      LogService.d('游戏路径已清除');

      // 路径清空后视为"未配置"，重新校验以更新失效状态
      add(SettingsCheckPathsValidity());
    } catch (e) {
      LogService.e('清除游戏路径失败', e);
    }
  }

  Future<void> _onClearSteamPath(
    SettingsClearSteamPath event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.remove(_keySteamPath);
      emit(state.copyWith(steamPath: '', steamPathError: null));
      // 重置 GameLauncherService 的检测缓存，避免之后重新检测时返回陈旧的 null 结果
      _gameLauncherService.resetPathCache();
      LogService.d('Steam路径已清除');

      // 路径清空后视为"未配置"，重新校验以更新失效状态
      add(SettingsCheckPathsValidity());
    } catch (e) {
      LogService.e('清除Steam路径失败', e);
    }
  }


  Future<void> _loadAudioSettings(Emitter<SettingsState> emit) async {
    try {
      await _audioService.initialize();
      emit(
        state.copyWith(
          audioVolume: _audioService.volume,
          warmupAudioVolume: _audioService.warmupVolume,
        ),
      );
      LogService.d(
        '音效设置已加载: volume=${_audioService.volume}, warmupVolume=${_audioService.warmupVolume}',
      );
    } catch (e) {
      LogService.e('加载音效设置失败', e);
    }
  }

  Future<void> _onSetAudioVolume(
    SettingsSetAudioVolume event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _audioService.setVolume(event.volume);
      emit(state.copyWith(audioVolume: event.volume));
      LogService.d('音量已设置: ${(event.volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('设置音量失败', e);
    }
  }

  Future<void> _onTestAudio(
    SettingsTestAudio event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _audioService.testSound();
      LogService.d('测试音效播放');
    } catch (e) {
      LogService.e('测试音效失败', e);
    }
  }

  Future<void> _onSetWarmupAudioVolume(
    SettingsSetWarmupAudioVolume event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _audioService.setWarmupVolume(event.volume);
      emit(state.copyWith(warmupAudioVolume: event.volume));
      LogService.d('暖服音量已设置: ${(event.volume * 100).toInt()}%');
    } catch (e) {
      LogService.e('设置暖服音量失败', e);
    }
  }

  Future<void> _onTestWarmupAudio(
    SettingsTestWarmupAudio event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _audioService.testWarmupSound();
      LogService.d('测试暖服音效播放');
    } catch (e) {
      LogService.e('测试暖服音效失败', e);
    }
  }


  Future<void> _onLoadCacheDetails(
    SettingsLoadCacheDetails event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoadingCacheDetails: true));
    try {
      final cacheDetails = await _calculateDetailedCacheInfo();
      emit(
        state.copyWith(
          cacheDetails: cacheDetails,
          isLoadingCacheDetails: false,
        ),
      );
      LogService.d('缓存详情已加载，共 ${cacheDetails.length} 个类别');
    } catch (e) {
      LogService.e('加载缓存详情失败', e);
      emit(state.copyWith(isLoadingCacheDetails: false));
    }
  }

  Future<void> _onClearCacheByType(
    SettingsClearCacheByType event,
    Emitter<SettingsState> emit,
  ) async {
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

      LogService.d('已清除缓存类型: ${event.cacheType.name}');
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

  Future<void> _onClearAllCache(
    SettingsClearAllCache event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 清除所有类型的缓存
      for (final cacheType in CacheType.values) {
        await _clearCacheByType(cacheType);
      }

      // 重新计算缓存大小
      final newCacheDetails = await _calculateDetailedCacheInfo();
      await _calculateCacheSize(emit);
      emit(state.copyWith(cacheDetails: newCacheDetails, isLoading: false));

      LogService.d('所有缓存已清除');
    } catch (e) {
      LogService.e('清除所有缓存失败', e);
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onClearSelectedCache(
    SettingsClearSelectedCache event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      // 检查是否包含应用数据清理
      final bool clearedAppData = event.cacheTypes.contains(CacheType.appData);

      // 清除选中类型的缓存
      for (final cacheType in event.cacheTypes) {
        await _clearCacheByType(cacheType);
      }

      // 重新计算缓存大小
      final newCacheDetails = await _calculateDetailedCacheInfo();
      await _calculateCacheSize(emit);
      emit(
        state.copyWith(
          cacheDetails: newCacheDetails,
          isLoading: false,
          needsRestart: clearedAppData, // 如果清理了应用数据，标记需要重启
        ),
      );

      LogService.d(
        '已清除选中的 ${event.cacheTypes.length} 种缓存${clearedAppData ? '，需要重启应用' : ''}',
      );
    } catch (e) {
      LogService.e('清除选中缓存失败', e);
      emit(state.copyWith(isLoading: false));
    }
  }

  /// 计算详细缓存信息
  Future<List<CacheItemInfo>> _calculateDetailedCacheInfo() async {
    final List<CacheItemInfo> details = [];

    try {
      // 1. 图片和临时文件缓存
      int cacheFilesSize = 0;
      if (PlatformUtils.isDesktopPlatform) {
        final cacheDir = Directory(AppDirectoryService.cachePath);
        if (await cacheDir.exists()) {
          cacheFilesSize = await _calculateDirectorySize(cacheDir);
        }
      } else {
        // 移动端：统计 AppDirectoryService 缓存目录（包含 lobby_images、images 等）
        final appCacheDir = Directory(AppDirectoryService.cachePath);
        if (await appCacheDir.exists()) {
          cacheFilesSize += await _calculateDirectorySize(appCacheDir);
        }
        // 同时统计系统临时目录
        final tempDir = await getTemporaryDirectory();
        cacheFilesSize += await _calculateDirectorySize(tempDir);
      }
      details.add(
        CacheItemInfo(
          type: CacheType.cacheFiles,
          name: '图片缓存',
          description: '临时文件和图片缓存',
          sizeInBytes: cacheFilesSize,
        ),
      );

      // 2. 服务器相关数据（列表、地图信息、自定义服务器、监控列表）
      int serverDataSize = 0;
      final cachedServerList = StorageUtils.getString('cached_server_list');
      if (cachedServerList != null) serverDataSize += cachedServerList.length;
      final cachedMapInfo = StorageUtils.getString('cached_map_info');
      if (cachedMapInfo != null) serverDataSize += cachedMapInfo.length;
      final customServerCategories = StorageUtils.getString(
        'custom_server_categories',
      );
      if (customServerCategories != null) {
        serverDataSize += customServerCategories.length;
      }
      final monitoredData = StorageUtils.getStringList('monitored_servers');
      for (final item in monitoredData) {
        serverDataSize += item.length;
      }
      details.add(
        CacheItemInfo(
          type: CacheType.serverData,
          name: '服务器数据',
          description: '服务器列表、地图、自定义配置等',
          sizeInBytes: serverDataSize,
        ),
      );

      // 3. 应用数据（草稿、已读状态、应用配置等）
      int appDataSize = 0;

      // 草稿内容（使用 draft_content_ 前缀）
      final draftKeys = StorageUtils.getKeys()
          .where((key) => key.startsWith('draft_content_'))
          .toList();
      for (final key in draftKeys) {
        final value = StorageUtils.getString(key);
        if (value != null) appDataSize += value.length;
      }

      // 草稿时间戳（使用 draft_ts_ 前缀，int 类型）
      final draftTimestampKeys = StorageUtils.getKeys()
          .where((key) => key.startsWith('draft_ts_'))
          .toList();
      appDataSize += draftTimestampKeys.length * 8; // 每个 int 约 8 字节

      // 已读状态
      final announcementReadIds = StorageUtils.getString(
        'announcement_read_ids',
      );
      if (announcementReadIds != null) {
        appDataSize += announcementReadIds.length;
      }

      // 应用配置存储
      final storageDir = Directory('${AppDirectoryService.basePath}/storage');
      if (await storageDir.exists()) {
        appDataSize += await _calculateDirectorySize(storageDir);
      }

      details.add(
        CacheItemInfo(
          type: CacheType.appData,
          name: '应用数据',
          description: '草稿、已读状态、游戏路径、主题等（清理后需重新设置）',
          sizeInBytes: appDataSize,
        ),
      );

      // 4. 日志文件
      int logsSize = 0;
      final logsDir = Directory(AppDirectoryService.logsPath);
      if (await logsDir.exists()) {
        logsSize = await _calculateDirectorySize(logsDir);
      }
      details.add(
        CacheItemInfo(
          type: CacheType.logs,
          name: '日志文件',
          description: '应用运行日志',
          sizeInBytes: logsSize,
        ),
      );
    } catch (e) {
      LogService.e('计算详细缓存信息失败', e);
    }

    return details;
  }

  /// 根据类型清除缓存
  Future<void> _clearCacheByType(CacheType cacheType) async {
    switch (cacheType) {
      case CacheType.cacheFiles:
        // 清理磁盘图片缓存
        await DiskImageCacheService.instance.clearCache();
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
          // 移动端：清理 AppDirectoryService 缓存目录（lobby_images、images 等）
          final appCacheDir = Directory(AppDirectoryService.cachePath);
          if (appCacheDir.existsSync()) {
            await for (var entity in appCacheDir.list()) {
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
          // 同时清理系统临时目录
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
        }
        break;

      case CacheType.serverData:
        await CacheService.clearServerListCache();
        await CacheService.clearMapInfoCache();
        final serverApi = ServerApi();
        serverApi.clearMapInfoCache();
        await CustomServerService.clearAll();
        await StorageUtils.remove('monitored_servers');
        break;

      case CacheType.appData:
        // 清理所有草稿相关数据（内容和时间戳）
        final draftKeys = StorageUtils.getKeys()
            .where((key) => key.startsWith('draft_'))
            .toList();
        for (final key in draftKeys) {
          await StorageUtils.remove(key);
        }
        final announcementService = AnnouncementReadService();
        await announcementService.clearReadStatus();

        // 彻底清空应用配置
        await StorageUtils.clear();

        // 压缩数据库释放空间
        await StorageUtils.compact();
        LogService.d('应用数据已彻底清空并压缩');
        break;

      case CacheType.logs:
        await LogService.clearLogs();
        break;
    }
  }


  Future<void> _onSetNotificationPosition(
    SettingsSetNotificationPosition event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setInt(_keyNotificationPosition, event.position.index);
      emit(state.copyWith(notificationPosition: event.position));

      // 同步到 NotificationWindowService
      NotificationWindowService().setNotificationPosition(event.position);

      LogService.d('通知位置已设置: ${event.position.displayName}');
    } catch (e) {
      LogService.e('设置通知位置失败', e);
    }
  }


  Future<void> _onSetFloatingWindowPosition(
    SettingsSetFloatingWindowPosition event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setInt(
        _keyFloatingWindowPosition,
        event.position.index,
      );
      emit(state.copyWith(floatingWindowPosition: event.position));

      LogService.d('浮窗位置已设置: ${event.position.displayName}');
    } catch (e) {
      LogService.e('设置浮窗位置失败', e);
    }
  }


  Future<void> _onSetWarmupNotificationEnabled(
    SettingsSetWarmupNotificationEnabled event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setBool(_keyWarmupNotificationEnabled, event.enabled);
      emit(state.copyWith(warmupNotificationEnabled: event.enabled));

      // 同步到 WarmupMonitorService
      WarmupMonitorService().setEnabled(event.enabled);

      LogService.d('热身通知已${event.enabled ? '启用' : '禁用'}');
    } catch (e) {
      LogService.e('设置热身通知开关失败', e);
    }
  }


  Future<void> _onSetUpdateLogNotificationEnabled(
    SettingsSetUpdateLogNotificationEnabled event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setBool(
        _keyUpdateLogNotificationEnabled,
        event.enabled,
      );
      emit(state.copyWith(updateLogNotificationEnabled: event.enabled));

      // 同步到 UpdateLogMonitorService
      UpdateLogMonitorService().setEnabled(event.enabled);

      LogService.d('更新日志通知已${event.enabled ? '启用' : '禁用'}');
    } catch (e) {
      LogService.e('设置更新日志通知开关失败', e);
    }
  }

  Future<void> _onSetAppExitBehavior(
    SettingsSetAppExitBehavior event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setInt(_keyAppExitBehavior, event.behavior.index);
      emit(state.copyWith(appExitBehavior: event.behavior));
      LogService.d('主窗口关闭行为已设置: ${event.behavior.displayName}');
    } catch (e) {
      LogService.e('设置主窗口关闭行为失败', e);
    }
  }

  Future<void> _onSetServerSortMode(
    SettingsSetServerSortMode event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setInt(_keyServerSortMode, event.mode.index);
      emit(state.copyWith(serverSortMode: event.mode));
      LogService.d('服务器排序模式已设置: ${event.mode.displayName}');
    } catch (e) {
      LogService.e('设置服务器排序模式失败', e);
    }
  }


  Future<void> _onSetBroadcastNotificationType(
    SettingsSetBroadcastNotificationType event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await StorageUtils.setInt(
        _keyBroadcastNotificationType,
        event.notificationType.index,
      );
      emit(state.copyWith(broadcastNotificationType: event.notificationType));
      LogService.d('广播通知方式已设置: ${event.notificationType.displayName}');
    } catch (e) {
      LogService.e('设置广播通知方式失败', e);
    }
  }


  Future<void> _onLoadMobileCacheDetails(
    SettingsLoadMobileCacheDetails event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoadingMobileCacheDetails: true));
    try {
      final details = await _calculateMobileCacheInfo();
      emit(
        state.copyWith(
          mobileCacheDetails: details,
          isLoadingMobileCacheDetails: false,
        ),
      );
    } catch (e) {
      LogService.e('加载移动端缓存详情失败', e);
      emit(state.copyWith(isLoadingMobileCacheDetails: false));
    }
  }

  Future<void> _onClearMobileCacheByType(
    SettingsClearMobileCacheByType event,
    Emitter<SettingsState> emit,
  ) async {
    // 标记正在清理
    final updated = state.mobileCacheDetails.map((item) {
      if (item.type == event.cacheType) return item.copyWith(isClearing: true);
      return item;
    }).toList();
    emit(state.copyWith(mobileCacheDetails: updated));

    try {
      await _clearMobileCacheByType(event.cacheType);
      final newDetails = await _calculateMobileCacheInfo();
      await _calculateCacheSize(emit);
      emit(state.copyWith(mobileCacheDetails: newDetails));
      LogService.d('移动端缓存已清除: ${event.cacheType.name}');
    } catch (e) {
      LogService.e('清除移动端缓存失败', e);
      final restored = state.mobileCacheDetails.map((item) {
        if (item.type == event.cacheType) {
          return item.copyWith(isClearing: false);
        }
        return item;
      }).toList();
      emit(state.copyWith(mobileCacheDetails: restored));
    }
  }

  /// 计算移动端各分类缓存大小
  Future<List<MobileCacheItemInfo>> _calculateMobileCacheInfo() async {
    final List<MobileCacheItemInfo> details = [];

    // 1. 服务器背景图片（DiskImageCacheService → cache/images/）
    final serverImagesSize = await DiskImageCacheService.instance
        .getCacheSize();
    details.add(
      MobileCacheItemInfo(
        type: MobileCacheType.serverImages,
        name: '服务器背景图片',
        description: '服务器列表中的背景图片',
        sizeInBytes: serverImagesSize,
        canClear: true,
      ),
    );

    // 2. 服务器数据（StorageUtils 中的缓存键）
    int serverDataSize = 0;
    final cachedServerList = StorageUtils.getString('cached_server_list');
    if (cachedServerList != null) serverDataSize += cachedServerList.length;
    final cachedMapInfo = StorageUtils.getString('cached_map_info');
    if (cachedMapInfo != null) serverDataSize += cachedMapInfo.length;
    details.add(
      MobileCacheItemInfo(
        type: MobileCacheType.serverData,
        name: '服务器数据',
        description: '服务器列表、地图信息等缓存数据',
        sizeInBytes: serverDataSize,
        canClear: true,
      ),
    );

    // 3. 日志文件
    int logsSize = 0;
    final logsDir = Directory(AppDirectoryService.logsPath);
    if (await logsDir.exists()) {
      logsSize = await _calculateDirectorySize(logsDir);
    }
    details.add(
      MobileCacheItemInfo(
        type: MobileCacheType.logs,
        name: '日志文件',
        description: '应用运行日志',
        sizeInBytes: logsSize,
        canClear: true,
      ),
    );

    // 4. 大厅图片（LobbyImageCacheService → cache/lobby_images/，只读）
    int lobbyImagesSize = 0;
    final lobbyDir = Directory(
      '${AppDirectoryService.cachePath}${Platform.pathSeparator}lobby_images',
    );
    if (await lobbyDir.exists()) {
      lobbyImagesSize = await _calculateDirectorySize(lobbyDir);
    }
    details.add(
      MobileCacheItemInfo(
        type: MobileCacheType.lobbyImages,
        name: '大厅图片',
        description: '大厅背景及角色图片，用于离线显示',
        sizeInBytes: lobbyImagesSize,
        canClear: false,
      ),
    );

    return details;
  }

  /// 按类型清除移动端缓存
  Future<void> _clearMobileCacheByType(MobileCacheType type) async {
    switch (type) {
      case MobileCacheType.serverImages:
        await DiskImageCacheService.instance.clearCache();
        break;
      case MobileCacheType.serverData:
        await CacheService.clearServerListCache();
        await CacheService.clearMapInfoCache();
        final serverApi = ServerApi();
        serverApi.clearMapInfoCache();
        break;
      case MobileCacheType.logs:
        await LogService.clearLogs();
        break;
      case MobileCacheType.lobbyImages:
        // 大厅图片不允许清理
        break;
    }
  }


  final GuideApi _guideApi = GuideApi();

  Future<void> _onLoadBlocklist(
    SettingsLoadBlocklist event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoadingBlocklist: true));
    try {
      // 从本地存储加载黑名单
      final blockedJson = StorageUtils.getStringList('blocked_users');
      final users = <BlockedUserInfo>[];
      for (final item in blockedJson) {
        final parts = item.split('|');
        if (parts.length >= 3) {
          users.add(
            BlockedUserInfo(
              userId: int.tryParse(parts[0]) ?? 0,
              userName: parts[1],
              blockedAt: DateTime.tryParse(parts[2]) ?? DateTime.now(),
            ),
          );
        }
      }
      emit(state.copyWith(blockedUsers: users, isLoadingBlocklist: false));
    } catch (e) {
      LogService.e('加载黑名单失败', e);
      emit(state.copyWith(isLoadingBlocklist: false));
    }
  }

  Future<void> _onBlockUser(
    SettingsBlockUser event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // 立即本地更新
      final newUser = BlockedUserInfo(
        userId: event.userId,
        userName: event.userName,
        blockedAt: DateTime.now(),
      );
      final updatedList = [...state.blockedUsers, newUser];
      emit(state.copyWith(blockedUsers: updatedList));

      // 持久化到本地存储
      await _persistBlocklist(updatedList);

      // 调用远程 API
      await _guideApi.block(event.userId);

      LogService.d('已拉黑用户: ${event.userName} (${event.userId})');
    } catch (e) {
      // API 失败不回滚本地状态（本地兜底 + 服务端权威的设计）
      LogService.e('拉黑用户 API 调用失败（本地已生效）', e);
    }
  }

  Future<void> _onUnblockUser(
    SettingsUnblockUser event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      // 立即本地移除
      final updatedList = state.blockedUsers
          .where((u) => u.userId != event.userId)
          .toList();
      emit(state.copyWith(blockedUsers: updatedList));

      // 持久化到本地存储
      await _persistBlocklist(updatedList);

      // 调用远程 API
      await _guideApi.unblock(event.userId);

      LogService.d('已取消拉黑用户: ${event.userId}');
    } catch (e) {
      LogService.e('取消拉黑用户 API 调用失败（本地已生效）', e);
    }
  }

  /// 持久化黑名单到本地存储
  Future<void> _persistBlocklist(List<BlockedUserInfo> users) async {
    final serialized = users.map((u) {
      return '${u.userId}|${u.userName}|${u.blockedAt.toIso8601String()}';
    }).toList();
    await StorageUtils.setStringList('blocked_users', serialized);
  }


  Future<void> _onSetWeakNetworkMode(
    SettingsSetWeakNetworkMode event,
    Emitter<SettingsState> emit,
  ) async {
    if (state.weakNetworkMode == event.enabled) return;

    // 1. 持久化到 NetworkModeService（也会广播 changes 事件）
    await NetworkModeService.instance.setWeakNetwork(event.enabled);

    // 2. 联动 Realtime 主推送服务
    if (event.enabled) {
      // 开启弱网：停掉 Realtime 主推送
      await RealtimeService().stop();
      RealtimeMapInfoInvalidator().stop();
      LogService.i('[Settings] 弱网模式开启，已停止 Realtime 主推送');
    } else {
      // 关闭弱网：重新启动 Realtime 主推送
      await RealtimeService().start();
      RealtimeMapInfoInvalidator().start();
      LogService.i('[Settings] 弱网模式关闭，已恢复 Realtime 主推送');
    }

    // 3. 更新 UI 状态
    emit(state.copyWith(weakNetworkMode: event.enabled));
  }
}
