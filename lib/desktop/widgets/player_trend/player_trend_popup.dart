import 'package:flutter/material.dart';
import '../../../core/models/server_models.dart';
import 'player_trend_chart.dart';

/// 玩家趋势图表弹出层
/// 用于在悬停时显示玩家趋势图表
class PlayerTrendPopup extends StatefulWidget {
  /// 玩家趋势数据
  final List<PlayerTrendInfo> infos;

  /// 服务器最大玩家数
  final int maxPlayers;

  /// 弹出位置
  final Offset position;

  /// 是否显示
  final bool show;

  /// 鼠标进入回调
  final VoidCallback? onMouseEnter;

  /// 鼠标离开回调
  final VoidCallback? onMouseLeave;

  const PlayerTrendPopup({
    super.key,
    required this.infos,
    required this.maxPlayers,
    required this.position,
    required this.show,
    this.onMouseEnter,
    this.onMouseLeave,
  });

  @override
  State<PlayerTrendPopup> createState() => _PlayerTrendPopupState();
}

class _PlayerTrendPopupState extends State<PlayerTrendPopup> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    if (widget.show) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(PlayerTrendPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      if (widget.show) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.infos.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        if (_fadeAnimation.value == 0) return const SizedBox.shrink();
        
        return Positioned(
          left: widget.position.dx,
          top: widget.position.dy,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: MouseRegion(
              onEnter: (_) => widget.onMouseEnter?.call(),
              onExit: (_) => widget.onMouseLeave?.call(),
              child: PlayerTrendChart(
                infos: widget.infos,
                maxPlayers: widget.maxPlayers,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 玩家趋势图表悬停控制器
/// 用于管理悬停显示逻辑
class PlayerTrendHoverController {
  bool _isHoveringTrigger = false;
  bool _isHoveringPopup = false;
  VoidCallback? _onShowChange;
  
  /// 设置显示状态变化回调
  set onShowChange(VoidCallback? callback) {
    _onShowChange = callback;
  }

  /// 是否应该显示弹出层
  bool get shouldShow => _isHoveringTrigger || _isHoveringPopup;

  /// 触发器鼠标进入
  void onTriggerEnter() {
    _isHoveringTrigger = true;
    _onShowChange?.call();
  }

  /// 触发器鼠标离开
  void onTriggerLeave() {
    _isHoveringTrigger = false;
    // 延迟检查，给用户时间移动到弹出层
    Future.delayed(const Duration(milliseconds: 100), () {
      _onShowChange?.call();
    });
  }

  /// 弹出层鼠标进入
  void onPopupEnter() {
    _isHoveringPopup = true;
    _onShowChange?.call();
  }

  /// 弹出层鼠标离开
  void onPopupLeave() {
    _isHoveringPopup = false;
    _onShowChange?.call();
  }

  /// 重置状态
  void reset() {
    _isHoveringTrigger = false;
    _isHoveringPopup = false;
    _onShowChange?.call();
  }
}

/// 带悬停显示趋势图的包装组件
class PlayerTrendHoverWrapper extends StatefulWidget {
  /// 子组件（触发器）
  final Widget child;

  /// 玩家趋势数据
  final List<PlayerTrendInfo>? infos;

  /// 服务器最大玩家数
  final int maxPlayers;

  /// 弹出层偏移量
  final Offset popupOffset;

  const PlayerTrendHoverWrapper({
    super.key,
    required this.child,
    required this.infos,
    required this.maxPlayers,
    this.popupOffset = const Offset(0, -220),
  });

  @override
  State<PlayerTrendHoverWrapper> createState() => _PlayerTrendHoverWrapperState();
}

class _PlayerTrendHoverWrapperState extends State<PlayerTrendHoverWrapper> {
  final _controller = PlayerTrendHoverController();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller.onShowChange = _updateOverlay;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _updateOverlay() {
    if (_controller.shouldShow && widget.infos != null && widget.infos!.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: widget.popupOffset,
          child: MouseRegion(
            onEnter: (_) => _controller.onPopupEnter(),
            onExit: (_) => _controller.onPopupLeave(),
            child: PlayerTrendChart(
              infos: widget.infos!,
              maxPlayers: widget.maxPlayers,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有趋势数据，直接返回子组件
    if (widget.infos == null || widget.infos!.isEmpty) {
      return widget.child;
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _controller.onTriggerEnter(),
        onExit: (_) => _controller.onTriggerLeave(),
        child: widget.child,
      ),
    );
  }
}
