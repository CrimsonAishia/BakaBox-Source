import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  /// 当前鼠标光标
  MouseCursor _currentCursor = SystemMouseCursors.basic;

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
      LogService.d(
        '[LobbyScene] 发现新增 sprite，重新创建游戏: ${newIds.difference(oldIds)}',
      );
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
    LogService.d(
      '[LobbyScene] _createGame: users=${state.users.length} sprites=${state.availableSprites.length}',
    );

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
        return MouseRegion(
          cursor: _currentCursor,
          onHover: (event) {
            _game?.handleHoverMove(event);
            _updateCursor();
          },
          onExit: (event) {
            _game?.handleHoverExit();
            if (_currentCursor != SystemMouseCursors.basic) {
              setState(() {
                _currentCursor = SystemMouseCursors.basic;
              });
            }
          },
          child: Stack(
            children: [
              Positioned.fill(child: _buildMainContent(isDark)),
              // 聚焦角色时的周围模糊高亮特效
              Positioned.fill(
                child: IgnorePointer(child: _buildFocusOverlay()),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 根据游戏 hover 状态更新鼠标光标
  void _updateCursor() {
    final newCursor = (_game != null && _game!.isHoveringInteractablePlayer)
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic;
    if (newCursor != _currentCursor) {
      setState(() {
        _currentCursor = newCursor;
      });
    }
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

  /// 聚焦特效层：每帧从游戏拉取聚光灯位置，舞台剧式聚光（周围变暗 + 顶部光束）
  Widget _buildFocusOverlay() {
    final game = _game;
    if (game == null) return const SizedBox.shrink();
    return _LobbyFocusSpotlightOverlay(game: game);
  }
}

/// 地图加载占位符组件
class _LoadingPlaceholder extends StatelessWidget {
  final MapLoadState? mapState;
  final bool isDark;

  const _LoadingPlaceholder({super.key, this.mapState, required this.isDark});

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
                    isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
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

/// 舞台剧式聚光灯特效层
///
/// 当聚焦某个角色时：
/// 1. 整个场景变暗（暗色蒙版）
/// 2. 角色周围保留一圈柔和的亮区（聚光池）
/// 3. 从屏幕顶部向角色打下一束渐隐的光束（舞台灯效果）
///
/// 自带 [Ticker] 每帧主动从 [LobbyGame] 拉取聚光灯位置，
/// 避免在 Flame 游戏循环里触发 Flutter 重建导致的 setState during build 异常。
class _LobbyFocusSpotlightOverlay extends StatefulWidget {
  final LobbyGame game;

  const _LobbyFocusSpotlightOverlay({required this.game});

  @override
  State<_LobbyFocusSpotlightOverlay> createState() =>
      _LobbyFocusSpotlightOverlayState();
}

class _LobbyFocusSpotlightOverlayState
    extends State<_LobbyFocusSpotlightOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// 当前聚光灯信息（每帧从游戏拉取）
  LobbyFocusSpotlight? _spotlight;

  /// 最近一次有效的聚光灯信息（用于淡出时保持位置）
  LobbyFocusSpotlight? _lastSpotlight;

  /// 0~1 特效强度（用于淡入淡出）
  double _intensity = 0.0;

  Duration _lastTick = Duration.zero;

  static const double _fadeInSpeed = 3.2; // 约 0.31 秒淡入
  static const double _fadeOutSpeed = 4.5; // 约 0.22 秒淡出

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final next = widget.game.computeFocusSpotlight();
    if (next != null) _lastSpotlight = next;

    // 目标强度：有聚焦 -> 1，无聚焦 -> 0
    final target = next != null ? 1.0 : 0.0;
    double newIntensity = _intensity;
    if (target > _intensity) {
      newIntensity = (_intensity + dt * _fadeInSpeed).clamp(0.0, 1.0);
    } else if (target < _intensity) {
      newIntensity = (_intensity - dt * _fadeOutSpeed).clamp(0.0, 1.0);
    }

    final changed = next != _spotlight || newIntensity != _intensity;
    if (changed && mounted) {
      setState(() {
        _spotlight = next;
        _intensity = newIntensity;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_intensity <= 0.001) return const SizedBox.shrink();
    final spotlight = _spotlight ?? _lastSpotlight;
    if (spotlight == null) return const SizedBox.shrink();

    return CustomPaint(
      painter: _SpotlightPainter(spotlight: spotlight, intensity: _intensity),
    );
  }
}

/// 绘制舞台聚光灯：暗场蒙版 + 中心亮池 + 顶部光束
class _SpotlightPainter extends CustomPainter {
  final LobbyFocusSpotlight spotlight;

  /// 0~1 特效强度（用于淡入淡出）
  final double intensity;

  _SpotlightPainter({required this.spotlight, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = spotlight.center;
    final radius = spotlight.radius;
    final fullRect = Offset.zero & size;

    // ── 1. 暗场蒙版：整体变暗，仅在角色周围精确挖出一个柔和亮池 ──
    // 用 saveLayer + dstOut 精确控制亮池半径（像素级），只聚焦这个人。
    canvas.saveLayer(fullRect, Paint());
    // 全屏暗色
    canvas.drawRect(
      fullRect,
      Paint()..color = Colors.black.withValues(alpha: 0.74 * intensity),
    );
    // 挖空中心亮池（dstOut：径向渐变，中心完全清除、边缘平滑过渡）
    final holePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = RadialGradient(
        colors: [
          Colors.black,
          Colors.black,
          Colors.black.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, holePaint);
    canvas.restore();

    // ── 2. 顶部光束：从屏幕顶部向角色打下的梯形光锥 ──
    _drawLightBeam(canvas, size, center, radius);

    // ── 3. 中心亮池：角色身上的柔和高光，强化聚光感 ──
    final poolPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF6D8).withValues(alpha: 0.20 * intensity),
          const Color(0xFFFFF1C4).withValues(alpha: 0.07 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, poolPaint);
  }

  /// 绘制从顶部打向角色的梯形光束
  void _drawLightBeam(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
  ) {
    // 光束顶部（屏幕外上方）较窄，底部（角色处）略宽，形成贴合角色的光锥
    final topWidth = radius * 0.4;
    final bottomWidth = radius * 1.25;
    final topY = -40.0;
    final bottomY = center.dy + radius * 0.45;
    final apexX = center.dx;

    final beamPath = Path()
      ..moveTo(apexX - topWidth / 2, topY)
      ..lineTo(apexX + topWidth / 2, topY)
      ..lineTo(apexX + bottomWidth / 2, bottomY)
      ..lineTo(apexX - bottomWidth / 2, bottomY)
      ..close();

    // 光束渐变：顶部更亮，向下逐渐淡出
    final beamPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFF8E1).withValues(alpha: 0.18 * intensity),
          const Color(0xFFFFF3D0).withValues(alpha: 0.10 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTRB(apexX - bottomWidth / 2, topY,
          apexX + bottomWidth / 2, bottomY))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawPath(beamPath, beamPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight ||
        oldDelegate.intensity != intensity;
  }
}
