import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/map_api_key_provider.dart';
import '../../../core/services/map_tile_provider.dart';

final mapTileConfigProvider = Provider<MapTileConfig>((ref) {
  final String? apiKey = ref.watch(mapApiKeyProvider);
  if (apiKey != null && apiKey.isNotEmpty) {
    // Use the user's custom Style1-Dark as primary
    return OlaStyleDarkTileConfig(apiKey: apiKey);
  }
  return const OsmTileConfig();
});

/// Current location stream — yields last-known position immediately,
/// then streams live GPS updates. Uses position.speed (Doppler-based)
/// which is accurate and returns 0 when stationary.
final currentLocationProvider = StreamProvider<LatLng?>((ref) async* {
  final LocationPermission permission = await Geolocator.checkPermission();
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled ||
      permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield null;
    return;
  }

  // ✅ Emit last-known position immediately (zero GPS warm-up wait)
  final Position? last = await Geolocator.getLastKnownPosition();
  if (last != null) {
    yield LatLng(last.latitude, last.longitude);
  }

  // Stream live updates with 3s interval, 5m distance filter
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // emit every 5m movement
    ),
  ).map((Position p) => LatLng(p.latitude, p.longitude));
});

/// Live GPS speed in km/h — uses position.speed (Doppler, not coord-delta).
/// Returns 0 when below 0.5 m/s threshold to avoid GPS noise artefacts.
final currentSpeedKmhProvider = StreamProvider<double>((ref) async* {
  final LocationPermission permission = await Geolocator.checkPermission();
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled ||
      permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield 0;
    return;
  }

  double _prevSmoothed = 0.0;

  await for (final Position p in Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // emit on every update for speed accuracy
    ),
  )) {
    // GPS speed in m/s — Doppler based, accurate at 0
    final double rawMs = (p.speed < 0) ? 0 : p.speed;
    // Low-pass smoothing: 70% previous + 30% new reading
    _prevSmoothed = 0.7 * _prevSmoothed + 0.3 * rawMs;
    // Kill noise below 0.5 m/s (1.8 km/h) — shows 0 at standstill
    final double kmh = _prevSmoothed < 0.5 ? 0 : _prevSmoothed * 3.6;
    yield double.parse(kmh.toStringAsFixed(1));
  }
});