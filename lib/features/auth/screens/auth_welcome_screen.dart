import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_header_banner.dart';
import '../widgets/pill_button.dart';
import 'signup_email_screen.dart'; // We will build this next in Step 3
import 'login_screen.dart';

class AuthWelcomeScreen extends StatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  State<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends State<AuthWelcomeScreen> {
  final PageController _pageController = PageController();

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'ELEGANT FLORAL ARRANGEMENTS',
      'subtitle': 'Handcrafted artisan bouquets curated for your special moments.',
    },
    {
      'title': 'SAME DAY EXPRESS DELIVERY',
      'subtitle': 'Freshly bloomed flowers delivered straight to your doorstep in KL.',
    },
    {
      'title': 'CUSTOM EVENT STYLING',
      'subtitle': 'Tailored floral concepts for weddings, galas, and corporate events.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-Bleed Dark Hero Image Header
          const AuthHeaderBanner(
            heightFactor: 1.0,
            showBackButton: false,
          ),

          // 2. Centered Content Overlay (Logo, Onboarding Title Carousel, Dots)
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                
                // Brand Mark & Wordmark
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_florist,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'bloom & bunch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Title & Subtitle Carousel
                SizedBox(
                  height: 140,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _onboardingData[index]['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _onboardingData[index]['subtitle']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Carousel Dots Indicator
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _onboardingData.length,
                  effect: const ExpandingDotsEffect(
                    activeDotColor: Colors.white,
                    dotColor: Colors.white38,
                    dotHeight: 6,
                    dotWidth: 6,
                    expansionFactor: 3,
                    spacing: 6,
                  ),
                ),

                const SizedBox(height: 220), // Space reservation for bottom sheet
              ],
            ),
          ),

          // 3. Bottom Card Action Area
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Log In Button
                    PillButton(
                      label: 'Log in',
                      isPrimary: true,
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 350),
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                const LoginScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Secondary Sign Up Button
                    PillButton(
                      label: 'Sign up',
                      isPrimary: false,
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 400),
                            reverseTransitionDuration: const Duration(milliseconds: 350),
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                const SignupEmailScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Legal Disclaimer
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        children: [
                          const TextSpan(text: 'By continuing, you agree to Bloom & Bunch’s\n'),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Terms of Use',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}