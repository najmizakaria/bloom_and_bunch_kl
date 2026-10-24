import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AuthHeaderBanner extends StatelessWidget {
  final double heightFactor;
  final Widget? overlayContent;
  final bool showBackButton;

  const AuthHeaderBanner({
    super.key,
    this.heightFactor = 0.35,
    this.overlayContent,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext me) {
    final screenHeight = MediaQuery.of(me).size.height;

    return Container(
      height: screenHeight * heightFactor,
      width: double.infinity,
      decoration: const BoxDecoration(color: AppColors.primary),
      child: SafeArea(
        child: Stack(
          children: [
            if (showBackButton)
              Positioned(
                top: 12,
                left: 16,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.of(me).pop(),
                ),
              ),
            ?overlayContent,
          ],
        ),
      ),
    );
  }
}
