import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported Map Rendering Engines in WakeUp-Buddy:
/// - [ola]: Official Native Ola Maps SDK vector tiles (India-first, high accuracy)
/// - [vela]: Vela Maps engine based on OpenFreeMap / MapLibre (https://github.com/PimpinPumpkin/Vela)
/// - [osm]: Standard OpenStreetMap community tiles
enum MapRendererType { ola, vela, osm }

extension MapRendererTypeExtension on MapRendererType {
  String get displayName {
    switch (this) {
      case MapRendererType.ola:
        return 'Ola Maps';
      case MapRendererType.vela:
        return 'Vela Maps';
      case MapRendererType.osm:
        return 'OpenStreetMap (OSM)';
    }
  }

  String get description {
    switch (this) {
      case MapRendererType.ola:
        return 'Official Ola vector tiles via native Android SDK';
      case MapRendererType.vela:
        return 'OpenFreeMap degoogled vector stack (Vela)';
      case MapRendererType.osm:
        return 'Standard OpenStreetMap community raster tiles';
    }
  }
}

// Versioned so installs that previously persisted the broken native Ola
// default are migrated to the reliable Flutter raster renderer.
const String _kMapRendererStorageKey = 'selected_map_renderer_v2';

final mapRendererProvider =
    StateNotifierProvider<MapRendererNotifier, MapRendererType>((ref) {
      return MapRendererNotifier();
    });

class MapRendererNotifier extends StateNotifier<MapRendererType> {
  MapRendererNotifier() : super(MapRendererType.osm) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kMapRendererStorageKey);
    // Keep the safe default for clean installs. Only an explicit saved
    // selection may opt back into the native Ola renderer.
    if (saved != null) {
      if (saved == 'vela') {
        state = MapRendererType.vela;
      } else if (saved == 'osm') {
        state = MapRendererType.osm;
      } else if (saved == 'ola') {
        state = MapRendererType.ola;
      }
    }
  }

  Future<void> setRenderer(MapRendererType type) async {
    state = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMapRendererStorageKey, type.name);
  }
}
