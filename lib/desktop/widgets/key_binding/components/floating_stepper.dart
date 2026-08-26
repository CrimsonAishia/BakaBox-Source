import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class FloatingStepper extends StatefulWidget {
  final List<String> steps;
  final List<bool> completedSteps;
  final ValueChanged<int> onStepTapped;
  final int activeIndex;

  const FloatingStepper({
    super.key,
    required this.steps,
    required this.completedSteps,
    required this.onStepTapped,
    this.activeIndex = 0,
  });

  @override
  State<FloatingStepper> createState() => _FloatingStepperState();
}

class _FloatingStepperState extends State<FloatingStepper> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.slate800.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppColors.slate700.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(widget.steps.length, (index) {
                  return _StepperItem(
                    index: index,
                    title: widget.steps[index],
                    isCompleted: widget.completedSteps[index],
                    isActive: index == widget.activeIndex,
                    onTap: () => widget.onStepTapped(index),
                    isDark: isDark,
                    isExpanded: _isExpanded,
                  );
                }),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Tooltip(
                    message: _isExpanded ? '折叠' : '展开',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_double_arrow_right
                              : Icons.keyboard_double_arrow_left,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperItem extends StatefulWidget {
  final int index;
  final String title;
  final bool isCompleted;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final bool isExpanded;

  const _StepperItem({
    required this.index,
    required this.title,
    required this.isCompleted,
    this.isActive = false,
    required this.onTap,
    required this.isDark,
    required this.isExpanded,
  });

  @override
  State<_StepperItem> createState() => _StepperItemState();
}

class _StepperItemState extends State<_StepperItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isCompleted = widget.isCompleted;
    final isActive = widget.isActive;
    final index = widget.index;
    final isExpanded = widget.isExpanded;

    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final activeBgColor = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.1);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive
                ? activeBgColor
                : (_isHovered ? hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.emerald500
                      : (isActive || _isHovered
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.emerald500
                        : (isActive || _isHovered
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.slate500
                                    : Colors.grey[400]!)),
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive || _isHovered
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.slate300
                                    : Colors.grey[600]),
                        ),
                      ),
              ),
              if (isExpanded) ...[
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCompleted || isActive || _isHovered
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCompleted || isActive || _isHovered
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? AppColors.slate400 : Colors.grey[600]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DraggableFloatingStepper extends StatefulWidget {
  final FloatingStepper child;

  const DraggableFloatingStepper({super.key, required this.child});

  @override
  State<DraggableFloatingStepper> createState() =>
      _DraggableFloatingStepperState();
}

class _DraggableFloatingStepperState extends State<DraggableFloatingStepper> {
  double? _right = 5;
  double? _bottom = 24;
  double? _left;
  double? _top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      right: _right,
      bottom: _bottom,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            if (_left != null) {
              _left = _left! + details.delta.dx;
            } else if (_right != null) {
              _right = _right! - details.delta.dx;
            }

            if (_top != null) {
              _top = _top! + details.delta.dy;
            } else if (_bottom != null) {
              _bottom = _bottom! - details.delta.dy;
            }
          });
        },
        child: widget.child,
      ),
    );
  }
}
