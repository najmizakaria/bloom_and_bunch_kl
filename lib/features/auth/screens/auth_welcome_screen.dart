import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/pill_button.dart';
import 'login_screen.dart';
import 'signup_email_screen.dart';

class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const AuthBrand(),
          const SizedBox(height: 42),
          Text(
            'Flowers for every\nmeaningful moment',
            textAlign: TextAlign.center,
            style: const AppTypography.display(),
          ),
          const SizedBox(height: 14),
          Text(
            'Fresh bouquets, thoughtful details, and delivery across KL.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 44),
          PillButton(
            label: 'Get started',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SignupEmailScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: 'I already have an account',
            isPrimary: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'By continuing, you agree to our Terms of Use and Privacy Policy.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
