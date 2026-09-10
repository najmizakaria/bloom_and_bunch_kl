import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/pill_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _loading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await AuthService().sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.code == 'invalid-email'
          ? 'Enter a valid email address.'
          : 'We could not send the reset email. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrand(compact: true),
            const SizedBox(height: 38),
            Icon(
              _sent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
              color: AppColors.primary,
              size: 42,
            ),
            const SizedBox(height: 18),
            Text(
              _sent ? 'Check your inbox' : 'Reset your password',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              _sent
                  ? 'We sent a password reset link to ${_emailController.text.trim()}.'
                  : 'Enter the email connected to your account and we’ll send you a reset link.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 28),
            if (!_sent) ...[
              const AuthFieldLabel('Email address'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email address';
                  if (!email.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              PillButton(
                label: 'Send reset link',
                isLoading: _loading,
                onPressed: _send,
              ),
            ] else ...[
              PillButton(
                label: 'Back to login',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _sent = false),
                child: const Text('Use another email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
