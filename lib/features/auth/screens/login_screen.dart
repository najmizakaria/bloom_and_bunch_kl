import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_header_banner.dart';
import '../widgets/pill_button.dart';
import 'signup_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Success: AuthGate's StreamBuilder detects the new auth state
      // and swaps to the right home screen automatically. No navigation needed here.
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _showError('No account found for that email.');
          break;
        case 'wrong-password':
        case 'invalid-credential':
          _showError('Incorrect email or password.');
          break;
        case 'invalid-email':
          _showError('That email address looks invalid.');
          break;
        default:
          _showError(e.message ?? 'Login failed. Please try again.');
      }
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
      // Same as above — AuthGate handles the redirect once auth state changes.
    } catch (_) {
      _showError('Google sign-in failed. Please try again.');
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
            heightFactor: 0.35,
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
                    child: const Icon(Icons.local_florist, color: Colors.white, size: 16),
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
              height: MediaQuery.of(context).size.height * 0.78,
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
                          'Log in',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Google Sign-In
                      PillButton(
                        label: 'Continue with Google',
                        isPrimary: false,
                        isLoading: _isGoogleLoading,
                        icon: const Icon(Icons.g_mobiledata, size: 24, color: AppColors.textDark),
                        onPressed: _handleGoogleLogin,
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.inputBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ),
                          const Expanded(child: Divider(color: AppColors.inputBorder)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Email Field
                      const Text(
                        'Email address',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: 'alexsmith.mobbin@gmail.com',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryRosewood, width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password Field
                      const Text(
                        'Password',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryRosewood, width: 1.5),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      PillButton(
                        label: 'Log in',
                        isPrimary: true,
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),

                      const SizedBox(height: 20),

                      // Sign up link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignupEmailScreen()),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                              children: [
                                TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: 'Sign up',
                                  style: TextStyle(
                                    color: AppColors.primaryRosewood,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}