import 'package:flutter/material.dart';

/// Navy + white design tokens for the app theme.
class AppColors {
  AppColors._();

  static const navy     = Color(0xFF000080); // primary
  static const navyLight = Color(0xFF0000B3); // primary-light
  static const navyDark  = Color(0xFF00004D); // primary-dark

  static const background = Colors.white;
  static const surface    = Color(0xFFF2F2F2); // cards, sheets
  static const divider    = Color(0xFFDDDDDD); // borders

  static const textPrimary   = Color(0xFF111111);
  static const textSecondary = Color(0xFF555555);

  static const success = Color(0xFF2E7D32);
  static const error   = Color(0xFFB00020);
}

/// Navy-and-white theme.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.navyLight,
    onSecondary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.textPrimary,
    surfaceVariant: AppColors.surface,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.divider,
    shadow: Colors.black26,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.navyLight,
  ),
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  dialogBackgroundColor: Colors.white,
  dividerColor: AppColors.divider,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AppColors.textPrimary),
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodySmall: TextStyle(color: AppColors.textSecondary),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    centerTitle: true,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surface,
    selectedColor: AppColors.navy,
    disabledColor: AppColors.divider,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    secondaryLabelStyle: const TextStyle(color: Colors.white),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
