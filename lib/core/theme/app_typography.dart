import 'package:flutter/material.dart';

/// Shared text roles. Font family is inherited from the Manrope TextTheme.
/// Keeping these constructors const also supports TextSpan and const widgets.
class AppTypography extends TextStyle {
  const AppTypography.display({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.2,
    super.fontWeight = FontWeight.w800,
  }) : super(fontSize: 32);

  const AppTypography.screenTitle({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w700,
  }) : super(fontSize: 24);

  const AppTypography.sectionTitle({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.3,
    super.fontWeight = FontWeight.w700,
  }) : super(fontSize: 20);

  const AppTypography.productTitle({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.3,
    super.fontWeight = FontWeight.w600,
  }) : super(fontSize: 16);

  const AppTypography.body({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.45,
    super.fontWeight = FontWeight.w400,
  }) : super(fontSize: 15);

  const AppTypography.supporting({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.4,
    super.fontWeight = FontWeight.w400,
  }) : super(fontSize: 14);

  const AppTypography.button({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w700,
  }) : super(fontSize: 15);

  const AppTypography.label({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.3,
    super.fontWeight = FontWeight.w600,
  }) : super(fontSize: 13);

  const AppTypography.navigation({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w600,
  }) : super(fontSize: 11);

  const AppTypography.price({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w800,
  }) : super(fontSize: 17);

  const AppTypography.total({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w800,
  }) : super(fontSize: 22);

  const AppTypography.badge({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w700,
  }) : super(fontSize: 11);

  const AppTypography.caption({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.35,
    super.fontWeight = FontWeight.w500,
  }) : super(fontSize: 12);

  const AppTypography.brand({
    super.color,
    super.backgroundColor,
    super.decoration,
    super.fontStyle,
    super.overflow,
    super.letterSpacing,
    super.height = 1.25,
    super.fontWeight = FontWeight.w800,
  }) : super(fontSize: 22);

  static const textTheme = TextTheme(
    displayLarge: AppTypography.display(),
    displayMedium: AppTypography.display(),
    displaySmall: AppTypography.display(),
    headlineLarge: AppTypography.display(),
    headlineMedium: AppTypography.screenTitle(),
    headlineSmall: AppTypography.screenTitle(),
    titleLarge: AppTypography.sectionTitle(),
    titleMedium: AppTypography.productTitle(),
    titleSmall: AppTypography.label(),
    bodyLarge: AppTypography.body(),
    bodyMedium: AppTypography.supporting(),
    bodySmall: AppTypography.caption(),
    labelLarge: AppTypography.button(),
    labelMedium: AppTypography.label(),
    labelSmall: AppTypography.badge(),
  );
}
