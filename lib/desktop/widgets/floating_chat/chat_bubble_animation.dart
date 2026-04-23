import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Internal data model
// ---------------------------------------------------------------------------

class BubbleEntry {
  BubbleEntry({
    required this.id,
    required this.text,
    required this.senderName,
    required this.angle,
    required this.controller,
    required this.expireTimer,
    this.radius = 32.0,
  });

  final String id;
  final String text;
  final String senderName;

  /// Angle in radians, standard math convention:
  /// 0 = right, π/2 = up, π = left, 3π/2 = down.
  final double angle;
  final double radius;
  final AnimationController controller;
  final Timer expireTimer;
}

// ---------------------------------------------------------------------------
// Pure functions
// ---------------------------------------------------------------------------

String truncateBubbleText(String content) {
  if (content.length > 20) return '${content.substring(0, 20)}…';
  return content;
}

String truncateSenderName(String name) {
  if (name.length > 6) return '${name.substring(0, 6)}…';
  return name;
}

double generateBubbleAngle(
  double seed, {
  double angleMin = 0,
  double angleMax = 2 * pi,
}) {
  return angleMin + seed * (angleMax - angleMin);
}

// ---------------------------------------------------------------------------
// _ChatBubbleWidget — scale + fade animation wrapper
// ---------------------------------------------------------------------------

class _ChatBubbleWidget extends StatelessWidget {
  const _ChatBubbleWidget({required this.entry});

  final BubbleEntry entry;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: entry.controller,
      curve: Curves.easeOutBack,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: t, child: child),
        );
      },
      child: _BubbleBody(text: entry.text, senderName: entry.senderName),
    );
  }
}

// ---------------------------------------------------------------------------
// _BubbleBody — bubble with tail always at bottom-center
// ---------------------------------------------------------------------------

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.text, required this.senderName});

  final String text;
  final String senderName;

  static const double _tailH = 7.0;
  static const double _tailW = 10.0;
  static const double _borderRadius = 12.0;
  static const double _maxWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1E293B);
    const borderColor = Color(0xFF334155);
    const nameColor = Color(0xFF60A5FA);
    const textColor = Color(0xFFE2E8F0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bubble body
        Container(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF0080FF).withValues(alpha: 0.1),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                style: const TextStyle(
                  color: nameColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Triangle tail pointing downward (toward button)
        CustomPaint(
          size: Size(_tailW * 2, _tailH),
          painter: _TrianglePainter(
            fillColor: bgColor,
            borderColor: borderColor,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TrianglePainter — downward-pointing triangle tail
// ---------------------------------------------------------------------------

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}

// ---------------------------------------------------------------------------
// ChatBubbleAnimation — public widget
// ---------------------------------------------------------------------------

/// Renders chat bubbles scattered around the floating button.
///
/// Each bubble is placed at [entry.radius] from the button centre at
/// [entry.angle], then rotated so its downward tail always points back
/// toward the button. The container is centred on the button centre.
class ChatBubbleAnimation extends StatelessWidget {
  const ChatBubbleAnimation({
    super.key,
    required this.bubbles,
    required this.buttonSize,
  });

  final List<BubbleEntry> bubbles;
  final Size buttonSize;

  /// Half the container size. Container is 2× this in each dimension.
  /// Must be >= max(radius) + bubble diagonal/2 to avoid clipping.
  static const double halfContainer = 200.0;

  @override
  Widget build(BuildContext context) {
    // Button centre in container-local coordinates.
    const cx = halfContainer;
    const cy = halfContainer;

    return IgnorePointer(
      child: SizedBox(
        width: halfContainer * 2,
        height: halfContainer * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: bubbles.map((entry) {
            // Bubble centre in container-local coordinates.
            // Standard math angle → screen coords: negate sin for y-down.
            final bx = cx + cos(entry.angle) * entry.radius;
            final by = cy - sin(entry.angle) * entry.radius;

            // Rotation so the tail (bottom of the Column) points toward
            // the button centre at (cx, cy).
            // atan2 in screen coords gives the angle of the vector
            // from bubble to button. The tail points down by default
            // (screen angle = π/2), so we subtract π/2.
            final rotation = atan2(cy - by, cx - bx) - pi / 2;

            return Positioned(
              key: ValueKey(entry.id),
              left: bx,
              top: by,
              child: FractionalTranslation(
                // Shift so the widget's bottom-centre (tail tip) aligns to (bx, by).
                // This means the bubble body always grows away from the button.
                translation: const Offset(-0.5, -1.0),
                child: Transform.rotate(
                  angle: rotation,
                  // Rotate around the tail tip (bottom-centre of the widget)
                  alignment: Alignment.bottomCenter,
                  child: _ChatBubbleWidget(entry: entry),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
