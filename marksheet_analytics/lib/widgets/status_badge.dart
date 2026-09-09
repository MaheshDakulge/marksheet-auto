import 'package:flutter/material.dart';
import '../core/constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label = status.toUpperCase();

    if (status == 'done' || status == 'completed') {
      bgColor = AppColors.success.withValues(alpha: 0.15);
      textColor = AppColors.success;
    } else if (status == 'processing' || status == 'pending') {
      bgColor = AppColors.warning.withValues(alpha: 0.15);
      textColor = AppColors.warning;
    } else if (status == 'failed' || status == 'error') {
      bgColor = AppColors.error.withValues(alpha: 0.15);
      textColor = AppColors.error;
    } else {
      bgColor = AppColors.textSecondary.withValues(alpha: 0.15);
      textColor = AppColors.textSecondary;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
      },
      child: Container(
        key: ValueKey<String>(status),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
