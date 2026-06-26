import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/server/server_bloc.dart';
import '../../../core/bloc/server/server_event.dart';
import '../../../core/models/server_models.dart';
import '../../../core/services/obs_server_service.dart';
import '../../../core/services/console_log_service.dart';
import '../../../core/services/game_status_service.dart';
import '../../../core/services/source_server_service.dart';
import '../../../core/api/server_api.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../core/utils/toast_utils.dart';

// 导入拆分出去的子组件
import 'obs_element_renderers.dart';
import 'obs_floating_panel.dart';

// 导出拆分出去的子组件
export 'obs_element_renderers.dart';
export 'obs_color_picker.dart';
export 'obs_floating_panel.dart';
export 'obs_utils.dart';

class ObsTool extends StatefulWidget {
  const ObsTool({super.key});

  @override
  State<ObsTool> createState() => _ObsToolState();
}

class _ObsToolState extends State<ObsTool> {
  List<Map<String, dynamic>> _elements = [];

  final String _obsUrl = 'http://127.0.0.1:25566/obs';
  String? _selectedElementId;
  bool _showAddMenu = false;
  Offset? _panelPosition;
  bool _obsEnabled = false; // OBS 投屏功能开关

  // 文本组件的 TextEditingController 映射
  final Map<String, TextEditingController> _textControllers = {};

  // 画布分辨率
  static const double _canvasWidth = 1920.0;
  static const double _canvasHeight = 1080.0;

  String? _lastFetchedMapName;

  SourceServerInfo? _queriedServerInfo;
  MapData? _queriedMapData;
  String? _queriedAddress;
  String? _queriedDisplayName;
  String? _lastRefreshedAddress; // 用于避免重复刷新

  static const List<Map<String, dynamic>> _availableComponents = [
    {
      'type': 'server_card',
      'name': '服务器卡片',
      'icon': Icons.dns,
      'description': '显示服务器信息卡片，含地图背景',
    },
    {
      'type': 'text',
      'name': '文本信息',
      'icon': Icons.text_fields,
      'description': '自定义文本，支持变量替换',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureServersLoaded();
      _loadLayout();
      _loadPanelPosition();
      _loadObsEnabled();
      // 如果 OBS 功能之前已开启，则自动启动服务
      if (_obsEnabled) {
        _initObsService();
      }
    });
  }

  /// 初始化 OBS 服务
  Future<void> _initObsService() async {
    await ObsServerService().start();
    _syncToObsService();
  }

  /// 加载面板位置
  void _loadPanelPosition() {
    final savedX =
        StorageUtils.getDouble('obs_panel_position_x', defaultValue: 24.0) ??
        24.0;
    final savedY =
        StorageUtils.getDouble('obs_panel_position_y', defaultValue: 24.0) ??
        24.0;
    _panelPosition = Offset(savedX, savedY);
    setState(() {});
  }

  /// 保存面板位置
  void _savePanelPosition() {
    if (_panelPosition != null) {
      StorageUtils.setDouble('obs_panel_position_x', _panelPosition!.dx);
      StorageUtils.setDouble('obs_panel_position_y', _panelPosition!.dy);
    }
  }

  void _loadObsEnabled() {
    _obsEnabled = StorageUtils.getBool('obs_tool_enabled', defaultValue: false);
    setState(() {});
  }

  void _toggleObsEnabled(bool value) {
    setState(() {
      _obsEnabled = value;
    });
    StorageUtils.setBool('obs_tool_enabled', value);
    if (value) {
      _initObsService();
    } else {
      ObsServerService().stop();
    }
  }

  void _ensureServersLoaded() {
    try {
      final serverBloc = context.read<ServerBloc>();
      if (serverBloc.state.serverCategories.isEmpty &&
          !serverBloc.state.isLoading) {
        serverBloc.add(ServerFetchList());
      }
    } catch (_) {}
  }

  void _refreshMapInfoIfNeeded(ExtendedServerItem server) {
    final currentMapName = server.serverData?.map;
    if (currentMapName == null) return;

    if (currentMapName != _lastFetchedMapName) {
      _lastFetchedMapName = currentMapName;
      _fetchServerAndMapInfo(
        server.serverItem.address ?? server.serverItem.serverAddress ?? '',
      );
    }
  }

  Future<void> _fetchServerAndMapInfo(String address) async {
    try {
      final parts = address.split(':');
      if (parts.length != 2) return;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return;

      _queriedAddress = address;

      String? listServerNickname;
      try {
        final serverBloc = context.read<ServerBloc>();
        for (var category in serverBloc.state.serverCategories) {
          for (var item in category.serverList) {
            final itemAddress = item.address ?? item.serverAddress;
            if (itemAddress == address) {
              listServerNickname = item.nickname;
              break;
            }
          }
          if (listServerNickname != null) break;
        }
      } catch (_) {}

      final info = await SourceServerService.getServerInfo(
        ip,
        port,
        timeout: 3000,
      );
      if (info != null) {
        final displayName =
            listServerNickname != null && listServerNickname.isNotEmpty
            ? listServerNickname
            : info.name;
        _queriedServerInfo = info;
        _queriedDisplayName = displayName;

        final serverApi = ServerApi();
        final mapData = await serverApi.refreshMapInfo(info.map, address: address);
        if (mounted) {
          setState(() {
            _queriedMapData = mapData;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // 清理所有 TextEditingControllers
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  void _loadLayout() {
    try {
      final savedStr = StorageUtils.getString('obs_tool_elements');
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);

        List<Map<String, dynamic>>? elements;

        if (decoded is Map &&
            decoded.containsKey('elements') &&
            decoded['elements'] is List) {
          elements = List<Map<String, dynamic>>.from(decoded['elements']);
        } else if (decoded is List && decoded.isNotEmpty) {
          elements = List<Map<String, dynamic>>.from(decoded);
        }

        if (elements != null && elements.isNotEmpty) {
          setState(() {
            _elements = elements!;
            for (var el in _elements) {
              _applyDefaultElementValues(el);
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncToObsService();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load OBS layout: $e');
    }
  }

  void _applyDefaultElementValues(Map<String, dynamic> el) {
    if (el['type'] == 'server_card') {
      el['titleFontSize'] ??= 20.0;
      el['mapFontSize'] ??= 16.0;
      el['ipFontSize'] ??= 15.0;
      el['showMapImage'] ??= true;
      el['showIp'] ??= true;
      el['showPing'] ??= false;
      el['showPlayers'] ??= true;
      el['showMap'] ??= true;
      el['showTitle'] ??= true;
      el['gradientOpacity'] ??= 0.6;
      el['bgBlur'] ??= 0.0;
    }
    if (el['type'] == 'text') {
      el['fontSize'] ??= 24.0;
      el['fontWeight'] ??= 'bold';
      el['textColor'] ??= '#FFFFFF';
      el['backgroundColor'] ??= '#80000000';
      el['showBackground'] ??= true;
      el['textAlign'] ??= 'left';
      el['fontStyle'] ??= 'normal';
      el['decoration'] ??= 'none';
      el['showTextShadow'] ??= true;
      el['shadowBlur'] ??= 4.0;
      el['shadowOffset'] ??= 2.0;
      el['padding'] ??= 12.0;
      el['borderRadius'] ??= 8.0;
    }
  }

  void _syncToObsService() {
    final layout = {'elements': _elements};
    ObsServerService().updateLayout(layout);
  }

  void _saveLayout() {
    if (_elements.isEmpty) return;

    final layout = {'elements': _elements};
    StorageUtils.setString('obs_tool_elements', jsonEncode(layout));
    _syncToObsService();
  }

  void _addComponent(String type) {
    // 先创建元素，获取其 id
    final newElement = _createDefaultElement(type);
    final id = newElement['id'] as String;

    // 为文本元素创建 TextEditingController
    if (type == 'text' && !_textControllers.containsKey(id)) {
      _textControllers[id] = TextEditingController(
        text: newElement['template']?.toString() ?? '',
      );
    }

    setState(() {
      _elements.add(newElement);
      _selectedElementId = id;
      _showAddMenu = false;
    });
    _saveLayout();
  }

  Map<String, dynamic> _createDefaultElement(String type) {
    switch (type) {
      case 'server_card':
        final id = 'card-${DateTime.now().millisecondsSinceEpoch}';
        return {
          'id': id,
          'type': 'server_card',
          'x': 100.0,
          'y': 100.0,
          'scale': 1.0,
          'showMapImage': true,
          'showIp': true,
          'showPing': false,
          'showPlayers': true,
          'showMap': true,
          'showTitle': true,
          'titleFontSize': 20.0,
          'mapFontSize': 16.0,
          'ipFontSize': 15.0,
          'gradientOpacity': 0.6,
          'bgBlur': 0.0,
        };
      case 'text':
        final id = 'text-${DateTime.now().millisecondsSinceEpoch}';
        return {
          'id': id,
          'type': 'text',
          'x': 100.0,
          'y': 300.0,
          'scale': 1.0,
          'template': '服务器: {serverName}\n地图: {map}\nIP: {ip}\n人数: {players}',
          'fontSize': 24.0,
          'fontWeight': 'bold',
          'textColor': '#FFFFFF',
          'backgroundColor': '#80000000',
          'showBackground': true,
          'textAlign': 'left',
          'fontStyle': 'normal',
          'decoration': 'none',
          'showTextShadow': true,
          'shadowBlur': 4.0,
          'shadowOffset': 2.0,
          'padding': 12.0,
          'borderRadius': 8.0,
        };
      default:
        final id = '$type-${DateTime.now().millisecondsSinceEpoch}';
        return {'id': id, 'type': type};
    }
  }

  void _removeElement(String id) {
    // 清理对应的 TextEditingController
    _textControllers[id]?.dispose();
    _textControllers.remove(id);

    setState(() {
      _elements.removeWhere((e) => e['id'] == id);
      if (_selectedElementId == id) {
        _selectedElementId = null;
      }
    });
    _saveLayout();
  }

  void _selectElement(String? id) {
    setState(() {
      _selectedElementId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ExtendedServerItem? mockServer;
    bool isConnected = false;

    try {
      final consoleLogService = ConsoleLogService();
      final consoleState = consoleLogService.currentState;
      final isInServerFromConsole =
          consoleState.isInServer && consoleState.serverAddress.isNotEmpty;

      if (isInServerFromConsole) {
        final currentServerAddress = consoleState.serverAddress;

        final serverState = context.watch<ServerBloc>().state;

        for (var ext in serverState.servers) {
          final address =
              ext.serverItem.address ?? ext.serverItem.serverAddress;
          if (address == currentServerAddress && ext.serverData != null) {
            mockServer = ext;
            isConnected = true;
            // 只有地址变化时才刷新
            if (_lastRefreshedAddress != currentServerAddress) {
              _lastRefreshedAddress = currentServerAddress;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _refreshMapInfoIfNeeded(ext);
              });
            }
            break;
          }
        }

        if (mockServer == null && isInServerFromConsole) {
          isConnected = true;
          // 只有地址变化时才刷新
          if (_lastRefreshedAddress != currentServerAddress) {
            _lastRefreshedAddress = currentServerAddress;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (currentServerAddress.isNotEmpty) {
                _fetchServerAndMapInfo(currentServerAddress);
              }
            });
          }
        }
      } else {
        // 不在服务器中时重置标志
        _lastRefreshedAddress = null;
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        _buildCanvas(
                          context,
                          mockServer,
                          isConnected,
                          _queriedServerInfo,
                          _queriedMapData,
                          constraints.maxHeight,
                        ),
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: _buildAddButton(context),
                        ),
                        if (_showAddMenu)
                          Positioned(
                            right: 24,
                            bottom: 84,
                            child: _buildAddMenu(context),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // 浮动设置面板
          _buildFloatingPanelOverlay(context),
        ],
      ),
    );
  }

  /// 构建浮动设置面板
  Widget _buildFloatingPanelOverlay(BuildContext context) {
    if (_selectedElementId == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height;

    return _buildFloatingPanel(context, availableHeight);
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.live_tv, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          // OBS 功能开关
          _buildObsServiceSwitch(context),
          const SizedBox(width: 12),
          // 游戏监控状态
          _buildGameStatusIndicator(context),
          const Spacer(),
          // 提示：如果 OBS 看不到内容，需要刷新浏览器源
          Tooltip(
            message:
                '如果 OBS 浏览器源未显示，请在 OBS 中选中该浏览器源，并点击上方的"刷新"按钮，一般是先启动OBS在启动BakaBox导致的',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    '不显示？',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => _showTutorial(context),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('使用教程'),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _obsUrl));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已复制服务器地址 ($_obsUrl)')));
            },
            icon: const Icon(Icons.link, size: 18),
            label: const Text('复制OBS插件地址'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    ExtendedServerItem? mockServer,
    bool isConnected, [
    SourceServerInfo? queriedInfo,
    MapData? queriedMapData,
    double? availableHeight,
  ]) {
    final theme = Theme.of(context);

    // 画布分辨率
    final canvasWidth = _canvasWidth;
    final canvasHeight = _canvasHeight;
    final aspectRatio = canvasWidth / canvasHeight;

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border.all(color: theme.colorScheme.outline, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final renderScale = constraints.maxWidth / canvasWidth;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.8,
                        child: Image.asset(
                          'assets/images/queue/queue_background.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              '${canvasWidth.toInt()} x ${canvasHeight.toInt()} 预览画布',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_elements.isEmpty)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_box_outlined,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '点击右下角 + 添加组件',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._elements.map((el) {
                      final isSelected = el['id'] == _selectedElementId;
                      // 根据元素类型设置默认尺寸
                      final elementWidth = el['type'] == 'server_card'
                          ? 450.0
                          : 200.0;
                      final elementHeight = el['type'] == 'server_card'
                          ? 140.0
                          : 50.0;
                      final scale = (el['scale'] as num?)?.toDouble() ?? 1.0;
                      // 基于元素实际大小计算边界
                      final maxX = canvasWidth - (elementWidth * scale);
                      final maxY = canvasHeight - (elementHeight * scale);
                      return Positioned(
                        left: (el['x'] as num).toDouble() * renderScale,
                        top: (el['y'] as num).toDouble() * renderScale,
                        child: GestureDetector(
                          onTap: () => _selectElement(el['id']),
                          onPanUpdate: (details) {
                            setState(() {
                              _selectedElementId = el['id'];
                              el['x'] =
                                  ((el['x'] as num).toDouble() +
                                          details.delta.dx / renderScale)
                                      .clamp(
                                        0.0,
                                        maxX > 0 ? maxX : canvasWidth - 100,
                                      );
                              el['y'] =
                                  ((el['y'] as num).toDouble() +
                                          details.delta.dy / renderScale)
                                      .clamp(
                                        0.0,
                                        maxY > 0 ? maxY : canvasHeight - 50,
                                      );
                            });
                          },
                          onPanEnd: (_) => _saveLayout(),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.move,
                            child: Transform.scale(
                              scale: (el['scale'] as num?)?.toDouble() ?? 1.0,
                              alignment: Alignment.topLeft,
                              child: Transform.scale(
                                scale: renderScale,
                                alignment: Alignment.topLeft,
                                child: Container(
                                  decoration: isSelected
                                      ? BoxDecoration(
                                          border: Border.all(
                                            color: theme.colorScheme.primary,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        )
                                      : null,
                                  child: buildElementMock(
                                    el,
                                    mockServer,
                                    isConnected,
                                    queriedInfo,
                                    queriedMapData,
                                    _queriedDisplayName,
                                    _queriedAddress,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final theme = Theme.of(context);

    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _showAddMenu = !_showAddMenu;
        });
      },
      backgroundColor: _showAddMenu
          ? theme.colorScheme.secondary
          : theme.colorScheme.primaryContainer,
      child: Icon(
        _showAddMenu ? Icons.close : Icons.add,
        color: _showAddMenu
            ? theme.colorScheme.onSecondary
            : theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildAddMenu(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('选择组件', style: theme.textTheme.titleSmall),
            ),
            const Divider(),
            ..._availableComponents.map((component) {
              return ListTile(
                leading: Icon(component['icon']),
                title: Text(component['name']),
                subtitle: Text(
                  component['description'],
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                ),
                onTap: () => _addComponent(component['type']),
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingPanel(BuildContext context, double availableHeight) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 安全检查：如果没有元素或找不到对应元素，直接返回空
    if (_elements.isEmpty) {
      return const SizedBox();
    }

    // 查找匹配的元素，如果找不到则返回 null 而不是第一个元素
    Map<String, dynamic>? matchedElement;
    try {
      matchedElement = _elements.firstWhere(
        (e) => e['id'] == _selectedElementId,
      );
    } catch (_) {
      matchedElement = null;
    }

    // 如果没有匹配的元素，清除选择状态
    if (matchedElement == null) {
      _selectedElementId = null;
      return const SizedBox();
    }

    final el = matchedElement;

    double panelWidth = 320.0;
    double panelHeight = 500.0;
    double bottomMargin = 24.0;

    // 初始化面板位置，如果之前保存的位置超出当前屏幕范围则重置为默认值
    _panelPosition ??= const Offset(24.0, 24.0);

    // 检查保存的位置是否在当前屏幕有效范围内，如果超出则重置
    final maxX = screenSize.width - panelWidth;
    final maxY = screenSize.height - panelHeight - bottomMargin;
    if (_panelPosition!.dx < 0 ||
        _panelPosition!.dx > maxX ||
        _panelPosition!.dy < 0 ||
        _panelPosition!.dy > maxY) {
      _panelPosition = const Offset(24.0, 24.0);
    }

    double dx = _panelPosition!.dx.clamp(0.0, maxX);
    double dy = _panelPosition!.dy.clamp(0.0, maxY);

    return buildObsFloatingPanel(
      context: context,
      theme: theme,
      screenSize: screenSize,
      panelWidth: panelWidth,
      panelPosition: _panelPosition!,
      dx: dx,
      dy: dy,
      element: el,
      textControllers: _textControllers,
      onPositionChanged: (newPosition) {
        setState(() {
          _panelPosition = newPosition;
        });
        _savePanelPosition();
      },
      onClose: () => _selectElement(null),
      onDelete: () => _removeElement(el['id']),
      onSave: _saveLayout,
      onChanged: () {
        setState(() {});
      },
    );
  }

  void _showTutorial(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 680,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.live_tv,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OBS 投屏工具',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '将游戏状态实时投屏到 OBS',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // 内容
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 游戏启动说明
                      _buildTutorialSection(
                        context,
                        icon: Icons.play_circle_outline,
                        title: '游戏启动说明',
                        color: Colors.redAccent,
                        children: [
                          _buildStepRow(
                            context,
                            '1',
                            '使用 BakaBox 启动游戏',
                            '软件会自动添加监控所需的参数',
                          ),
                          _buildStepRow(
                            context,
                            '2',
                            '使用 Steam 启动游戏',
                            '请手动给 Steam 的 CS2 游戏添加 -condebug 启动项',
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 36,
                              top: 4,
                              bottom: 8,
                            ),
                            child: Text(
                              '注意：必须使用上述方法之一启动游戏，否则将无法监控游戏状态。',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 快速开始卡片
                      _buildTutorialSection(
                        context,
                        icon: Icons.flash_on,
                        title: '快速开始',
                        color: Colors.amber,
                        children: [
                          _buildStepRow(context, '1', '点击右下角 + 按钮', '添加组件到画布'),
                          _buildStepRow(context, '2', '拖拽组件', '调整在画面中的位置'),
                          _buildStepRow(context, '3', '点击组件', '打开属性设置面板'),
                          _buildStepRow(
                            context,
                            '4',
                            '复制 OBS 地址',
                            '在 OBS 中添加浏览器源',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 组件说明
                      _buildTutorialSection(
                        context,
                        icon: Icons.widgets,
                        title: '组件说明',
                        color: Colors.blue,
                        children: [
                          _buildComponentCard(
                            context,
                            icon: Icons.dns,
                            name: '服务器卡片',
                            desc: '显示当前游戏服务器信息',
                            features: ['服务器名称', '地图及背景', '玩家人数'],
                          ),
                          const SizedBox(height: 12),
                          _buildComponentCard(
                            context,
                            icon: Icons.text_fields,
                            name: '文本信息',
                            desc: '自由定义的自定义文本',
                            features: ['支持变量替换', '自定义颜色', '背景样式', '文字阴影'],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 变量说明
                      _buildTutorialSection(
                        context,
                        icon: Icons.code,
                        title: '变量占位符',
                        color: Colors.green,
                        children: [
                          _buildVarChip(context, '{serverName}', '服务器名称'),
                          _buildVarChip(context, '{map}', '当前地图'),
                          _buildVarChip(context, '{ip}', '服务器地址'),
                          _buildVarChip(context, '{players}', '玩家人数'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // OBS 设置
                      _buildTutorialSection(
                        context,
                        icon: Icons.settings_suggest,
                        title: 'OBS 配置步骤',
                        color: Colors.purple,
                        children: [
                          _buildObsStep(context, '1', '添加浏览器源', '右键来源 → 浏览器'),
                          // 图片1：右键添加浏览器源
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/tutorials/obs_add_browser_source.png',
                                width: 400,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          ),
                          // 图片2：浏览器源设置页面（包含URL、分辨率、CSS）
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/tutorials/obs_browser_settings.png',
                                width: 400,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          ),
                          _buildObsStep(
                            context,
                            '2',
                            '设置参数',
                            '填写 URL、分辨率，添加自定义 CSS',
                          ),
                          // URL
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Material(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _obsUrl),
                                  );
                                  ToastUtils.showSuccess(context, '已复制 URL');
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.link,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _obsUrl,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '点击复制',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // CSS
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Material(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          'body { margin: 0; background: transparent; }',
                                    ),
                                  );
                                  ToastUtils.showSuccess(context, '已复制 CSS 代码');
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.copy,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'body { margin: 0; background: transparent; }',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '点击复制',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 底部按钮
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildStepRow(
    BuildContext context,
    String num,
    String title,
    String desc,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                num,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(
            desc,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentCard(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String desc,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: features
                .take(4)
                .map(
                  (f) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVarChip(BuildContext context, String varName, String desc) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            varName,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            desc,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildObsStep(
    BuildContext context,
    String num,
    String title,
    String desc,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            desc,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// 构建 OBS 服务开关组件
  Widget _buildObsServiceSwitch(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _obsEnabled
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _obsEnabled
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _obsEnabled ? Icons.play_circle : Icons.pause_circle,
            size: 16,
            color: _obsEnabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            _obsEnabled ? '服务运行中' : '服务已停止',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _obsEnabled ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 20,
            child: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: _obsEnabled,
                onChanged: _toggleObsEnabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建游戏监控状态指示器
  Widget _buildGameStatusIndicator(BuildContext context) {
    // 从 GameStatusService 获取游戏状态
    bool isMonitorable = false;

    try {
      final gameStatusService = GameStatusService();
      isMonitorable = gameStatusService.isMonitorable;
    } catch (_) {}

    // 只有游戏可监控（带 -condebug 启动）时才显示监控中
    final bool isMonitoring = isMonitorable;

    return Tooltip(
      preferBelow: false,
      message: isMonitoring ? '' : '请使用 BakaBox 启动游戏',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMonitoring
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMonitoring
                ? Colors.green.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMonitoring ? Icons.check_circle : Icons.visibility_off,
              size: 16,
              color: isMonitoring ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              isMonitoring ? '监控中' : '未启动游戏',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isMonitoring ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
