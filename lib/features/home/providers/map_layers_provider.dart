import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/map_layers_config.dart';
import 'map_provider.dart';

final mapLayersConfigProvider =
    StateNotifierProvider<MapLayersNotifier, MapLayersConfig>((ref) {
  return MapLayersNotifier(ref);
});

class MapLayersNotifier extends StateNotifier<MapLayersConfig> {
  final Ref _ref;
  static const String _prefKey = 'map_layers_config_v1';

  MapLayersNotifier(this._ref) : super(const MapLayersConfig()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final config = MapLayersConfig.fromJson(decoded);
        state = config;
        _ref.read(isDarkMapProvider.notifier).state = config.isDarkMode;
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void toggleTrafficFlow() {
    state = state.copyWith(showTrafficFlow: !state.showTrafficFlow);
    _persist();
  }

  void toggleRoadClosures() {
    state = state.copyWith(showRoadClosures: !state.showRoadClosures);
    _persist();
  }

  void toggleDelayBadges() {
    state = state.copyWith(showDelayBadges: !state.showDelayBadges);
    _persist();
  }

  void toggleIncidents() {
    state = state.copyWith(showIncidents: !state.showIncidents);
    _persist();
  }

  void setMapStyleType(String type) {
    state = state.copyWith(mapStyleType: type);
    _ref.read(isDarkMapProvider.notifier).state = (type == 'dark');
    _persist();
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(mapStyleType: isDark ? 'dark' : 'standard');
    _ref.read(isDarkMapProvider.notifier).state = isDark;
    _persist();
  }
}
