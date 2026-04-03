import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../core/core.dart';
import 'lobby_player_component.dart';

/// 大厅场景游戏引擎
/// 负责高效渲染地图背景、渐变叠加层和角色节点
class LobbyGame extends FlameGame with HasCollisionDetection, TapCallbacks, HoverCallbacks {
  LobbyGame({
    required LobbyBloc bloc,
    required LobbyMapConfig mapConfig,
    required List<LobbyUser> users,
    required List<LobbySprite> sprites,
    required bool showNameplates,
    required bool showChatBubbles,
  })  : _bloc = bloc,
        _initialMapConfig = mapConfig,
        _initialUsers = users,
        _initialSprites = sprites,
        _initialShowNameplates = showNameplates,
        _initialShowChatBubbles = showChatBubbles {
    _init();
  }

  void _init() {
    _stateSubscription = _bloc.stream.listen(_onStateChanged);
  }

  final LobbyBloc _bloc;
  late final StreamSubscription<LobbyState> _stateSubscription;

  final LobbyMapConfig _initialMapConfig;
  final List<LobbyUser> _initialUsers;
  final List<LobbySprite> _initialSprites;
  final bool _initialShowNameplates;
  final bool _initialShowChatBubbles;

  /// 相机组件
  late final CameraComponent _cameraComponent;

  /// 世界尺寸（地图实际尺寸）
  late Vector2 _worldSize;

  /// 背景层组件
  late final BackgroundComponent _backgroundLayer;
  late final GradientOverlayComponent _gradientLayer;

  /// 传送门组件列表
  final List<PortalComponent> _portalComponents = [];
  /// 当前悬停的传送门
  PortalComponent? _hoveredPortal;

  /// 目标位置标记组件（显示红色叉号）
  TargetMarkerComponent? _targetMarker;

  /// 当前玩家正在移动的目标位置
  LobbyPosition? _currentTargetPosition;

  /// 世界根组件（包含所有游戏对象，相机对其生效）
  late final World _world;
  final Map<String, LobbyPlayerComponent> _playerComponents = {};

  LobbyMapConfig? _mapConfig;
  List<LobbySprite> _sprites = [];
  bool _showNameplates = false;
  bool _showChatBubbles = false;
  bool _isInitialized = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 初始化状态
    _mapConfig = _initialMapConfig;
    _sprites = _initialSprites;
    _showNameplates = _initialShowNameplates;
    _showChatBubbles = _initialShowChatBubbles;

    // 世界尺寸 = 地图实际尺寸
    _worldSize = Vector2(_mapConfig!.width, _mapConfig!.height);

    // 创建世界根组件
    _world = World();

    // 创建相机组件，跟随当前玩家
    _cameraComponent = CameraComponent(world: _world);
    _cameraComponent.viewfinder.anchor = Anchor.topLeft;

    // 添加世界和相机
    await add(_world);
    await add(_cameraComponent);

    // 创建背景层和渐变层，加入世界
    _backgroundLayer = BackgroundComponent(
      mapConfig: _mapConfig!,
      worldSize: _worldSize,
    );
    _gradientLayer = GradientOverlayComponent(worldSize: _worldSize);
    await _world.add(_backgroundLayer);
    await _world.add(_gradientLayer);

    // 创建传送门组件
    await _updatePortalComponents();

    // 添加角色组件到世界
    for (final user in _initialUsers) {
      await _addPlayerComponent(user);
    }

    LogService.d('[LobbyGame] onLoad 完成: playersAdded=${_initialUsers.length} worldChildren=${_world.children.length}');

    // 初始相机跟随当前玩家（如果有）
    _followCurrentPlayer();

    _isInitialized = true;
  }

  /// 更新传送门组件
  Future<void> _updatePortalComponents() async {
    if (_mapConfig == null) return;

    // 移除旧的传送门组件
    for (final portal in _portalComponents) {
      portal.removeFromParent();
    }
    _portalComponents.clear();

    // 创建新的传送门组件
    for (final portalConfig in _mapConfig!.portals) {
      final portalComponent = PortalComponent(
        portal: portalConfig,
        onClick: (clickPos) => _bloc.add(LobbyPortalClicked(clickPos)),
      );
      await _world.add(portalComponent);
      _portalComponents.add(portalComponent);
    }
  }

  /// 相机跟随当前玩家（每帧调用，驱动插值跟随）
  void _followCurrentPlayer() {
    final selfUser = _bloc.state.selfUser;
    if (selfUser == null) return;

    // 传送时优先使用传送目标位置
    final teleportTarget = _bloc.state.teleportTarget;
    LobbyPosition targetPos;
    if (teleportTarget != null && _bloc.state.isTeleporting) {
      targetPos = teleportTarget.position;
    } else {
      // 优先使用玩家组件的实时插值位置，fallback 到服务器位置
      final playerComp = _playerComponents[selfUser.userId];
      if (playerComp != null) {
        targetPos = playerComp.currentRenderPosition;
      } else {
        targetPos = selfUser.targetPosition ?? selfUser.renderPosition;
      }
    }

    final screenCenter = _cameraComponent.viewport.size / 2;

    // 计算目标相机位置，确保角色在屏幕中心
    double targetCamX = targetPos.x - screenCenter.x;
    double targetCamY = targetPos.y - screenCenter.y;

    // 边界限制：相机不能超出世界范围
    final maxX = math.max(0.0, _worldSize.x - _cameraComponent.viewport.size.x);
    final maxY = math.max(0.0, _worldSize.y - _cameraComponent.viewport.size.y);
    targetCamX = targetCamX.clamp(0.0, maxX);
    targetCamY = targetCamY.clamp(0.0, maxY);

    // 平滑插值跟随（只在地图大于视野时生效）
    final lerpSpeed = _getCameraLerpSpeed();
    final currentCam = _cameraComponent.viewfinder.position;
    final newCamX = lerp(currentCam.x, targetCamX, lerpSpeed);
    final newCamY = lerp(currentCam.y, targetCamY, lerpSpeed);

    _cameraComponent.viewfinder.position = Vector2(newCamX, newCamY);
  }

  /// 根据地图与视野的关系计算相机插值速度
  /// - 地图 <= 视野：角色始终在视野内，相机固定（不插值）
  /// - 地图 > 视野：相机平滑跟随角色
  double _getCameraLerpSpeed() {
    final viewportSize = _cameraComponent.viewport.size;
    final mapWider = _worldSize.x > viewportSize.x;
    final mapTaller = _worldSize.y > viewportSize.y;

    if (!mapWider && !mapTaller) {
      // 地图小于等于视野，相机固定居中（一次设置完成）
      return 1.0;
    }

    // 地图大于视野，平滑跟随（约 0.12 ≈ 8 帧到达目标位置）
    return 0.12;
  }

  static double lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }

  void _onStateChanged(LobbyState state) {
    if (!_isInitialized) return;

    // 更新 sprites 列表（如果 assets 变化）
    if (state.assets.sprites.isNotEmpty && state.assets.sprites != _sprites) {
      _sprites = state.assets.sprites;
    }

    // 更新地图配置
    if (state.mapConfig != null && state.mapConfig != _mapConfig) {
      _mapConfig = state.mapConfig;
      _worldSize = Vector2(_mapConfig!.width, _mapConfig!.height);
      _backgroundLayer.updateMapConfig(_mapConfig!);
      _backgroundLayer.updateWorldSize(_worldSize);
      _gradientLayer.updateWorldSize(_worldSize);
      // 更新传送门组件
      _updatePortalComponents();
    }

    // 更新用户列表
    _syncUsers(state.users, state);

    // 更新显示设置
    _showNameplates = state.showNameplates;
    _showChatBubbles = state.showChatBubbles;

    // 更新目标位置标记（显示红色叉号）
    _updateTargetMarker(state);

    // 更新所有角色组件的显示设置
    for (final component in _playerComponents.values) {
      component.updateDisplaySettings(
        showNameplate: _showNameplates,
        showChatBubble: _showChatBubbles,
      );
    }

    // 相机跟随当前玩家
    _followCurrentPlayer();
  }

  /// 更新目标位置标记（显示红色叉号）
  void _updateTargetMarker(LobbyState state) {
    // 获取当前用户
    final selfUser = state.selfUser;
    if (selfUser == null) {
      // 没有当前用户，移除标记
      _clearTargetMarker();
      return;
    }

    // 检查是否有目标位置且正在移动
    if (selfUser.targetPosition != null && selfUser.isMoving) {
      final targetPos = selfUser.targetPosition!;
      // 检查是否需要更新或创建标记
      if (_currentTargetPosition?.x != targetPos.x ||
          _currentTargetPosition?.y != targetPos.y) {
        _currentTargetPosition = targetPos;
        _showTargetMarker(targetPos);
      }
    } else {
      // 没有移动目标，移除标记
      _clearTargetMarker();
    }
  }

  /// 显示目标位置标记
  void _showTargetMarker(LobbyPosition position) {
    // 如果标记已存在但位置不同，先移除
    if (_targetMarker != null) {
      _targetMarker!.removeFromParent();
      _targetMarker = null;
    }

    // 创建新的标记组件
    _targetMarker = TargetMarkerComponent(
      worldPosition: Vector2(position.x, position.y),
    );
    _world.add(_targetMarker!);
  }

  /// 清除目标位置标记
  void _clearTargetMarker() {
    if (_targetMarker != null) {
      _targetMarker!.removeFromParent();
      _targetMarker = null;
    }
    _currentTargetPosition = null;
  }

  void _syncUsers(List<LobbyUser> newUsers, LobbyState state) {
    // 移除离开的用户
    final currentUserIds = _playerComponents.keys.toSet();
    final newUserIds = newUsers.map((u) => u.userId).toSet();

    for (final userId in currentUserIds.difference(newUserIds)) {
      final component = _playerComponents.remove(userId);
      component?.removeFromParent();
    }

    // 添加或更新用户
    for (final user in newUsers) {
      if (_playerComponents.containsKey(user.userId)) {
        // 更新现有用户
        _playerComponents[user.userId]!.updateUser(user, _sprites);
      } else {
        // 添加新用户
        _addPlayerComponent(user);
      }
    }
  }

  Future<void> _addPlayerComponent(LobbyUser user) async {
    LogService.d('[LobbyGame] _addPlayerComponent: userId=${user.userId} spriteId=${user.spriteId}');
    // 优先查找用户 spriteId 对应的 sprite，其次找 default sprite，最后兜底
    LobbySprite sprite;
    try {
      sprite = _sprites.firstWhere((s) => s.id == user.spriteId);
    } catch (_) {
      sprite = _sprites.where((s) => s.isDefault).firstOrNull ?? const LobbySprite(
        id: 'sprite_01',
        label: '默认角色',
        accentColor: Color(0xFF60A5FA),
      );
    }

    final component = LobbyPlayerComponent(
      user: user,
      sprite: sprite,
      showNameplate: _showNameplates,
      showChatBubble: _showChatBubbles,
      onArrived: _onPlayerArrived,
      onDustEmitted: (position) {
        // 扬尘需要生成在角色实际脚底，而不是组件锚点（锚点在状态文字区域底部）
        // 所以需要在 Y 轴上补偿 statusTextAreaHeight
        final dust = DustCloudComponent(
          worldPosition: Vector2(
            position.x,
            position.y - LobbyPlayerComponent.statusTextAreaHeight,
          ),
        );
        _world.add(dust);
      },
    );

    await _world.add(component);
    _playerComponents[user.userId] = component;
    LogService.d('[LobbyGame] _addPlayerComponent 完成: total players=${_playerComponents.length}');
  }

  /// 角色到达目标时的回调
  void _onPlayerArrived(String userId, LobbyPosition arrivedPosition) {
    // 通知 Bloc 更新状态（设置 isMoving = false），避免其他角色误判
    _bloc.add(LobbyPlayerArrived(userId, arrivedPosition));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 当视口大小变化时，重新限制相机位置
    if (_isInitialized) {
      _followCurrentPlayer();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (_mapConfig == null) return;

    // 获取相机偏移量
    final cameraOffset = _cameraComponent.viewfinder.position;

    // 将点击坐标转换为世界坐标
    // 组件锚点在脚底（bottomCenter），状态文字在脚底上方 statusTextAreaHeight 高度内，
    // 所以点击sprite脚底时 localY = size.y - statusTextAreaHeight，
    // 对应 worldY = 脚底 + statusTextAreaHeight，
    // 直接加上 statusTextAreaHeight 将坐标对齐到角色脚底
    final dx = event.localPosition.x + cameraOffset.x;
    final dy = event.localPosition.y + cameraOffset.y + LobbyPlayerComponent.statusTextAreaHeight;

    // 验证点击在世界范围内
    if (dx < 0 || dx > _worldSize.x || dy < 0 || dy > _worldSize.y) {
      return;
    }

    _bloc.add(LobbySceneTapped(LobbyPosition(x: dx, y: dy)));
  }

  void handleHoverMove(PointerHoverEvent event) {
    _handleHover(Vector2(event.localPosition.dx, event.localPosition.dy));
  }

  void handleHoverExit() {
    _clearHover();
  }

  void _clearHover() {
    if (_hoveredPortal != null) {
      _hoveredPortal!.handleHoverExit();
      _hoveredPortal = null;
    }
  }

  void _handleHover(Vector2 localPosition) {
    if (_mapConfig == null || _portalComponents.isEmpty) return;

    // 获取相机偏移量
    final cameraOffset = _cameraComponent.viewfinder.position;

    // 将鼠标坐标转换为世界坐标
    final dx = localPosition.x + cameraOffset.x;
    final dy = localPosition.y + cameraOffset.y;

    // 查找是否有传送门在鼠标位置
    PortalComponent? hoveredPortal;
    for (final portal in _portalComponents) {
      if (portal.containsPoint(Vector2(dx, dy))) {
        hoveredPortal = portal;
        break;
      }
    }

    // 更新 hover 状态
    if (hoveredPortal != null) {
      if (_hoveredPortal != hoveredPortal) {
        // 离开之前的传送门
        if (_hoveredPortal != null) {
          _hoveredPortal!.handleHoverExit();
        }
        // 进入新传送门
        _hoveredPortal = hoveredPortal;
        _hoveredPortal!.handleHoverEnter();
      }
    } else {
      // 离开传送门
      if (_hoveredPortal != null) {
        _hoveredPortal!.handleHoverExit();
        _hoveredPortal = null;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 每帧更新角色位置（移动插值）
    for (final component in _playerComponents.values) {
      component.updatePosition(dt);
    }
    // 每帧相机跟随角色（驱动插值跟随）
    if (_isInitialized) {
      _followCurrentPlayer();
    }
  }

  @override
  void onRemove() {
    _stateSubscription.cancel();
    super.onRemove();
  }
}

/// 背景层组件：负责渲染地图背景图片
class BackgroundComponent extends PositionComponent with HasGameReference<LobbyGame> {
  BackgroundComponent({
    required LobbyMapConfig mapConfig,
    required Vector2 worldSize,
  })  : _mapConfig = mapConfig,
        _worldSize = worldSize,
        super(priority: -2);

  final LobbyMapConfig _mapConfig;
  Vector2 _worldSize;
  bool _loaded = false;

  // 组件销毁标志，用于防止图片加载完成后访问已销毁的组件
  bool _disposed = false;

  @override
  Future<void> onLoad() async {
    await _loadBackground();
  }

  Future<void> _loadBackground() async {
    if (_loaded) return;
    _loaded = true;

    // 设置背景组件大小为世界尺寸
    size = _worldSize;

    // 加载背景（优先从本地缓存，fallback 到网络）
    if (_mapConfig.backgroundUrl != null && _mapConfig.backgroundUrl!.isNotEmpty) {
      try {
        // 优先从本地缓存获取
        final imageInfo = await _loadCachedOrNetworkImage(_mapConfig.backgroundUrl!);
        if (imageInfo != null) {
          final sprite = Sprite(imageInfo);
          final bgComponent = SpriteComponent(
            sprite: sprite,
            size: _worldSize,
          );
          bgComponent.paint = Paint()..colorFilter = const ColorFilter.mode(
            Color(0x3D000000),
            BlendMode.darken,
          );
          await add(bgComponent);
          return;
        }
      } catch (_) {
        // 加载失败，使用默认背景
      }
    }
    await _addDefaultBackground();
  }

  /// 优先从本地缓存加载图片，fallback 到网络
  Future<ui.Image?> _loadCachedOrNetworkImage(String url) async {
    // 确保图片服务已初始化
    if (!LobbyImageCacheService.instance.isInitialized) {
      await LobbyImageCacheService.instance.init();
    }

    // 优先从本地缓存获取
    final cachedImage = await LobbyImageCacheService.instance.getDecodedImage(url);
    if (cachedImage != null) {
      LogService.d('[BackgroundComponent] 从本地缓存加载背景: $url');
      return cachedImage;
    }

    // 本地没有，尝试网络下载
    if (_disposed) return null;
    LogService.d('[BackgroundComponent] 本地缓存未命中，下载背景: $url');
    return _loadNetworkImage(url);
  }

  Future<ui.Image?> _loadNetworkImage(String url) async {
    if (_disposed) return null;
    final imageProvider = NetworkImage(url);
    final completer = Completer<ui.Image>();
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!_disposed && !completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!_disposed && !completer.isCompleted) {
          completer.completeError(error);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    try {
      return await completer.future;
    } catch (_) {
      if (!_disposed) {
        stream.removeListener(listener);
      }
      return null;
    }
  }

  Future<void> _addDefaultBackground() async {
    final paint = Paint()..color = const Color(0xFF0B1120);
    add(
      RectangleComponent(
        size: _worldSize,
        paint: paint,
      ),
    );
  }

  void updateMapConfig(LobbyMapConfig mapConfig) {
    // 重新加载背景
    children.toList().forEach((c) => c.removeFromParent());
    _loaded = false;
    _loadBackground();
  }

  void updateWorldSize(Vector2 size) {
    _worldSize = size;
    this.size = size;
    for (final child in children) {
      if (child is SpriteComponent) {
        child.size = size;
      } else if (child is RectangleComponent) {
        child.size = size;
      }
    }
  }

  @override
  void onRemove() {
    _disposed = true;
    super.onRemove();
  }
}

/// 渐变叠加层组件
class GradientOverlayComponent extends PositionComponent {
  GradientOverlayComponent({required Vector2 worldSize}) : super(priority: -1) {
    size = worldSize;
  }

  void updateWorldSize(Vector2 worldSize) {
    size = worldSize;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.18),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.28),
        ],
      ).createShader(size.toRect());

    canvas.drawRect(size.toRect(), paint);
  }
}

/// 传送门组件 - 东方风格发光传送门
class PortalComponent extends PositionComponent with TapCallbacks {
  final LobbyPortal portal;
  final void Function(LobbyPosition clickPosition) onClick;

  bool _isHovered = false;
  double _glowIntensity = 0.0;
  double _rotationAngle = 0.0;
  double _pulsePhase = 0.0;

  /// 发光粒子组件
  ParticleSystemComponent? _glowParticles;

  PortalComponent({
    required this.portal,
    required this.onClick,
  }) : super(
          position: Vector2(portal.x - kLobbyPortalRadius, portal.y - kLobbyPortalRadius),
          size: Vector2(kLobbyPortalRadius * 2, kLobbyPortalRadius * 2),
          anchor: Anchor.topLeft,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _initParticles();
  }

  /// 初始化发光粒子效果
  Future<void> _initParticles() async {
    // 创建围绕魔法阵旋转的发光粒子
    _glowParticles = ParticleSystemComponent(
      particle: _createOrbitingParticle(),
      anchor: Anchor.center,
    );
    await add(_glowParticles!);
  }

  /// 创建环绕传送门的发光粒子
  Particle _createOrbitingParticle() {
    final colors = [Colors.purpleAccent, Colors.cyanAccent, Colors.pinkAccent];
    
    return Particle.generate(
      count: 12,
      generator: (i) {
        // 交替使用紫色和青色
        final color = colors[i % colors.length];
        
        // 创建带初始角度偏移的圆周运动粒子
        final angle = (i / 12) * math.pi * 2;
        final radius = kLobbyPortalRadius * 0.7;
        
        return AcceleratedParticle(
          // 初始位置在圆周上，速度沿切线方向
          position: Vector2(
            kLobbyPortalRadius + math.cos(angle) * radius,
            kLobbyPortalRadius + math.sin(angle) * radius,
          ),
          speed: Vector2(
            -math.sin(angle) * 25,
            math.cos(angle) * 25,
          ),
          acceleration: Vector2.zero(),
          child: CircleParticle(
            radius: 2.5 + (i % 2) * 1.0,
            paint: Paint()
              ..color = color.withValues(alpha: 0.7)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          ),
        );
      },
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    // 点击传送门，传递点击位置到 Bloc 处理
    final clickWorldPos = position + event.localPosition;
    onClick(LobbyPosition(x: clickWorldPos.x, y: clickWorldPos.y));
  }

  // 供外部调用来处理 hover 状态
  void handleHoverEnter() {
    if (!_isHovered) {
      _isHovered = true;
      // 悬停时增强粒子可见度
      _glowParticles?.particle = _createOrbitingParticle();
    }
  }

  void handleHoverExit() {
    if (_isHovered) {
      _isHovered = false;
      _glowIntensity = 0.0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 基础旋转动画
    _rotationAngle += dt * 0.5;

    // 呼吸脉冲效果
    _pulsePhase += dt * 2.0;
    if (_pulsePhase > math.pi * 2) {
      _pulsePhase -= math.pi * 2;
    }

    // 悬停时增强发光强度
    if (_isHovered) {
      _glowIntensity = (_glowIntensity + dt * 4.0).clamp(0.0, 1.0);
    } else {
      _glowIntensity = (_glowIntensity - dt * 3.0).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = size / 2;
    final radius = math.min(size.x, size.y) / 2;

    // 呼吸缩放
    final breathScale = 1.0 + math.sin(_pulsePhase) * 0.05;
    final actualRadius = radius * breathScale;

    // 发光强度（基础 + hover 增强）
    final baseGlow = 0.3 + _glowIntensity * 0.5;
    final glowRadius = 10.0 + _glowIntensity * 15.0;

    // 绘制外圈光环
    _drawGlowRing(canvas, center, actualRadius, baseGlow, glowRadius);

    // 绘制旋转魔法阵
    _drawMagicCircle(canvas, center, actualRadius * 0.8);

    // 绘制内圈核心
    _drawCore(canvas, center, actualRadius * 0.3);

    // 默认显示标签，hover 时更明显
    _drawLabel(canvas, center, actualRadius, isHovered: _isHovered || _glowIntensity > 0.3);
  }

  void _drawGlowRing(Canvas canvas, Vector2 center, double radius, double intensity, double blur) {
    // 外发光
    final outerPaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: intensity * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center.toOffset(), radius, outerPaint);

    // 内发光
    final innerPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: intensity * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.5)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center.toOffset(), radius * 0.8, innerPaint);

    // 主圆环
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: intensity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center.toOffset(), radius, ringPaint);
  }

  void _drawMagicCircle(Canvas canvas, Vector2 center, double radius) {
    canvas.save();
    canvas.translate(center.x, center.y);
    canvas.rotate(_rotationAngle);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.pinkAccent.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..blendMode = BlendMode.plus;

    // 绘制六芒星
    final path = Path();
    for (int i = 0; i <= 12; i++) {
      final angle = (i * math.pi) / 6;
      final r = i.isEven ? radius : radius * 0.5;
      final x = math.cos(angle - math.pi / 2) * r;
      final y = math.sin(angle - math.pi / 2) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // 绘制内圈
    canvas.drawCircle(Offset.zero, radius * 0.4, paint);

    canvas.restore();
  }

  void _drawCore(Canvas canvas, Vector2 center, double radius) {
    // 核心渐变
    final gradient = ui.Gradient.radial(
      center.toOffset(),
      radius,
      [
        Colors.white.withValues(alpha: 0.9),
        Colors.cyanAccent.withValues(alpha: 0.7),
        Colors.purpleAccent.withValues(alpha: 0.3),
        Colors.transparent,
      ],
      [0.0, 0.3, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    canvas.drawCircle(center.toOffset(), radius, paint);

    // 中心亮点
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(center.toOffset(), radius * 0.2, centerPaint);
  }

  void _drawLabel(Canvas canvas, Vector2 center, double radius, {bool isHovered = false}) {
    // 使用系统默认字体，支持中英文和特殊字符
    final pixelTextStyle = TextStyle(
      fontFamily: null, // null 表示使用系统默认字体
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: portal.label, style: pixelTextStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 在传送门下方显示标签
    final textOffset = Offset(
      center.x - textPainter.width / 2,
      center.y + radius + 8,
    );

    // 背景框
    final bgRect = Rect.fromCenter(
      center: Offset(center.x, textOffset.dy + textPainter.height / 2),
      width: textPainter.width + 16,
      height: textPainter.height + 8,
    );
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: isHovered ? 0.7 : 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      bgPaint,
    );

    textPainter.paint(canvas, textOffset);
  }
}

/// 移动扬尘特效组件
///
/// 这是一个独立的粒子组件，位于世界空间中，不跟随角色移动。
/// 角色移动时会在脚底位置创建此组件，粒子效果完成后自动从父组件移除。
class DustCloudComponent extends PositionComponent with HasGameReference<LobbyGame> {
  DustCloudComponent({
    required Vector2 worldPosition,
  }) : super(
          position: worldPosition,
          anchor: Anchor.bottomCenter,
          // size.y = 0 让组件的视觉原点精确对齐世界坐标（脚底位置），
          // size.x = 40 控制粒子水平扩散范围
          size: Vector2(40.0, 0.0),
          priority: 0, // 扬尘在角色下方
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 扬尘颜色（温暖米棕色）
    const dustColor = Color(0xFFB8A090);

    // 创建 3 个随机尘点粒子
    final particle = Particle.generate(
      count: 3,
      generator: (_) {
        // size.y 为 0，size.x / 2 = 20 作为水平中心
        final offsetX = (math.Random().nextDouble() - 0.5) * 16.0;
        return AcceleratedParticle(
          // 初始位置在组件中心偏下（脚底位置）
          position: Vector2(size.x / 2 + offsetX, 0),
          speed: Vector2(
            (math.Random().nextDouble() - 0.5) * 20.0,
            -15.0 - math.Random().nextDouble() * 10.0,
          ),
          acceleration: Vector2(
            (math.Random().nextDouble() - 0.5) * 8.0,
            -3.0,
          ),
          lifespan: 0.5,
          child: CircleParticle(
            radius: 3.0 + math.Random().nextDouble() * 2.0,
            paint: Paint()
              ..color = dustColor.withValues(alpha: 0.7)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          ),
        );
      },
    );

    final particleSystem = ParticleSystemComponent(
      particle: particle,
    );

    await add(particleSystem);

    // 等待粒子效果完成后自动移除组件
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!isRemoving) {
        removeFromParent();
      }
    });
  }
}

/// 目标位置标记组件 - 显示红色叉号
///
/// 当角色移动时，在目标位置显示一个醒目的红色叉号，
/// 到达后自动消失。
class TargetMarkerComponent extends PositionComponent with HasGameReference<LobbyGame> {
  TargetMarkerComponent({
    required Vector2 worldPosition,
  }) : super(
          position: worldPosition,
          anchor: Anchor.bottomCenter,
          size: Vector2(32.0, 32.0),
          priority: 2,
        );

  double _pulsePhase = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 4.0;
    if (_pulsePhase > math.pi * 2) {
      _pulsePhase -= math.pi * 2;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final centerX = size.x / 2;
    final centerY = size.y / 2;

    // 脉冲透明度效果 - 适中亮度
    final pulseAlpha = 0.6 + math.sin(_pulsePhase) * 0.25;
    final baseColor = const Color(0xFFE53030); // 红色

    // 绘制外圈发光
    final outerPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.35 * pulseAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(centerX, centerY), 14, outerPaint);

    // 绘制内圈发光
    final innerPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.5 * pulseAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(centerX, centerY), 8, innerPaint);

    // 绘制 X 叉号 - 中等粗细
    final strokePaint = Paint()
      ..color = baseColor.withValues(alpha: pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    const crossSize = 14.0;

    // 第一条斜线
    canvas.drawLine(
      Offset(centerX - crossSize, centerY - crossSize),
      Offset(centerX + crossSize, centerY + crossSize),
      strokePaint,
    );

    // 第二条斜线
    canvas.drawLine(
      Offset(centerX + crossSize, centerY - crossSize),
      Offset(centerX - crossSize, centerY + crossSize),
      strokePaint,
    );

    // 绘制旋转的虚线圆环（动态效果）
    _drawRotatingRing(canvas, centerX, centerY, pulseAlpha);
  }

  void _drawRotatingRing(Canvas canvas, double centerX, double centerY, double alpha) {
    final ringRadius = 22.0;
    const dashCount = 12;
    const dashLength = 4.0;
    const gapLength = 6.0;
    final totalLength = dashLength + gapLength;

    final ringPaint = Paint()
      ..color = const Color(0xFFFF6060).withValues(alpha: alpha * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * totalLength / ringRadius) + _pulsePhase * 0.5;
      final endAngle = startAngle + dashLength / ringRadius;

      path.moveTo(
        centerX + math.cos(startAngle) * ringRadius,
        centerY + math.sin(startAngle) * ringRadius,
      );
      path.lineTo(
        centerX + math.cos(endAngle) * ringRadius,
        centerY + math.sin(endAngle) * ringRadius,
      );
    }

    canvas.drawPath(path, ringPaint);
  }
}
