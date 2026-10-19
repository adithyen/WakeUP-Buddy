import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

abstract final class AppTheme {
  static ThemeData buildDarkTheme(Color accentColor) => _buildTheme(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: accentColor,
          onPrimary: ThemeData.estimateBrightnessForColor(accentColor) == Brightness.light
              ? Colors.black
              : Colors.white,
          secondary: AppColors.secondary,
          onSecondary: Colors.black,
          error: AppColors.error,
          onError: Colors.white,
          surface: AppColors.darkBackground,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerHighest: AppColors.darkSurfaceVariant,
          onSurfaceVariant: AppColors.darkTextSecondary,
          outline: AppColors.darkBorder,
        ),
      );

  static ThemeData buildLightTheme(Color accentColor) => _buildTheme(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: accentColor,
          onPrimary: ThemeData.estimateBrightnessForColor(accentColor) == Brightness.light
              ? Colors.black
              : Colors.white,
          secondary: AppColors.secondary,
          onSecondary: Colors.black,
          error: AppColors.error,
          onError: Colors.white,
          surface: const Color(0xFFF4F6F8),
          onSurface: const Color(0xFF0F172A),
          surfaceContainerHighest: const Color(0xFFEDF2F7),
          onSurfaceVariant: const Color(0xFF64748B),
          outline: const Color(0xFFE2E8F0),
        ),
      );

  static ThemeData get darkTheme => buildDarkTheme(AppColors.limeAccent);
  static ThemeData get lightTheme => buildLightTheme(AppColors.limeAccent);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final TextTheme textTheme = _buildTextTheme(isDark: isDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          side: BorderSide(color: colorScheme.primary),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.xl,
          vertical: AppDimensions.lg,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(colorScheme.primary),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withAlpha(102);
          }
          return colorScheme.outline.withAlpha(77);
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme({required bool isDark}) {
    final Color primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color tertiary = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final TextTheme base = GoogleFonts.interTextTheme();

    return base.copyWith(
      displayLarge: AppTypography.displayLarge.copyWith(color: primary),
      displayMedium: AppTypography.displayMedium.copyWith(color: primary),
      displaySmall: AppTypography.displaySmall.copyWith(color: primary),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: primary),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: primary),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: primary),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: primary),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: secondary),
      bodySmall: AppTypography.bodySmall.copyWith(color: tertiary),
      labelLarge: AppTypography.labelLarge.copyWith(color: primary),
      labelMedium: AppTypography.labelMedium.copyWith(color: secondary),
      labelSmall: AppTypography.labelSmall.copyWith(color: tertiary),
    );
  }
}

extension AppThemeExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appAccent => Theme.of(this).colorScheme.primary;

  Color get appBackground =>
      isDarkMode ? AppColors.obsidianBase : const Color(0xFFF4F6F8);

  Color get appCard =>
      isDarkMode ? AppColors.obsidianCard : Colors.white;

  Color get appSurface => appCard;

  Color get appCardElevated =>
      isDarkMode ? AppColors.obsidianElevated : const Color(0xFFEDF2F7);

  Color get appBorder =>
      isDarkMode ? AppColors.obsidianBorder : const Color(0xFFE2E8F0);

  Color get appTextPrimary =>
      isDarkMode ? Colors.white : const Color(0xFF0F172A);

  Color get appTextSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : const Color(0xFF64748B);

  Color get appTextTertiary =>
      isDarkMode ? AppColors.darkTextTertiary : const Color(0xFF94A3B8);
}