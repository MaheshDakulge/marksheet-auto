import 'package:flutter/material.dart';
import '../core/constants.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onActionButtonPressed;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox,
    this.buttonText,
    this.onActionButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (buttonText != null && onActionButtonPressed != null)
              ElevatedButton(
                onPressed: onActionButtonPressed,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(buttonText!),
              ),
          ],
        ),
      ),
    );
  }
}
