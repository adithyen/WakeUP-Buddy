# Phase 02 — Design System & Theming

> **Goal:** Establish a complete design system with light/dark themes, typography, color palette, spacing scale, and reusable UI components — all designed for sleepy travelers using the app one-handed.  
> **Dependencies:** Phase 01  
> **Deliverable:** Theme toggle works; all core UI components render correctly in both light and dark modes.

---

## 2.1 — Color Palette

### 2.1.1 Design Philosophy
- **Calm, muted tones** for travel/night use — no aggressive reds or bright whites
- **High contrast** for readability by drowsy users
- **Blue-purple** primary palette (associated with calm, sleep, night)
- **Amber/gold** accent for alerts and CTAs (grabs attention without aggression)

### 2.1.2 Color Tokens — `lib/core/constants/app_colors.dart`

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  // ─── Brand Colors ───
  static const Color primaryDark = Color(0xFF6C5CE7);    // Soft purple
  static const Color primaryLight = Color(0xFF7C6FF0);   // Lighter purple
  static const Color secondary = Color(0xFF00CEC9);       // Teal accent
  static const Color accent = Color(0xFFFDAA5E);          // Warm amber (alert CTA)
  static const Color accentDanger = Color(0xFFE17055);    // Soft red (cancel/stop)

  // ─── Dark Theme Surface Colors ───
  static const Color darkBackground = Color(0xFF0D0D1A);      // Deep navy-black
  static const Color darkSurface = Color(0xFF1A1A2E);          // Card background
  static const Color darkSurfaceVariant = Color(0xFF242442);   // Elevated surface
  static const Color darkBorder = Color(0xFF2D2D50);           // Subtle borders

  // ─── Light Theme Surface Colors ───
  static const Color lightBackground = Color(0xFFF8F7FF);      // Warm off-white
  static const Color lightSurface = Color(0xFFFFFFFF);          // Pure white cards
  static const Color lightSurfaceVariant = Color(0xFFF0EDFF);  // Tinted surface
  static const Color lightBorder = Color(0xFFE8E5F0);          // Soft border

  // ─── Text Colors ───
  static const Color darkTextPrimary = Color(0xFFF5F5FA);      // Near-white
  static const Color darkTextSecondary = Color(0xFFA0A0C0);    // Muted lavender
  static const Color darkTextTertiary = Color(0xFF6B6B8D);     // Very muted

  static const Color lightTextPrimary = Color(0xFF1A1A2E);     // Dark navy
  static const Color lightTextSecondary = Color(0xFF6B6B8D);   // Mid gray
  static const Color lightTextTertiary = Color(0xFFA0A0B8);    // Light gray

  // ─── Status Colors ───
  static const Color success = Color(0xFF00B894);       // Mint green
  static const Color warning = Color(0xFFFDAA5E);       // Amber
  static const Color error = Color(0xFFE17055);          // Soft coral-red
  static const Color info = Color(0xFF74B9FF);           // Sky blue

  // ─── Map Specific ───
  static const Color routeLine = Color(0xFF6C5CE7);           // Primary purple
  static const Color alertRadius = Color(0x336C5CE7);          // Translucent purple
  static const Color alertRadiusBorder = Color(0xFF6C5CE7);
  static const Color destinationPin = Color(0xFFE17055);       // Coral
  static const Color currentLocation = Color(0xFF00CEC9);      // Teal

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: [Color(0xFFFDAA5E), Color(0xFFE17055)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF242442)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
```

### 2.1.3 Color Palette Rationale

| Token | Hex | Purpose |
|-------|-----|---------|
| `primaryDark` | `#6C5CE7` | Main brand, buttons, active elements |
| `secondary` | `#00CEC9` | Current location indicator, secondary actions |
| `accent` | `#FDAA5E` | Alert trigger, "Set Destination" CTA |
| `accentDanger` | `#E17055` | Stop/cancel alert, destination pin |
| `darkBackground` | `#0D0D1A` | Dark theme base — very deep, easy on eyes at night |
| `lightBackground` | `#F8F7FF` | Light theme base — warm off-white, not harsh pure white |

---

## 2.2 — Typography

### 2.2.1 Font Selection
- **Primary font:** Inter (Google Fonts) — clean, highly legible, excellent for UI
- **Fallback:** System default sans-serif
- **Loaded dynamically** via `google_fonts` package (no font bundling needed)

### 2.2.2 Typography Scale — `lib/core/constants/app_typography.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // ─── Display (Hero numbers, distance display) ───
  static TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.1,
  );

  static TextStyle displayMedium = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.2,
  );

  static TextStyle displaySmall = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // ─── Headlines (Screen titles) ───
  static TextStyle headlineLarge = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle headlineMedium = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static TextStyle headlineSmall = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // ─── Body (General text) ───
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ─── Labels (Buttons, chips, badges) ───
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // ─── Specialized ───
  static TextStyle distanceHero = GoogleFonts.inter(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.0,
    height: 1.0,
  );

  static TextStyle distanceUnit = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
  );

  static TextStyle statusLabel = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
}
```

### 2.2.3 Typography Hierarchy for Key Screens

| Screen Element | Style | Size |
|----------------|-------|------|
| Distance remaining (Active Trip) | `distanceHero` | 56px, w800 |
| Distance unit ("km", "m") | `distanceUnit` | 18px, w500 |
| Screen titles | `headlineLarge` | 24px, w700 |
| Section headings | `headlineMedium` | 20px, w600 |
| Body text | `bodyLarge` | 16px, w400 |
| Button text | `labelLarge` | 16px, w600 |
| Status badges | `statusLabel` | 13px, w600 |
| Caption/metadata | `bodySmall` | 12px, w400 |

---

## 2.3 — Spacing & Dimensions

### 2.3.1 Spacing Scale — `lib/core/constants/app_dimensions.dart`

```dart
abstract final class AppDimensions {
  // ─── Spacing Scale (4px base) ───
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // ─── Border Radius ───
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;    // Pill shape

  // ─── Component Sizes ───
  static const double buttonHeight = 56.0;        // Large, tappable
  static const double buttonHeightSmall = 44.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  // ─── Map ───
  static const double mapPinSize = 48.0;
  static const double mapBottomSheetMinHeight = 200.0;
  static const double mapBottomSheetMaxHeight = 0.85;    // 85% of screen

  // ─── Safe Areas ───
  static const double screenPaddingH = 20.0;   // Horizontal screen padding
  static const double screenPaddingV = 16.0;   // Vertical screen padding

  // ─── Elevation ───
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;

  // ─── Animation Durations ───
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animVerySlow = Duration(milliseconds: 800);
}
```

---

## 2.4 — Theme Configuration

### 2.4.1 Theme Data — `lib/core/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_dimensions.dart';

abstract final class AppTheme {
  // ─── Dark Theme ───
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryDark,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: Colors.white,
      outline: AppColors.darkBorder,
    ),
    textTheme: _buildTextTheme(isDark: true),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.darkBorder,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        textStyle: AppTypography.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        textStyle: AppTypography.labelLarge,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
      ),
      hintStyle: AppTypography.bodyLarge.copyWith(
        color: AppColors.darkTextTertiary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.lg,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primaryDark,
      inactiveTrackColor: AppColors.darkBorder,
      thumbColor: AppColors.primaryDark,
      overlayColor: AppColors.primaryDark.withOpacity(0.2),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurfaceVariant,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
  );

  // ─── Light Theme ───
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.lightSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      onError: Colors.white,
      outline: AppColors.lightBorder,
    ),
    textTheme: _buildTextTheme(isDark: false),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.lightTextPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.lightBorder,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        textStyle: AppTypography.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
        textStyle: AppTypography.labelLarge,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      hintStyle: AppTypography.bodyLarge.copyWith(
        color: AppColors.lightTextTertiary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.lg,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primaryLight,
      inactiveTrackColor: AppColors.lightBorder,
      thumbColor: AppColors.primaryLight,
      overlayColor: AppColors.primaryLight.withOpacity(0.2),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightTextPrimary,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
  );

  // ─── Shared Text Theme Builder ───
  static TextTheme _buildTextTheme({required bool isDark}) {
    final Color primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: primary),
      displayMedium: AppTypography.displayMedium.copyWith(color: primary),
      displaySmall: AppTypography.displaySmall.copyWith(color: primary),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: primary),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: primary),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: primary),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: primary),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: secondary),
      bodySmall: AppTypography.bodySmall.copyWith(color: secondary),
      labelLarge: AppTypography.labelLarge.copyWith(color: primary),
      labelMedium: AppTypography.labelMedium.copyWith(color: secondary),
      labelSmall: AppTypography.labelSmall.copyWith(color: secondary),
    );
  }
}
```

### 2.4.2 Theme State Provider — `lib/core/theme/theme_provider.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeOption { system, light, dark }

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeOption>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeOption> {
  static const _key = 'theme_mode';

  ThemeNotifier() : super(ThemeOption.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeOption.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ThemeOption.system,
      );
    }
  }

  Future<void> setTheme(ThemeOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.name);
  }

  ThemeMode get themeMode => switch (state) {
    ThemeOption.system => ThemeMode.system,
    ThemeOption.light => ThemeMode.light,
    ThemeOption.dark => ThemeMode.dark,
  };
}
```

### 2.4.3 Update `lib/app.dart` to Use Theme Provider
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/presentation/home_screen.dart';

class WakeUpBuddyApp extends ConsumerWidget {
  const WakeUpBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeOption = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp(
      title: 'WakeUp Buddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const HomeScreen(),
    );
  }
}
```

---

## 2.5 — Reusable UI Components

### 2.5.1 Primary Button — `lib/core/widgets/app_button.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    // ... button implementation with gradient backgrounds,
    // subtle shadow, press animation, loading spinner
  }
}
```

**Variants:**
| Variant | Background | Use Case |
|---------|------------|----------|
| `primary` | `primaryGradient` | "Set Destination", "Start Trip" |
| `secondary` | Outlined with border | "Change Radius", "Settings" |
| `danger` | `accentDanger` solid | "Cancel Alert", "Stop Tracking" |
| `ghost` | Transparent | "Skip", "Later" |

### 2.5.2 Glass Card — `lib/core/widgets/app_card.dart`
A semi-transparent card with blur effect (glassmorphism) for overlaying on maps:

```dart
// Glassmorphism card with:
// - BackdropFilter blur
// - Semi-transparent background
// - Subtle border
// - Rounded corners
// - Optional gradient border
```

### 2.5.3 Bottom Sheet — `lib/core/widgets/app_bottom_sheet.dart`
Draggable bottom sheet used for destination search and alert config:
- Drag handle at top
- Smooth snap points (collapsed, half, full)
- Gesture-dismissible

### 2.5.4 Loading Indicator — `lib/core/widgets/loading_indicator.dart`
Animated pulsing dot indicator matching brand colors.

### 2.5.5 Status Badge — `lib/core/widgets/status_badge.dart`
Small pill-shaped badge for "Tracking Active", "Approaching", etc.

---

## 2.6 — Animations

### 2.6.1 Animation Constants
Using `flutter_animate` for declarative micro-animations:

| Element | Animation | Duration |
|---------|-----------|----------|
| Screen transitions | Fade + SlideUp | 300ms |
| Button press | Scale (0.96) | 150ms |
| Card appear | FadeIn + SlideUp | 300ms, staggered |
| Distance number change | Animated counter | 500ms |
| Alert radius circle (map) | Pulse opacity | 1500ms, loop |
| Status badge | FadeIn + Scale | 200ms |
| Bottom sheet | SlideUp with spring curve | 400ms |

### 2.6.2 Page Transitions
```dart
// Custom page route with fade + slide transition
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required Widget child})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
}
```

---

## 2.7 — Theme Toggle UI

### 2.7.1 Theme Toggle Widget
A segmented control or animated toggle for Light / Dark / System in the Settings screen.

```
┌──────────────────────────┐
│  ☀️ Light │ 🌙 Dark │ 🔄 Auto │
└──────────────────────────┘
```

---

## ✅ Phase 02 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Dark theme renders correctly | Set theme to dark; all screens use dark surfaces |
| 2 | Light theme renders correctly | Set theme to light; all screens use light surfaces |
| 3 | System theme auto-switches | Change device theme; app follows |
| 4 | Theme persists across restarts | Toggle dark → kill app → relaunch → still dark |
| 5 | All color tokens defined | `app_colors.dart` compiles with all tokens |
| 6 | Typography scale applied | Text hierarchy visible in demo screen |
| 7 | AppButton renders all variants | Primary, secondary, danger, ghost buttons visible |
| 8 | Animations are smooth | No jank on page transitions or button presses |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| `withOpacity` causes poor perf | Use `Color.fromRGBO` or pre-computed colors instead |
| Google Fonts requires internet | First run needs internet; fonts are cached after |
| Theme not applied to all widgets | Ensure `ThemeData` covers `cardTheme`, `sliderTheme`, etc. |
| Dark/light text colors wrong | Always use `Theme.of(context).textTheme` instead of hardcoded colors |
