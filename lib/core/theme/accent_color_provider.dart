import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';

const String _kAccentKey = 'selected_accent_color_index';

/// Provides the currently selected accent color index (0-6).
final accentColorIndexProvider =
    StateNotifierProvider<AccentColorNotifier, int>((ref) {
  return AccentColorNotifier();
});

/// Provides the current accent Color value.
final accentColorProvider = Provider<Color>((ref) {
  final int index = ref.watch(accentColorIndexProvider);
  return AppColors.accentPalette[index.clamp(0, AppColors.accentPalette.length - 1)];
});

class AccentColorNotifier extends StateNotifier<int> {
  AccentColorNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_kAccentKey) ?? 0;
  }

  Future<void> setIndex(int index) async {
    state = index.clamp(0, AppColors.accentPalette.length - 1);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, state);
  }
}
