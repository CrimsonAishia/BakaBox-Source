import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/gsi_models.dart';
import '../utils/log_service.dart';
import 'game_launcher_service.dart';
import 'game_path_service.dart';

/// GSI 服务状态
class GsiStatus {
  final bool enabled;
  final bool running;
  final int port;
  final bool hasData;

  const GsiStatus({
    this.enabled = false,
    this.running = false,
    this.port = 59595,
    this.hasData = false,
  });
}

/// GSI 服务 - 接收 CS2 游戏状态数据
class GsiService {
  static final GsiService _instance = GsiService._internal();
  factory GsiService() => _instance;
  GsiService._internal();

  final GamePathService _gamePathService = GamePathService();
  final GameLauncherService _gameLauncherService = GameLauncherService();

  HttpServer? _server;
  bool _enabled = false;
  int _port = 59595;
  GsiGameState? _latestState;
  bool _isRunning = false;

  final List<GsiGameLog> _gameLogs = [];
  static const int _maxGameLogs = 50;

  // 状态变化流
  final _stateController = StreamController<GsiGameState?>.broadcast();
  Stream<GsiGameState?> get stateStream => _stateController.stream;

  // 日志变化流
  final _logController = StreamController<List<GsiGameLog>>.broadcast();
  Stream<List<GsiGameLog>> get logStream => _logController.stream;

  /// 获取最新状态
  GsiGameState? get latestState => _latestState;

  /// 获取游戏日志
  List<GsiGameLog> get gameLogs => List.unmodifiable(_gameLogs);

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// GSI 是否处于活跃可用状态（HTTP 服务在运行且近期收到过游戏数据）。
  ///
  /// 用于在游戏未带 -condebug（不可监控）时，判断能否依赖 GSI 信号
  /// 验证"是否真正进入服务器"，从而避免挤服时"命令一发就乐观判成功"
  /// 导致的假成功（别人看到进去又出来、自己也无从判断）。
  ///
  /// 时效窗口取 90s：CS2 在主菜单也会按 heartbeat 周期推送，
  /// 近期有数据即说明 GSI 配置已就位、端点连通。
  bool get isLive {
    if (!_isRunning) return false;
    final received = _latestState?.receivedAt;
    if (received == null) return false;
    return DateTime.now().difference(received) < const Duration(seconds: 90);
  }

  /// 当前端口
  int get port => _port;

  /// 初始化服务（应用启动时调用）
  Future<void> initialize() async {
    LogService.i('[GSI] 服务初始化完成');
  }

  /// 启动 GSI 服务
  Future<({bool success, String? error})> start() async {
    if (_isRunning) {
      return (success: false, error: 'GSI 服务已在运行');
    }

    // 检查端口占用
    if (await _isPortInUse(_port)) {
      LogService.w('[GSI] 端口 $_port 已被占用，尝试自动切换端口');
      final newPort = await _findAvailablePort(_port);
      if (newPort == 0) {
        return (success: false, error: '端口被占用且无法自动切换，请稍后重试');
      }
      _port = newPort;
      LogService.i('[GSI] 已切换到可用端口: $newPort');
    }

    // 检查并安装/更新配置文件（会自动检测端口是否匹配）
    LogService.i('[GSI] 检查配置文件...');
    final installResult = await installConfigFile();
    if (!installResult.success) {
      LogService.w('[GSI] 配置文件安装失败: ${installResult.error}，服务仍将启动');
    } else if (installResult.needRestart) {
      LogService.w('[GSI] 配置已更新，但游戏正在运行，需要重启游戏后 GSI 才能生效');
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      LogService.i('[GSI] 服务启动在端口 $_port');

      _server!.listen(_handleRequest);
      _isRunning = true;
      _enabled = true;

      return (success: true, error: null);
    } catch (e) {
      LogService.e('[GSI] 启动服务失败', e);
      return (success: false, error: '启动 GSI 服务失败: $e');
    }
  }

  /// 停止 GSI 服务
  Future<({bool success, String? error})> stop() async {
    if (!_isRunning) {
      return (success: false, error: 'GSI 服务未运行');
    }

    try {
      await _server?.close(force: true);
      _server = null;
      _isRunning = false;
      _enabled = false;
      LogService.i('[GSI] 服务已停止');
      return (success: true, error: null);
    } catch (e) {
      LogService.e('[GSI] 停止服务失败', e);
      return (success: false, error: '停止 GSI 服务失败: $e');
    }
  }

  /// 处理 HTTP 请求
  void _handleRequest(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('只接受 POST 请求')
        ..close();
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final gameState = GsiGameState.fromJson(json);

      // 不验证 Token，因为只监听本地回环地址，安全性已足够

      gameState.receivedAt = DateTime.now();
      _latestState = gameState;
      _stateController.add(gameState);

      // 保存日志
      _addGameLog(body, gameState);

      if (gameState.player != null) {
        LogService.d(
          '[GSI] 数据接收: 玩家=${gameState.player!.name}, '
          '队伍=${gameState.player!.team}, 活动=${gameState.player!.activity}',
        );
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write('OK')
        ..close();
    } catch (e) {
      LogService.e('[GSI] 处理请求失败', e);
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('解析数据失败')
        ..close();
    }
  }

  /// 添加游戏日志
  void _addGameLog(String rawJson, GsiGameState gameState) {
    final summary = StringBuffer();

    if (gameState.player != null) {
      final health = gameState.player!.state?.health ?? 0;
      final money = gameState.player!.state?.money ?? 0;
      summary.write(
        '玩家: ${gameState.player!.name} | '
        '队伍: ${gameState.player!.team} | '
        '生命: $health | 金钱: \$$money | '
        '活动: ${gameState.player!.activity}',
      );
    }

    if (gameState.map != null) {
      summary.write(
        ' | 地图: ${gameState.map!.name} | '
        '回合: ${gameState.map!.round} | '
        '阶段: ${gameState.map!.phase}',
      );
    }

    final log = GsiGameLog(
      timestamp: DateTime.now(),
      rawJson: rawJson,
      summary: summary.toString(),
    );

    _gameLogs.add(log);
    if (_gameLogs.length > _maxGameLogs) {
      _gameLogs.removeAt(0);
    }

    _logController.add(List.unmodifiable(_gameLogs));
  }

  /// 清空游戏日志
  void clearGameLogs() {
    _gameLogs.clear();
    _logController.add([]);
    LogService.i('[GSI] 游戏日志已清空');
  }

  /// 获取服务状态
  GsiStatus getStatus() {
    return GsiStatus(
      enabled: _enabled,
      running: _isRunning,
      port: _port,
      hasData: _latestState != null,
    );
  }

  /// 获取游戏路径（优先已保存的，否则自动检测）
  Future<String?> _getGamePath() async {
    // 优先使用已保存的路径
    String? gamePath = await _gamePathService.getGamePath();
    if (gamePath != null && gamePath.isNotEmpty) {
      return gamePath;
    }

    // 使用 GameLauncherService 的检测方法（有更完善的注册表查询）
    gamePath = await _gameLauncherService.detectGamePath();
    if (gamePath != null) {
      LogService.i('[GSI] 自动检测到游戏路径: $gamePath');
    }
    return gamePath;
  }

  /// 安装 GSI 配置文件到 CS2 目录
  /// [force] 强制覆盖，即使端口匹配也重新写入
  /// 返回 needRestart 表示游戏正在运行，需要重启才能生效
  Future<({bool success, String? error, String? path, bool needRestart})>
  installConfigFile({bool force = false}) async {
    final gamePath = await _getGamePath();

    if (gamePath == null || gamePath.isEmpty) {
      LogService.w('[GSI] 无法获取游戏路径');
      return (
        success: false,
        error: '无法自动检测游戏路径，请在设置中手动配置',
        path: null,
        needRestart: false,
      );
    }

    final cfgDir =
        '$gamePath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg';
    final dir = Directory(cfgDir);
    if (!await dir.exists()) {
      LogService.w('[GSI] 配置目录不存在: $cfgDir');
      return (
        success: false,
        error: '配置目录不存在: $cfgDir\n请确认游戏路径是否正确',
        path: null,
        needRestart: false,
      );
    }

    final configFileName = 'gamestate_integration_bakabox.cfg';
    final configFilePath = '$cfgDir${Platform.pathSeparator}$configFileName';

    // 检查现有配置文件的端口是否匹配
    final existingFile = File(configFilePath);
    if (await existingFile.exists() && !force) {
      final content = await existingFile.readAsString();
      if (content.contains(':$_port"')) {
        LogService.i('[GSI] 配置文件已存在且端口匹配，无需更新');
        return (
          success: true,
          error: null,
          path: configFilePath,
          needRestart: false,
        );
      }
      LogService.i('[GSI] 配置文件端口不匹配，需要更新');
    }

    // 检查游戏是否运行
    final gameRunning = await _gameLauncherService.isCS2Running();

    final configContent = _generateConfigFileContent();
    try {
      await File(configFilePath).writeAsString(configContent);
      LogService.i('[GSI] 配置文件已安装到: $configFilePath');

      if (gameRunning) {
        LogService.w('[GSI] 游戏正在运行，配置需要重启游戏后生效');
      }

      return (
        success: true,
        error: null,
        path: configFilePath,
        needRestart: gameRunning,
      );
    } catch (e) {
      LogService.e('[GSI] 写入配置文件失败', e);
      return (
        success: false,
        error: '写入配置文件失败: $e',
        path: null,
        needRestart: false,
      );
    }
  }

  /// 移除 GSI 配置文件
  Future<({bool success, String? error})> removeConfigFile() async {
    final gamePath = await _getGamePath();
    if (gamePath == null || gamePath.isEmpty) {
      return (success: false, error: '游戏路径未设置');
    }

    final cfgDir =
        '$gamePath${Platform.pathSeparator}game${Platform.pathSeparator}csgo${Platform.pathSeparator}cfg';
    final configFilePath =
        '$cfgDir${Platform.pathSeparator}gamestate_integration_bakabox.cfg';

    final file = File(configFilePath);
    if (!await file.exists()) {
      return (success: false, error: '配置文件不存在');
    }

    try {
      await file.delete();
      LogService.i('[GSI] 配置文件已移除: $configFilePath');
      return (success: true, error: null);
    } catch (e) {
      LogService.e('[GSI] 删除配置文件失败', e);
      return (success: false, error: '删除配置文件失败: $e');
    }
  }

  /// 生成配置文件内容
  String _generateConfigFileContent() {
    return '''"BakaBox GSI Configuration"
{
	"uri" "http://127.0.0.1:$_port"
	"timeout" "5.0"
	"buffer" "0.1"
	"throttle" "0.5"
	"heartbeat" "30.0"
	"data"
	{
		"provider"              "1"
		"map"                   "1"
		"round"                 "1"
		"player_id"             "1"
		"player_state"          "1"
		"player_weapons"        "1"
		"player_match_stats"    "1"
		"player_position"       "1"
		"allplayers_id"         "1"
		"allplayers_state"      "1"
		"allplayers_match_stats" "1"
		"allplayers_position"   "1"
		"allplayers_weapons"    "1"
		"bomb"                  "1"
		"phase_countdowns"      "1"
	}
}
''';
  }

  /// 检查端口是否被占用
  Future<bool> _isPortInUse(int port) async {
    try {
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await server.close();
      return false;
    } catch (_) {
      return true;
    }
  }

  /// 查找可用端口
  Future<int> _findAvailablePort(int startPort) async {
    for (var port = startPort + 1; port < startPort + 100; port++) {
      if (!await _isPortInUse(port)) {
        return port;
      }
    }
    return 0;
  }

  /// 生成随机令牌（保留备用）
  // String _generateRandomToken(int length) {
  //   const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  //   final random = Random.secure();
  //   return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  // }

  /// 清理资源
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
    await _logController.close();
  }
}
