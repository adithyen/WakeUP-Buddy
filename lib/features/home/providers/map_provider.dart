import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/map_renderer_provider.dart';
import '../../../core/services/map_tile_provider.dart';
import '../../../core/theme/theme_provider.dart';

final isDarkMapProvider = StateProvider<bool>((ref) {
  final theme = ref.watch(themeProvider);
  return theme != ThemeOption.light;
});

final recenterMapTriggerProvider = StateProvider<int>((ref) => 0);

final mapTileConfigProvider = Provider<MapTileConfig>((ref) {
  final bool isDark = ref.watch(isDarkMapProvider);
  final MapRendererType renderer = ref.watch(mapRendererProvider);

  switch (renderer) {
    case MapRendererType.osm:
      return OsmTileConfig();
    case MapRendererType.vela:
      return isDark ? VelaDarkTileConfig() : VelaLightTileConfig();
    case MapRendererType.ola:
      return isDark ? OlaMapsDarkTileConfig() : OlaMapsTileConfig();
  }
});

final currentLocationProvider = StreamProvider<LatLng?>((ref) async* {
  final LocationPermission permission = await Geolocator.checkPermission();
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled ||
      permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield null;
    return;
  }

  // Emit last-known position instantly (no GPS warm-up wait)
  final Position? last = await Geolocator.getLastKnownPosition();
  if (last != null) {
    yield LatLng(last.latitude, last.longitude);
  }

  // Then stream live updates — distanceFilter 3m for smooth tracking
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    ),
  ).map((Position p) => LatLng(p.latitude, p.longitude));
});