import 'package:flutter/material.dart';

/// Warm / earthy design tokens for the app theme.
class AppColors {
  AppColors._();

  // Palette
  static const terracotta = Color(0xFFC4622D); // primary
  static const sandstone = Color(0xFFE8956D); // primary-light
  static const burntSienna = Color(0xFF8B3A1A); // primary-dark

  static const surface1 = Color(0xFFFAF4EC); // app background
  static const surface2 = Color(0xFFF0E6D3); // cards, sheets
  static const surface3 = Color(0xFFD9C9B0); // dividers, borders

  static const espresso = Color(0xFF2C1A0E); // text primary
  static const warmUmber = Color(0xFF6B4C35); // text secondary

  static const oliveSage = Color(0xFF7A8C5E); // accent / success
  static const clayRed = Color(0xFFB94040); // error / destructive
}

/// Central warm/earthy light theme.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.terracotta,
    onPrimary: Colors.white,
    secondary: AppColors.oliveSage,
    onSecondary: Colors.white,
    error: AppColors.clayRed,
    onError: Colors.white,
    surface: AppColors.surface1,
    onSurface: AppColors.espresso,
    surfaceVariant: AppColors.surface2,
    onSurfaceVariant: AppColors.warmUmber,
    outline: AppColors.surface3,
    shadow: Colors.black26,
    inverseSurface: AppColors.espresso,
    onInverseSurface: AppColors.surface1,
    inversePrimary: AppColors.sandstone,
  ),
  scaffoldBackgroundColor: AppColors.surface1,
  cardColor: AppColors.surface2,
  dialogBackgroundColor: AppColors.surface2,
  dividerColor: AppColors.surface3,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AppColors.espresso),
    bodyLarge: TextStyle(color: AppColors.espresso),
    bodySmall: TextStyle(color: AppColors.warmUmber),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.terracotta,
    foregroundColor: Colors.white,
    centerTitle: true,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.terracotta,
    foregroundColor: Colors.white,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surface2,
    selectedColor: AppColors.oliveSage,
    disabledColor: AppColors.surface3,
    labelStyle: const TextStyle(color: AppColors.warmUmber),
    secondaryLabelStyle: const TextStyle(color: Colors.white),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
