import 'package:flutter/material.dart';

/// 浮窗动画工具类
class FloatingWindowAnimations {
  // 动画时长
  static const Duration enterDuration = Duration(milliseconds: 250);
  static const Duration exitDuration = Duration(milliseconds: 200);
  static const Duration colorTransitionDuration = Duration(milliseconds: 200);
  static const Duration iconCrossfadeDuration = Duration(milliseconds: 200);

  // 动画曲线
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;

  /// 创建成功弹跳动画
  static Animation<double> createBounceAnimation(
    AnimationController controller,
  ) {
    return Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  /// 创建失败抖动动画
  static Animation<Offset> createShakeAnimation(
    AnimationController controller,
  ) {
    return TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0.02, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.02, 0), end: const Offset(-0.02, 0)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.02, 0), end: const Offset(0.02, 0)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.02, 0), end: const Offset(-0.02, 0)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.02, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }
}
