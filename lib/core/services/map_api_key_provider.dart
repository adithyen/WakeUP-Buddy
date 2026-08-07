import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

/// Default fallback key — overridable in Settings or via --dart-define=OLA_MAPS_API_KEY=...
const String _kDefaultApiKey = String.fromEnvironment('OLA_MAPS_API_KEY', defaultValue: '');

final mapApiKeyProvider = StateNotifierProvider<MapApiKeyNotifier, String?>((ref) {
  return MapApiKeyNotifier();
});

class MapApiKeyNotifier extends StateNotifier<String?> {
  MapApiKeyNotifier() : super(_kDefaultApiKey) {
    _loadOverride();
  }

  /// Load a user-saved override from prefs; if none, keep the hardcoded default.
  Future<void> _loadOverride() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(ApiConstants.olaApiKeyStorageKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
    // else keep the hardcoded default
  }

  Future<void> setKey(String? value) async {
    final String? trimmed = value?.trim().isEmpty == true ? null : value?.trim();
    // If cleared, revert to hardcoded default
    state = trimmed ?? _kDefaultApiKey;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (trimmed == null) {
      await prefs.remove(ApiConstants.olaApiKeyStorageKey);
    } else {
      await prefs.setString(ApiConstants.olaApiKeyStorageKey, trimmed);
    }
  }
}