import 'package:flutter/material.dart';

abstract final class AppColors {
  // Flagship 2026 Ola & Uber-inspired Palette (from Designs/ references)
  static const Color limeAccent = Color(0xFFC6FF00); // Distinctive electric lime
  static const Color limeAccentDark = Color(0xFFAEEA00);
  static const Color cyanAccent = Color(0xFF00E5FF); // Electric cyan telemetry
  static const Color coralAlert = Color(0xFFFF5252); // Critical alert & cancel trip
  static const Color orangeWarning = Color(0xFFFF9100);

  // Obsidian Dark Surfaces
  static const Color obsidianBase = Color(0xFF0A0E13);
  static const Color obsidianCard = Color(0xFF131922);
  static const Color obsidianElevated = Color(0xFF1C2430);
  static const Color obsidianBorder = Color(0xFF222E3C);
  static const Color obsidianBorderGlow = Color(0x66C6FF00);

  // Legacy compatibility tokens
  static const Color primaryDark = limeAccent;
  static const Color primaryLight = limeAccentDark;
  static const Color secondary = cyanAccent;
  static const Color accent = limeAccent;
  static const Color accentDanger = coralAlert;

  static const Color darkBackground = obsidianBase;
  static const Color darkSurface = obsidianCard;
  static const Color darkSurfaceVariant = obsidianElevated;
  static const Color darkBorder = obsidianBorder;

  static const Color lightBackground = Color(0xFFF8F7FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0EDFF);
  static const Color lightBorder = Color(0xFFE8E5F0);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E9DAE);
  static const Color darkTextTertiary = Color(0xFF5A697A);

  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B6B8D);
  static const Color lightTextTertiary = Color(0xFFA0A0B8);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = coralAlert;
  static const Color info = cyanAccent;

  static const Color routeLine = cyanAccent;
  static const Color alertRadius = Color(0x33C6FF00);
  static const Color alertRadiusBorder = limeAccent;
  static const Color destinationPin = Color(0xFFFF6D00);
  static const Color currentLocation = limeAccent;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [limeAccent, Color(0xFF00E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: [Color(0xFFFF9100), coralAlert],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [obsidianCard, obsidianElevated],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}