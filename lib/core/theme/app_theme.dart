import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static const Color primary = AppColors.primary;
  static const Color secondary = AppColors.secondarySurface;
  static const Color background = AppColors.background;
  static const Color textDark = AppColors.textDark;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.manropeTextTheme(AppTypography.textTheme);

    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.cardWhite,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
      primaryTextTheme: baseTextTheme,
      // Preserve the existing typography and touch targets. Material supplies
      // component shapes, borders, interaction states, and other styling.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.headlineSmall?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.inputBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: baseTextTheme.labelMedium,
        hintStyle: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.textMuted,
        ),
        helperStyle: baseTextTheme.bodySmall,
        errorStyle: baseTextTheme.bodySmall,
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: baseTextTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: baseTextTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: baseTextTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: baseTextTheme.labelMedium?.copyWith(
          color: AppColors.textDark,
        ),
        secondaryLabelStyle: baseTextTheme.labelMedium?.copyWith(
          color: AppColors.onPrimary,
        ),
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.onPrimary,
        side: const BorderSide(color: AppColors.inputBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelPadding: const EdgeInsets.only(top: 4),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.secondarySurface,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return baseTextTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted,
          );
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: baseTextTheme.labelLarge),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: baseTextTheme.titleMedium?.copyWith(color: textDark),
        subtitleTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: baseTextTheme.labelMedium,
        unselectedLabelStyle: baseTextTheme.bodyMedium,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(color: textDark),
        contentTextStyle: baseTextTheme.bodyLarge?.copyWith(color: textDark),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}
