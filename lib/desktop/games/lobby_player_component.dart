import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_texturepacker/flame_texturepacker.dart';
import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'lobby_game.dart';

/// 模型切换特效状态
enum SpriteSwitchState { idle, fadingOut, fadingIn }

/// 待处理的角色切换请求
class _PendingSpriteSwitch {
  final String spriteId;
  final LobbySprite sprite;

  _PendingSpriteSwitch({required this.spriteId, required this.sprite});
}

/// 翻转状态枚举
enum FlipState { idleLeft, idleRight, turningToLeft, turningToRight }

/// 大厅角色组件
/// 负责渲染角色贴图、弹跳动画、翻转动画、名字标签和聊天气泡
class LobbyPlayerComponent extends PositionComponent with HasGameReference {
  LobbyPlayerComponent({
    required LobbyUser user,
    required LobbySprite sprite,
    required bool showNameplate,
    required bool showChatBubble,
    required void Function(String userId, LobbyPosition arrivedPosition)
    onArrived,
    required this.onDustEmitted,
  }) : _user = user,
       _sprite = sprite,
       _currentSpriteId = user.spriteId,
       _showNameplate = showNameplate,
       _showChatBubble = showChatBubble,
       _onArrived = onArrived,
       super(
         // 自己的层级比普通玩家高，不会被遮挡；但低于悬停(100)和关注(200)
         priority: user.isSelf ? _selfPriority : 1,
         // 必须与 _spriteWidth/_spriteHeight 一致，否则 anchor、翻转补偿与文字坐标会错位
         size: Vector2(_spriteWidth, _spriteHeight),
         anchor: Anchor.bottomCenter,
       );

  /// 自己的默认层级：高于普通玩家(1)，低于悬停(100)和关注(200)
  static const int _selfPriority = 50;

  /// 当前组件的默认层级（自己为 50，其他玩家为 1）
  int get _defaultPriority => _user.isSelf ? _selfPriority : 1;

  LobbyUser _user;
  LobbySprite _sprite;
  String _currentSpriteId;
  bool _showNameplate;
  bool _showChatBubble;
  bool _isFollowed = false;

  /// 公开用户数据（供 LobbyGame 右键菜单使用）
  LobbyUser get user => _user;

  /// 是否被关注（橙名 + 最高层级）
  bool get isFollowed => _isFollowed;
  set isFollowed(bool value) {
    if (_isFollowed != value) {
      _isFollowed = value;
      // 关注的用户层级最高（200），普通用户为 1（自己为 50），悬停为 100
      if (value && !_isHovered) {
        priority = 200;
      } else if (!value && !_isHovered) {
        priority = _defaultPriority;
      }
      // 名字缓存失效，下次 render 时重建
      _cachedDisplayName = null;
      _cachedNamePainter?.dispose();
      _cachedNamePainter = null;
      _cachedNameStrokePainter?.dispose();
      _cachedNameStrokePainter = null;
      // 状态文字缓存失效（关注状态影响颜色）
      _cachedStatusText = null;
      _cachedStatusPainter?.dispose();
      _cachedStatusPainter = null;
      _cachedStatusStrokePainter?.dispose();
      _cachedStatusStrokePainter = null;
    }
  }

  /// 到达目标时的回调（用于通知 Bloc 更新状态）
  final void Function(String userId, LobbyPosition arrivedPosition) _onArrived;

  // 模型切换特效状态
  SpriteSwitchState _spriteSwitchState = SpriteSwitchState.idle;
  double _spriteOpacity = 1.0;
  static const double _spriteSwitchDuration = 0.3; // 淡入淡出时长（秒）
  LobbySprite? _pendingSprite; // 待切换的模型配置
  _PendingSpriteSwitch? _queuedSpriteSwitch; // 排队的切换请求
  SpriteComponent? _spriteComponent; // 当前显示的贴图组件（静态图片）
  SpriteAnimationComponent? _animComponent; // 当前显示的动画组件（图集动画）

  bool _isHovered = false;
  bool _isContextMenuTarget = false;
  double _contextMenuPulse = 0.0; // 0~1 脉冲动画进度

  // ========== 聊天气泡动画系统 ==========
  /// 气泡整体透明度
  double _bubbleOpacity = 0.0;
  /// 气泡整体缩放
  double _bubbleScale = 0.0;
  /// 气泡缩放速度（弹簧物理）
  double _bubbleScaleVelocity = 0.0;

  /// 气泡动画阶段: 0=hidden, 1=entering, 2=visible, 3=exiting
  int _bubblePhase = 0;

  // 弹簧参数（Q弹效果）
  static const double _springStiffness = 280.0;
  static const double _springDamping = 14.0;
  static const double _exitSpringStiffness = 200.0;
  static const double _exitSpringDamping = 18.0;

  // 消息文字切换动画
  String? _displayedMessage;       // 当前显示的消息文字
  String? _outgoingMessage;        // 正在退出的旧消息文字
  double _msgTransitionProgress = 1.0; // 0→1，1=新消息完全显示
  static const double _msgTransitionSpeed = 4.5; // 切换速度

  /// 气泡是否曾经可见（用于检测首次出现 vs 消息更新）
  bool _bubbleWasVisible = false;

  // 翻转状态机
  FlipState _flipState = FlipState.idleRight;
  static const double _flipSpeed = 12.0; // 翻转速度（弧度/秒，这里用 0-1 范围）

  // === 移动扬尘粒子效果 ===
  /// 发射扬尘的回调（由 LobbyGame 提供，在世界空间中创建 DustCloudComponent）
  final void Function(LobbyPosition worldPosition) onDustEmitted;

  /// 累积移动距离（用于控制粒子发射频率）
  double _accumulatedMoveDistance = 0.0;

  /// 发射扬尘的距离阈值（每移动这么多像素发射一次粒子）
  static const double _dustEmitDistanceThreshold = 18.0;

  // 移动插值
  LobbyPosition _currentRenderPosition = LobbyPosition(x: 0, y: 0);
  LobbyPosition? _targetPosition;
  bool _spriteLoaded = false;

  /// 是否正在执行 fade-in 动画（贴图预加载完成后渐显）
  bool _fadeInActive = false;

  /// fade-in 动画速度（每秒增加的透明度，3.0 表示约 0.33 秒完成）
  static const double _fadeInSpeed = 3.0;

  /// 当前渲染位置（插值中的实际位置，供外部相机跟随使用）
  LobbyPosition get currentRenderPosition => _currentRenderPosition;

  // 移动插值速度必须与 LobbyBloc._moveSpeed (2.8) 保持一致，避免判断时机不同导致抖动
  static const double _moveSpeed = 2.8;

  // ========== 行走节奏动画（方案一）==========
  /// 行走周期时间（累积移动时间）
  double _walkCycleTime = 0;

  /// 行走周期频率（Hz），约 8 次/秒的脚步节奏
  static const double _walkCycleFrequency = 8.0;

  /// 垂直起伏幅度（像素）
  static const double _walkBobAmplitude = 3.0;

  /// 水平摇摆幅度（像素）
  static const double _walkSwayAmplitude = 1.5;

  /// 旋转幅度（弧度）
  static const double _walkTiltAngle = 0.03;

  /// 行走动画振幅（用于停止时平滑衰减）
  double _walkAmplitude = 1.0;

  /// 停止时振幅衰减速度（每秒衰减量）
  static const double _walkAmplitudeDecaySpeed = 8.0;

  // ========== TextPainter 缓存系统 ==========
  // 名字标签缓存
  String? _cachedDisplayName;
  TextPainter? _cachedNamePainter;
  TextPainter? _cachedNameStrokePainter;
  // 状态文字缓存
  String? _cachedStatusText;
  TextPainter? _cachedStatusPainter;
  TextPainter? _cachedStatusStrokePainter;

  // 组件销毁标志，用于防止图片加载完成后访问已销毁的组件
  bool _disposed = false;
  static const double _spriteWidth = 152.0;

  /// 逻辑框总高度：名字 + 角色槽 + 状态行 + 底部留白（调角色大小只改 [_characterDisplayHeight]）
  static const double _spriteHeight = 180.0;
  static const double _characterDisplayHeight = 52.0; // 角色贴图显示高度（所有尺寸的基准常量）
  static const double _nameGapAboveCharacter = 4.0;
  static const double _statusGapBelowSprite = 4.0;
  static const double _statusTextLineHeight = 14.0;
  static const double _padBottom = 6.0;

  /// 底部状态文字区域高度（供外部补偿点击偏移）
  static const double statusTextAreaHeight =
      _statusGapBelowSprite + _statusTextLineHeight + _padBottom;

  double _characterDisplayWidth = 52.0; // 角色贴图显示宽度（由高度和图片宽高比计算）
  double _actualCharWidth = 44.0; // 实际用于计算文字位置的宽度
  double _actualCharHeight = 58.0; // 实际用于计算文字位置的高度

  /// 角色贴图区域左上角 Y（脚底在槽底，与状态行之间留白由常量控制）
  double get _characterSlotTopY =>
      size.y -
      _characterDisplayHeight -
      _statusGapBelowSprite -
      _statusTextLineHeight -
      _padBottom;

  /// 角色贴图底边 Y（不含状态行）
  double get _spriteBottomY => _characterSlotTopY + _characterDisplayHeight;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 计算初始位置
    _currentRenderPosition = _user.renderPosition;
    _targetPosition = _user.targetPosition;

    // 初始化翻转状态（不触发动画）
    _flipState = (_user.facing == LobbyFacing.right)
        ? FlipState.idleRight
        : FlipState.idleLeft;
    _applyScale();

    await _loadCharacterSpriteProgressive();
    _updatePosition();
  }

  /// 渐进式加载角色贴图
  ///
  /// 优先从 LobbyGame 的预加载注册表获取已缓存的图片，
  /// 如果尚未加载完成则注册等待，由 Game 层统一加载后批量通知。
  /// 图集模式仍走独立加载路径。
  Future<void> _loadCharacterSpriteProgressive() async {
    final url = _sprite.spriteUrl;
    if (url == null || url.isEmpty) return;

    try {
      // 图集模式：仍走独立加载（图集逻辑复杂，不适合批量预加载）
      if (_sprite.usesAtlas) {
        await _loadAtlasSprite();
        return;
      }

      // 检查 Game 层是否已经预加载了该 spriteId 的图片
      final game = findGame();
      if (game is LobbyGame) {
        final preloaded = game.getPreloadedSpriteImage(_currentSpriteId);
        if (preloaded != null) {
          // 已预加载完成，直接使用并 fade-in
          _applyPreloadedImage(preloaded);
          return;
        }

        // 尚未加载完成，注册等待通知
        // 由 Game 层的 _preloadSpritesProgressively 或 ensureSpriteLoaded 统一调度加载
        game.registerSpriteWaiter(_currentSpriteId, this);

        // 设置超时兜底：如果 5 秒后仍未收到通知，走独立加载
        Future.delayed(const Duration(seconds: 5), () {
          if (!_disposed && !isRemoved && !_spriteLoaded) {
            LogService.w('[LobbyPlayerComponent] 等待预加载超时，走独立加载: $_currentSpriteId');
            game.unregisterSpriteWaiter(_currentSpriteId, this);
            _loadNetworkSprite();
          }
        });
        return;
      }

      // fallback：如果无法获取 Game 引用，走原有独立加载路径
      await _loadNetworkSprite();
    } catch (_) {
      // 加载失败，使用 fallback 色块
    }
  }

  /// 当 Game 层预加载完成后调用此方法，批量通知所有使用该 spriteId 的玩家
  void onSpritePreloaded(ui.Image image) {
    if (_disposed || isRemoved) return;
    // 如果已经加载过了（比如模型切换后重新加载），忽略
    if (_spriteLoaded) return;
    _applyPreloadedImage(image);
  }

  /// 当 Game 层预加载失败时调用，回退到独立加载路径
  void onSpritePreloadFailed() {
    if (_disposed || isRemoved) return;
    if (_spriteLoaded) return;
    // 回退到原有的独立加载路径
    _loadNetworkSprite();
  }

  /// 应用预加载的图片，创建 SpriteComponent 并触发 fade-in
  void _applyPreloadedImage(ui.Image image) {
    _spriteLoaded = true;

    // 计算图片实际宽高比，调整显示宽度（高度固定为 _characterDisplayHeight）
    _characterDisplayWidth =
        _characterDisplayHeight * (image.width / image.height);

    // 角色身体在组件内的位置（居中显示）
    final charX = (_spriteWidth - _characterDisplayWidth) / 2;
    final charY = _characterSlotTopY;

    // 实际用于文字计算的尺寸
    _actualCharWidth = _characterDisplayWidth * 0.55;
    _actualCharHeight = _characterDisplayHeight * 0.7;

    final spriteComp = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2(_characterDisplayWidth, _characterDisplayHeight),
      position: Vector2(charX, charY),
    );
    // 初始完全透明，通过 update 中的 fade-in 逐渐显示
    spriteComp.paint = Paint()..color = const Color(0x00FFFFFF);
    add(spriteComp);
    _spriteComponent = spriteComp;

    // 触发 fade-in 动画
    _spriteOpacity = 0.0;
    _fadeInActive = true;
  }

  Future<void> _loadCharacterSprite() async {
    final url = _sprite.spriteUrl;
    if (url == null || url.isEmpty) return;

    try {
      // 检查是否使用图集模式
      if (_sprite.usesAtlas) {
        await _loadAtlasSprite();
      } else {
        await _loadNetworkSprite();
      }
    } catch (_) {
      // 加载失败，使用 fallback 色块
    }
  }

  /// 加载 TexturePacker 图集动画
  Future<void> _loadAtlasSprite() async {
    if (!_sprite.usesAtlas) return;

    try {
      // 从 assets 加载图集（使用游戏实例的 atlasFromAssets）
      final gameRef = findGame();
      if (gameRef == null) {
        LogService.w('[LobbyPlayerComponent] 游戏实例未找到');
        await _loadNetworkSprite();
        return;
      }

      final atlas = await gameRef.atlasFromAssets(_sprite.atlasUrl!);
      if (isRemoved) return;

      // 获取动画帧
      final frameName = _sprite.atlasImagePath ?? _sprite.id;
      final frames = atlas.findSpritesByName(frameName);

      if (frames.isEmpty) {
        LogService.w('[LobbyPlayerComponent] 图集中未找到帧: $frameName');
        await _loadNetworkSprite();
        return;
      }

      _spriteLoaded = true;

      // 计算显示尺寸（基于第一帧）
      final frameWidth = frames.first.srcSize.x.toDouble();
      final frameHeight = frames.first.srcSize.y.toDouble();
      _characterDisplayWidth =
          _characterDisplayHeight * (frameWidth / frameHeight);

      // 角色身体在组件内的位置
      final charX = (_spriteWidth - _characterDisplayWidth) / 2;
      final charY = _characterSlotTopY;

      // 实际用于文字计算的尺寸
      _actualCharWidth = _characterDisplayWidth * 0.55;
      _actualCharHeight = _characterDisplayHeight * 0.7;

      // 创建动画组件
      final frameDuration = _sprite.frameDuration ?? 0.1;
      final animation = SpriteAnimation.spriteList(
        frames,
        stepTime: frameDuration,
        loop: true,
      );

      final animComponent = SpriteAnimationComponent(
        animation: animation,
        size: Vector2(_characterDisplayWidth, _characterDisplayHeight),
        position: Vector2(charX, charY),
      );

      await add(animComponent);
      _animComponent = animComponent;
      LogService.d('[LobbyPlayerComponent] 图集动画加载成功: ${_sprite.id}');
    } catch (e, stack) {
      LogService.e('[LobbyPlayerComponent] 图集加载失败: ${_sprite.id}', e, stack);
      // 回退到单张图片
      await _loadNetworkSprite();
    }
  }

  /// 加载单张网络图片
  Future<void> _loadNetworkSprite() async {
    final url = _sprite.spriteUrl;
    if (url == null || url.isEmpty) return;

    try {
      final imageInfo = await _loadCachedOrNetworkImage(url);
      if (imageInfo == null || isRemoved) return;

      // 防止竞态：如果在 await 期间已经通过其他路径加载完成，跳过
      if (_spriteLoaded) return;

      _spriteLoaded = true;

      // 计算图片实际宽高比，调整显示宽度（高度固定为 _characterDisplayHeight）
      _characterDisplayWidth =
          _characterDisplayHeight * (imageInfo.width / imageInfo.height);

      // 角色身体在组件内的位置（居中显示，与名字/状态行同一套布局）
      final charX = (_spriteWidth - _characterDisplayWidth) / 2;
      final charY = _characterSlotTopY;

      // 实际用于文字计算的尺寸（与 fallback 一致的中心区域）
      _actualCharWidth = _characterDisplayWidth * 0.55;
      _actualCharHeight = _characterDisplayHeight * 0.7;

      final spriteComp = SpriteComponent(
        sprite: Sprite(imageInfo),
        size: Vector2(_characterDisplayWidth, _characterDisplayHeight),
        position: Vector2(charX, charY),
      );
      await add(spriteComp);
      _spriteComponent = spriteComp;
    } catch (_) {
      // 加载失败，使用 fallback 色块
    }
  }

  /// 优先从本地缓存加载图片，fallback 到网络
  Future<ui.Image?> _loadCachedOrNetworkImage(String url) async {
    // 确保图片服务已初始化
    if (!LobbyImageCacheService.instance.isInitialized) {
      await LobbyImageCacheService.instance.init();
    }

    // 优先从本地缓存获取
    final cachedImage = await LobbyImageCacheService.instance.getDecodedImage(
      url,
    );
    if (cachedImage != null) {
      debugPrint('[LobbyPlayerComponent] 从本地缓存加载角色贴图: $url');
      return cachedImage;
    }

    // 本地没有，尝试网络下载
    if (_disposed) return null;
    debugPrint('[LobbyPlayerComponent] 本地缓存未命中，下载角色贴图: $url');
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

  /// 根据 spriteId 查找对应的 LobbySprite
  LobbySprite _findSpriteById(List<LobbySprite> sprites, String spriteId) {
    return sprites.firstWhere(
      (s) => s.id == spriteId,
      orElse: () => const LobbySprite(
        id: 'sprite_01',
        label: '默认角色',
        accentColor: Color(0xFF60A5FA),
      ),
    );
  }

  void updateUser(LobbyUser user, [List<LobbySprite>? availableSprites]) {
    // 同步 BLoC 中的状态（statusText、lastMessage 等需要从 BLoC 同步）
    final prevLastMessage = _user.lastMessage;
    final prevLastMessageAt = _user.lastMessageAt;

    // 检测 spriteId 变化，触发动画切换
    final spriteIdChanged = _currentSpriteId != user.spriteId;
    if (spriteIdChanged) {
      debugPrint(
        '[LobbyPlayerComponent] 检测到模型切换: $_currentSpriteId -> ${user.spriteId}',
      );
      // 查找新模型的配置
      LobbySprite newSprite = _sprite;
      if (availableSprites != null) {
        newSprite = _findSpriteById(availableSprites, user.spriteId);
      }
      _triggerSpriteSwitch(user.spriteId, newSprite);
    }

    _user = _user.copyWith(
      nickname: user.nickname,
      isAnonymous: user.isAnonymous,
      serverUserId: user.serverUserId,
      businessUserId: user.businessUserId,
      avatarUrl: user.avatarUrl ?? _user.avatarUrl,
      isMoving: user.isMoving,
      isOnline: user.isOnline,
      lastMessage: user.lastMessage,
      lastMessageAt: user.lastMessageAt,
      statusText: user.statusText,
      spriteId: user.spriteId,
      facing: user.facing,
    );

    if (prevLastMessage != user.lastMessage ||
        prevLastMessageAt != user.lastMessageAt) {
      debugPrint(
        '[LobbyPlayerComponent] updateUser 消息变化: ${user.userId} '
        'lastMessage="${user.lastMessage}" '
        'lastMessageAt=${user.lastMessageAt} '
        'hasVisibleMessage=${_user.hasVisibleMessage}',
      );
      // 新消息到来
      if (_user.hasVisibleMessage) {
        final newMsg = _user.lastMessage ?? '';
        if (_bubblePhase == 2 || _bubblePhase == 1) {
          // 气泡已可见或正在入场 → 消息切换动画
          _outgoingMessage = _displayedMessage;
          _displayedMessage = newMsg;
          _msgTransitionProgress = 0.0;
          // 给气泡一个小弹跳反馈
          _bubbleScaleVelocity += 3.0;
        } else if (_bubblePhase == 3) {
          // 气泡正在退场 → 反转为入场，保留当前 scale 实现平滑过渡
          _displayedMessage = newMsg;
          _outgoingMessage = null;
          _msgTransitionProgress = 1.0;
          _bubblePhase = 1; // entering
          // 不重置 _bubbleScale，从当前位置弹回 1.0
          _bubbleScaleVelocity = 0.0;
        } else {
          // 气泡完全隐藏 → 入场动画
          _displayedMessage = newMsg;
          _outgoingMessage = null;
          _msgTransitionProgress = 1.0;
          _bubblePhase = 1; // entering
          _bubbleScale = 0.0;
          _bubbleScaleVelocity = 0.0;
          _bubbleOpacity = 0.0;
        }
      }
    }

    // 更新目标位置
    if (user.targetPosition != null) {
      _targetPosition = user.targetPosition;
    }

    // 直接使用服务器下发的 facing，不再自行计算
    // 服务器的 facing 是权威值，客户端自行计算会导致其他用户朝向错误
    final newFacing = user.facing;
    final targetFacing = (newFacing == LobbyFacing.right)
        ? FlipState.idleRight
        : FlipState.idleLeft;

    switch (_flipState) {
      case FlipState.idleRight:
      case FlipState.idleLeft:
        // 空闲状态：若服务器朝向与当前不一致，触发动画切换
        if (_flipState != targetFacing) {
          final dir = _flipState == FlipState.idleLeft ? '右边' : '左边';
          debugPrint(
            '[LobbyPlayerComponent] 服务器朝向变化，开始转向$dir: ${_user.userId}',
          );
          _flipState = (targetFacing == FlipState.idleRight)
              ? FlipState.turningToRight
              : FlipState.turningToLeft;
        }
        break;
      case FlipState.turningToLeft:
        // 正在转向左边：若服务器要求朝右，立即反转
        if (targetFacing == FlipState.idleRight) {
          debugPrint('[LobbyPlayerComponent] 服务器朝向变化，立即转向右边: ${_user.userId}');
          _flipState = FlipState.turningToRight;
        }
        break;
      case FlipState.turningToRight:
        // 正在转向右边：若服务器要求朝左，立即反转
        if (targetFacing == FlipState.idleLeft) {
          debugPrint('[LobbyPlayerComponent] 服务器朝向变化，立即转向左边: ${_user.userId}');
          _flipState = FlipState.turningToLeft;
        }
        break;
    }
  }

  /// 触发动画切换特效
  void _triggerSpriteSwitch(String newSpriteId, LobbySprite newSprite) {
    // 如果正在切换中，将请求排队
    if (_spriteSwitchState != SpriteSwitchState.idle) {
      debugPrint('[LobbyPlayerComponent] 模型切换中，排入队列: $newSpriteId');
      _queuedSpriteSwitch = _PendingSpriteSwitch(
        spriteId: newSpriteId,
        sprite: newSprite,
      );
      return;
    }

    _spriteSwitchState = SpriteSwitchState.fadingOut;
    _currentSpriteId = newSpriteId;
    _pendingSprite = newSprite; // 存储待切换的模型配置
  }

  void updateDisplaySettings({
    required bool showNameplate,
    required bool showChatBubble,
  }) {
    _showNameplate = showNameplate;
    _showChatBubble = showChatBubble;
  }

  void updatePosition(double dt) {
    if (_targetPosition == null) return;

    final dx = _targetPosition!.x - _currentRenderPosition.x;
    final dy = _targetPosition!.y - _currentRenderPosition.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    // 使用角色中心点判断方向
    // 角色中心点 = 当前渲染位置 + 中心偏移
    final currentCenterX = _currentRenderPosition.x;
    final targetCenterX = _targetPosition!.x;

    if (_flipState == FlipState.idleLeft ||
        _flipState == FlipState.turningToLeft) {
      // 当前朝左时：目标在右侧就转向右
      if (targetCenterX > currentCenterX + 1.0) {
        _flipState = FlipState.turningToRight;
      }
    } else if (_flipState == FlipState.idleRight ||
        _flipState == FlipState.turningToRight) {
      // 当前朝右时：目标在左侧就转向左
      if (targetCenterX < currentCenterX - 1.0) {
        _flipState = FlipState.turningToLeft;
      }
    }

    if (dist <= _moveSpeed) {
      // 到达目标
      _currentRenderPosition = _targetPosition!;
      final arrivedPosition = _currentRenderPosition;
      _targetPosition = null;
      // 重置扬尘累积距离
      _accumulatedMoveDistance = 0.0;
      // 不再清空 statusText，让它保持 BLoC 中的值（由 GameStatusService 驱动）
      _user = _user.copyWith(isMoving: false);
      debugPrint(
        '[LobbyPlayerComponent] 到达目标: ${_user.userId} isMoving=${_user.isMoving} statusText=${_user.statusText}',
      );
      // 通知 LobbyGame 更新 Bloc 状态，避免其他角色误判为仍在移动
      _onArrived(_user.userId, arrivedPosition);
    } else {
      // 继续移动
      final ratio = _moveSpeed / dist;
      _currentRenderPosition = LobbyPosition(
        x: _currentRenderPosition.x + dx * ratio,
        y: _currentRenderPosition.y + dy * ratio,
      );

      // === 扬尘粒子发射逻辑 ===
      _accumulatedMoveDistance += _moveSpeed;
      if (_accumulatedMoveDistance >= _dustEmitDistanceThreshold) {
        _accumulatedMoveDistance -= _dustEmitDistanceThreshold;
        // 使用当前渲染位置（脚底）作为扬尘生成位置
        onDustEmitted(_currentRenderPosition);
      }
    }

    _updatePosition();
  }

  /// 当前翻转值：1.0 = 右边, 0.0 = 左边
  double _flipValue = 1.0;

  void _updatePosition() {
    // 水平翻转
    double scaleX = 1.0 - 2.0 * _flipValue;
    double scaleY = 1.0;

    // 角色直接使用世界坐标（地图坐标），相机自动处理世界到屏幕的映射
    position = Vector2(_currentRenderPosition.x, _currentRenderPosition.y);

    // 应用翻转
    scale = Vector2(scaleX, scaleY);
  }

  /// 应用当前翻转状态到 scale
  void _applyScale() {
    _flipValue =
        (_flipState == FlipState.idleRight ||
            _flipState == FlipState.turningToRight)
        ? 1.0
        : 0.0;
    scale = Vector2(1.0 - 2.0 * _flipValue, 1.0);
  }

  void handleHoverEnter() {
    if (!_isHovered) {
      _isHovered = true;
      if (!_isContextMenuTarget) {
        priority = 100; // 悬停时提升层级，信息不会被遮挡
      }
    }
  }

  void handleHoverExit() {
    if (_isHovered) {
      _isHovered = false;
      if (!_isContextMenuTarget) {
        priority = _isFollowed ? 200 : _defaultPriority; // 关注用户保持高层级
      }
    }
  }

  /// 设置为右键菜单目标（边框闪动）
  void setContextMenuTarget(bool value) {
    if (_isContextMenuTarget != value) {
      _isContextMenuTarget = value;
      if (value) {
        _contextMenuPulse = 0.0;
        priority = 100; // 提升层级
      } else {
        // 恢复层级
        if (_isHovered) {
          priority = 100;
        } else {
          priority = _isFollowed ? 200 : _defaultPriority;
        }
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // 判定区域仅限角色贴图本身的范围（不含名字和状态文字区域的额外边距）
    final cx = _spriteWidth / 2;
    final halfWidth = _characterDisplayWidth / 2;

    if (point.x < cx - halfWidth || point.x > cx + halfWidth) return false;
    // 仅角色贴图的垂直范围
    if (point.y < _characterSlotTopY || point.y > _characterSlotTopY + _characterDisplayHeight) {
      return false;
    }

    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 贴图 fade-in 动画（预加载完成后渐显）
    if (_fadeInActive) {
      _spriteOpacity = (_spriteOpacity + dt * _fadeInSpeed).clamp(0.0, 1.0);
      _spriteComponent?.paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, _spriteOpacity);
      if (_spriteOpacity >= 1.0) {
        _fadeInActive = false;
      }
    }

    // 状态机驱动的翻转动画
    _updateFlipState(dt);

    // 更新模型切换动画
    _updateSpriteSwitch(dt);

    // 更新聊天气泡消失动画
    _updateBubbleAnimation(dt);

    // 更新行走节奏动画（方案一）
    _updateWalkCycle(dt);

    // 更新右键菜单目标脉冲动画
    if (_isContextMenuTarget) {
      _contextMenuPulse += dt * 4.0; // 约 0.25 秒一个周期
      if (_contextMenuPulse > 1.0) _contextMenuPulse -= 1.0;
    }
  }

  /// ========== 行走节奏动画实现（方案一）==========
  /// 更新行走节奏动画
  ///
  /// 原理：通过程序化方式模拟行走时的上下起伏、水平摇摆和轻微倾斜，
  /// 直接应用到精灵图组件的位置和角度上。
  /// 停止时使用振幅衰减实现平滑过渡。
  void _updateWalkCycle(double dt) {
    final isActuallyMoving = _targetPosition != null;

    if (isActuallyMoving) {
      // 累积行走周期时间
      _walkCycleTime += dt * _walkCycleFrequency;

      // 移动时振幅快速恢复到 1.0
      _walkAmplitude = (_walkAmplitude + dt * _walkAmplitudeDecaySpeed).clamp(
        0.0,
        1.0,
      );
    } else {
      // 停止时振幅衰减
      if (_walkAmplitude > 0) {
        _walkAmplitude -= dt * _walkAmplitudeDecaySpeed;
        if (_walkAmplitude < 0.01) {
          _walkAmplitude = 0;
          _walkCycleTime = 0;
        }
      }
    }

    // 计算行走节奏值（用于驱动精灵图偏移）
    if (_walkAmplitude > 0) {
      _applySpriteWalkOffset();
    } else {
      // 重置精灵图位置到原始位置
      _resetSpritePosition();
    }
  }

  /// 将行走偏移应用到精灵图组件
  void _applySpriteWalkOffset() {
    // 行走节奏的相位
    final phase = _walkCycleTime * math.pi * 2;

    // 垂直起伏：模拟脚步交替的上下跳动（乘以振幅衰减）
    final bobOffset = math.sin(phase) * _walkBobAmplitude * _walkAmplitude;

    // 水平摇摆：身体左右微摆（半周期，乘以振幅衰减）
    final swayOffset =
        math.cos(phase * 0.5) * _walkSwayAmplitude * _walkAmplitude;

    // 轻微倾斜：模拟身体重心的左右转移（乘以振幅衰减）
    final tiltAngle = math.sin(phase) * _walkTiltAngle * _walkAmplitude;

    // 应用到精灵图组件（动画）
    if (_animComponent != null) {
      final baseY = _characterSlotTopY;
      _animComponent!.position.y = baseY - bobOffset;
      _animComponent!.angle = tiltAngle;
      _animComponent!.position.x =
          (_spriteWidth - _characterDisplayWidth) / 2 + swayOffset;
    }

    // 应用到精灵图组件（静态）
    if (_spriteComponent != null) {
      final baseY = _characterSlotTopY;
      _spriteComponent!.position.y = baseY - bobOffset;
      _spriteComponent!.angle = tiltAngle;
      _spriteComponent!.position.x =
          (_spriteWidth - _characterDisplayWidth) / 2 + swayOffset;
    }
  }

  /// 重置精灵图位置到原始位置
  void _resetSpritePosition() {
    final baseX = (_spriteWidth - _characterDisplayWidth) / 2;
    final baseY = _characterSlotTopY;

    if (_animComponent != null) {
      _animComponent!.position.x = baseX;
      _animComponent!.position.y = baseY;
      _animComponent!.angle = 0;
    }

    if (_spriteComponent != null) {
      _spriteComponent!.position.x = baseX;
      _spriteComponent!.position.y = baseY;
      _spriteComponent!.angle = 0;
    }
  }

  /// 更新聊天气泡动画（弹簧物理驱动）
  void _updateBubbleAnimation(double dt) {
    final hasVisibleMessage = _user.hasVisibleMessage;

    // 修复：后台恢复时气泡卡住的问题
    // 当气泡处于活跃阶段（entering/visible）但消息已过期，且 _bubbleWasVisible
    // 未被正确更新时（例如 app 在后台期间收到消息，updateUser 设置了 phase
    // 但游戏循环未运行导致 _bubbleWasVisible 未同步），强制触发退场动画。
    if (!hasVisibleMessage && !_bubbleWasVisible &&
        (_bubblePhase == 1 || _bubblePhase == 2)) {
      _bubblePhase = 3; // exiting
      _bubbleScaleVelocity = 1.5;
    }

    // 状态转换检测
    if (hasVisibleMessage && !_bubbleWasVisible) {
      // 消息刚出现 → 入场（仅在 updateUser 未处理时）
      if (_bubblePhase == 0) {
        _bubblePhase = 1; // entering
        _bubbleScale = 0.0;
        _bubbleScaleVelocity = 0.0;
        _bubbleOpacity = 0.0;
        _displayedMessage = _user.lastMessage;
        _outgoingMessage = null;
        _msgTransitionProgress = 1.0;
      } else if (_bubblePhase == 3) {
        // 退场中 → 反转入场
        _bubblePhase = 1;
        _bubbleScaleVelocity = 0.0;
        _displayedMessage = _user.lastMessage;
        _outgoingMessage = null;
        _msgTransitionProgress = 1.0;
      }
    } else if (!hasVisibleMessage && _bubbleWasVisible) {
      // 消息消失 → 退场
      if (_bubblePhase == 1 || _bubblePhase == 2) {
        _bubblePhase = 3; // exiting
        _bubbleScaleVelocity = 1.5; // 先微微放大再缩小的初速度
      }
    }
    _bubbleWasVisible = hasVisibleMessage;

    // 弹簧物理更新
    switch (_bubblePhase) {
      case 1: // entering - 弹簧驱动 scale 从 0→1
        final displacement = _bubbleScale - 1.0;
        final springForce = -_springStiffness * displacement;
        final dampingForce = -_springDamping * _bubbleScaleVelocity;
        _bubbleScaleVelocity += (springForce + dampingForce) * dt;
        _bubbleScale += _bubbleScaleVelocity * dt;
        // 透明度快速跟上
        _bubbleOpacity = (_bubbleOpacity + dt * 8.0).clamp(0.0, 1.0);
        // 收敛判定
        if ((displacement).abs() < 0.005 && _bubbleScaleVelocity.abs() < 0.1) {
          _bubbleScale = 1.0;
          _bubbleScaleVelocity = 0.0;
          _bubbleOpacity = 1.0;
          _bubblePhase = 2; // visible
        }
        break;

      case 2: // visible - 弹簧回弹（消息切换时的小弹跳）
        if ((_bubbleScale - 1.0).abs() > 0.002 || _bubbleScaleVelocity.abs() > 0.05) {
          final displacement = _bubbleScale - 1.0;
          final springForce = -_springStiffness * displacement;
          final dampingForce = -_springDamping * _bubbleScaleVelocity;
          _bubbleScaleVelocity += (springForce + dampingForce) * dt;
          _bubbleScale += _bubbleScaleVelocity * dt;
          if ((displacement).abs() < 0.002 && _bubbleScaleVelocity.abs() < 0.05) {
            _bubbleScale = 1.0;
            _bubbleScaleVelocity = 0.0;
          }
        }
        _bubbleOpacity = 1.0;
        break;

      case 3: // exiting - 弹簧驱动 scale 从 1→0（先微弹再缩）
        final displacement = _bubbleScale - 0.0; // target = 0
        final springForce = -_exitSpringStiffness * displacement;
        final dampingForce = -_exitSpringDamping * _bubbleScaleVelocity;
        _bubbleScaleVelocity += (springForce + dampingForce) * dt;
        _bubbleScale += _bubbleScaleVelocity * dt;
        _bubbleScale = _bubbleScale.clamp(0.0, 1.5);
        // 透明度跟随缩放
        _bubbleOpacity = (_bubbleScale / 0.5).clamp(0.0, 1.0);
        // 收敛判定
        if (_bubbleScale < 0.02 && _bubbleScaleVelocity.abs() < 0.1) {
          _bubbleScale = 0.0;
          _bubbleScaleVelocity = 0.0;
          _bubbleOpacity = 0.0;
          _bubblePhase = 0; // hidden
          _displayedMessage = null;
          _outgoingMessage = null;
        }
        break;

      default: // hidden
        break;
    }

    // 消息文字切换动画进度
    if (_msgTransitionProgress < 1.0) {
      _msgTransitionProgress = (_msgTransitionProgress + _msgTransitionSpeed * dt).clamp(0.0, 1.0);
      if (_msgTransitionProgress >= 1.0) {
        _outgoingMessage = null;
      }
    }
  }

  /// 更新模型切换动画
  void _updateSpriteSwitch(double dt) {
    if (_spriteSwitchState == SpriteSwitchState.idle) return;

    final step = dt / _spriteSwitchDuration;

    switch (_spriteSwitchState) {
      case SpriteSwitchState.fadingOut:
        _spriteOpacity -= step;
        if (_spriteOpacity <= 0) {
          _spriteOpacity = 0;
          _spriteSwitchState = SpriteSwitchState.fadingIn;
          // 淡出完成，重新加载贴图
          _reloadSprite();
        }
        break;

      case SpriteSwitchState.fadingIn:
        _spriteOpacity += step;
        if (_spriteOpacity >= 1.0) {
          _spriteOpacity = 1.0;
          _spriteSwitchState = SpriteSwitchState.idle;
          debugPrint('[LobbyPlayerComponent] 模型切换完成: ${_user.spriteId}');

          // 检查是否有排队的切换请求，如果有则立即处理
          if (_queuedSpriteSwitch != null) {
            debugPrint(
              '[LobbyPlayerComponent] 处理排队的切换: ${_queuedSpriteSwitch!.spriteId}',
            );
            final queued = _queuedSpriteSwitch!;
            _queuedSpriteSwitch = null;
            _triggerSpriteSwitch(queued.spriteId, queued.sprite);
          }
        }
        break;

      case SpriteSwitchState.idle:
        break;
    }

    // 更新贴图组件的透明度
    if (_spriteComponent != null) {
      _spriteComponent!.paint = Paint()
        ..color = Colors.white.withValues(alpha: _spriteOpacity);
    }
  }

  /// 重新加载模型贴图
  Future<void> _reloadSprite() async {
    // 移除旧贴图
    _spriteComponent?.removeFromParent();
    _spriteComponent = null;
    _animComponent?.removeFromParent();
    _animComponent = null;
    _spriteLoaded = false;
    _fadeInActive = false; // 停止渐显动画，由 _updateSpriteSwitch 管理透明度

    // 应用待切换的模型配置
    if (_pendingSprite != null) {
      _sprite = _pendingSprite!;
      _pendingSprite = null;
    }

    // 重新加载新贴图
    await _loadCharacterSprite();

    // 重置行走周期，确保动画状态一致
    _walkCycleTime = 0;
  }

  /// 翻转状态机更新
  void _updateFlipState(double dt) {
    switch (_flipState) {
      case FlipState.idleLeft:
      case FlipState.idleRight:
        // 空闲状态：不做任何检查
        // 本地移动方向由 updatePosition 控制，服务器 facing 由 updateUser 处理
        // 两者互不干扰，避免到达目标后因服务器数据未更新而导致自动转向
        break;

      case FlipState.turningToLeft:
        // 正在转向左边，插值动画
        _flipValue -= _flipSpeed * dt;
        if (_flipValue <= 0.0) {
          _flipValue = 0.0;
          _flipState = FlipState.idleLeft;
          debugPrint('[LobbyPlayerComponent] 转向完成: left ${_user.userId}');
        }
        scale = Vector2(1.0 - 2.0 * _flipValue, 1.0);
        break;

      case FlipState.turningToRight:
        // 正在转向右边，插值动画
        _flipValue += _flipSpeed * dt;
        if (_flipValue >= 1.0) {
          _flipValue = 1.0;
          _flipState = FlipState.idleRight;
          debugPrint('[LobbyPlayerComponent] 转向完成: right ${_user.userId}');
        }
        scale = Vector2(1.0 - 2.0 * _flipValue, 1.0);
        break;
    }
  }

  @override
  void onRemove() {
    _disposed = true;
    // 取消贴图预加载等待注册
    final game = findGame();
    if (game is LobbyGame) {
      game.unregisterSpriteWaiter(_currentSpriteId, this);
    }
    // 释放缓存的 TextPainter 原生资源
    _cachedNamePainter?.dispose();
    _cachedNameStrokePainter?.dispose();
    _cachedStatusPainter?.dispose();
    _cachedStatusStrokePainter?.dispose();
    _cachedNamePainter = null;
    _cachedNameStrokePainter = null;
    _cachedStatusPainter = null;
    _cachedStatusStrokePainter = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    // 关注用户常驻高亮描边、右键菜单目标或悬停高亮
    if (_isContextMenuTarget || _isHovered || _isFollowed) {
      _renderSpriteOutline(canvas);
    }

    // 渲染名字标签
    if (_showNameplate) {
      _renderNameplate(canvas);
    }

    // 渲染角色身体
    _renderCharacter(canvas);

    // 渲染状态文字
    if (_user.statusText != null) {
      _renderStatusText(canvas);
    }

    // 渲染聊天气泡
    if (_showChatBubble && _bubblePhase != 0) {
      _renderChatBubble(canvas);
    }
  }

  /// 多向偏移渲染法：绘制角色精灵的轮廓描边高亮
  /// 原理：用纯色滤镜将角色变为高亮色，向 8 个方向各偏移几像素绘制作为底色，
  /// 最后在正中间绘制原始角色覆盖在上面，形成贴合角色形状的描边效果。
  void _renderSpriteOutline(Canvas canvas) {
    // 只有贴图加载完成才能使用此效果
    if (!_spriteLoaded) return;

    // 模型切换期间（淡出/淡入），描边也跟随透明度变化
    if (_spriteOpacity <= 0.0) return;

    // 确定描边颜色和宽度
    Color outlineColor;
    double outlineWidth;
    double glowAlpha;

    if (_isContextMenuTarget) {
      // 右键菜单目标：橙色脉冲描边
      final pulse = (math.sin(_contextMenuPulse * math.pi * 2) + 1.0) / 2.0;
      final alpha = (0.6 + pulse * 0.4) * _spriteOpacity;
      outlineColor = Colors.orangeAccent.withValues(alpha: alpha);
      outlineWidth = 2.5;
      glowAlpha = alpha * 0.5;
    } else if (_isHovered) {
      // 悬停：白色描边
      outlineColor = Colors.white.withValues(alpha: 0.95 * _spriteOpacity);
      outlineWidth = 2.0;
      glowAlpha = 0.4 * _spriteOpacity;
    } else {
      // 关注用户：金黄色常驻描边
      outlineColor = const Color(0xFFFFD740).withValues(alpha: 0.75 * _spriteOpacity);
      outlineWidth = 1.5;
      glowAlpha = 0.3 * _spriteOpacity;
    }

    // 创建纯色滤镜 Paint：保留图片透明度，将不透明像素替换为 outlineColor
    final outlinePaint = Paint()
      ..colorFilter = ColorFilter.mode(outlineColor, BlendMode.srcIn);

    // 外发光 Paint（模糊效果增强视觉）
    final glowPaint = Paint()
      ..colorFilter = ColorFilter.mode(
        outlineColor.withValues(alpha: glowAlpha),
        BlendMode.srcIn,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // 8 个方向的偏移量
    final offsets = [
      Offset(-outlineWidth, -outlineWidth),
      Offset(0, -outlineWidth),
      Offset(outlineWidth, -outlineWidth),
      Offset(-outlineWidth, 0),
      Offset(outlineWidth, 0),
      Offset(-outlineWidth, outlineWidth),
      Offset(0, outlineWidth),
      Offset(outlineWidth, outlineWidth),
    ];

    // 获取当前精灵图的 Sprite 对象
    final sprite = _spriteComponent?.sprite;
    final animSprite = _animComponent?.animationTicker?.getSprite();

    final activeSprite = sprite ?? animSprite;
    if (activeSprite == null) return;

    // 角色贴图在组件内的位置
    final charX = (_spriteWidth - _characterDisplayWidth) / 2;
    final charY = _characterSlotTopY;

    // 应用行走偏移（与 _applySpriteWalkOffset 保持一致）
    double walkOffsetX = 0;
    double walkOffsetY = 0;
    double walkAngle = 0;
    if (_walkAmplitude > 0) {
      final phase = _walkCycleTime * math.pi * 2;
      walkOffsetY = -(math.sin(phase) * _walkBobAmplitude * _walkAmplitude);
      walkOffsetX = math.cos(phase * 0.5) * _walkSwayAmplitude * _walkAmplitude;
      walkAngle = math.sin(phase) * _walkTiltAngle * _walkAmplitude;
    }

    final baseX = charX + walkOffsetX;
    final baseY = charY + walkOffsetY;

    // 先绘制外发光层（8 方向偏移，带模糊）
    for (final offset in offsets) {
      canvas.save();
      canvas.translate(baseX + offset.dx, baseY + offset.dy);
      if (walkAngle != 0) {
        canvas.translate(_characterDisplayWidth / 2, _characterDisplayHeight / 2);
        canvas.rotate(walkAngle);
        canvas.translate(-_characterDisplayWidth / 2, -_characterDisplayHeight / 2);
      }
      activeSprite.render(
        canvas,
        size: Vector2(_characterDisplayWidth, _characterDisplayHeight),
        overridePaint: glowPaint,
      );
      canvas.restore();
    }

    // 再绘制纯色描边层（8 方向偏移，清晰边缘）
    for (final offset in offsets) {
      canvas.save();
      canvas.translate(baseX + offset.dx, baseY + offset.dy);
      if (walkAngle != 0) {
        canvas.translate(_characterDisplayWidth / 2, _characterDisplayHeight / 2);
        canvas.rotate(walkAngle);
        canvas.translate(-_characterDisplayWidth / 2, -_characterDisplayHeight / 2);
      }
      activeSprite.render(
        canvas,
        size: Vector2(_characterDisplayWidth, _characterDisplayHeight),
        overridePaint: outlinePaint,
      );
      canvas.restore();
    }
  }

  void _renderNameplate(Canvas canvas) {
    // 保存 canvas 状态以处理翻转
    canvas.save();

    // 如果组件向左翻转（scale.x < 0），文字需要跟随翻转
    if (scale.x < 0) {
      // 以角色中心为轴翻转回正向
      final centerX = size.x / 2;
      canvas.translate(centerX, 0);
      canvas.scale(-1, 1);
      canvas.translate(-centerX, 0);
    }

    // 缓存名字 TextPainter，只在名字变化时重建
    final currentName = _user.displayName;
    if (_cachedDisplayName != currentName || _cachedNamePainter == null) {
      _cachedDisplayName = currentName;

      // 关注用户使用亮金橙色名字，普通用户白色
      final nameColor = _isFollowed
          ? const Color(0xFFFFD740) // 亮金黄色
          : Colors.white;

      final pixelTextStyle = TextStyle(
        fontFamily: null,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: nameColor,
      );

      final displayName = _truncateText(currentName, pixelTextStyle, 120);
      _cachedNamePainter = TextPainter(
        text: TextSpan(text: displayName, style: pixelTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // 关注用户使用橙色描边增强辨识度，普通用户黑色描边
      final strokeColor = _isFollowed
          ? const Color(0xFF8B4500) // 深橙棕色描边
          : Colors.black.withValues(alpha: 0.7);

      final strokeStyle = TextStyle(
        fontFamily: null,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = strokeColor,
      );
      _cachedNameStrokePainter = TextPainter(
        text: TextSpan(text: displayName, style: strokeStyle),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    // 居中绘制，名字紧贴角色头顶上方
    final offsetX = (_spriteWidth - _cachedNamePainter!.width) / 2;
    final offsetY =
        _characterSlotTopY - _cachedNamePainter!.height - _nameGapAboveCharacter;

    _cachedNameStrokePainter!.paint(canvas, Offset(offsetX, offsetY));
    _cachedNamePainter!.paint(canvas, Offset(offsetX, offsetY));

    canvas.restore();
  }

  /// 截断过长的文本，添加省略号
  String _truncateText(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) return text;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    // 如果文本宽度在允许范围内，直接返回
    if (textPainter.width <= maxWidth) {
      return text;
    }

    // 逐步减少文本长度直到宽度合适
    String truncated = text;
    const ellipsis = '...';
    while (truncated.isNotEmpty) {
      final testText = '$truncated$ellipsis';
      final testPainter = TextPainter(
        text: TextSpan(text: testText, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      if (testPainter.width <= maxWidth) {
        return testText;
      }
      // 移除最后一个字符（可能是汉字、英文字母或其他）
      truncated = truncated.substring(0, truncated.length - 1);
    }

    // 最少显示省略号
    return ellipsis;
  }

  void _renderCharacter(Canvas canvas) {
    // 贴图已加载时由 SpriteComponent 渲染
    if (_spriteLoaded) return;

    // Fallback：渐变色块（贴图未加载时显示，底与角色槽底对齐）
    // 应用透明度变换（用于模型切换特效）
    if (_spriteOpacity < 1.0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.white.withValues(alpha: _spriteOpacity),
      );
    }

    final charX = (_spriteWidth - _actualCharWidth) / 2;
    final charY =
        _characterSlotTopY + _characterDisplayHeight - _actualCharHeight;

    final rect = Rect.fromLTWH(
      charX,
      charY,
      _actualCharWidth,
      _actualCharHeight,
    );

    // 渐变填充
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _sprite.accentColor.withValues(alpha: 0.95),
          _sprite.accentColor.withValues(alpha: 0.55),
        ],
      ).createShader(rect);

    // 圆角矩形
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // 阴影
    final shadowPaint = Paint()
      ..color = _sprite.accentColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawRRect(rrect.shift(const Offset(0, 6)), shadowPaint);

    // 填充
    canvas.drawRRect(rrect, gradientPaint);

    // 边框
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(rrect, borderPaint);

    // 图标
    final iconPaint = Paint()..color = Colors.white;
    // 简单绘制一个圆形作为图标
    canvas.drawCircle(
      Offset(charX + _actualCharWidth / 2, charY + _actualCharHeight / 2),
      10,
      iconPaint,
    );

    // 关闭透明度层
    if (_spriteOpacity < 1.0) {
      canvas.restore();
    }
  }

  void _renderStatusText(Canvas canvas) {
    // 保存 canvas 状态以处理翻转
    canvas.save();

    // 如果组件向左翻转（scale.x < 0），文字需要跟随翻转
    if (scale.x < 0) {
      final centerX = size.x / 2;
      canvas.translate(centerX, 0);
      canvas.scale(-1, 1);
      canvas.translate(-centerX, 0);
    }

    // 缓存状态文字 TextPainter，只在文字变化时重建
    final currentStatus = _user.statusText ?? '';
    if (_cachedStatusText != currentStatus || _cachedStatusPainter == null) {
      _cachedStatusText = currentStatus;

      // 关注用户状态文字用浅金色，普通用户用灰白色
      final statusColor = _isFollowed
          ? const Color(0xFFFFD54F) // 浅金黄色
          : const Color(0xFFE2E8F0);

      final textStyle = TextStyle(
        fontFamily: null,
        color: statusColor,
        fontSize: 11,
      );

      final displayStatus = _truncateText(currentStatus, textStyle, 120);
      _cachedStatusPainter = TextPainter(
        text: TextSpan(text: displayStatus, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // 关注用户用深金色描边，普通用户用黑色描边
      final strokeColor = _isFollowed
          ? const Color(0xFF6D4C00) // 深金棕色描边
          : Colors.black.withValues(alpha: 0.6);

      final strokeStyle = TextStyle(
        fontFamily: null,
        fontSize: 11,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = strokeColor,
      );
      _cachedStatusStrokePainter = TextPainter(
        text: TextSpan(text: displayStatus, style: strokeStyle),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final offsetX = (_spriteWidth - _cachedStatusPainter!.width) / 2;
    final offsetY = _spriteBottomY + _statusGapBelowSprite;

    _cachedStatusStrokePainter!.paint(canvas, Offset(offsetX, offsetY));
    _cachedStatusPainter!.paint(canvas, Offset(offsetX, offsetY));

    canvas.restore();
  }

  void _renderChatBubble(Canvas canvas) {
    // 透明度为 0 时完全不渲染
    if (_bubbleOpacity <= 0.0 || _bubbleScale <= 0.0) return;

    // 保存状态并取消组件翻转的影响，使气泡始终正向
    canvas.save();
    if (scale.x < 0) {
      final centerX = size.x / 2;
      canvas.translate(centerX, 0);
      canvas.scale(-1, 1);
      canvas.translate(-centerX, 0);
    }

    // 聊天气泡位置 - 居中对齐在 sprite 上方
    final bubbleWidth = 120.0;
    final bubbleX = (_spriteWidth - bubbleWidth) / 2;
    const bubbleBottom = 80.0;

    // 测量当前消息文字高度
    final textStyle = TextStyle(
      fontFamily: null,
      color: const Color(0xFF0F172A),
      fontSize: 12,
      height: 1.3,
    );

    final currentMsg = _displayedMessage ?? '';
    final textSpan = TextSpan(text: currentMsg, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: bubbleWidth - 24);

    final lineCount = textPainter.computeLineMetrics().length;
    final bubbleHeight = (lineCount * 16.0 + 16.0).clamp(40.0, 64.0);
    final bubbleY = bubbleBottom - bubbleHeight;

    // 应用弹簧缩放（从底部中心缩放，更自然）
    final scaleCenterX = bubbleX + bubbleWidth / 2;
    final scaleCenterY = bubbleY + bubbleHeight; // 从底部缩放
    canvas.save();
    canvas.translate(scaleCenterX, scaleCenterY);
    canvas.scale(_bubbleScale, _bubbleScale);
    canvas.translate(-scaleCenterX, -scaleCenterY);

    // 气泡阴影（柔和发光）
    final shadowPaint = Paint()
      ..color = _sprite.accentColor.withValues(alpha: 0.18 * _bubbleOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final shadowRect = Rect.fromLTWH(
      bubbleX + 2,
      bubbleY + 3,
      bubbleWidth,
      bubbleHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(16)),
      shadowPaint,
    );

    final rect = Rect.fromLTWH(bubbleX, bubbleY, bubbleWidth, bubbleHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // 背景：毛玻璃质感渐变
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.96 * _bubbleOpacity),
          _sprite.accentColor.withValues(alpha: 0.10 * _bubbleOpacity),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // 顶部高光弧线
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.5 * _bubbleOpacity),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTWH(bubbleX, bubbleY, bubbleWidth, bubbleHeight * 0.45),
      );
    canvas.drawRRect(rrect, highlightPaint);

    // 边框（带角色主题色微光）
    final borderPaint = Paint()
      ..color = _sprite.accentColor.withValues(alpha: 0.25 * _bubbleOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, borderPaint);

    // ===== 消息文字渲染（带切换动画）=====
    // 裁剪区域，防止文字溢出气泡
    canvas.save();
    canvas.clipRRect(rrect);

    final textAreaX = bubbleX + 12;
    final textAreaY = bubbleY + 8;
    final textAreaHeight = bubbleHeight - 16;

    if (_outgoingMessage != null && _msgTransitionProgress < 1.0) {
      // 有旧消息正在退出 → 交叉动画
      // 使用 easeOut 曲线让动画更自然
      final t = _msgTransitionProgress;
      final easeT = 1.0 - (1.0 - t) * (1.0 - t); // easeOut

      // 旧消息：向上滑出 + 淡出
      final outOpacity = (1.0 - easeT).clamp(0.0, 1.0) * _bubbleOpacity;
      final outOffsetY = -easeT * textAreaHeight * 0.6;
      if (outOpacity > 0.01) {
        final outStyle = TextStyle(
          fontFamily: null,
          color: const Color(0xFF0F172A).withValues(alpha: outOpacity),
          fontSize: 12,
          height: 1.3,
        );
        final outSpan = TextSpan(text: _outgoingMessage!, style: outStyle);
        final outPainter = TextPainter(
          text: outSpan,
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '...',
        )..layout(maxWidth: bubbleWidth - 24);
        outPainter.paint(canvas, Offset(textAreaX, textAreaY + outOffsetY));
      }

      // 新消息：从下方滑入 + 淡入
      final inOpacity = easeT.clamp(0.0, 1.0) * _bubbleOpacity;
      final inOffsetY = (1.0 - easeT) * textAreaHeight * 0.6;
      if (inOpacity > 0.01) {
        final inStyle = TextStyle(
          fontFamily: null,
          color: const Color(0xFF0F172A).withValues(alpha: inOpacity),
          fontSize: 12,
          height: 1.3,
        );
        final inSpan = TextSpan(text: currentMsg, style: inStyle);
        final inPainter = TextPainter(
          text: inSpan,
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '...',
        )..layout(maxWidth: bubbleWidth - 24);
        inPainter.paint(canvas, Offset(textAreaX, textAreaY + inOffsetY));
      }
    } else {
      // 无切换动画，直接绘制当前消息
      final normalStyle = TextStyle(
        fontFamily: null,
        color: const Color(0xFF0F172A).withValues(alpha: _bubbleOpacity),
        fontSize: 12,
        height: 1.3,
      );
      final normalSpan = TextSpan(text: currentMsg, style: normalStyle);
      final normalPainter = TextPainter(
        text: normalSpan,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
      )..layout(maxWidth: bubbleWidth - 24);
      normalPainter.paint(canvas, Offset(textAreaX, textAreaY));
    }

    canvas.restore(); // 恢复裁剪

    // 气泡尾巴
    _drawBubbleTail(
      canvas,
      bubbleX + 14,
      bubbleY + bubbleHeight,
      _bubbleOpacity,
    );

    canvas.restore(); // 恢复缩放
    canvas.restore(); // 恢复翻转
  }

  void _drawBubbleTail(Canvas canvas, double x, double y, double opacity) {
    final path = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x + 6, y + 2, x + 14, y + 12)
      ..quadraticBezierTo(x + 6, y + 9, x + 1, y + 4)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.96 * opacity);
    final strokePaint = Paint()
      ..color = _sprite.accentColor.withValues(alpha: 0.35 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }
}
