import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_header_banner.dart';
import '../widgets/pill_button.dart';

class SignupEmailScreen extends StatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _finishAuthentication() {
    if (!mounted) return;

    // This screen is pushed on top of AuthGate. Authentication rebuilds the
    // gate underneath it, so remove the pushed auth screens once the profile
    // has been created and reveal the role-appropriate home screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
      );
      if (credential?.user != null) _finishAuthentication();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _showError('An account already exists for that email.');
          break;
        case 'weak-password':
          _showError('Password is too weak (use at least 6 characters).');
          break;
        case 'invalid-email':
          _showError('That email address looks invalid.');
          break;
        default:
          _showError(e.message ?? 'Sign up failed. Please try again.');
      }
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential?.user != null) _finishAuthentication();
    } catch (_) {
      _showError('Google sign-up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AuthHeaderBanner(
            heightFactor: 0.28,
            showBackButton: true,
            overlayContent: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_florist,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'bloom & bunch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.86,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Signup',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create your own account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _label('Full name'),
                      _field(
                        controller: _nameController,
                        hint: 'Alex Smith',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your name'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Email address'),
                      _field(
                        controller: _emailController,
                        hint: 'alexsmith.mobbin@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(v.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _label('Phone number'),
                      _field(
                        controller: _phoneController,
                        hint: '012-3456789',
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your phone number'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Password'),
                      _field(
                        controller: _passwordController,
                        hint: '••••••••',
                        obscureText: !_isPasswordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _label('Confirm password'),
                      _field(
                        controller: _confirmPasswordController,
                        hint: '••••••••',
                        obscureText: !_isPasswordVisible,
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      PillButton(
                        label: 'Create account',
                        isPrimary: true,
                        isLoading: _isLoading,
                        onPressed: _handleSignUp,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.inputBorder),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.inputBorder),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      PillButton(
                        label: 'Continue with Google',
                        isPrimary: false,
                        isLoading: _isGoogleLoading,
                        icon: const Icon(
                          Icons.g_mobiledata,
                          size: 24,
                          color: AppColors.textDark,
                        ),
                        onPressed: _handleGoogleSignUp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primaryRosewood,
              width: 1.5,
            ),
          ),
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      ),
    );
  }
}
