import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'floating_window_animations.dart';
import 'floating_window_colors.dart';
import 'floating_window_state.dart';

/// 左侧图标区域 - 固定宽度 70px
class FloatingIconArea extends StatefulWidget {
  final FloatingWindowState state;

  const FloatingIconArea({super.key, required this.state});

  @override
  State<FloatingIconArea> createState() => _FloatingIconAreaState();
}

class _FloatingIconAreaState extends State<FloatingIconArea>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = FloatingWindowAnimations.createBounceAnimation(_bounceController);
    
    _updateAnimation();
  }

  @override
  void didUpdateWidget(FloatingIconArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.state != widget.state.state) {
      _updateAnimation();
      
      // 成功时播放弹跳动画
      if (widget.state.isSuccess) {
        _bounceController.forward().then((_) => _bounceController.reverse());
      }
    }
  }

  void _updateAnimation() {
    if (_isLoadingState(widget.state)) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  bool _isLoadingState(FloatingWindowState state) {
    return state.isIdle || 
           state.isLaunching || 
           state.isConnecting || 
           state.isLoading || 
           state.isQueueing;
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = FloatingWindowColors.fromState(widget.state);
    final isLoading = _isLoadingState(widget.state);

    return SizedBox(
      width: 70,
      child: Center(
        child: AnimatedSwitcher(
          duration: FloatingWindowAnimations.iconCrossfadeDuration,
          child: isLoading
              ? _buildLoadingIcon(color)
              : _buildStaticIcon(color),
        ),
      ),
    );
  }

  Widget _buildLoadingIcon(Color color) {
    return SizedBox(
      key: ValueKey('loading_${widget.state.state}'),
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 旋转圆环
          RotationTransition(
            turns: _rotationController,
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          // 中心图标
          Icon(
            _getStateIcon(widget.state),
            size: 20,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticIcon(Color color) {
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Container(
        key: ValueKey('static_${widget.state.state}'),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Icon(
          _getTerminalIcon(widget.state),
          size: 26,
          color: color,
        ),
      ),
    );
  }

  IconData _getStateIcon(FloatingWindowState state) {
    if (state.isLaunching) return MdiIcons.rocketLaunch;
    if (state.isQueueing) return MdiIcons.accountMultiplePlus;
    if (state.isConnecting) return MdiIcons.connection;
    if (state.isLoading) return MdiIcons.mapMarker;
    return MdiIcons.connection;
  }

  IconData _getTerminalIcon(FloatingWindowState state) {
    if (state.isSuccess) return MdiIcons.checkCircle;
    if (state.isFailed) return MdiIcons.closeCircle;
    if (state.isServerFull) return MdiIcons.accountGroup;
    if (state.isPaused) return MdiIcons.pause;
    return MdiIcons.informationOutline;
  }
}
