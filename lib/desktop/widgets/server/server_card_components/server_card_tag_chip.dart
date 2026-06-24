import 'package:flutter/material.dart';
import '../../../../core/models/map_tag_models.dart';

class ServerCardTagChip extends StatelessWidget {
  final MapTagSimple tag;

  const ServerCardTagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    if (tag.difficultyType == 'tier_combined' &&
        tag.color != null &&
        tag.color!.contains(',')) {
      final colorStrs = tag.color!.split(',');
      final colors = <Color>[];
      for (final hexStr in colorStrs) {
        try {
          final hex = hexStr.replaceFirst('#', '');
          if (hex.length == 6) {
            colors.add(Color(int.parse('FF$hex', radix: 16)));
          } else if (hex.length == 8) {
            colors.add(Color(int.parse(hex, radix: 16)));
          }
        } catch (_) {}
      }

      if (colors.isNotEmpty) {
        final gradientColors = colors.length == 1
            ? [
                Color.lerp(
                  colors.first,
                  Colors.white,
                  0.6,
                )!.withValues(alpha: 0.4),
                colors.first.withValues(alpha: 0.5),
                Color.lerp(
                  colors.first,
                  Colors.black,
                  0.2,
                )!.withValues(alpha: 0.45),
              ]
            : colors.map((c) => c.withValues(alpha: 0.6)).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: colors.first.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            tag.isOfficial == true ? '官:${tag.name}' : tag.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: colors.first.withValues(alpha: 0.8),
                  blurRadius: 2,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 1,
                  offset: const Offset(1, 1),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 1,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
          ),
        );
      }
    }

    final tagColorValue = tag.colorValue;

    if (tagColorValue != null) {
      final darkColor = Color.lerp(tagColorValue, Colors.black, 0.2)!;
      final lightColor = Color.lerp(tagColorValue, Colors.white, 0.6)!;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              lightColor.withValues(alpha: 0.4),
              tagColorValue.withValues(alpha: 0.5),
              darkColor.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColorValue.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tagColorValue.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          tag.isOfficial == true ? '官:${tag.name}' : tag.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: tagColorValue.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, 0),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
        ),
      );
    }

    // 无颜色时
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        tag.isOfficial == true ? '官:${tag.name}' : tag.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
