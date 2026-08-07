import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeOption { system, light, dark }

extension ThemeOptionX on ThemeOption {
  ThemeMode get themeMode => switch (this) {
        ThemeOption.system => ThemeMode.system,
        ThemeOption.light => ThemeMode.light,
        ThemeOption.dark => ThemeMode.dark,
      };
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeOption>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeOption> {
  static const String _key = 'theme_mode';

  ThemeNotifier() : super(ThemeOption.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedTheme = prefs.getString(_key);

    if (savedTheme == null) {
      return;
    }

    state = ThemeOption.values.firstWhere(
      (ThemeOption option) => option.name == savedTheme,
      orElse: () => ThemeOption.system,
    );
  }

  Future<void> setTheme(ThemeOption option) async {
    state = option;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.name);
  }

}