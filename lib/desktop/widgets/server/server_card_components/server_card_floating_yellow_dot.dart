import 'package:flutter/material.dart';

class ServerCardFloatingYellowDot extends StatelessWidget {
  const ServerCardFloatingYellowDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD700),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.8),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
