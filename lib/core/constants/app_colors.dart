import 'package:flutter/material.dart';

/// Design system colors extracted from WakeUp Buddy v2 design references.
/// Primary accent: Electric Lime (#C8FF00) — the signature color throughout.
abstract final class AppColors {
  // ── Accent (signature lime-yellow) ────────────────────────────────────────
  static const Color accent       = Color(0xFFC8FF00); // Electric lime
  static const Color accentDim    = Color(0xFFA8D400); // Dimmed lime
  static const Color accentGlow   = Color(0x40C8FF00); // Glow / shadow

  // ── Legacy aliases (kept for backward compatibility) ──────────────────────
  static const Color primaryDark  = Color(0xFFC8FF00);
  static const Color primaryLight = Color(0xFFC8FF00);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background       = Color(0xFF0A0A0A); // Near black
  static const Color surface          = Color(0xFF141414); // Card surface
  static const Color surfaceVariant   = Color(0xFF1E1E1E); // Elevated surface
  static const Color surfaceBright    = Color(0xFF2A2A2A); // Search / input bg

  // ── Aliases for dark theme ─────────────────────────────────────────────
  static const Color darkBackground      = Color(0xFF0A0A0A);
  static const Color darkSurface         = Color(0xFF141414);
  static const Color darkSurfaceVariant  = Color(0xFF1E1E1E);
  static const Color darkBorder          = Color(0xFF2A2A2A);

  // ── Light theme (minimal — design is primarily dark) ─────────────────────
  static const Color lightBackground      = Color(0xFFF5F5F5);
  static const Color lightSurface         = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant  = Color(0xFFEEEEEE);
  static const Color lightBorder          = Color(0xFFDDDDDD);

  // ── Border / divider ──────────────────────────────────────────────────────
  static const Color border     = Color(0xFF2A2A2A);
  static const Color divider    = Color(0xFF1E1E1E);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textTertiary  = Color(0xFF555555);

  static const Color darkTextPrimary   = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF888888);
  static const Color darkTextTertiary  = Color(0xFF555555);

  static const Color lightTextPrimary   = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF444444);
  static const Color lightTextTertiary  = Color(0xFF888888);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error   = Color(0xFFFF4444);
  static const Color info    = Color(0xFF29B6F6);

  // ── Legacy aliases (backward compatibility) ────────────────────────────────
  static const Color accentDanger    = error;              // was used in alarm/button widgets
  static const Color secondary       = currentLocationActive; // was used in trip_info_panel

  // ── Map / navigation specific ─────────────────────────────────────────────
  static const Color destinationPin    = Color(0xFFFF6B6B); // Coral red (from Active_trip.png)
  static const Color currentLocation   = Color(0xFFC8FF00); // Lime (home screen)
  static const Color currentLocationActive = Color(0xFF00E5CC); // Cyan (active trip)
  static const Color routeLine         = Color(0xFFC8FF00); // Lime route polyline
  static const Color routeLineAlt      = Color(0xFF555555); // Alternate routes
  static const Color alertRadius       = Color(0x20C8FF00); // Lime with low alpha
  static const Color alertRadiusBorder = Color(0x80C8FF00); // Lime border

  // ── Accent color palette for user-selectable accent (Settings) ────────────
  static const List<Color> accentPalette = <Color>[
    Color(0xFFC8FF00), // Lime (default)
    Color(0xFF4CAF50), // Green
    Color(0xFF00E5CC), // Teal
    Color(0xFF7C4DFF), // Purple
    Color(0xFFFF4081), // Pink
    Color(0xFFFF6D00), // Orange
    Color(0xFFFFD600), // Yellow
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFFC8FF00), Color(0xFF8BCB00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: <Color>[Color(0xFFFF6B6B), Color(0xFFFF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: <Color>[Color(0xFF141414), Color(0xFF1E1E1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}