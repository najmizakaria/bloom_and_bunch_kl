import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PillButton extends StatefulWidget {
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
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: widget.isPrimary ? AppColors.primaryRosewood : Colors.white,
              foregroundColor: widget.isPrimary ? Colors.white : AppColors.textDark,
              shape: const StadiumBorder(),
              side: widget.isPrimary
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            onPressed: widget.isLoading ? null : widget.onPressed,
            child: widget.isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.isPrimary ? Colors.white : AppColors.textDark,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isPrimary ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}