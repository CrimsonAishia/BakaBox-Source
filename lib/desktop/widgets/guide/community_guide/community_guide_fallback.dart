import 'package:flutter/material.dart';

/// 封面 / 头像缺失时使用的渐变与图标轮换池。
///
/// 通过 seed（如攻略 id、用户 id）取模选择，保证同一对象的渐变稳定。
class CommunityGuideFallback {
  CommunityGuideFallback._();

  static const List<List<Color>> _palette = [
    [Color(0xFFE94560), Color(0xFFC2185B), Color(0xFF8E1538)],
    [Color(0xFFFFD54F), Color(0xFFFFA726), Color(0xFF6D4C41)],
    [Color(0xFF26C6DA), Color(0xFF1976D2), Color(0xFF512DA8)],
    [Color(0xFFD32F2F), Color(0xFF8E1538), Color(0xFF4A148C)],
    [Color(0xFF66BB6A), Color(0xFF43A047), Color(0xFF1B5E20)],
    [Color(0xFF4DB6AC), Color(0xFF00897B), Color(0xFF004D40)],
    [Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFF0D47A1)],
    [Color(0xFFB388FF), Color(0xFF7E57C2), Color(0xFF311B92)],
    [Color(0xFFEF5350), Color(0xFFC62828), Color(0xFF6A1B9A)],
    [Color(0xFF81D4FA), Color(0xFF29B6F6), Color(0xFF01579B)],
    [Color(0xFFEC407A), Color(0xFFAD1457), Color(0xFF4A148C)],
    [Color(0xFFFFB74D), Color(0xFFEF5350), Color(0xFF6A1B9A)],
  ];

  static const List<IconData> _icons = [
    Icons.local_florist,
    Icons.auto_awesome,
    Icons.style,
    Icons.castle,
    Icons.account_balance,
    Icons.airline_stops,
    Icons.flutter_dash,
    Icons.temple_buddhist,
    Icons.water_drop,
    Icons.flash_on,
    Icons.castle_outlined,
  ];

  static List<Color> gradient(int seed) {
    final s = seed.abs();
    return _palette[s % _palette.length];
  }

  static IconData icon(int seed) {
    final s = seed.abs();
    return _icons[s % _icons.length];
  }
}
