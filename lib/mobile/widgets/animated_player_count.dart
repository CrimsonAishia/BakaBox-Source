import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AnimatedPlayerCount extends StatefulWidget {
  final int currentPlayers;
  final int maxPlayers;
  final int queueCount;
  final int warmupCount;
  final TextStyle? textStyle;
  final Color? iconColor;

  const AnimatedPlayerCount({
    super.key,
    required this.currentPlayers,
    required this.maxPlayers,
    this.queueCount = 0,
    this.warmupCount = 0,
    this.textStyle,
    this.iconColor,
  });

  @override
  State<AnimatedPlayerCount> createState() => _AnimatedPlayerCountState();
}

class _AnimatedPlayerCountState extends State<AnimatedPlayerCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousCurrent = 0;
  int _currentCurrent = 0;
  int _previousMax = 0;
  int _currentMax = 0;

  @override
  void initState() {
    super.initState();
    _currentCurrent = widget.currentPlayers;
    _previousCurrent = widget.currentPlayers;
    _currentMax = widget.maxPlayers;
    _previousMax = widget.maxPlayers;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AnimatedPlayerCount oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentPlayers != widget.currentPlayers ||
        oldWidget.maxPlayers != widget.maxPlayers) {
      _previousCurrent = _currentCurrent;
      _currentCurrent = widget.currentPlayers;
      _previousMax = _currentMax;
      _currentMax = widget.maxPlayers;

      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person, size: 16, color: widget.iconColor),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final displayCurrent =
                (_previousCurrent +
                        (_currentCurrent - _previousCurrent) * _animation.value)
                    .round();
            final displayMax =
                (_previousMax + (_currentMax - _previousMax) * _animation.value)
                    .round();

            final extraCount = widget.queueCount + widget.warmupCount;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$displayCurrent', style: widget.textStyle),
                if (extraCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: _buildExtraCount(
                      widget.queueCount,
                      widget.warmupCount,
                      extraCount,
                    ),
                  ),
                Text('/$displayMax', style: widget.textStyle),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildExtraCount(int queueCount, int warmupCount, int extraCount) {
    final baseStyle = widget.textStyle ?? const TextStyle(fontSize: 13);
    final style = baseStyle.copyWith(fontWeight: FontWeight.bold);

    if (queueCount > 0 && warmupCount > 0) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFF44336), AppColors.amber500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
        child: Text('+$extraCount', style: style.copyWith(color: Colors.white)),
      );
    } else if (queueCount > 0) {
      return Text(
        '+$extraCount',
        style: style.copyWith(color: const Color(0xFFF44336)),
      );
    } else {
      return Text(
        '+$extraCount',
        style: style.copyWith(color: AppColors.amber500),
      );
    }
  }
}
