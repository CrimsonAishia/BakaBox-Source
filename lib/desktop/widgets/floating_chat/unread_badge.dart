import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  static String formatCount(int n) {
    if (n <= 0) return '';
    if (n <= 99) return '$n';
    return '99+';
  }

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.red500,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatCount(count),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
