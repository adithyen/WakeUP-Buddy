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
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (!serviceEnabled ||
      permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    final Position? last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      yield LatLng(last.latitude, last.longitude);
    } else {
      yield null;
    }
    return;
  }

  // 1. Emit last-known position instantly
  final Position? last = await Geolocator.getLastKnownPosition();
  if (last != null) {
    yield LatLng(last.latitude, last.longitude);
  }

  // 2. Fetch current high accuracy position immediately
  try {
    final Position current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 4),
      ),
    );
    yield LatLng(current.latitude, current.longitude);
  } catch (_) {}

  // 3. Continuously stream live updates
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    ),
  ).map((Position p) => LatLng(p.latitude, p.longitude));
});