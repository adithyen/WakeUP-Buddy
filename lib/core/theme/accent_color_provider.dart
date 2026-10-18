import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAccentOption {
  final int id;
  final String name;
  final Color color;

  const AppAccentOption({
    required this.id,
    required this.name,
    required this.color,
  });
}

const List<AppAccentOption> availableAccents = [
  AppAccentOption(id: 0, name: 'Lime', color: Color(0xFFC6FF00)),
  AppAccentOption(id: 1, name: 'Emerald', color: Color(0xFF00E676)),
  AppAccentOption(id: 2, name: 'Cyan', color: Color(0xFF00E5FF)),
  AppAccentOption(id: 3, name: 'Blue', color: Color(0xFF536DFE)),
  AppAccentOption(id: 4, name: 'Pink', color: Color(0xFFE040FB)),
  AppAccentOption(id: 5, name: 'Orange', color: Color(0xFFFF6D00)),
  AppAccentOption(id: 6, name: 'Amber', color: Color(0xFFFFD600)),
];

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, AppAccentOption>((ref) {
  return AccentColorNotifier();
});

class AccentColorNotifier extends StateNotifier<AppAccentOption> {
  static const String _key = 'selected_accent_index';

  AccentColorNotifier() : super(availableAccents[0]) {
    _loadAccent();
  }

  Future<void> _loadAccent() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int index = prefs.getInt(_key) ?? 0;
      if (index >= 0 && index < availableAccents.length) {
        state = availableAccents[index];
      }
    } catch (_) {}
  }

  Future<void> setAccentIndex(int index) async {
    if (index < 0 || index >= availableAccents.length) return;
    state = availableAccents[index];
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, index);
    } catch (_) {}
  }
}
