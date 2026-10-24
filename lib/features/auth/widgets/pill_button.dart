import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Widget? icon;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isPrimary ? AppColors.onPrimary : AppColors.primary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Text(label),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isPrimary
          ? FilledButton(
              onPressed: isLoading ? null : onPressed,
              child: content,
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              child: content,
            ),
    );
  }
}
