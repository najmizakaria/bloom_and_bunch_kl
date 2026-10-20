import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'admin_navigation_scope.dart';

/// SB Admin 2's visual tokens, scoped to the administration workspace.
class AdminTheme {
  static const primary = Color(0xFF4E73DF);
  static const primaryDark = Color(0xFF224ABE);
  static const background = Color(0xFFF8F9FC);
  static const border = Color(0xFFE3E6F0);
  static const ink = Color(0xFF5A5C69);
  static const muted = Color(0xFF6E707E);
  static const success = Color(0xFF1CC88A);
  static const info = Color(0xFF36B9CC);
  static const warning = Color(0xFFF6C23E);

  /// Shared inventory widgets keep their florist palette outside this shell.
  static Color sharedColor(BuildContext context, Color original) {
    if (AdminNavigationScope.maybeOf(context) == null) {
      return original;
    }
    return {
          AppColors.primary: primary,
          AppColors.primaryDark: primaryDark,
          AppColors.background: background,
          AppColors.inputFill: background,
          AppColors.inputBorder: border,
        }[original] ??
        original;
  }

  static ThemeData get light {
    final text = ThemeData.light().textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: ink,
      displayColor: ink,
    );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      side: BorderSide(color: border),
    );
    final button = FilledButton.styleFrom(
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      textStyle: text.labelLarge,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: Colors.white,
        onSurface: ink,
        error: const Color(0xFFE74A3B),
      ),
      scaffoldBackgroundColor: background,
      textTheme: text,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: ink.withValues(alpha: .12),
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(background),
        headingTextStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        dataRowMinHeight: 56,
        dataRowMaxHeight: 72,
        dividerThickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        dividerColor: border,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
    );
  }
}
