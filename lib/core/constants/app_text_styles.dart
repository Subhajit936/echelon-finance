import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Display — Manrope (the "voice")
  static TextStyle displayLg = GoogleFonts.manrope(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
    letterSpacing: -0.5,
  );

  static TextStyle displayMd = GoogleFonts.manrope(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
    letterSpacing: -0.3,
  );

  static TextStyle displaySm = GoogleFonts.manrope(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  // Headlines — Manrope
  static TextStyle headlineLg = GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static TextStyle headlineMd = GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  // Titles — Inter (the "engine")
  static TextStyle titleLg = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static TextStyle titleMd = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  // Body — Inter
  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  // Labels — Inter (engraved micro-copy)
  static TextStyle labelLg = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceVariant,
    letterSpacing: 0.05,
  );

  static TextStyle labelMd = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceVariant,
    letterSpacing: 0.05,
  );

  static TextStyle labelSm = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
    letterSpacing: 0.05,
  );

  // Amount helpers
  static TextStyle amountPositive = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.secondary,
  );

  static TextStyle amountNegative = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.tertiary,
  );
}
