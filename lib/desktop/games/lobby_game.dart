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
import 'lobby_context_menu_component.dart';

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

  // ─── 角色贴图批量预加载注册表 ───────────────────────────────
  /// 已加载的贴图缓存：spriteId -> ui.Image
  final Map<String, ui.Image> _preloadedSpriteImages = {};

  /// 正在加载的 spriteId 集合（防止重复加载）
  final Set<String> _loadingSpriteIds = {};

  /// 等待某个 spriteId 加载完成的玩家组件列表
  final Map<String, List<LobbyPlayerComponent>> _waitingForSprite = {};

  /// 查询某个 spriteId 是否已预加载完成
  ui.Image? getPreloadedSpriteImage(String spriteId) => _preloadedSpriteImages[spriteId];

  /// 注册一个玩家组件等待某个 spriteId 的贴图加载完成
  void registerSpriteWaiter(String spriteId, LobbyPlayerComponent component) {
    _waitingForSprite.putIfAbsent(spriteId, () => []).add(component);
  }

  /// 取消注册（组件销毁时调用）
  void unregisterSpriteWaiter(String spriteId, LobbyPlayerComponent component) {
    _waitingForSprite[spriteId]?.remove(component);
  }

  /// 按 spriteId 渐进式预加载贴图，逐个加载避免瞬间吃满性能
  ///
  /// 每加载完一种 sprite 后再加载下一种，确保：
  /// - 不会同时发起大量网络请求
  /// - 不会同时解码多张大图占满 CPU
  /// - 每种加载完立即通知对应玩家显示，用户感知到逐步加载
  Future<void> _preloadSpritesProgressively() async {
    // 收集当前场景中用到的所有 spriteId，并按使用人数降序排列（优先加载多人用的）
    final spriteUsageCount = <String, int>{};
    for (final user in _initialUsers) {
      spriteUsageCount[user.spriteId] = (spriteUsageCount[user.spriteId] ?? 0) + 1;
    }

    // 按使用人数降序排序，优先加载最多人使用的 sprite
    final sortedSpriteIds = spriteUsageCount.keys.toList()
      ..sort((a, b) => spriteUsageCount[b]!.compareTo(spriteUsageCount[a]!));

    // 逐个加载，每完成一个再加载下一个
    for (final spriteId in sortedSpriteIds) {
      if (_preloadedSpriteImages.containsKey(spriteId)) continue;
      if (_loadingSpriteIds.contains(spriteId)) continue;

      final sprite = _sprites.where((s) => s.id == spriteId).firstOrNull;
      if (sprite == null) continue;

      await _loadSpriteForId(spriteId, sprite);

      // 每加载完一个，让出一帧给渲染线程，避免连续解码卡 UI
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// 加载单个 sprite 类型的贴图，完成后通知所有使用该 spriteId 的玩家
  Future<void> _loadSpriteForId(String spriteId, LobbySprite sprite) async {
    if (_loadingSpriteIds.contains(spriteId)) return;
    _loadingSpriteIds.add(spriteId);

    try {
      ui.Image? image;

      if (sprite.usesAtlas) {
        // 图集模式：不走批量预加载，让各组件自行处理
        // （图集需要 atlasFromAssets，逻辑较复杂）
        _loadingSpriteIds.remove(spriteId);
        return;
      }

      final url = sprite.spriteUrl;
      if (url == null || url.isEmpty) {
        _loadingSpriteIds.remove(spriteId);
        return;
      }

      // 从缓存或网络加载图片
      if (!LobbyImageCacheService.instance.isInitialized) {
        await LobbyImageCacheService.instance.init();
      }
      image = await LobbyImageCacheService.instance.getDecodedImage(url);
      if (image == null) {
        // 尝试网络下载
        final bytes = await LobbyImageCacheService.instance.downloadWithStableKey(url);
        if (bytes != null) {
          image = await LobbyImageCacheService.instance.getDecodedImage(url);
        }
      }

      if (image != null) {
        _preloadedSpriteImages[spriteId] = image;
        LogService.d('[LobbyGame] 贴图预加载完成: $spriteId, 通知 ${_waitingForSprite[spriteId]?.length ?? 0} 个玩家');

        // 通知所有等待该 spriteId 的玩家组件
        final waiters = _waitingForSprite.remove(spriteId);
        if (waiters != null) {
          for (final component in waiters) {
            if (!component.isRemoved) {
              component.onSpritePreloaded(image);
            }
          }
        }
      } else {
        // 加载失败：通知等待的组件走独立加载 fallback
        LogService.w('[LobbyGame] 贴图预加载失败（无数据）: $spriteId, 通知等待者自行加载');
        final waiters = _waitingForSprite.remove(spriteId);
        if (waiters != null) {
          for (final component in waiters) {
            if (!component.isRemoved) {
              component.onSpritePreloadFailed();
            }
          }
        }
      }
    } catch (e) {
      LogService.e('[LobbyGame] 贴图预加载失败: $spriteId', e);
      // 异常时也通知等待者 fallback
      final waiters = _waitingForSprite.remove(spriteId);
      if (waiters != null) {
        for (final component in waiters) {
          if (!component.isRemoved) {
            component.onSpritePreloadFailed();
          }
        }
      }
    } finally {
      _loadingSpriteIds.remove(spriteId);
    }
  }

  /// 当新用户加入时，确保其 sprite 贴图已加载或正在加载
  ///
  /// 仅在初始化完成后（_isInitialized=true）才触发加载，
  /// 初始阶段由 _preloadSpritesProgressively 统一串行调度。
  void ensureSpriteLoaded(String spriteId) {
    if (!_isInitialized) return; // 初始阶段由 _preloadSpritesProgressively 管理
    if (_preloadedSpriteImages.containsKey(spriteId)) return;
    if (_loadingSpriteIds.contains(spriteId)) return;

    final sprite = _sprites.where((s) => s.id == spriteId).firstOrNull;
    if (sprite == null || sprite.usesAtlas) return;

    unawaited(_loadSpriteForId(spriteId, sprite));
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
  /// 当前悬停的玩家
  LobbyPlayerComponent? _hoveredPlayer;
  /// 传送门更新锁，防止并发更新
  bool _portalUpdateInProgress = false;

  /// 右键菜单组件
  LobbyContextMenuComponent? _contextMenu;

  /// 右键菜单目标玩家（用于闪动边框和抑制其他 hover）
  LobbyPlayerComponent? _contextMenuTarget;

  /// 右键菜单打开时目标玩家的位置（用于距离检测自动关闭）
  LobbyPosition? _contextMenuTargetOriginPos;

  /// 目标玩家移动超过此距离时自动关闭菜单
  static const double _contextMenuAutoCloseDistance = 40.0;

  /// 关注用户 ID 集合（本地持久化）
  Set<String> _followedUserIds = {};

  /// 右键菜单回调：调查用户
  void Function(LobbyUser user)? onInvestigateUser;

  /// 当前是否悬停在可交互的玩家上（用于切换鼠标光标）
  bool get isHoveringInteractablePlayer {
    if (_hoveredPlayer == null) return false;
    final user = _hoveredPlayer!.user;
    // 有 businessUserId 且非自己才可交互
    if (user.businessUserId == null || user.businessUserId!.isEmpty) return false;
    if (user.isSelf) return false;
    return true;
  }

  /// 目标位置标记组件（显示红色叉号）
  TargetMarkerComponent? _targetMarker;

  /// 当前玩家正在移动的目标位置
  LobbyPosition? _currentTargetPosition;

  /// 世界根组件（包含所有游戏对象，相机对其生效）
  late final World _world;
  final Map<String, LobbyPlayerComponent> _playerComponents = {};

  /// 待处理用户队列：用于确保用户添加/移除操作的顺序性
  /// 避免异步操作导致的竞态条件
  final Set<String> _pendingUserIds = {};

  LobbyMapConfig? _mapConfig;
  List<LobbySprite> _sprites = [];
  bool _showNameplates = false;
  bool _showChatBubbles = false;
  bool _isInitialized = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 加载关注列表
    _loadFollowedUsers();

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

    // 异步批量预加载角色贴图（不阻塞 onLoad）
    // 每种贴图加载完成后，所有使用该贴图的玩家同时 fade-in 显示
    _preloadSpritesProgressively();
  }

  /// 更新传送门组件
  Future<void> _updatePortalComponents() async {
    if (_mapConfig == null) return;

    // 如果已经在更新中，跳过
    if (_portalUpdateInProgress) return;
    _portalUpdateInProgress = true;

    try {
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
    } finally {
      _portalUpdateInProgress = false;
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
    final leavingUserIds = currentUserIds.difference(newUserIds);

    for (final userId in leavingUserIds) {
      final component = _playerComponents.remove(userId);
      if (component != null) {
        // 如果离开的用户是右键菜单目标，关闭菜单
        if (_contextMenuTarget == component) {
          _dismissContextMenu();
        }
        component.removeFromParent();
      }
    }

    // 添加或更新用户
    for (final user in newUsers) {
      if (_playerComponents.containsKey(user.userId)) {
        // 更新现有用户
        _playerComponents[user.userId]!.updateUser(user, _sprites);
        // 刷新关注状态（基于 businessUserId，用户登出后 businessUserId 会变空）
        _playerComponents[user.userId]!.isFollowed =
            isBusinessUserFollowed(user.businessUserId);
      } else if (!_pendingUserIds.contains(user.userId)) {
        // 添加新用户（但不在待处理队列中）
        _addPlayerComponent(user);
      }
    }
  }

  Future<void> _addPlayerComponent(LobbyUser user) async {
    // 检测重复添加（既不在现有组件中，也不在待处理队列中）
    if (_playerComponents.containsKey(user.userId) || _pendingUserIds.contains(user.userId)) {
      return;
    }

    // 将用户标记为待处理，避免在异步操作期间被重复添加
    _pendingUserIds.add(user.userId);

    try {
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

      // 关键：在组件添加到世界后，检查用户是否已经离开
      // 这是解决"玩家离开后模型残留"问题的核心逻辑
      final currentUserIds = _bloc.state.users.map((u) => u.userId).toSet();
      if (!currentUserIds.contains(user.userId)) {
        component.removeFromParent();
        return;
      }

      _playerComponents[user.userId] = component;
      // 应用关注状态（基于 businessUserId）
      component.isFollowed = isBusinessUserFollowed(user.businessUserId);

      // 确保该 spriteId 的贴图正在加载（新用户加入时触发）
      ensureSpriteLoaded(user.spriteId);
    } finally {
      _pendingUserIds.remove(user.userId);
    }
  }

  /// 角色到达目标时的回调
  void _onPlayerArrived(String userId, LobbyPosition arrivedPosition) {
    // 通知 Bloc 更新状态（设置 isMoving = false），避免其他角色误判
    _bloc.add(LobbyPlayerArrived(userId, arrivedPosition));
  }

  // ========== 关注用户管理 ==========

  static const String _followedUsersKey = 'lobby_followed_user_ids';

  /// 加载关注列表
  void _loadFollowedUsers() {
    final list = StorageUtils.getStringList(_followedUsersKey);
    _followedUserIds = list.toSet();
    // 更新已有组件的关注状态
    _applyFollowStates();
  }

  /// 保存关注列表
  Future<void> _saveFollowedUsers() async {
    await StorageUtils.setStringList(
      _followedUsersKey,
      _followedUserIds.toList(),
    );
  }

  /// 应用关注状态到所有玩家组件
  /// 使用 businessUserId（账户级 ID）判断关注，只有已登录用户才有此字段
  void _applyFollowStates() {
    for (final component in _playerComponents.values) {
      final user = component.user;
      final bizId = user.businessUserId;
      if (bizId == null || bizId.isEmpty) {
        component.isFollowed = false;
      } else {
        component.isFollowed = _followedUserIds.contains(bizId);
      }
    }
  }

  /// 关注/取消关注用户
  void toggleFollowUser(String userId) {
    // 使用 businessUserId（账户级 ID）作为持久化标识
    final component = _playerComponents[userId];
    final bizId = component?.user.businessUserId;
    if (bizId == null || bizId.isEmpty) return;

    if (_followedUserIds.contains(bizId)) {
      _followedUserIds.remove(bizId);
    } else {
      _followedUserIds.add(bizId);
    }
    _saveFollowedUsers();
    // 更新所有组件的关注状态
    _applyFollowStates();
  }

  /// 检查用户是否被关注（基于 businessUserId）
  bool isUserFollowed(String userId) {
    final component = _playerComponents[userId];
    final bizId = component?.user.businessUserId;
    if (bizId == null || bizId.isEmpty) return false;
    return _followedUserIds.contains(bizId);
  }

  /// 通过 businessUserId 检查是否被关注
  bool isBusinessUserFollowed(String? businessUserId) {
    if (businessUserId == null || businessUserId.isEmpty) return false;
    return _followedUserIds.contains(businessUserId);
  }

  /// 直接通过 businessUserId 切换关注状态（用于右键菜单闭包，避免依赖组件引用）
  void _toggleFollowByBusinessUserId(String businessUserId) {
    if (businessUserId.isEmpty) return;

    if (_followedUserIds.contains(businessUserId)) {
      _followedUserIds.remove(businessUserId);
    } else {
      _followedUserIds.add(businessUserId);
    }
    _saveFollowedUsers();
    _applyFollowStates();
  }

  // ========== 右键菜单 ==========

  /// 处理右键点击（由 LobbyScene 转发）
  void handleSecondaryTapDown(PointerEvent event) {
    if (_mapConfig == null) return;

    // 先关闭已有菜单
    _dismissContextMenu();

    // 获取相机偏移量
    final cameraOffset = _cameraComponent.viewfinder.position;

    // 将点击坐标转换为世界坐标
    final dx = event.localPosition.dx + cameraOffset.x;
    final dy = event.localPosition.dy + cameraOffset.y;
    final worldPoint = Vector2(dx, dy);

    // 查找右键点击的玩家
    LobbyPlayerComponent? targetPlayer;
    for (final player in _playerComponents.values) {
      if (player.containsPoint(worldPoint)) {
        targetPlayer = player;
      }
    }

    if (targetPlayer == null) return;

    final user = targetPlayer.user;

    // 只允许对已登录的用户操作（有 businessUserId 表示是真实账户）
    if (user.businessUserId == null || user.businessUserId!.isEmpty) return;

    // 不对自己操作
    if (user.isSelf) return;

    // 设置右键菜单目标（闪动边框）
    _contextMenuTarget = targetPlayer;
    _contextMenuTargetOriginPos = targetPlayer.currentRenderPosition;
    targetPlayer.setContextMenuTarget(true);
    // 清除其他玩家的 hover 状态
    if (_hoveredPlayer != null && _hoveredPlayer != targetPlayer) {
      _hoveredPlayer!.handleHoverExit();
      _hoveredPlayer = null;
    }

    // 构建菜单项
    final isFollowed = isBusinessUserFollowed(user.businessUserId);
    final items = [
      const ContextMenuItem(id: 'investigate', label: '调查'),
      ContextMenuItem(
        id: 'follow',
        label: isFollowed ? '取消关注' : '关注',
      ),
    ];

    // 计算菜单位置（在点击位置附近显示）
    final menuPosition = Vector2(dx + 4, dy + 4);

    _contextMenu = LobbyContextMenuComponent(
      items: items,
      worldPosition: menuPosition,
      onItemSelected: (itemId) {
        if (itemId == 'investigate') {
          // 触发调查回调
          onInvestigateUser?.call(user);
        } else if (itemId == 'follow') {
          // 直接使用捕获的 businessUserId，避免用户离开后组件被移除导致无法获取
          _toggleFollowByBusinessUserId(user.businessUserId!);
        }
      },
      onDismiss: _dismissContextMenu,
    );

    _world.add(_contextMenu!);
  }

  /// 关闭右键菜单
  void _dismissContextMenu() {
    if (_contextMenu != null) {
      _contextMenu!.removeFromParent();
      _contextMenu = null;
    }
    // 清除目标闪动状态
    if (_contextMenuTarget != null) {
      if (!_contextMenuTarget!.isRemoved) {
        _contextMenuTarget!.setContextMenuTarget(false);
      }
      _contextMenuTarget = null;
    }
    _contextMenuTargetOriginPos = null;
  }

  /// 处理鼠标悬停时更新菜单状态
  void _updateContextMenuHover(Vector2 worldPoint) {
    if (_contextMenu == null) return;

    // 将世界坐标转换为菜单本地坐标
    final menuPos = _contextMenu!.position;
    final localPoint = Vector2(
      worldPoint.x - menuPos.x,
      worldPoint.y - menuPos.y,
    );
    _contextMenu!.handleHoverAt(localPoint);
  }

  /// 检查点击是否在菜单内
  bool _isPointInContextMenu(Vector2 worldPoint) {
    if (_contextMenu == null) return false;
    return _contextMenu!.containsPoint(worldPoint);
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
    final dx = event.localPosition.x + cameraOffset.x;
    final dy = event.localPosition.y + cameraOffset.y + LobbyPlayerComponent.statusTextAreaHeight;

    // 如果右键菜单打开，检查点击是否在菜单内
    if (_contextMenu != null) {
      final menuWorldPoint = Vector2(
        event.localPosition.x + cameraOffset.x,
        event.localPosition.y + cameraOffset.y,
      );
      if (_isPointInContextMenu(menuWorldPoint)) {
        // 点击在菜单内，处理菜单点击
        final menuPos = _contextMenu!.position;
        final localPoint = Vector2(
          menuWorldPoint.x - menuPos.x,
          menuWorldPoint.y - menuPos.y,
        );
        _contextMenu!.handleTapAt(localPoint);
        return;
      } else {
        // 点击在菜单外，关闭菜单
        _dismissContextMenu();
        return;
      }
    }

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
    if (_hoveredPlayer != null) {
      _hoveredPlayer!.handleHoverExit();
      _hoveredPlayer = null;
    }
  }

  void _handleHover(Vector2 localPosition) {
    if (_mapConfig == null) return;

    // 获取相机偏移量
    final cameraOffset = _cameraComponent.viewfinder.position;

    // 将鼠标坐标转换为世界坐标
    final dx = localPosition.x + cameraOffset.x;
    final dy = localPosition.y + cameraOffset.y;
    final worldPoint = Vector2(dx, dy);

    // 更新右键菜单悬停状态
    _updateContextMenuHover(worldPoint);

    // 查找是否有传送门在鼠标位置
    PortalComponent? hoveredPortal;
    for (final portal in _portalComponents) {
      if (portal.containsPoint(worldPoint)) {
        hoveredPortal = portal;
        break;
      }
    }

    if (hoveredPortal != null) {
      if (_hoveredPortal != hoveredPortal) {
        // 离开之前的传送门
        _hoveredPortal?.handleHoverExit();
        // 进入新传送门
        _hoveredPortal = hoveredPortal;
        _hoveredPortal!.handleHoverEnter();
      }
      // 如果悬停在传送门上，取消角色的悬停
      if (_hoveredPlayer != null) {
        _hoveredPlayer!.handleHoverExit();
        _hoveredPlayer = null;
      }
      return; // 悬停了传送门，后面的就不需要判断了
    } else {
      // 离开传送门
      if (_hoveredPortal != null) {
        _hoveredPortal!.handleHoverExit();
        _hoveredPortal = null;
      }
    }

    // 查找玩家角色
    // 右键菜单打开时，不对其他玩家显示 hover 效果
    if (_contextMenu != null) return;

    LobbyPlayerComponent? hoveredPlayer;
    for (final player in _playerComponents.values) {
      if (player.containsPoint(worldPoint)) {
        hoveredPlayer = player;
        // 如果有多个叠加在一起可以 break 也可以继续找最新添加的。
        // 为了确保能选中在上面的玩家，可以继续遍历覆盖
      }
    }

    if (hoveredPlayer != null) {
      if (_hoveredPlayer != hoveredPlayer) {
        _hoveredPlayer?.handleHoverExit();
        _hoveredPlayer = hoveredPlayer;
        _hoveredPlayer!.handleHoverEnter();
      }
    } else {
      if (_hoveredPlayer != null) {
        _hoveredPlayer!.handleHoverExit();
        _hoveredPlayer = null;
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
    // 检查右键菜单目标是否移动过远，自动关闭
    _checkContextMenuDistance();
  }

  /// 检查右键菜单目标玩家是否移动超出范围
  void _checkContextMenuDistance() {
    if (_contextMenuTarget == null || _contextMenuTargetOriginPos == null) return;

    final currentPos = _contextMenuTarget!.currentRenderPosition;
    final originPos = _contextMenuTargetOriginPos!;
    final dx = currentPos.x - originPos.x;
    final dy = currentPos.y - originPos.y;
    final distSq = dx * dx + dy * dy;

    if (distSq > _contextMenuAutoCloseDistance * _contextMenuAutoCloseDistance) {
      _dismissContextMenu();
    }
  }

  @override
  void onRemove() {
    _stateSubscription.cancel();
    // 关闭右键菜单（清理引用）
    _contextMenu = null;
    _contextMenuTarget = null;
    // 清理待处理队列中的所有用户
    for (final userId in _pendingUserIds) {
      _playerComponents.remove(userId);
    }
    _pendingUserIds.clear();
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
  bool _loading = false;

  // 组件销毁标志，用于防止图片加载完成后访问已销毁的组件
  bool _disposed = false;

  @override
  Future<void> onLoad() async {
    await _loadBackground();
  }

  Future<void> _loadBackground() async {
    if (_loaded || _loading) return;
    _loading = true;

    try {
      // 设置背景组件大小为世界尺寸
      size = _worldSize;

      // 加载背景（优先从本地缓存，fallback 到网络）
      if (_mapConfig.backgroundUrl != null && _mapConfig.backgroundUrl!.isNotEmpty) {
        try {
          // 优先从本地缓存获取
          final imageInfo = await _loadCachedOrNetworkImage(_mapConfig.backgroundUrl!);
          if (imageInfo != null && !_disposed) {
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
            _loaded = true;
            return;
          }
        } catch (_) {
          // 加载失败，使用默认背景
        }
      }
      await _addDefaultBackground();
      _loaded = true;
    } finally {
      _loading = false;
    }
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
    // 重置状态并重新加载
    children.toList().forEach((c) => c.removeFromParent());
    _loaded = false;
    _loading = false;  // 重置加载状态，允许重新加载
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
    _rebuildShader();
  }

  Paint? _cachedPaint;
  Rect? _cachedRect;

  void updateWorldSize(Vector2 worldSize) {
    size = worldSize;
    _rebuildShader();
  }

  void _rebuildShader() {
    final rect = size.toRect();
    _cachedRect = rect;
    _cachedPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.18),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.28),
        ],
      ).createShader(rect);
  }

  @override
  void render(Canvas canvas) {
    if (_cachedPaint != null && _cachedRect != null) {
      canvas.drawRect(_cachedRect!, _cachedPaint!);
    }
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

  // 缓存标签 TextPainter（标签文字不变，只需创建一次）
  TextPainter? _cachedLabelPainter;

  // 缓存魔法阵 Paint（颜色不变）
  late final Paint _magicCirclePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.pinkAccent.withValues(alpha: 0.8)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
    ..blendMode = BlendMode.plus;

  // 缓存中心亮点 Paint
  late final Paint _centerBrightPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.8)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

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
    canvas.drawPath(path, _magicCirclePaint);

    // 绘制内圈
    canvas.drawCircle(Offset.zero, radius * 0.4, _magicCirclePaint);

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
    canvas.drawCircle(center.toOffset(), radius * 0.2, _centerBrightPaint);
  }

  void _drawLabel(Canvas canvas, Vector2 center, double radius, {bool isHovered = false}) {
    // 缓存标签 TextPainter（标签文字不变）
    if (_cachedLabelPainter == null) {
      final pixelTextStyle = TextStyle(
        fontFamily: null,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
      _cachedLabelPainter = TextPainter(
        text: TextSpan(text: portal.label, style: pixelTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final textPainter = _cachedLabelPainter!;

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

  @override
  void onRemove() {
    _cachedLabelPainter?.dispose();
    _cachedLabelPainter = null;
    super.onRemove();
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
