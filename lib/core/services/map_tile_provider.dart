import 'package:flutter_map/flutter_map.dart';

import '../constants/api_constants.dart';

/// Default API key configurable via compile-time environment or Settings screen.
const String kDefaultOlaApiKey = String.fromEnvironment('OLA_MAPS_API_KEY', defaultValue: '');

abstract class MapTileConfig {
  String get urlTemplate;
  String? get fallbackUrl;
  Map<String, String> get additionalOptions;
  String get attribution;
  TileProvider get tileProvider;
}

/// Primary tile config: Ola Maps Style1-Dark.
/// NOTE: flutter_map only interpolates {z}/{x}/{y}/{s} in urlTemplate.
/// The api_key must be baked directly into the URL string.
class OlaStyleDarkTileConfig implements MapTileConfig {
  const OlaStyleDarkTileConfig({required this.apiKey});
  final String apiKey;

  @override
  String get urlTemplate =>
      '${ApiConstants.olaTilesCustomDark}?api_key=$apiKey';

  @override
  String? get fallbackUrl => ApiConstants.osmTiles; // OSM if Ola fails

  @override
  Map<String, String> get additionalOptions => const <String, String>{};

  @override
  String get attribution => '© Ola Maps';

  @override
  TileProvider get tileProvider => NetworkTileProvider(
        headers: <String, String>{'User-Agent': 'WakeUpBuddy/2.0'},
      );
}

/// Ola Maps built-in light tiles.
class OlaLightTileConfig implements MapTileConfig {
  const OlaLightTileConfig({required this.apiKey});
  final String apiKey;

  @override
  String get urlTemplate =>
      '${ApiConstants.olaTilesLight}?api_key=$apiKey';

  @override
  String? get fallbackUrl => ApiConstants.osmTiles;

  @override
  Map<String, String> get additionalOptions => const <String, String>{};

  @override
  String get attribution => '© Ola Maps';

  @override
  TileProvider get tileProvider => NetworkTileProvider(
        headers: <String, String>{'User-Agent': 'WakeUpBuddy/2.0'},
      );
}

/// OSM fallback (used when no API key set).
class OsmTileConfig implements MapTileConfig {
  const OsmTileConfig();

  @override
  String get urlTemplate => ApiConstants.osmTiles;

  @override
  String? get fallbackUrl => null;

  @override
  Map<String, String> get additionalOptions => const <String, String>{};

  @override
  String get attribution => '© OpenStreetMap contributors';

  @override
  TileProvider get tileProvider => NetworkTileProvider();
}

// Backward-compat aliases
typedef OlaMapsTileConfig = OlaStyleDarkTileConfig;
typedef OlaMapsDarkTileConfig = OlaStyleDarkTileConfig;