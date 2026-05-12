import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/lobby/lobby_bloc.dart';
import '../../../core/models/lobby_models.dart';
import '../../../core/services/lobby_map_loader_service.dart';
import '../../../core/utils/log_service.dart';
import '../../../desktop/games/lobby_game.dart';

/// 移动端大厅地图场景组件
///
/// 复用桌面端的 [LobbyGame] 引擎，但去掉鼠标悬停等桌面交互。
class LobbySceneMobile extends StatefulWidget {
  final LobbyMapConfig mapConfig;
  final LobbyState state;

  const LobbySceneMobile({
    super.key,
    required this.mapConfig,
    required this.state,
  });

  @override
  State<LobbySceneMobile> createState() => _LobbySceneMobileState();
}

class _LobbySceneMobileState extends State<LobbySceneMobile> {
  LobbyGame? _game;
  StreamSubscription<MapLoadState>? _mapLoadSubscription;
  MapLoadState? _currentMapState;
  bool _isWaitingForMapLoad = false;
  bool _isTransitioning = false;
  String? _targetMapId;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void didUpdateWidget(LobbySceneMobile oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newMapId = widget.mapConfig.mapId;
    final oldMapId = oldWidget.mapConfig.mapId;

    if (newMapId != oldMapId) {
      LogService.d('[LobbySceneMobile] 地图切换 $oldMapId -> $newMapId');
      _handleMapChange(newMapId);
      return;
    }

    // sprites 列表有新增时重建游戏
    final oldIds = oldWidget.state.availableSprites.map((s) => s.id).toSet();
    final newIds = widget.state.availableSprites.map((s) => s.id).toSet();
    if (newIds.difference(oldIds).isNotEmpty) {
      LogService.d('[LobbySceneMobile] 发现新增 sprite，重新创建游戏');
      _disposeGame();
      _createGame();
    }
  }

  Future<void> _handleMapChange(String newMapId) async {
    if (_isWaitingForMapLoad && _targetMapId == newMapId) return;

    _listenToMapLoadState(newMapId);

    if (LobbyMapLoaderService.instance.isMapReady(newMapId)) {
      _performMapSwitch(newMapId);
    } else {
      _isWaitingForMapLoad = true;
      _targetMapId = newMapId;
      LobbyMapLoaderService.instance.preloadMap(widget.mapConfig);
    }
  }

  void _listenToMapLoadState(String mapId) {
    _mapLoadSubscription?.cancel();
    _mapLoadSubscription =
        LobbyMapLoaderService.instance.getStateStream(mapId).listen((state) {
      if (!mounted) return;
      setState(() => _currentMapState = state);
      if (state.isReady && _isWaitingForMapLoad && _targetMapId == mapId) {
        _isWaitingForMapLoad = false;
        _performMapSwitch(mapId);
      }
    });
  }

  void _performMapSwitch(String newMapId) {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _disposeGame();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _createGame();
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
    _game = LobbyGame(
      bloc: context.read<LobbyBloc>(),
      mapConfig: widget.mapConfig,
      users: state.users,
      sprites: state.availableSprites,
      showNameplates: state.showNameplates,
      showChatBubbles: state.showChatBubbles,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isTransitioning) {
      return Container(color: Colors.black);
    }

    if (_isWaitingForMapLoad || _game == null) {
      return _MobileLoadingPlaceholder(
        mapState: _currentMapState,
        isDark: Theme.of(context).brightness == Brightness.dark,
      );
    }

    return RepaintBoundary(
      child: ExcludeFocus(
        child: GameWidget<LobbyGame>.controlled(
          gameFactory: () => _game!,
          backgroundBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MobileLoadingPlaceholder extends StatelessWidget {
  final MapLoadState? mapState;
  final bool isDark;

  const _MobileLoadingPlaceholder({this.mapState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0B1120), const Color(0xFF1A1F2E)]
              : [const Color(0xFFDDE7F7), const Color(0xFFE8EEF7)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '正在加载地图...',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            if (mapState != null && mapState!.progress > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 140,
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
            ],
          ],
        ),
      ),
    );
  }
}
