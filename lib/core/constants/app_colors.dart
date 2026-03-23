import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette — deep architectural teal
  static const Color primary = Color(0xFF00333F);
  static const Color primaryContainer = Color(0xFF0E4B5A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFB0E0E8);

  // Secondary — emerald green (growth / income)
  static const Color secondary = Color(0xFF006C49);
  static const Color secondaryContainer = Color(0xFF89F8C7);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF002114);

  // Tertiary — coral rose (spending / alerts)
  static const Color tertiary = Color(0xFF64001E);
  static const Color tertiaryContainer = Color(0xFFFFD9DF);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF3F0011);

  // Surface hierarchy (no borders — use these for depth)
  static const Color surface = Color(0xFFF8F9FF);           // base
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);  // sectioning
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // primary cards
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);  // interaction

  // On-surface
  static const Color onSurface = Color(0xFF0B1C30);         // never pure black
  static const Color onSurfaceVariant = Color(0xFF42535D);
  static const Color outlineVariant = Color(0xFFC0C8CB);    // ghost border at 15%

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // Gradient for CTA buttons (135°)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(135 * 3.14159 / 180),
    colors: [primary, primaryContainer],
  );

  // Chart colors
  static const Color chartGrowth = secondary;
  static const Color chartSpend = tertiary;
  static const Color chartNeutral = Color(0xFF8094A3);
}
