# Phase 04 — Map Integration (Ola Maps)

> **Goal:** Display an interactive map showing the user's current location with Ola Maps raster tiles, with automatic fallback to OpenStreetMap when Ola API key is unavailable.  
> **Dependencies:** Phase 02 (theming), Phase 03 (location permission)  
> **Deliverable:** Map renders with tiles; blue dot shows current location; map follows user; dark/light map style matches theme.

API KEY: <YOUR_OLA_MAPS_API_KEY> (Obtain from https://maps.olakrutrim.com/)
!!refer each and every sections of "https://maps.olakrutrim.com/docs"(Ola Maps
Developer Docs
Overview
Authentication
Multilingual Language Support

Routing APIs

Roads APIs

Places APIs

Geocoding

Map Tiles

Navigation SDKs

Map SDKs

Places SDKs

Web SDK

Ola Maps MCP
Street View)


## 4.1 — Map Provider Architecture

### 4.1.1 Abstraction Layer
We create a map provider abstraction so the tile source can be swapped without touching UI code:

```dart
// lib/core/services/map_tile_provider.dart

abstract class MapTileConfig {
  String get urlTemplate;
  String? get fallbackUrl;
  Map<String, String> get additionalOptions;
  String get attribution;
}

class OlaMapsTileConfig implements MapTileConfig {
  final String apiKey;

  OlaMapsTileConfig({required this.apiKey});

  @override
  String get urlTemplate =>
    'https://api.olamaps.io/tiles/v1/styles/default-light-standard/{z}/{x}/{y}.png?api_key=$apiKey';

  @override
  String? get fallbackUrl =>
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Map<String, String> get additionalOptions => {};

  @override
  String get attribution => '© Ola Maps | © OpenStreetMap contributors';
}

class OsmTileConfig implements MapTileConfig {
  @override
  String get urlTemplate =>
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  String? get fallbackUrl => null;

  @override
  Map<String, String> get additionalOptions => {};

  @override
  String get attribution => '© OpenStreetMap contributors';
}
```

### 4.1.2 Dark Mode Map Tiles
Ola Maps supports custom styles via their Style Editor. For dark mode:

```dart
class OlaMapsDarkTileConfig implements MapTileConfig {
  final String apiKey;

  OlaMapsDarkTileConfig({required this.apiKey});

  @override
  String get urlTemplate =>
    'https://api.olamaps.io/tiles/v1/styles/default-dark-standard/{z}/{x}/{y}.png?api_key=$apiKey';

  // ...
}

// OSM dark mode fallback using CartoDB dark tiles
class OsmDarkTileConfig implements MapTileConfig {
  @override
  String get urlTemplate =>
    'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';

  @override
  Map<String, String> get additionalOptions => {
    's': 'abcd',  // Subdomains
  };
  // ...
}
```

### 4.1.3 Tile Config Provider — Riverpod

```dart
// lib/features/home/providers/map_provider.dart

final mapTileConfigProvider = Provider<MapTileConfig>((ref) {
  final apiKey = ref.watch(olaApiKeyProvider);
  final isDark = ref.watch(themeProvider) == ThemeOption.dark ||
    (ref.watch(themeProvider) == ThemeOption.system &&
     WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  if (apiKey != null && apiKey.isNotEmpty) {
    return isDark ? OlaMapsDarkTileConfig(apiKey: apiKey) : OlaMapsTileConfig(apiKey: apiKey);
  }
  return isDark ? OsmDarkTileConfig() : OsmTileConfig();
});

final olaApiKeyProvider = StateProvider<String?>((ref) {
  // Load from SharedPreferences or env config
  return null; // null = use OSM fallback
});
```

---

## 4.2 — API Key Management

### 4.2.1 Secure Storage — `lib/core/constants/api_constants.dart`

```dart
abstract final class ApiConstants {
  // Ola Maps API endpoints
  static const String olaBaseUrl = 'https://api.olamaps.io';
  static const String olaAutocomplete = '$olaBaseUrl/places/v1/autocomplete';
  static const String olaReverseGeocode = '$olaBaseUrl/places/v1/reverse-geocode';
  static const String olaDirections = '$olaBaseUrl/routing/v1/directions';

  // Tile endpoints
  static const String olaTilesLight = '$olaBaseUrl/tiles/v1/styles/default-light-standard/{z}/{x}/{y}.png';
  static const String olaTilesDark = '$olaBaseUrl/tiles/v1/styles/default-dark-standard/{z}/{x}/{y}.png';

  // OSM Fallback
  static const String osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmDarkTiles = 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';

  // Nominatim Fallback (free geocoding when Ola API unavailable)
  static const String nominatimSearch = 'https://nominatim.openstreetmap.org/search';
  static const String nominatimReverse = 'https://nominatim.openstreetmap.org/reverse';
}
```

### 4.2.2 API Key Entry Flow
Since the user may or may not have an API key:

```
┌─────────────────────────────────┐
│  Settings Screen                │
│                                 │
│  Ola Maps API Key               │
│  ┌────────────────────────────┐ │
│  │ Enter your API key...      │ │
│  └────────────────────────────┘ │
│                                 │
│  ⓘ Get a free API key at       │
│    olakrutrim.com               │
│                                 │
│  Status: ✅ Connected /         │
│          ⚠️ Using OpenStreetMap │
│                                 │
│  ┌─────────────────────────┐    │
│  │   Verify & Save          │    │
│  └─────────────────────────┘    │
└─────────────────────────────────┘
```

- Validate key by making a test API call
- Store key in `SharedPreferences` (encrypted in production with `flutter_secure_storage`)
- Show connection status indicator

---

## 4.3 — flutter_map Setup

### 4.3.1 Map Widget — `lib/features/home/presentation/widgets/map_view.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class MapView extends ConsumerStatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final LatLng? destinationMarker;
  final double? alertRadius;
  final List<LatLng>? routePoints;
  final void Function(LatLng)? onTap;
  final void Function(LatLng)? onLongPress;

  const MapView({
    super.key,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.destinationMarker,
    this.alertRadius,
    this.routePoints,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> with TickerProviderStateMixin {
  late final MapController _mapController;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final tileConfig = ref.watch(mapTileConfigProvider);
    final currentLocation = ref.watch(currentLocationProvider);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialCenter ?? currentLocation ?? const LatLng(12.9716, 77.5946),
        initialZoom: widget.initialZoom,
        minZoom: 4,
        maxZoom: 18,
        onTap: (tapPosition, point) => widget.onTap?.call(point),
        onLongPress: (tapPosition, point) => widget.onLongPress?.call(point),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // Tile Layer
        TileLayer(
          urlTemplate: tileConfig.urlTemplate,
          fallbackUrl: tileConfig.fallbackUrl,
          additionalOptions: tileConfig.additionalOptions,
          userAgentPackageName: 'com.wakeupbuddy.wakeup_buddy',
          maxZoom: 18,
          tileProvider: NetworkTileProvider(),
        ),

        // Alert Radius Circle (if destination set)
        if (widget.destinationMarker != null && widget.alertRadius != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: widget.destinationMarker!,
                radius: widget.alertRadius!,   // in meters
                useRadiusInMeter: true,
                color: AppColors.alertRadius,
                borderColor: AppColors.alertRadiusBorder,
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // Route Polyline
        if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints!,
                color: AppColors.routeLine,
                strokeWidth: 4.0,
                isDotted: false,
              ),
            ],
          ),

        // Destination Marker
        if (widget.destinationMarker != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.destinationMarker!,
                width: AppDimensions.mapPinSize,
                height: AppDimensions.mapPinSize,
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.destinationPin,
                  size: 48,
                ),
              ),
            ],
          ),

        // Current Location Marker
        if (currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.currentLocation,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.currentLocation.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        // Attribution
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(tileConfig.attribution),
          ],
        ),
      ],
    );
  }

  /// Animate map camera to a new position
  void animateToPosition(LatLng target, {double? zoom}) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom ?? camera.zoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    final animation = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) controller.dispose();
    });

    controller.forward();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}
```

---

## 4.4 — Current Location Tracking (for Map Display)

### 4.4.1 Location Provider — `lib/features/home/providers/location_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Provides the user's current location as a stream
final currentLocationProvider = StreamProvider<LatLng?>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    ),
  ).map((position) => LatLng(position.latitude, position.longitude));
});

/// One-shot current location fetch
final initialLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    return null; // Fall back to default location
  }
});
```

### 4.4.2 Default Location
If GPS is unavailable on first load:
- Default center: Bangalore (12.9716, 77.5946) — can be changed to any Indian city
- Show "Waiting for GPS..." indicator
- Auto-animate to real location once GPS locks

---

## 4.5 — Map Controls

### 4.5.1 Custom Map Controls — `lib/features/home/presentation/widgets/map_controls.dart`

Floating action buttons overlaying the map:

```
              ┌─────┐
              │  📍 │  ← "My Location" button (re-center)
              └─────┘
              ┌─────┐
              │  ＋ │  ← Zoom In
              └─────┘
              ┌─────┐
              │  ー │  ← Zoom Out
              └─────┘
```

Design:
- Circular buttons with glassmorphism background
- Position: bottom-right, above bottom sheet
- Subtle shadow for depth
- Animated entry (slide in from right)

### 4.5.2 "My Location" Button Behavior
1. First press: Pan to current location at current zoom
2. Double press: Pan to current location + zoom to 17
3. If location unavailable: Show snackbar "Waiting for GPS..."

---

## 4.6 — Map State Management

### 4.6.1 Map State — `lib/features/home/providers/map_state_provider.dart`

```dart
class MapState {
  final LatLng center;
  final double zoom;
  final LatLng? currentLocation;
  final LatLng? destination;
  final double? alertRadius;
  final List<LatLng> routePoints;
  final bool isFollowingUser;      // Auto-pan to user
  final MapTileConfig tileConfig;

  // ...
}
```

### 4.6.2 Key Map Interactions

| Interaction | Action |
|-------------|--------|
| User pans map | Set `isFollowingUser = false` |
| "My Location" tapped | Set `isFollowingUser = true`, animate to user |
| Destination selected | Show marker, draw route, fit bounds |
| Trip started | Follow user, show destination + radius |
| Approaching destination | Zoom in to show both points |

---

## 4.7 — Offline Tile Caching

### 4.7.1 Strategy
- Cache downloaded tiles to disk using `flutter_map`'s built-in tile caching
- Cache last-viewed region for immediate display on launch
- Limit cache size to 100 MB

### 4.7.2 Implementation (Optional Enhancement)
```dart
// Using flutter_map_cache or custom NetworkTileProvider with caching
// This is an optional enhancement — skip for MVP if time-constrained
```

---

## 4.8 — Testing

### 4.8.1 Unit Tests
- [ ] `OlaMapsTileConfig` generates correct URL with API key
- [ ] `OsmTileConfig` generates correct URL without API key
- [ ] Dark tile configs return dark-styled URLs
- [ ] `mapTileConfigProvider` returns Ola tiles when key exists, OSM when null

### 4.8.2 Widget Tests
- [ ] `MapView` renders without crash with default parameters
- [ ] Map displays current location marker when location provided
- [ ] Destination marker appears when destination prop is set
- [ ] Alert radius circle renders with correct radius
- [ ] Map controls (zoom, my location) are visible

### 4.8.3 Integration Tests (Manual)
- [ ] Map tiles load from Ola Maps with valid API key
- [ ] Map tiles load from OSM when no API key set
- [ ] Fallback tiles load when primary tile server fails
- [ ] Current location dot appears after GPS permission granted
- [ ] Map follows user when `isFollowingUser` is true
- [ ] Dark map tiles render in dark mode

---

## ✅ Phase 04 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Map renders with Ola tiles (with key) | Set API key → Ola tiles visible |
| 2 | Map renders with OSM tiles (no key) | Remove API key → OSM tiles visible |
| 3 | Current location blue dot visible | Grant location → blue dot appears |
| 4 | Map pans to current location | "My Location" button → map centers |
| 5 | Dark map tiles in dark mode | Toggle dark theme → dark tiles load |
| 6 | Light map tiles in light mode | Toggle light theme → light tiles load |
| 7 | Zoom controls work | +/- buttons adjust zoom |
| 8 | Map is interactive | Pan, pinch-zoom, tap all work |
| 9 | Destination marker renders | Set test destination → pin appears |
| 10 | Alert radius circle renders | Set test radius → translucent circle visible |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| Tiles not loading (blank map) | Check internet, verify URL template format, check API key |
| OSM tiles blocked (429 error) | Set proper `userAgentPackageName` per OSM policy |
| Map janky when following user | Use `animateToPosition` instead of instant `move()` |
| Location marker position lag | Reduce `distanceFilter` to 5m during active tracking |
| CartoDB dark tiles have CORS issues | Only happens in web; fine on mobile |
| API key visible in network logs | Acceptable for development; use ProGuard obfuscation for release |
