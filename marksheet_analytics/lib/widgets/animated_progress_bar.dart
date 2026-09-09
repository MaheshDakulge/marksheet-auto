import 'package:flutter/material.dart';
import '../core/constants.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const AnimatedProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.background,
          color: AppColors.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        );
      },
    );
  }
}
