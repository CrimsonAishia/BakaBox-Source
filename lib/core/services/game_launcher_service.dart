import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../utils/log_service.dart';
import '../utils/platform_utils.dart';
import '../utils/server_item_utils.dart';
import '../utils/storage_utils.dart';
import 'console_log_service.dart';
import 'game_status_service.dart';
import 'steam_user_service.dart';

/// 游戏启动结果
class GameLaunchResult {
  final bool success;
  final String? message;
  final String? error;
  final bool alreadyRunning;

  GameLaunchResult({
    required this.success,
    this.message,
    this.error,
    this.alreadyRunning = false,
  });

  factory GameLaunchResult.success({
    String? message,
    bool alreadyRunning = false,
  }) {
    return GameLaunchResult(
      success: true,
      message: message,
      alreadyRunning: alreadyRunning,
    );
  }

  factory GameLaunchResult.failure(String error) {
    return GameLaunchResult(success: false, error: error);
  }
}

/// 服务器连接结果
class ServerConnectResult {
  final bool success;
  final String? message;
  final String? error;
  final String? method;
  final bool needCsgoLegacy; // 是否需要安装 CSGO Legacy
  final bool needManualLaunch; // 是否需要手动启动（CSGO 已安装但无法自动启动）

  ServerConnectResult({
    required this.success,
    this.message,
    this.error,
    this.method,
    this.needCsgoLegacy = false,
    this.needManualLaunch = false,
  });

  factory ServerConnectResult.success({String? message, String? method}) {
    return ServerConnectResult(success: true, message: message, method: method);
  }

  factory ServerConnectResult.failure(
    String error, {
    bool needCsgoLegacy = false,
    bool needManualLaunch = false,
  }) {
    return ServerConnectResult(
      success: false,
      error: error,
      needCsgoLegacy: needCsgoLegacy,
      needManualLaunch: needManualLaunch,
    );
  }
}

/// 启动平台枚举
enum LaunchPlatform {
  worldwide, // 国际版
  perfect, // 完美世界
}

/// 游戏启动器服务 - 桌面端专属功能
///
/// 提供以下功能：
/// - 检测CS2游戏是否运行
/// - 启动CS2游戏
/// - 通过Steam URL连接服务器
/// - 支持密码服务器连接
class GameLauncherService {
  static const String _keyGamePath = 'game_path';
  static const String _keySteamPath = 'steam_path';
  static const String _keyLaunchPlatform = 'launch_platform';
  static const String _keyLaunchOptions = 'launch_options';

  // CS2 App ID
  static const String _cs2AppId = '730';

  // 进程名称
  static const List<String> _gameProcessNames = ['cs2.exe', 'csgo.exe'];

  /// 单例模式
  static final GameLauncherService _instance = GameLauncherService._internal();
  factory GameLauncherService() => _instance;
  GameLauncherService._internal();

  // 游戏路径检测缓存（避免重复检测）
  bool _gamePathDetectionAttempted = false;
  String? _cachedGamePath;

  // Steam路径检测缓存
  bool _steamPathDetectionAttempted = false;
  String? _cachedSteamPath;

  /// 检查是否为桌面平台
  bool get isDesktopPlatform => PlatformUtils.isDesktopPlatform;

  /// 检查游戏路径是否已配置
  Future<bool> hasGamePath() async {
    final path = StorageUtils.getString(_keyGamePath);
    return path != null && path.isNotEmpty;
  }

  /// 检测CS2是否正在运行
  Future<bool> isCS2Running() async {
    if (!isDesktopPlatform) {
      LogService.w('游戏检测功能仅支持桌面平台');
      return false;
    }

    try {
      if (PlatformUtils.isWindows) {
        return await _isCS2RunningWindows();
      }
      return false;
    } catch (e) {
      LogService.e('检测游戏运行状态失败', e);
      return false;
    }
  }

  /// Windows平台检测CS2进程
  Future<bool> _isCS2RunningWindows() async {
    for (final processName in _gameProcessNames) {
      try {
        final result = await Process.run('tasklist', [
          '/FI',
          'IMAGENAME eq $processName',
          '/FO',
          'CSV',
        ], runInShell: true);

        if (result.exitCode == 0 &&
            result.stdout.toString().toLowerCase().contains(
              processName.toLowerCase(),
            )) {
          LogService.d('检测到游戏进程: $processName');
          return true;
        }
      } catch (e) {
        LogService.d('检测进程 $processName 失败: $e');
      }
    }
    return false;
  }

  /// 检测 Steam 是否认为游戏正在运行
  ///
  /// 通过读取注册表 HKEY_CURRENT_USER\Software\Valve\Steam\RunningAppID 判断
  ///
  /// 返回值：
  /// - 正在运行的游戏 AppID（如 730 表示 CS2/CSGO）
  /// - 0 表示没有游戏在运行
  /// - null 表示检测失败
  Future<int?> getSteamRunningAppId() async {
    if (!PlatformUtils.isWindows) {
      return null;
    }

    try {
      final result = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Valve\\Steam',
        '/v',
        'RunningAppID',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // 格式: "    RunningAppID    REG_DWORD    0x2da" (0x2da = 730)
        final regex = RegExp(
          r'RunningAppID\s+REG_DWORD\s+(0x[0-9a-fA-F]+|\d+)',
        );
        final match = regex.firstMatch(output);
        if (match != null) {
          final valueStr = match.group(1)!;
          int appId;
          if (valueStr.startsWith('0x')) {
            appId = int.parse(valueStr.substring(2), radix: 16);
          } else {
            appId = int.parse(valueStr);
          }
          LogService.d('Steam RunningAppID: $appId');
          return appId;
        }
      }
      return 0; // 未找到或值为0
    } catch (e) {
      LogService.e('检测 Steam RunningAppID 失败', e);
      return null;
    }
  }

  /// 检测 Steam 状态是否卡住（Steam 认为游戏在运行但进程不存在）
  ///
  /// 返回值：
  /// - true: Steam 状态卡住，需要用户手动处理
  /// - false: 状态正常
  Future<bool> isSteamStatusStuck() async {
    if (!PlatformUtils.isWindows) {
      return false;
    }

    try {
      // 检测 Steam 认为正在运行的游戏
      final runningAppId = await getSteamRunningAppId();

      // 如果 Steam 认为 CS2/CSGO (AppID 730) 在运行
      if (runningAppId == 730) {
        // 检测实际进程是否存在
        final processRunning = await isCS2Running();

        if (!processRunning) {
          LogService.w(
            '检测到 Steam 状态卡住：Steam 认为游戏在运行 (AppID=$runningAppId)，但进程不存在',
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      LogService.e('检测 Steam 状态失败', e);
      return false;
    }
  }

  /// 检测当前运行的游戏类型
  ///
  /// 返回值：
  /// - 'cs2': CS2 正在运行
  /// - 'csgo': CSGO 正在运行
  /// - null: 没有游戏运行
  Future<String?> getRunningGameType() async {
    if (!isDesktopPlatform) {
      return null;
    }

    try {
      if (PlatformUtils.isWindows) {
        // 检测 cs2.exe
        final cs2Result = await Process.run('tasklist', [
          '/FI',
          'IMAGENAME eq cs2.exe',
          '/FO',
          'CSV',
        ], runInShell: true);

        if (cs2Result.exitCode == 0 &&
            cs2Result.stdout.toString().toLowerCase().contains('cs2.exe')) {
          LogService.d('检测到 CS2 正在运行');
          return 'cs2';
        }

        // 检测 csgo.exe
        final csgoResult = await Process.run('tasklist', [
          '/FI',
          'IMAGENAME eq csgo.exe',
          '/FO',
          'CSV',
        ], runInShell: true);

        if (csgoResult.exitCode == 0 &&
            csgoResult.stdout.toString().toLowerCase().contains('csgo.exe')) {
          LogService.d('检测到 CSGO 正在运行');
          return 'csgo';
        }
      }
      return null;
    } catch (e) {
      LogService.e('检测游戏类型失败', e);
      return null;
    }
  }

  /// 检测游戏是否带有 -condebug 参数启动（判断是否可监控）
  ///
  /// 返回值：
  /// - true: 游戏带 -condebug 启动，可以监控 console.log
  /// - false: 游戏未带 -condebug 或未运行
  Future<bool> isCS2LaunchedWithCondebug() async {
    if (!PlatformUtils.isWindows) {
      // 非 Windows 平台暂时返回 false，后续可扩展
      return false;
    }

    try {
      // 检测所有游戏进程的启动参数
      for (final processName in _gameProcessNames) {
        try {
          final result = await Process.run('wmic', [
            'process',
            'where',
            "name='$processName'",
            'get',
            'CommandLine',
            '/format:value',
          ], runInShell: true);

          if (result.exitCode == 0) {
            final output = result.stdout.toString().toLowerCase();

            // 检查是否包含 -condebug 参数
            if (output.contains('-condebug') &&
                output.contains('commandline=')) {
              LogService.d('检测到 $processName 带 -condebug 参数启动');
              return true;
            }

            // 如果有输出但没有 -condebug，记录日志但继续检查其他进程
            if (output.contains('commandline=') &&
                output.contains(processName.toLowerCase())) {
              LogService.d('$processName 运行中但未带 -condebug 参数');
            }
          }
        } catch (e) {
          LogService.d('检测进程 $processName 启动参数失败: $e');
        }
      }

      return false;
    } catch (e) {
      LogService.e('检测游戏启动参数失败', e);
      return false;
    }
  }

  /// 获取游戏进程的完整命令行参数
  /// 返回第一个找到的游戏进程的命令行
  Future<String?> getCS2CommandLine() async {
    if (!PlatformUtils.isWindows) {
      return null;
    }

    try {
      // 检测所有游戏进程
      for (final processName in _gameProcessNames) {
        try {
          final result = await Process.run('wmic', [
            'process',
            'where',
            "name='$processName'",
            'get',
            'CommandLine',
            '/format:value',
          ], runInShell: true);

          if (result.exitCode == 0) {
            final output = result.stdout.toString();
            final lines = output.split('\n');
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.startsWith('CommandLine=')) {
                final cmdLine = trimmed.substring('CommandLine='.length).trim();
                if (cmdLine.isNotEmpty) {
                  LogService.d('获取到 $processName 命令行参数');
                  return cmdLine;
                }
              }
            }
          }
        } catch (e) {
          LogService.d('获取 $processName 命令行参数失败: $e');
        }
      }
      return null;
    } catch (e) {
      LogService.e('获取游戏命令行参数失败', e);
      return null;
    }
  }

  /// 启动CS2游戏（不连接服务器）
  Future<GameLaunchResult> launchCS2() async {
    if (!isDesktopPlatform) {
      return GameLaunchResult.failure('游戏启动功能仅支持桌面平台');
    }

    // 检查游戏路径是否已配置
    final hasPath = await hasGamePath();
    if (!hasPath) {
      return GameLaunchResult.failure('请先在设置中配置游戏路径');
    }

    LogService.d('收到CS2启动请求');

    // 检查Steam启动选项是否已配置 -condebug（仅Windows）
    if (PlatformUtils.isWindows) {
      final condebugConfigured = await ensureCondebugConfigured();
      if (!condebugConfigured) {
        LogService.w('未能自动配置Steam启动选项，请手动在Steam中设置');
        // 继续尝试启动，不阻塞用户
      }
    }

    // 检查游戏是否已在运行
    if (await isCS2Running()) {
      LogService.d('游戏已在运行');
      return GameLaunchResult.success(message: '游戏已在运行', alreadyRunning: true);
    }

    try {
      // 启动前清空 console.log（用于判断是否由 BakaBox 启动）
      final consoleLogService = ConsoleLogService();
      await consoleLogService.clearConsoleLog();

      final gameStatusService = GameStatusService();

      GameLaunchResult launchResult;

      // Windows使用命令行方式启动
      if (PlatformUtils.isWindows) {
        launchResult = await _launchCS2Windows();
      } else {
        // 其他平台使用Steam URL
        final platform = await getLaunchPlatform();
        final launchOptions = await getLaunchOptions();
        final steamUrl = _buildLaunchUrl(platform, launchOptions);
        LogService.d('启动游戏URL: $steamUrl');

        final uri = Uri.parse(steamUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launchResult = GameLaunchResult.success(message: '游戏启动命令已发送');
        } else {
          return GameLaunchResult.failure('无法启动Steam，请确保Steam已安装');
        }
      }

      if (!launchResult.success) {
        return launchResult;
      }

      LogService.d('游戏启动命令已发送');

      // 等待游戏启动
      final started = await _waitForGameStart();
      if (started) {
        // 标记为可监控，并保存游戏类型（启动的是 CS2）
        gameStatusService.markAsMonitorable(gameType: 'cs2');
        LogService.d('游戏已成功启动');
        return GameLaunchResult.success(message: '游戏启动成功');
      } else {
        return GameLaunchResult.failure('游戏启动超时，请检查Steam是否正常运行');
      }
    } catch (e) {
      LogService.e('启动游戏失败', e);
      return GameLaunchResult.failure('启动游戏失败，请检查Steam是否正常运行');
    }
  }

  /// 构建游戏启动URL
  String _buildLaunchUrl(LaunchPlatform platform, List<String> launchOptions) {
    final options = <String>['-condebug'];

    // 添加平台参数
    if (platform == LaunchPlatform.perfect) {
      options.add('-perfectworld');
    } else {
      options.add('-worldwide');
    }

    // 添加用户自定义启动选项
    options.addAll(launchOptions);

    // 构建Steam URL
    // 格式: steam://run/730//<options>
    final optionsStr = options.join(' ');
    return 'steam://run/$_cs2AppId//$optionsStr';
  }

  /// 使用命令行启动游戏
  Future<GameLaunchResult> _launchCS2Windows() async {
    try {
      // 优先从设置获取Steam路径，没有设置才自动检测
      String? steamPath = await getSteamPath();
      if (steamPath == null || steamPath.isEmpty) {
        LogService.d('设置中未配置Steam路径，尝试自动检测');
        steamPath = await detectSteamPath();
      }

      if (steamPath == null) {
        return GameLaunchResult.failure('未找到Steam路径，请在「设置 → 游戏设置」中配置Steam安装路径');
      }

      final steamExe = '$steamPath\\steam.exe';
      if (!await File(steamExe).exists()) {
        return GameLaunchResult.failure('Steam.exe不存在: $steamExe');
      }

      // 获取启动配置
      final platform = await getLaunchPlatform();
      final launchOptions = await getLaunchOptions();

      // 构建启动参数
      final args = <String>['-applaunch', _cs2AppId, '-condebug'];

      // 添加平台参数
      if (platform == LaunchPlatform.perfect) {
        args.add('-perfectworld');
      } else {
        args.add('-worldwide');
      }

      // 添加用户自定义启动选项
      args.addAll(launchOptions);

      LogService.d('启动游戏命令: $steamExe ${args.join(" ")}');

      // 使用Process.start启动
      final process = await Process.start(
        steamExe,
        args,
        mode: ProcessStartMode.detached,
      );

      LogService.d('游戏启动命令已发送，PID: ${process.pid}');
      return GameLaunchResult.success(message: '游戏启动命令已发送');
    } catch (e) {
      LogService.e('启动游戏失败', e);
      return GameLaunchResult.failure('启动游戏失败，请检查Steam是否正常运行');
    }
  }

  /// 使用命令行连接服务器
  ///
  /// [gameType] 游戏类型，用于判断启动 CS2 还是 CSGO
  ///
  /// 注意：调用此方法前，CSGO 服务器应该已经通过 connectToServer 进行了检查
  Future<ServerConnectResult> _connectUsingCmdWindows(
    String serverAddress,
    String? password, {
    String? gameType,
  }) async {
    try {
      LogService.d('使用命令行连接服务器: $serverAddress');

      // 构建Steam URL（统一格式，不区分 CS2 和 CSGO）
      String steamUrl;
      if (password != null && password.isNotEmpty) {
        steamUrl =
            'steam://run/$_cs2AppId//+connect $serverAddress +password $password';
      } else {
        steamUrl = 'steam://run/$_cs2AppId//+connect $serverAddress';
      }

      LogService.d('生成的Steam URL: $steamUrl');

      // 使用cmd.exe的start命令打开Steam URL
      final result = await Process.run('cmd.exe', [
        '/C',
        'start',
        '',
        steamUrl,
      ], runInShell: false);

      if (result.exitCode == 0) {
        LogService.d('Steam URL连接命令已发送');
        return ServerConnectResult.success(
          message: '连接命令已发送',
          method: 'steam-url',
        );
      } else {
        LogService.e('连接命令执行失败: ${result.stderr}');
        return ServerConnectResult.failure('连接命令执行失败');
      }
    } catch (e) {
      LogService.e('连接服务器失败', e);
      return ServerConnectResult.failure('连接服务器失败，请检查Steam是否正常运行');
    }
  }

  /// 验证游戏类型是否匹配
  ///
  /// 返回值：
  /// - null: 验证通过或无需验证
  /// - ServerConnectResult: 验证失败，返回错误结果
  Future<ServerConnectResult?> _validateGameTypeMatch(String? gameType) async {
    // 判断是否为 CSGO 服务器
    final isCsgo = ServerItemUtils.isCsgoServer(gameType);

    // 检查游戏是否正在运行
    final isRunning = await isCS2Running();

    // 如果游戏正在运行，检查游戏类型是否匹配
    if (isRunning) {
      // 从 GameStatusService 获取已保存的游戏类型
      final gameStatusService = GameStatusService();
      final runningGameType = gameStatusService.runningGameType;

      if (runningGameType != null) {
        // 检查游戏类型是否匹配
        final isRunningCsgo = runningGameType == 'csgo';

        if (isCsgo && !isRunningCsgo) {
          // 服务器是 CSGO，但运行的是 CS2
          LogService.w('尝试连接 CSGO 服务器，但当前运行的是 CS2');
          return ServerConnectResult.failure('此服务器需要 CSGO 客户端，请关闭 CS2 后重试');
        } else if (!isCsgo && isRunningCsgo) {
          // 服务器是 CS2，但运行的是 CSGO
          LogService.w('尝试连接 CS2 服务器，但当前运行的是 CSGO');
          return ServerConnectResult.failure('此服务器需要 CS2 客户端，请关闭 CSGO 后重试');
        }
      }
    }

    return null; // 验证通过
  }

  /// 验证 CSGO 服务器的前置条件
  ///
  /// 返回值：
  /// - null: 验证通过
  /// - ServerConnectResult: 验证失败，返回错误结果
  Future<ServerConnectResult?> _validateCsgoPrerequisites(
    bool isCsgo,
    bool isRunning,
  ) async {
    if (!isCsgo) {
      return null; // 不是 CSGO 服务器，无需检查
    }

    // 检查是否安装了 Legacy 分支
    final isInstalled = await isCsgoLegacyInstalled();
    if (!isInstalled) {
      LogService.w('尝试连接 CSGO 服务器，但未检测到 CSGO Legacy 安装');
      return ServerConnectResult.failure(
        '此服务器需要 CSGO 客户端',
        needCsgoLegacy: true,
      );
    }

    // 检查 CSGO 是否正在运行
    if (!isRunning) {
      LogService.w('CSGO 未运行，需要用户手动启动');
      return ServerConnectResult.failure(
        '请先在 Steam 中启动 CSGO',
        needManualLaunch: true,
      );
    }

    LogService.d('检测到 CSGO 正在运行，使用普通 connect 命令连接');
    return null; // 验证通过
  }

  /// 检测是否安装了 CSGO Legacy 分支
  ///
  /// 通过检查 CSGO 特有的可执行文件来判断是否安装了 Legacy 分支
  /// 返回值：
  /// - true: 已安装 CSGO Legacy
  /// - false: 未安装
  Future<bool> isCsgoLegacyInstalled() async {
    try {
      // 获取游戏路径
      String? gamePath = await getGamePath();
      if (gamePath == null || gamePath.isEmpty) {
        gamePath = await detectGamePath();
      }

      if (gamePath == null) {
        LogService.w('无法检测游戏路径，无法判断 CSGO Legacy 是否安装');
        return false;
      }

      // CSGO Legacy 的特征文件：csgo.exe
      // 这是 CSGO 的主程序，只有安装了 Legacy 分支才会存在
      // CS2 只有 cs2.exe，不会有 csgo.exe
      final csgoExePath = '$gamePath\\csgo.exe';
      final csgoExeExists = await File(csgoExePath).exists();

      if (csgoExeExists) {
        LogService.d('检测到 CSGO Legacy 已安装: $csgoExePath');
        return true;
      }

      LogService.d('未检测到 CSGO Legacy 安装（csgo.exe 不存在）');
      return false;
    } catch (e) {
      LogService.e('检测 CSGO Legacy 安装状态失败', e);
      return false;
    }
  }

  /// 等待游戏启动
  Future<bool> _waitForGameStart({
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      await Future.delayed(const Duration(seconds: 1));

      if (await isCS2Running()) {
        LogService.d('检测到CS2进程已启动，等待进程稳定...');
        // 等待3秒确保进程稳定
        await Future.delayed(const Duration(seconds: 3));

        // 再次确认进程仍在运行
        if (await isCS2Running()) {
          LogService.d('CS2进程已稳定运行');
          // 额外等待2秒，确保游戏完全初始化
          await Future.delayed(const Duration(seconds: 2));
          return true;
        } else {
          LogService.d('CS2进程启动后崩溃，继续等待...');
        }
      }
    }

    return false;
  }

  /// 连接到服务器（通过Steam URL）
  ///
  /// [address] 服务器地址，格式为 ip:port 或 ip:port;password=xxx
  /// [gameType] 游戏类型，用于判断启动 CS2 还是 CSGO（可选，如果不传则默认启动 CS2）
  Future<ServerConnectResult> connectToServer(
    String address, {
    String? gameType,
  }) async {
    if (!isDesktopPlatform) {
      return ServerConnectResult.failure('服务器连接功能仅支持桌面平台');
    }

    // 检查游戏路径是否已配置
    final hasPath = await hasGamePath();
    if (!hasPath) {
      return ServerConnectResult.failure('请先在设置中配置游戏路径');
    }

    LogService.d('收到连接服务器请求，目标服务器: $address, 游戏类型: $gameType');

    // 验证游戏类型是否匹配
    final typeValidation = await _validateGameTypeMatch(gameType);
    if (typeValidation != null) {
      return typeValidation; // 验证失败，返回错误
    }

    // 判断是否为 CSGO 服务器
    final isCsgo = ServerItemUtils.isCsgoServer(gameType);
    final isRunning = await isCS2Running();

    // 验证 CSGO 前置条件
    final csgoValidation = await _validateCsgoPrerequisites(isCsgo, isRunning);
    if (csgoValidation != null) {
      return csgoValidation; // 验证失败，返回错误
    }

    // 解析地址和密码
    String serverAddress;
    String? password;

    if (address.contains(';password=')) {
      final parts = address.split(';password=');
      serverAddress = parts[0];
      password = parts.length > 1 ? parts[1] : null;
    } else {
      serverAddress = address;
    }

    LogService.d('连接到服务器: $serverAddress');
    if (password != null && password.isNotEmpty) {
      LogService.d('服务器设置了密码保护');
    }

    // 使用Steam URL连接
    return await _connectUsingSteamUrl(
      serverAddress,
      password,
      gameType: gameType,
    );
  }

  /// 连接到密码服务器
  ///
  /// [address] 服务器地址，格式为 ip:port
  /// [password] 服务器密码
  /// [gameType] 游戏类型，用于判断启动 CS2 还是 CSGO（可选）
  Future<ServerConnectResult> connectToPasswordServer(
    String address,
    String password, {
    String? gameType,
  }) async {
    if (!isDesktopPlatform) {
      return ServerConnectResult.failure('服务器连接功能仅支持桌面平台');
    }

    LogService.d('收到连接密码服务器请求，目标服务器: $address, 游戏类型: $gameType');

    // 验证游戏类型是否匹配
    final typeValidation = await _validateGameTypeMatch(gameType);
    if (typeValidation != null) {
      return typeValidation; // 验证失败，返回错误
    }

    // 判断是否为 CSGO 服务器
    final isCsgo = ServerItemUtils.isCsgoServer(gameType);
    final isRunning = await isCS2Running();

    // 验证 CSGO 前置条件
    final csgoValidation = await _validateCsgoPrerequisites(isCsgo, isRunning);
    if (csgoValidation != null) {
      return csgoValidation; // 验证失败，返回错误
    }

    return await _connectUsingSteamUrl(address, password, gameType: gameType);
  }

  /// 使用Steam URL连接服务器
  ///
  /// [gameType] 游戏类型，用于判断启动 CS2 还是 CSGO
  /// - 如果 gameType 包含 "csgo" 或 "cs:go"（不区分大小写），则启动 CSGO
  /// - 否则启动 CS2
  ///
  /// 注意：调用此方法前，CSGO 服务器应该已经通过 connectToServer 进行了检查
  Future<ServerConnectResult> _connectUsingSteamUrl(
    String serverAddress,
    String? password, {
    String? gameType,
  }) async {
    // Windows使用命令行方式
    if (PlatformUtils.isWindows) {
      return await _connectUsingCmdWindows(
        serverAddress,
        password,
        gameType: gameType,
      );
    }

    // 其他平台使用url_launcher
    try {
      LogService.d('使用Steam URL连接服务器: $serverAddress');

      // 构建Steam URL（统一格式，不区分 CS2 和 CSGO）
      String steamUrl;
      if (password != null && password.isNotEmpty) {
        steamUrl =
            'steam://run/$_cs2AppId//+connect $serverAddress +password $password';
      } else {
        steamUrl = 'steam://run/$_cs2AppId//+connect $serverAddress';
      }

      LogService.d('生成的Steam URL: $steamUrl');

      final uri = Uri.parse(steamUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.d('Steam URL连接命令已发送');

        return ServerConnectResult.success(
          message: '连接命令已发送',
          method: 'steam-url',
        );
      } else {
        LogService.e('无法打开Steam URL');
        return ServerConnectResult.failure('无法打开Steam，请确保Steam已安装');
      }
    } catch (e) {
      LogService.e('连接服务器失败', e);
      return ServerConnectResult.failure('连接服务器失败，请检查Steam是否正常运行');
    }
  }

  /// 启动游戏并连接到服务器
  ///
  /// [address] 服务器地址，格式为 ip:port 或 ip:port;password=xxx
  /// [gameType] 游戏类型，用于判断启动 CS2 还是 CSGO（可选）
  ///
  /// 注意：CSGO 服务器无法自动启动，会返回 needManualLaunch 错误
  Future<ServerConnectResult> launchAndConnect(
    String address, {
    String? gameType,
  }) async {
    if (!isDesktopPlatform) {
      return ServerConnectResult.failure('游戏启动功能仅支持桌面平台');
    }

    LogService.d('启动游戏并连接到服务器: $address, 游戏类型: $gameType');

    // 验证游戏类型是否匹配
    final typeValidation = await _validateGameTypeMatch(gameType);
    if (typeValidation != null) {
      return typeValidation; // 验证失败，返回错误
    }

    // 判断是否为 CSGO 服务器
    final isCsgo = ServerItemUtils.isCsgoServer(gameType);
    final isRunning = await isCS2Running();

    // 如果是 CSGO 服务器，无法自动启动
    if (isCsgo) {
      // 验证 CSGO 前置条件
      final csgoValidation = await _validateCsgoPrerequisites(
        isCsgo,
        isRunning,
      );
      if (csgoValidation != null) {
        return csgoValidation; // 验证失败，返回错误
      }

      // CSGO 已在运行，直接连接
      LogService.d('检测到 CSGO 正在运行，直接连接');
      return await connectToServer(address, gameType: gameType);
    }

    // CS2 服务器，正常启动并连接
    // 解析地址和密码
    String serverAddress;
    String? password;

    if (address.contains(';password=')) {
      final parts = address.split(';password=');
      serverAddress = parts[0];
      password = parts.length > 1 ? parts[1] : null;
    } else {
      serverAddress = address;
    }

    // 直接使用Steam URL启动并连接
    return await _connectUsingSteamUrl(
      serverAddress,
      password,
      gameType: gameType,
    );
  }

  // ==================== 配置管理 ====================

  /// 获取游戏路径
  Future<String?> getGamePath() async {
    return StorageUtils.getString(_keyGamePath);
  }

  /// 设置游戏路径
  Future<void> setGamePath(String path) async {
    await StorageUtils.setString(_keyGamePath, path);
    // 重置缓存，因为用户手动设置了路径
    _gamePathDetectionAttempted = false;
    _cachedGamePath = null;
    LogService.d('游戏路径已设置: $path');
  }

  /// 获取Steam路径
  Future<String?> getSteamPath() async {
    return StorageUtils.getString(_keySteamPath);
  }

  /// 设置Steam路径
  Future<void> setSteamPath(String path) async {
    await StorageUtils.setString(_keySteamPath, path);
    // 重置缓存，因为用户手动设置了路径
    _steamPathDetectionAttempted = false;
    _cachedSteamPath = null;
    LogService.d('Steam路径已设置: $path');
  }

  /// 获取启动平台
  Future<LaunchPlatform> getLaunchPlatform() async {
    final value = StorageUtils.getString(_keyLaunchPlatform);
    if (value == 'perfect') {
      return LaunchPlatform.perfect;
    }
    return LaunchPlatform.worldwide;
  }

  /// 设置启动平台
  Future<void> setLaunchPlatform(LaunchPlatform platform) async {
    await StorageUtils.setString(
      _keyLaunchPlatform,
      platform == LaunchPlatform.perfect ? 'perfect' : 'worldwide',
    );
    LogService.d(
      '启动平台已设置: ${platform == LaunchPlatform.perfect ? "完美世界" : "国际版"}',
    );
  }

  /// 获取自定义启动选项
  Future<List<String>> getLaunchOptions() async {
    return StorageUtils.getStringList(_keyLaunchOptions);
  }

  /// 设置自定义启动选项
  Future<void> setLaunchOptions(List<String> options) async {
    await StorageUtils.setStringList(_keyLaunchOptions, options);
    LogService.d('启动选项已设置: ${options.join(" ")}');
  }

  /// 自动检测Steam路径（仅Windows）
  /// 检测顺序：注册表 → 进程
  /// 带缓存，避免重复检测
  Future<String?> detectSteamPath() async {
    if (!PlatformUtils.isWindows) {
      return null;
    }

    // 如果已经尝试过检测，直接返回缓存结果
    if (_steamPathDetectionAttempted) {
      return _cachedSteamPath;
    }

    try {
      // 方法1: 从注册表查找
      final regPath = await _findSteamPathFromRegistry();
      if (regPath != null) {
        LogService.d('从注册表检测到Steam路径: $regPath');
        _steamPathDetectionAttempted = true;
        _cachedSteamPath = regPath;
        return regPath;
      }

      // 方法2: 从进程查找
      final processPath = await _findSteamPathFromProcess();
      if (processPath != null) {
        LogService.d('从进程检测到Steam路径: $processPath');
        _steamPathDetectionAttempted = true;
        _cachedSteamPath = processPath;
        return processPath;
      }

      LogService.d('未能自动检测到Steam路径');
      _steamPathDetectionAttempted = true;
      _cachedSteamPath = null;
      return null;
    } catch (e) {
      LogService.e('检测Steam路径失败', e);
      _steamPathDetectionAttempted = true;
      _cachedSteamPath = null;
      return null;
    }
  }

  /// 从注册表查找Steam路径
  Future<String?> _findSteamPathFromRegistry() async {
    try {
      final result = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Valve\\Steam',
        '/v',
        'SteamPath',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('SteamPath')) {
            // 格式: "    SteamPath    REG_SZ    C:/Program Files (x86)/Steam"
            final parts = line.split(RegExp(r'\s{4,}'));
            if (parts.length >= 3) {
              var steamPath = parts.last.trim();
              // 将正斜杠转换为反斜杠
              steamPath = steamPath.replaceAll('/', '\\');

              // 验证路径存在
              if (await File('$steamPath\\steam.exe').exists()) {
                return steamPath;
              }
            }
          }
        }
      }
    } catch (e) {
      LogService.d('从注册表查找Steam路径失败: $e');
    }
    return null;
  }

  /// 从进程查找Steam路径
  Future<String?> _findSteamPathFromProcess() async {
    try {
      final result = await Process.run('wmic', [
        'process',
        'where',
        "name='steam.exe'",
        'get',
        'ExecutablePath',
        '/format:value',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('ExecutablePath=')) {
            final executablePath = trimmed
                .substring('ExecutablePath='.length)
                .trim();
            if (executablePath.isNotEmpty &&
                executablePath.toLowerCase().endsWith('steam.exe')) {
              // 从可执行文件路径提取Steam安装目录
              final steamPath = File(executablePath).parent.path;
              LogService.d('从进程路径提取Steam目录: $steamPath');
              return steamPath;
            }
          }
        }
      }
    } catch (e) {
      LogService.d('从进程查找Steam路径失败: $e');
    }
    return null;
  }

  /// 自动检测游戏路径
  /// 带缓存，避免重复检测
  Future<String?> detectGamePath() async {
    // 如果已经尝试过检测，直接返回缓存结果
    if (_gamePathDetectionAttempted) {
      return _cachedGamePath;
    }

    try {
      // 优先从设置获取Steam路径
      String? steamPath = await getSteamPath();
      if (steamPath == null || steamPath.isEmpty) {
        steamPath = await detectSteamPath();
      }

      // 如果有Steam路径，检查默认游戏安装位置
      if (steamPath != null) {
        final gamePath =
            '$steamPath\\steamapps\\common\\Counter-Strike Global Offensive';
        final exePath = '$gamePath\\game\\bin\\win64\\cs2.exe';
        if (await File(exePath).exists()) {
          LogService.d('检测到游戏路径: $gamePath');
          _gamePathDetectionAttempted = true;
          _cachedGamePath = gamePath;
          return gamePath;
        }

        // 检查Steam库文件夹配置
        final libraryFoldersFile = File(
          '$steamPath\\steamapps\\libraryfolders.vdf',
        );
        if (await libraryFoldersFile.exists()) {
          try {
            final content = await libraryFoldersFile.readAsString();
            final pathRegex = RegExp(r'"path"\s+"([^"]+)"');
            final matches = pathRegex.allMatches(content);

            for (final match in matches) {
              final libPath = match.group(1)?.replaceAll('\\\\', '\\');
              if (libPath != null && libPath != steamPath) {
                final altGamePath =
                    '$libPath\\steamapps\\common\\Counter-Strike Global Offensive';
                final altExePath = '$altGamePath\\game\\bin\\win64\\cs2.exe';
                if (await File(altExePath).exists()) {
                  LogService.d('在Steam库中检测到游戏路径: $altGamePath');
                  _gamePathDetectionAttempted = true;
                  _cachedGamePath = altGamePath;
                  return altGamePath;
                }
              }
            }
          } catch (e) {
            LogService.d('解析Steam库文件夹失败: $e');
          }
        }
      }

      LogService.d('未能自动检测到游戏路径');
      _gamePathDetectionAttempted = true;
      _cachedGamePath = null;
      return null;
    } catch (e) {
      LogService.e('检测游戏路径失败', e);
      _gamePathDetectionAttempted = true;
      _cachedGamePath = null;
      return null;
    }
  }

  /// 重置路径检测缓存（当用户更新设置时调用）
  void resetPathCache() {
    _gamePathDetectionAttempted = false;
    _cachedGamePath = null;
    _steamPathDetectionAttempted = false;
    _cachedSteamPath = null;
    LogService.d('路径检测缓存已重置');
  }

  // ==================== Steam 启动选项自动配置 ====================

  /// CS2 的 AppID
  static const String _cs2AppIdForLaunchOptions = '730';

  /// Steam 用户服务单例
  final SteamUserService _steamUserService = SteamUserService();

  /// 查找匹配的右括号位置
  int _findMatchingBrace(String content, int openBracePos) {
    if (content[openBracePos] != '{') return -1;

    int depth = 1;
    int i = openBracePos + 1;

    while (i < content.length && depth > 0) {
      if (content[i] == '{') {
        depth++;
      } else if (content[i] == '}') {
        depth--;
      }
      i++;
    }

    return depth == 0 ? i - 1 : -1;
  }

  /// 获取当前登录的Steam用户ID
  Future<String?> _getCurrentSteamUserId() async {
    return await _steamUserService.getCurrentSteamUserId();
  }

  /// 获取 Steam 配置文件路径
  Future<String?> _getSteamConfigPath() async {
    String? steamPath = await getSteamPath();
    if (steamPath == null || steamPath.isEmpty) {
      steamPath = await detectSteamPath();
    }
    if (steamPath == null) {
      LogService.d('无法获取Steam路径');
      return null;
    }

    LogService.d('Steam安装路径: $steamPath');

    final userId = await _getCurrentSteamUserId();
    if (userId == null) {
      LogService.d('无法获取Steam用户ID');
      return null;
    }
    LogService.d('Steam用户ID: $userId');

    final path = '$steamPath\\userdata\\$userId\\config\\localconfig.vdf';
    LogService.d('Steam配置文件完整路径: $path');
    return path;
  }

  /// 读取当前 CS2 的启动选项
  ///
  /// LaunchOptions 存储在 Software\Valve\Steam\apps\{AppID}\LaunchOptions
  Future<String?> _getCurrentLaunchOptions() async {
    final configPath = await _getSteamConfigPath();
    if (configPath == null) {
      LogService.d('无法获取Steam配置路径');
      return null;
    }

    try {
      final file = File(configPath);
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final lines = content.split('\n');

      // 复用解析逻辑
      return _parseLaunchOptionsFromLines(lines);
    } catch (e) {
      LogService.d('读取启动选项失败: $e');
      return null;
    }
  }

  /// 在已解析的行中查找 CS2 的 LaunchOptions
  String? _parseLaunchOptionsFromLines(List<String> lines) {
    // 第一步：找到 apps 块
    int appsBlockLine = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('"apps"')) {
        appsBlockLine = i;
        LogService.d('找到 apps 块，行号: $i');
        break;
      }
    }

    if (appsBlockLine < 0) {
      LogService.d('未找到 apps 块');
      return null;
    }

    // 第二步：在 apps 块内查找 730 游戏
    int braceDepth = 0;
    bool inAppBlock = false;
    bool inAppsBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 先找到 apps 块开始
      if (!inAppsBlock && line.contains('"apps"')) {
        inAppsBlock = true;
        LogService.d('进入 apps 块，行号: $i');
      }

      if (inAppsBlock) {
        // 统计括号变化
        int lineBraceChange = 0;
        for (final char in line.runes) {
          if (char == 123) {
            lineBraceChange++;
          } else if (char == 125) {
            lineBraceChange--;
          }
        }

        // 查找 730 块开始
        if (!inAppBlock &&
            braceDepth == 0 &&
            line.contains('"$_cs2AppIdForLaunchOptions"')) {
          inAppBlock = true;
          braceDepth += lineBraceChange;
          LogService.d('找到 730 应用块，行号: $i，括号深度: $braceDepth');
        } else if (inAppBlock) {
          braceDepth += lineBraceChange;
        }

        // 如果在 730 块内
        if (inAppBlock && braceDepth >= 0) {
          // 检查是否离开 730 块
          if (braceDepth < 0) {
            LogService.d('退出 730 应用块，行号: $i');
            inAppBlock = false;
            continue;
          }

          // 检查是否有 LaunchOptions
          if (line.contains('"LaunchOptions"')) {
            LogService.d('找到 LaunchOptions 行: ${lines[i].trim()}');

            // 尝试匹配 LaunchOptions 值
            final match = RegExp(
              r'"LaunchOptions"[ \t]+"([^"]*)"',
            ).firstMatch(line);
            if (match != null) {
              LogService.d('解析到的启动选项: ${match.group(1)}');
              return match.group(1);
            }
          }
        }
      }
    }

    LogService.d('未找到 CS2 的启动选项');
    return null;
  }

  /// 检查是否已经配置了 -condebug
  Future<bool> isCondebugConfigured() async {
    final currentOptions = await _getCurrentLaunchOptions();
    if (currentOptions == null || currentOptions.isEmpty) return false;

    // 检查是否包含 -condebug（不区分大小写）
    final optionsLower = currentOptions.toLowerCase();
    return optionsLower.contains('-condebug');
  }

  /// 自动配置 Steam 启动选项，添加 -condebug
  ///
  /// 返回值：
  /// - true: 配置成功
  /// - false: 配置失败或用户取消
  Future<bool> autoConfigureCondebug() async {
    if (!PlatformUtils.isWindows) {
      LogService.w('自动配置启动选项仅支持Windows平台');
      return false;
    }

    LogService.d('开始自动配置 Steam 启动选项...');

    // 获取 Steam 配置路径
    final configPath = await _getSteamConfigPath();
    if (configPath == null) {
      LogService.e('无法获取Steam配置文件路径');
      return false;
    }

    LogService.d('配置文件路径: $configPath');

    final file = File(configPath);
    if (!await file.exists()) {
      LogService.e('Steam配置文件不存在: $configPath');
      return false;
    }

    try {
      // 读取现有配置
      var content = await file.readAsString();
      LogService.d('配置文件大小: ${content.length} 字节');

      // 将内容分割成行
      final lines = content.split('\n');

      // 直接解析，避免重复读取文件
      final currentOptions = _parseLaunchOptionsFromLines(lines);
      LogService.d('当前启动选项: ${currentOptions ?? "(空)"}');

      String newOptions;
      if (currentOptions != null && currentOptions.isNotEmpty) {
        // 如果已有启动选项，检查是否已包含 -condebug
        if (currentOptions.toLowerCase().contains('-condebug')) {
          LogService.d('Steam启动选项已包含 -condebug，无需修改');
          return true;
        }
        // 在现有选项基础上添加 -condebug
        newOptions = '$currentOptions -condebug';
        LogService.d('现有启动选项: $currentOptions，添加 -condebug');
      } else {
        // 新建启动选项
        newOptions = '-condebug';
        LogService.d('设置新的启动选项: -condebug');
      }

      // 更新配置文件
      // LaunchOptions 存储在 Software\Valve\Steam\apps\{AppID}\LaunchOptions
      // 如果 LaunchOptions 不存在，需要在 apps 块中添加游戏配置
      if (currentOptions == null || currentOptions.isEmpty) {
        LogService.d('需要新建 LaunchOptions 条目');

        // 检查是否已存在 730 块但没有 LaunchOptions
        final appBlockExists = content.contains('"$_cs2AppIdForLaunchOptions"');
        LogService.d('730 块是否已存在: $appBlockExists');

        if (appBlockExists) {
          // 730块存在但没有LaunchOptions，需要添加
          LogService.d('730 块存在，尝试在块内添加 LaunchOptions');

          // 找到 730 块的起始和结束位置
          final appBlockStart = content.indexOf('"$_cs2AppIdForLaunchOptions"');
          final afterAppId = content.indexOf('{', appBlockStart);
          final closingBrace = _findMatchingBrace(content, afterAppId);

          if (afterAppId > 0 && closingBrace > afterAppId) {
            // 在 730 块的第一个 } 前添加 LaunchOptions
            final insertContent =
                '''
		"LaunchOptions"		"$newOptions"
''';
            content =
                content.substring(0, closingBrace) +
                insertContent +
                content.substring(closingBrace);
            LogService.d('已在 730 块内添加 LaunchOptions');
          } else {
            LogService.e('无法找到 730 块的正确位置');
            return false;
          }
        } else {
          // 730 块完全不存在，需要创建
          LogService.d('730 块不存在，需要新建');

          // 查找 apps 块的位置
          final appsPattern = RegExp(r'"apps"\s*\{');
          final appsMatch = appsPattern.firstMatch(content);

          if (appsMatch != null) {
            LogService.d('找到 apps 块，插入位置: ${appsMatch.end}');
            // 在 apps 块开头添加新的游戏配置
            final insertPos = appsMatch.end;
            final newSection =
                '''
	"$_cs2AppIdForLaunchOptions"
	{
		"LaunchOptions"		"$newOptions"
	}
''';
            content =
                content.substring(0, insertPos) +
                newSection +
                content.substring(insertPos);
          } else {
            LogService.d('未找到 apps 块，尝试在 Steam 块中添加');
            // 如果没有找到 apps 块，尝试在 Steam 块中添加
            final steamPattern = RegExp(r'"Steam"\s*\{');
            final steamMatch = steamPattern.firstMatch(content);
            if (steamMatch != null) {
              final insertPos = steamMatch.end;
              final newSection =
                  '''
	"apps"
	{
	"$_cs2AppIdForLaunchOptions"
	{
		"LaunchOptions"		"$newOptions"
	}
}
''';
              content =
                  content.substring(0, insertPos) +
                  newSection +
                  content.substring(insertPos);
            } else {
              LogService.e('无法找到配置块位置');
              return false;
            }
          }
        }
      } else {
        // 更新现有的 LaunchOptions
        LogService.d('更新现有的 LaunchOptions');

        // 第一步：找到 apps 块的起始位置
        int appsBlockLine = -1;
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('"apps"')) {
            appsBlockLine = i;
            LogService.d('找到 apps 块，行号: $i');
            break;
          }
        }

        if (appsBlockLine < 0) {
          LogService.e('未找到 apps 块');
          return false;
        }

        // 第二步：在 apps 块内查找 730 游戏
        int braceDepth = 0;
        bool inAppBlock = false;
        bool inAppsBlock = false;
        int launchOptionsLine = -1;
        int lineNum = 0;

        for (final line in lines) {
          // 先找到 apps 块开始
          if (!inAppsBlock && line.contains('"apps"')) {
            inAppsBlock = true;
            LogService.d('进入 apps 块，行号: $lineNum');
          }

          if (inAppsBlock) {
            // 统计括号变化
            int lineBraceChange = 0;
            for (final char in line.runes) {
              if (char == 123) {
                lineBraceChange++;
              } else if (char == 125) {
                lineBraceChange--;
              }
            }

            // 查找 730 块开始
            if (!inAppBlock &&
                braceDepth == 0 &&
                line.contains('"$_cs2AppIdForLaunchOptions"')) {
              inAppBlock = true;
              braceDepth += lineBraceChange;
              LogService.d('进入 730 块，行号: $lineNum');
            } else if (inAppBlock) {
              braceDepth += lineBraceChange;
            }

            // 如果在 730 块内，查找 LaunchOptions
            if (inAppBlock && braceDepth >= 0) {
              if (line.contains('"LaunchOptions"')) {
                launchOptionsLine = lineNum;
                LogService.d('在 730 块内找到 LaunchOptions，行号: $lineNum');
                break;
              }

              // 退出 730 块
              if (braceDepth < 0) {
                LogService.d('退出 730 块，行号: $lineNum');
                inAppBlock = false;
              }
            }
          }
          lineNum++;
        }

        if (launchOptionsLine >= 0) {
          // 找到了 LaunchOptions 行，替换值
          final oldLine = lines[launchOptionsLine];
          LogService.d('找到 LaunchOptions 行: ${oldLine.trim()}');

          // 提取旧的选项值
          final match = RegExp(
            r'"LaunchOptions"[ \t]+"([^"]*)"',
          ).firstMatch(oldLine);
          if (match != null) {
            LogService.d('旧启动选项: ${match.group(1)}');

            // 替换该行
            final newLine = oldLine.replaceFirst(
              RegExp(r'"LaunchOptions"[ \t]+"[^"]*"'),
              '"LaunchOptions"		"$newOptions"',
            );
            lines[launchOptionsLine] = newLine;
            content = lines.join('\n');
            LogService.d('已更新 LaunchOptions 为: $newOptions');
          } else {
            LogService.e('无法解析 LaunchOptions 行: $oldLine');
            return false;
          }
        } else {
          LogService.e('在 730 块内未找到 LaunchOptions');
          return false;
        }
      }

      // 写入配置文件
      await file.writeAsString(content);
      LogService.d('Steam 启动选项已配置: $newOptions');

      // 注意：需要提示用户重启Steam才能生效
      return true;
    } catch (e) {
      LogService.e('配置Steam启动选项失败: $e');
      return false;
    }
  }

  /// 确保 Steam 启动选项已配置 -condebug
  ///
  /// 如果未配置，会自动配置并返回 true（需要用户重启Steam）
  /// 如果已配置，返回 true
  /// 如果配置失败，返回 false
  Future<bool> ensureCondebugConfigured() async {
    if (!PlatformUtils.isWindows) {
      return false;
    }

    // 检查是否已配置
    final isConfigured = await isCondebugConfigured();
    if (isConfigured) {
      LogService.d('Steam 启动选项已配置 -condebug');
      return true;
    }

    // 未配置，尝试自动配置
    LogService.d('Steam 启动选项未配置 -condebug，正在自动配置...');
    return await autoConfigureCondebug();
  }
}
