import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.roboto(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackground,
  );

  static TextStyle get displayMedium => GoogleFonts.roboto(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackground,
  );

  static TextStyle get headlineLarge => GoogleFonts.roboto(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackground,
  );

  static TextStyle get headlineMedium => GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackground,
  );

  static TextStyle get titleLarge => GoogleFonts.roboto(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.onBackground,
  );

  static TextStyle get bodyLarge => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackground,
  );

  static TextStyle get bodyMedium => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackground,
  );

  static TextStyle get labelLarge => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
  );
}
