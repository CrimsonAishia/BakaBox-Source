import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';
import '../../../core/services/lobby_map_loader_service.dart';
import '../../../core/utils/log_service.dart';
import '../../games/lobby_game.dart';
import 'lobby_user_profile_panel.dart';

/// 大厅地图场景组件
///
/// 负责创建和管理 Flame 游戏实例，通过 Bloc 订阅状态变化，
class LobbyScene extends StatefulWidget {
  final LobbyMapConfig mapConfig;
  final LobbyState state;
  final FocusNode sceneFocusNode;

  const LobbyScene({
    super.key,
    required this.mapConfig,
    required this.state,
    required this.sceneFocusNode,
  });

  @override
  State<LobbyScene> createState() => _LobbySceneState();
}

class _LobbySceneState extends State<LobbyScene> with TickerProviderStateMixin {
  LobbyGame? _game;

  /// 地图加载状态监听
  StreamSubscription<MapLoadState>? _mapLoadSubscription;
  MapLoadState? _currentMapState;

  /// 是否正在等待地图加载
  bool _isWaitingForMapLoad = false;

  /// 是否正在过渡中
  bool _isTransitioning = false;

  /// 目标地图 ID（等待加载的）
  String? _targetMapId;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void didUpdateWidget(LobbyScene oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newMapId = widget.mapConfig.mapId;
    final oldMapId = oldWidget.mapConfig.mapId;

    // 情况1：地图切换
    if (newMapId != oldMapId) {
      LogService.d('[LobbyScene] 地图切换 $oldMapId -> $newMapId');
      _handleMapChange(newMapId);
      return;
    }

    // 情况2：sprites 列表有新增 sprite，需要重建游戏以加载新资源
    final oldSprites = oldWidget.state.availableSprites;
    final newSprites = widget.state.availableSprites;
    final oldIds = oldSprites.map((s) => s.id).toSet();
    final newIds = newSprites.map((s) => s.id).toSet();
    final newSpriteAdded = newIds.difference(oldIds).isNotEmpty;

    if (newSpriteAdded) {
      LogService.d('[LobbyScene] 发现新增 sprite，重新创建游戏: ${newIds.difference(oldIds)}');
      _disposeGame();
      _createGame();
    }
  }

  /// 处理地图切换
  Future<void> _handleMapChange(String newMapId) async {
    // 如果已经在等待这个地图，直接返回
    if (_isWaitingForMapLoad && _targetMapId == newMapId) {
      return;
    }

    // 先监听地图加载状态
    _listenToMapLoadState(newMapId);

    // 检查地图是否已加载
    if (LobbyMapLoaderService.instance.isMapReady(newMapId)) {
      LogService.d('[LobbyScene] 地图已就绪，直接切换: $newMapId');
      _performMapSwitch(newMapId);
    } else {
      // 地图尚未加载，设置为等待状态并开始预加载
      LogService.d('[LobbyScene] 地图需要加载，等待加载: $newMapId');
      _isWaitingForMapLoad = true;
      _targetMapId = newMapId;

      // 开始预加载地图
      LobbyMapLoaderService.instance.preloadMap(widget.mapConfig);
    }
  }

  /// 监听地图加载状态
  void _listenToMapLoadState(String mapId) {
    _mapLoadSubscription?.cancel();

    _mapLoadSubscription = LobbyMapLoaderService.instance
        .getStateStream(mapId)
        .listen((state) {
      if (!mounted) return;

      setState(() {
        _currentMapState = state;
      });

      // 如果地图加载完成且正在等待，进行切换
      if (state.isReady && _isWaitingForMapLoad && _targetMapId == mapId) {
        LogService.d('[LobbyScene] 地图加载完成，开始切换: $mapId');
        _isWaitingForMapLoad = false;
        _performMapSwitch(mapId);
      }
    });
  }

  /// 执行地图切换
  void _performMapSwitch(String newMapId) {
    if (_isTransitioning) return;

    _isTransitioning = true;

    // 销毁旧游戏
    _disposeGame();

    // 短暂延迟后创建新游戏（让黑色背景先显示）
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _createGame();

      // 再延迟一小段时间确保游戏已加载
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _isTransitioning = false;
        setState(() {});
      });

      setState(() {});
    });

    setState(() {});
  }

  @override
  void dispose() {
    _mapLoadSubscription?.cancel();
    _disposeGame();
    super.dispose();
  }

  void _disposeGame() {
    if (_game != null) {
      _game!.onRemove();
      _game = null;
    }
  }

  void _createGame() {
    if (!mounted) return;

    final state = widget.state;
    LogService.d('[LobbyScene] _createGame: users=${state.users.length} sprites=${state.availableSprites.length}');

    _game = LobbyGame(
      bloc: context.read<LobbyBloc>(),
      mapConfig: widget.mapConfig,
      users: state.users,
      sprites: state.availableSprites,
      showNameplates: state.showNameplates,
      showChatBubbles: state.showChatBubbles,
    );

    // 设置调查用户回调
    _game!.onInvestigateUser = (user) {
      if (mounted) {
        LobbyUserProfilePanel.show(context, user);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (event) {
            // 右键点击转发给游戏
            if (event.buttons == kSecondaryMouseButton) {
              _game?.handleSecondaryTapDown(event);
            }
          },
          child: MouseRegion(
            onHover: (event) {
              _game?.handleHoverMove(event);
            },
            onExit: (event) {
              _game?.handleHoverExit();
            },
            child: _buildMainContent(isDark),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(bool isDark) {
    // 过渡期间显示黑色背景
    if (_isTransitioning) {
      return Container(color: Colors.black);
    }

    // 等待地图加载时显示占位符
    if (_isWaitingForMapLoad || _game == null) {
      return _LoadingPlaceholder(
        key: ValueKey('loading_${widget.mapConfig.mapId}'),
        mapState: _currentMapState,
        isDark: isDark,
      );
    }

    // 游戏实例
    return GameWidget<LobbyGame>.controlled(
      gameFactory: () => _game!,
      backgroundBuilder: (_) => const SizedBox.expand(),
    );
  }
}

/// 地图加载占位符组件
class _LoadingPlaceholder extends StatelessWidget {
  final MapLoadState? mapState;
  final bool isDark;

  const _LoadingPlaceholder({
    super.key,
    this.mapState,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF0B1120),
                  const Color(0xFF1A1F2E),
                ]
              : [
                  const Color(0xFFDDE7F7),
                  const Color(0xFFE8EEF7),
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 加载指示器
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 加载文字
            Text(
              _getLoadingText(),
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            // 进度条（如果有进度信息）
            if (mapState != null && mapState!.progress > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  value: mapState!.progress,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFCBD5E1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF3B82F6),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(mapState!.progress * 100).toInt()}%',
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLoadingText() {
    if (mapState == null) {
      return '正在加载地图...';
    }
    switch (mapState!.status) {
      case MapLoadStatus.loading:
        return '正在加载地图...';
      case MapLoadStatus.loaded:
        return '地图已加载';
      case MapLoadStatus.error:
        return '地图加载失败';
      case MapLoadStatus.unloaded:
        return '等待加载...';
    }
  }
}
