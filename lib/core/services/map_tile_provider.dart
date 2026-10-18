import 'package:flutter_map/flutter_map.dart';

abstract class MapTileConfig {
  String get urlTemplate;
  String? get fallbackUrl;
  Map<String, String> get additionalOptions;
  String get attribution;
  TileProvider get tileProvider;
}

/// Raster fallback used by Vela on platforms without the native Android
/// MapLibre view. Android Vela uses OpenFreeMap vector styles instead.
class VelaDarkTileConfig implements MapTileConfig {
  @override
  String get urlTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String? get fallbackUrl => 'https://tile.openstreetmap.de/{z}/{x}/{y}.png';

  @override
  // flutter_map normalizes this map in TileLayer, so it must be mutable.
  Map<String, String> get additionalOptions => <String, String>{};

  @override
  String get attribution => '© Vela Maps / OpenFreeMap / OpenStreetMap';

  @override
  TileProvider get tileProvider => NetworkTileProvider(
    headers: <String, String>{
      'User-Agent':
          'WakeUpBuddy-Vela/0.6.12 (https://github.com/PimpinPumpkin/Vela)',
    },
  );
}

class VelaLightTileConfig implements MapTileConfig {
  @override
  String get urlTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String? get fallbackUrl => 'https://tile.openstreetmap.de/{z}/{x}/{y}.png';

  @override
  Map<String, String> get additionalOptions => <String, String>{};

  @override
  String get attribution => '© Vela Maps / OpenFreeMap / OpenStreetMap';

  @override
  TileProvider get tileProvider => NetworkTileProvider(
    headers: <String, String>{
      'User-Agent':
          'WakeUpBuddy-Vela/0.6.12 (https://github.com/PimpinPumpkin/Vela)',
    },
  );
}

/// OpenStreetMap Community standard tile configuration
class OsmTileConfig implements MapTileConfig {
  @override
  String get urlTemplate => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String? get fallbackUrl => 'https://tile.openstreetmap.de/{z}/{x}/{y}.png';

  @override
  Map<String, String> get additionalOptions => <String, String>{};

  @override
  String get attribution => '© OpenStreetMap contributors';

  @override
  TileProvider get tileProvider => NetworkTileProvider(
    headers: <String, String>{
      'User-Agent': 'WakeUpBuddy/0.6.12 (support@wakeupbuddy.app)',
    },
  );
}

/// Backward compatibility aliases
class CartoDarkTileConfig extends VelaDarkTileConfig {}

class CartoLightTileConfig extends VelaLightTileConfig {}

class OlaMapsTileConfig extends VelaLightTileConfig {
  final String? apiKey;
  OlaMapsTileConfig({this.apiKey});
}

class OlaMapsDarkTileConfig extends VelaDarkTileConfig {
  final String? apiKey;
  OlaMapsDarkTileConfig({this.apiKey});
}
