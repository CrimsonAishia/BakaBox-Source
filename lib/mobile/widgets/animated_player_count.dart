import 'package:flutter/material.dart';

class AnimatedPlayerCount extends StatefulWidget {
  final int currentPlayers;
  final int maxPlayers;
  final TextStyle? textStyle;
  final Color? iconColor;

  const AnimatedPlayerCount({
    super.key,
    required this.currentPlayers,
    required this.maxPlayers,
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
        Icon(
          Icons.person,
          size: 16,
          color: widget.iconColor,
        ),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final displayCurrent = (_previousCurrent + 
                (_currentCurrent - _previousCurrent) * _animation.value).round();
            final displayMax = (_previousMax + 
                (_currentMax - _previousMax) * _animation.value).round();
            
            return Text(
              '$displayCurrent/$displayMax',
              style: widget.textStyle,
            );
          },
        ),
      ],
    );
  }
}
