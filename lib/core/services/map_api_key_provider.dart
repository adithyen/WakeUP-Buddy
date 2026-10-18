import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

/// Active API Key provider
final mapApiKeyProvider = StateNotifierProvider<MapApiKeyNotifier, String?>((ref) {
  return MapApiKeyNotifier();
});

class MapApiKeyNotifier extends StateNotifier<String?> {
  MapApiKeyNotifier() : super(ApiConstants.defaultOlaApiKey) {
    _loadOverride();
  }

  Future<void> _loadOverride() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(ApiConstants.olaApiKeyStorageKey);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
    }
  }

  Future<void> setKey(String? value) async {
    final String? trimmed = value?.trim().isEmpty == true ? null : value?.trim();
    state = trimmed ?? ApiConstants.defaultOlaApiKey;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (trimmed == null) {
      await prefs.remove(ApiConstants.olaApiKeyStorageKey);
    } else {
      await prefs.setString(ApiConstants.olaApiKeyStorageKey, trimmed);
    }
  }
}

/// Custom Map Style URL/ID provider (e.g., "Style1-Dark")
final customMapStyleProvider =
    StateNotifierProvider<CustomMapStyleNotifier, String?>((ref) {
  return CustomMapStyleNotifier();
});

class CustomMapStyleNotifier extends StateNotifier<String?> {
  CustomMapStyleNotifier() : super(null) {
    _loadOverride();
  }

  Future<void> _loadOverride() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(ApiConstants.olaCustomStyleStorageKey);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
    }
  }

  Future<void> setStyle(String? value) async {
    final String? trimmed = value?.trim().isEmpty == true ? null : value?.trim();
    state = trimmed;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (trimmed == null) {
      await prefs.remove(ApiConstants.olaCustomStyleStorageKey);
    } else {
      await prefs.setString(ApiConstants.olaCustomStyleStorageKey, trimmed);
    }
  }
}

/// Helper to get the active vector map style URL
String getActiveVectorStyleUrl(WidgetRef ref, {bool isDark = true}) {
  final customStyle = ref.watch(customMapStyleProvider);
  final apiKey = ref.watch(mapApiKeyProvider) ?? ApiConstants.defaultOlaApiKey;

  if (customStyle != null && customStyle.trim().isNotEmpty) {
    final style = customStyle.trim();
    if (style.startsWith('http')) {
      return style.contains('api_key=') ? style : '$style?api_key=$apiKey';
    }
    // If it's a style name like "Style1-Dark"
    return '${ApiConstants.olaBaseUrl}/tiles/vector/v1/styles/$style/style.json?api_key=$apiKey';
  }

  final baseStyle = isDark
      ? ApiConstants.olaVectorStyleDark
      : ApiConstants.olaVectorStyleLight;
  return '$baseStyle?api_key=$apiKey';
}