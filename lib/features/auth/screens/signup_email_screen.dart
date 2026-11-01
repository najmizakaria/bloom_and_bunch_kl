import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/legal_documents.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/pill_button.dart';
import 'login_screen.dart';

class SignupEmailScreen extends StatefulWidget {
  const SignupEmailScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _authService = widget.authService ?? AuthService();
  bool _passwordVisible = false;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _finish() {
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _signUp() async {
    if (_loading || _googleLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final credential = await _authService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: '',
      );
      if (credential?.user != null) _finish();
    } on FirebaseAuthException catch (error) {
      _showError(switch (error.code) {
        'email-already-in-use' => 'An account already uses this email.',
        'weak-password' =>
          'Use a stronger password with at least 6 characters.',
        'invalid-email' => 'Enter a valid email address.',
        _ => error.message ?? 'We could not create your account.',
      });
    } catch (_) {
      _showError('We could not create your account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignUp() async {
    if (_loading || _googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential?.user != null) _finish();
    } catch (_) {
      _showError('Google sign-up did not complete. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrand(compact: true),
            const SizedBox(height: 28),
            Text(
              'Create your account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Order and customise flowers in just a few steps.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 26),
            const AuthFieldLabel('Full name'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                hintText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            const AuthFieldLabel('Email address'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Enter your email address';
                if (!email.contains('@')) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const AuthFieldLabel('Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _signUp(),
              decoration: InputDecoration(
                hintText: 'At least 6 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter a password';
                if (value.length < 6) return 'Use at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 22),
            PillButton(
              label: 'Create account',
              isLoading: _loading,
              onPressed: _signUp,
            ),
            const SizedBox(height: 22),
            const AuthDivider(),
            const SizedBox(height: 22),
            PillButton(
              label: 'Continue with Google',
              isPrimary: false,
              isLoading: _googleLoading,
              icon: const Text(
                'G',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _googleSignUp,
            ),
            const SizedBox(height: 18),
            const Text(
              'By creating an account, you agree to our Terms of Use and Privacy Policy.',
              textAlign: TextAlign.center,
              style: AppTypography.caption(
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const PolicyLinks(),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already registered?',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
