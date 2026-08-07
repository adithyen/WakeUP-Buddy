# Phase 05 — Destination Search & Selection

> **Goal:** Enable users to search for and select their destination via Ola Maps Autocomplete API (with Nominatim fallback), place a marker on the map, and confirm their selection — all with a smooth, sleepy-user-friendly UX.  
> **Dependencies:** Phase 04 (map integration)  
> **Deliverable:** User can search → select → see destination pin on map → confirm selection.

---

## 5.1 — Search Architecture

### 5.1.1 Dual API Strategy

```
┌──────────────────────────────────┐
│         Search Input             │
│     "Kochi Metro Station"       │
└──────────────┬───────────────────┘
               │
        ┌──────┴──────────┐
        │ Ola API Key     │
        │ Available?      │
        └──┬──────────┬───┘
           │ Yes      │ No
           ▼          ▼
    Ola Autocomplete   Nominatim
    API                Search API
           │          │
           └────┬─────┘
                ▼
        Place Suggestions
        (Unified Model)
```

### 5.1.2 Unified Place Model — `lib/features/destination/data/models/place_suggestion.dart`

```dart
class PlaceSuggestion {
  final String placeId;          // Unique identifier
  final String name;             // Primary name (e.g., "Kochi Metro - Aluva Station")
  final String description;      // Secondary text (e.g., "Aluva, Ernakulam, Kerala")
  final double latitude;
  final double longitude;
  final String? formattedAddress;
  final PlaceType type;          // station, bus_stop, landmark, address, etc.
  final PlaceSource source;      // ola, nominatim

  const PlaceSuggestion({...});
}

enum PlaceType {
  busStop,
  trainStation,
  metroStation,
  airport,
  landmark,
  address,
  other,
}

enum PlaceSource { ola, nominatim }
```

### 5.1.3 Destination Model — `lib/features/destination/data/models/destination.dart`

```dart
class Destination {
  final String id;               // UUID
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final DateTime selectedAt;
  final PlaceSource source;

  const Destination({...});

  // Convert from PlaceSuggestion
  factory Destination.fromSuggestion(PlaceSuggestion suggestion) {
    return Destination(
      id: const Uuid().v4(),
      name: suggestion.name,
      description: suggestion.description,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      selectedAt: DateTime.now(),
      source: suggestion.source,
    );
  }
}
```

---

## 5.2 — Places Repository

### 5.2.1 Repository Interface — `lib/features/destination/data/repositories/places_repository.dart`

```dart
abstract class PlacesRepository {
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  });

  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng);
}
```

### 5.2.2 Ola Maps Implementation — `lib/features/destination/data/repositories/ola_places_repository.dart`

```dart
class OlaPlacesRepository implements PlacesRepository {
  final Dio _dio;
  final String _apiKey;

  OlaPlacesRepository({required Dio dio, required String apiKey})
    : _dio = dio, _apiKey = apiKey;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.olaAutocomplete,
        queryParameters: {
          'input': query,
          'api_key': _apiKey,
          if (nearLat != null && nearLng != null)
            'location': '$nearLat,$nearLng',
        },
      );

      if (response.statusCode == 200) {
        final predictions = response.data['predictions'] as List? ?? [];
        return predictions.map((p) => PlaceSuggestion(
          placeId: p['place_id'] ?? '',
          name: p['structured_formatting']?['main_text'] ?? p['description'] ?? '',
          description: p['structured_formatting']?['secondary_text'] ?? '',
          latitude: p['geometry']?['location']?['lat']?.toDouble() ?? 0,
          longitude: p['geometry']?['location']?['lng']?.toDouble() ?? 0,
          formattedAddress: p['description'],
          type: _inferPlaceType(p['types']),
          source: PlaceSource.ola,
        )).toList();
      }
      return [];
    } on DioException catch (e) {
      // Log error, return empty (fallback to Nominatim handled at provider level)
      throw PlacesApiException('Ola API error: ${e.message}');
    }
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        ApiConstants.olaReverseGeocode,
        queryParameters: {
          'latlng': '$lat,$lng',
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final first = results.first;
          return PlaceSuggestion(
            placeId: first['place_id'] ?? '',
            name: first['formatted_address'] ?? 'Unknown Location',
            description: first['formatted_address'] ?? '',
            latitude: lat,
            longitude: lng,
            formattedAddress: first['formatted_address'],
            type: PlaceType.address,
            source: PlaceSource.ola,
          );
        }
      }
      return null;
    } on DioException {
      return null;
    }
  }

  PlaceType _inferPlaceType(List? types) {
    if (types == null) return PlaceType.other;
    final typeSet = types.cast<String>().toSet();
    if (typeSet.contains('bus_station') || typeSet.contains('transit_station')) return PlaceType.busStop;
    if (typeSet.contains('train_station')) return PlaceType.trainStation;
    if (typeSet.contains('subway_station')) return PlaceType.metroStation;
    if (typeSet.contains('airport')) return PlaceType.airport;
    return PlaceType.other;
  }
}
```

### 5.2.3 Nominatim Fallback — `lib/features/destination/data/repositories/nominatim_places_repository.dart`

```dart
class NominatimPlacesRepository implements PlacesRepository {
  final Dio _dio;

  NominatimPlacesRepository({required Dio dio}) : _dio = dio;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.nominatimSearch,
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 10,
          'addressdetails': 1,
          'countrycodes': 'in',  // Restrict to India
          if (nearLat != null && nearLng != null) ...<String, String>{
            'viewbox': '${nearLng - 0.5},${nearLat + 0.5},${nearLng + 0.5},${nearLat - 0.5}',
            'bounded': '0',  // Prefer but don't restrict to viewbox
          },
        },
        options: Options(headers: {
          'User-Agent': 'WakeUpBuddy/1.0 (contact: your-email@example.com)',
        }),
      );

      if (response.statusCode == 200) {
        final results = response.data as List;
        return results.map((r) => PlaceSuggestion(
          placeId: r['place_id'].toString(),
          name: r['display_name']?.split(',')?.first ?? 'Unknown',
          description: (r['display_name']?.split(',')?.skip(1)?.join(', ') ?? '').trim(),
          latitude: double.tryParse(r['lat']?.toString() ?? '') ?? 0,
          longitude: double.tryParse(r['lon']?.toString() ?? '') ?? 0,
          formattedAddress: r['display_name'],
          type: _inferType(r['type'], r['class']),
          source: PlaceSource.nominatim,
        )).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        ApiConstants.nominatimReverse,
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
        options: Options(headers: {
          'User-Agent': 'WakeUpBuddy/1.0',
        }),
      );

      if (response.statusCode == 200) {
        return PlaceSuggestion(
          placeId: response.data['place_id'].toString(),
          name: response.data['display_name']?.split(',')?.first ?? 'Dropped Pin',
          description: response.data['display_name'] ?? '',
          latitude: lat,
          longitude: lng,
          formattedAddress: response.data['display_name'],
          type: PlaceType.address,
          source: PlaceSource.nominatim,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  PlaceType _inferType(String? type, String? osmClass) {
    if (type == 'bus_stop') return PlaceType.busStop;
    if (type == 'station' && osmClass == 'railway') return PlaceType.trainStation;
    if (type == 'halt' && osmClass == 'railway') return PlaceType.trainStation;
    return PlaceType.other;
  }
}
```

### 5.2.4 Composite Repository with Fallback

```dart
class CompositePlacesRepository implements PlacesRepository {
  final OlaPlacesRepository? _olaRepo;
  final NominatimPlacesRepository _nominatimRepo;

  CompositePlacesRepository({
    OlaPlacesRepository? olaRepo,
    required NominatimPlacesRepository nominatimRepo,
  }) : _olaRepo = olaRepo, _nominatimRepo = nominatimRepo;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(String query, {double? nearLat, double? nearLng}) async {
    // Try Ola first
    if (_olaRepo != null) {
      try {
        final results = await _olaRepo!.searchPlaces(query, nearLat: nearLat, nearLng: nearLng);
        if (results.isNotEmpty) return results;
      } catch (_) {
        // Fall through to Nominatim
      }
    }

    // Fallback to Nominatim
    return _nominatimRepo.searchPlaces(query, nearLat: nearLat, nearLng: nearLng);
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    if (_olaRepo != null) {
      try {
        final result = await _olaRepo!.reverseGeocode(lat, lng);
        if (result != null) return result;
      } catch (_) {}
    }
    return _nominatimRepo.reverseGeocode(lat, lng);
  }
}
```

---

## 5.3 — Search UI

### 5.3.1 Destination Search Screen Flow

```
┌───────────────────────────────────────────┐
│  Home Screen (Map)                        │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │  🔍  Where are you going?           │  │  ← Tap to open search
│  └─────────────────────────────────────┘  │
│                                           │
│           [MAP VIEW]                      │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │   📍 Set Destination                │  │  ← Primary CTA
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
                    │
                    │ Tap either search bar or CTA
                    ▼
┌───────────────────────────────────────────┐
│  ← Back                                  │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │  🔍  Search destination...  ✕       │  │  ← Auto-focused, keyboard up
│  └─────────────────────────────────────┘  │
│                                           │
│  ── Recent Destinations ──────────────── │
│  📍 Aluva Metro Station                  │
│     Ernakulam, Kerala                    │
│  📍 Kochi Boat Jetty                     │
│     Fort Kochi, Kerala                   │
│  ── ─────────────────────────────────── │
│                                           │
│  (Start typing to search...)             │
│                                           │
│  ──────── OR ─────────                   │
│  📌 Pick on Map                          │  ← Long-press map option
│                                           │
└───────────────────────────────────────────┘
                    │
                    │ User types "Aluva..."
                    ▼
┌───────────────────────────────────────────┐
│  ← Back                                  │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │  🔍  Aluva                    ✕     │  │
│  └─────────────────────────────────────┘  │
│                                           │
│  ── Search Results ───────────────────── │
│                                           │
│  🚇 Aluva Metro Station                  │
│     Aluva, Ernakulam, Kerala             │
│                                           │
│  🚌 Aluva Bus Stand                      │
│     Aluva, Ernakulam District            │
│                                           │
│  🚂 Aluva Railway Station                │
│     Aluva, Ernakulam, Kerala, India      │
│                                           │
│  📍 Aluva Palace Ground                   │
│     Palace Road, Aluva                    │
│                                           │
│  📍 Aluva Sivarathri Maidan              │
│     Near Sivarathri Temple               │
│                                           │
│  (Showing results from Ola Maps ✓)       │
└───────────────────────────────────────────┘
```

### 5.3.2 Search Bar — `lib/features/destination/presentation/widgets/search_bar.dart`

```dart
class DestinationSearchBar extends ConsumerStatefulWidget {
  // Features:
  // - TextField with search icon prefix
  // - Clear (✕) button suffix when text exists
  // - Debounced search (300ms delay after last keystroke)
  // - Loading shimmer below while fetching
  // - Auto-focus on screen open
}
```

### 5.3.3 Debounced Search — `lib/core/utils/debouncer.dart`

```dart
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
```

### 5.3.4 Suggestion List Item — `lib/features/destination/presentation/widgets/suggestion_list_item.dart`

```dart
class SuggestionListItem extends StatelessWidget {
  // Shows:
  // - Icon based on PlaceType (🚌 🚇 🚂 📍)
  // - Primary name (bold)
  // - Secondary description (muted)
  // - Subtle tap highlight animation
  // - API source indicator (small badge: "Ola" or "OSM")
}
```

### 5.3.5 Place Type Icons

| Type | Icon | Color |
|------|------|-------|
| `busStop` | `Icons.directions_bus` | Amber |
| `trainStation` | `Icons.train` | Blue |
| `metroStation` | `Icons.subway` | Purple |
| `airport` | `Icons.flight` | Teal |
| `landmark` | `Icons.place` | Primary |
| `address` | `Icons.location_on` | Secondary |

---

## 5.4 — Map Pin Drop Selection

### 5.4.1 "Pick on Map" Mode
An alternative to search — user long-presses on map to drop a pin:

```
┌───────────────────────────────────────────┐
│                                           │
│              [MAP VIEW]                   │
│                                           │
│         📌 (pin at center)                │
│                                           │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │  Long-press on map to set          │  │
│  │  destination                        │  │
│  └─────────────────────────────────────┘  │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │   ✓ Confirm Location                │  │  ← Appears after pin drop
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

**Behavior:**
1. User long-presses on map → pin drops at that location
2. Reverse geocode the coordinates → show address in bottom card
3. User can drag the pin to adjust
4. "Confirm Location" button appears
5. On confirm → proceed to alert configuration (Phase 06)

### 5.4.2 Reverse Geocoding on Pin Drop

```dart
Future<void> onMapLongPress(LatLng point) async {
  // 1. Drop pin immediately (responsive feedback)
  state = state.copyWith(pinnedLocation: point, isResolving: true);

  // 2. Reverse geocode in background
  final place = await placesRepository.reverseGeocode(point.latitude, point.longitude);

  // 3. Update with resolved name
  state = state.copyWith(
    resolvedPlace: place ?? PlaceSuggestion(
      name: 'Dropped Pin',
      description: '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
      latitude: point.latitude,
      longitude: point.longitude,
      // ...
    ),
    isResolving: false,
  );
}
```

---

## 5.5 — Destination Confirmation

### 5.5.1 Confirmation Bottom Sheet

After the user selects a destination (from search OR map pin):

```
┌─────────────────────────────────────┐
│  ─── (drag handle) ───              │
│                                     │
│  📍 Aluva Metro Station             │
│  Aluva, Ernakulam, Kerala          │
│                                     │
│  Distance: ~45 km away              │
│                                     │
│  ┌───────────────────────────────┐  │
│  │   🔔 Set Alert for This Stop │  │  ← Primary action
│  └───────────────────────────────┘  │
│                                     │
│        Change Destination           │  ← Ghost button
│                                     │
└─────────────────────────────────────┘
```

### 5.5.2 Distance Preview
Calculate straight-line distance from current location to selected destination:

```dart
// lib/core/utils/distance_calculator.dart

import 'dart:math';

class DistanceCalculator {
  /// Haversine formula — returns distance in meters
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double R = 6371000; // Earth radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * (pi / 180);

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}
```

---

## 5.6 — State Management

### 5.6.1 Destination Provider — `lib/features/destination/providers/destination_provider.dart`

```dart
enum SearchState { idle, loading, loaded, error }

class DestinationSearchState {
  final String query;
  final List<PlaceSuggestion> suggestions;
  final SearchState searchState;
  final Destination? selectedDestination;
  final LatLng? pinnedLocation;
  final PlaceSuggestion? resolvedPin;
  final bool isResolving;
  final String? errorMessage;

  const DestinationSearchState({...});
}

final destinationProvider = StateNotifierProvider<DestinationNotifier, DestinationSearchState>((ref) {
  final placesRepo = ref.watch(placesRepositoryProvider);
  return DestinationNotifier(placesRepo);
});

class DestinationNotifier extends StateNotifier<DestinationSearchState> {
  final PlacesRepository _repository;
  final Debouncer _debouncer = Debouncer();

  DestinationNotifier(this._repository) : super(const DestinationSearchState());

  void onSearchChanged(String query) {
    state = state.copyWith(query: query);
    if (query.length < 2) {
      state = state.copyWith(suggestions: [], searchState: SearchState.idle);
      return;
    }
    _debouncer.run(() => _search(query));
  }

  Future<void> _search(String query) async {
    state = state.copyWith(searchState: SearchState.loading);
    try {
      final results = await _repository.searchPlaces(query);
      state = state.copyWith(
        suggestions: results,
        searchState: SearchState.loaded,
      );
    } catch (e) {
      state = state.copyWith(
        searchState: SearchState.error,
        errorMessage: e.toString(),
      );
    }
  }

  void selectSuggestion(PlaceSuggestion suggestion) {
    state = state.copyWith(
      selectedDestination: Destination.fromSuggestion(suggestion),
    );
  }

  Future<void> onMapPinDrop(LatLng point) async { /* ... */ }

  void clearSearch() {
    state = const DestinationSearchState();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
```

---

## 5.7 — Testing

### 5.7.1 Unit Tests
- [ ] `PlaceSuggestion` model serializes/deserializes correctly
- [ ] `Destination.fromSuggestion` creates correct destination
- [ ] `DistanceCalculator.calculateDistance` returns accurate results (test with known coords)
- [ ] `DistanceCalculator.formatDistance` formats correctly (500m → "500 m", 1500m → "1.5 km")
- [ ] `Debouncer` delays execution correctly
- [ ] `OlaPlacesRepository` parses API response correctly (mock Dio)
- [ ] `NominatimPlacesRepository` parses API response correctly (mock Dio)
- [ ] `CompositePlacesRepository` falls back to Nominatim on Ola failure

### 5.7.2 Widget Tests
- [ ] Search bar renders with placeholder text
- [ ] Typing triggers search after debounce delay
- [ ] Suggestion list shows correct items
- [ ] Tapping suggestion calls `selectSuggestion`
- [ ] Clear button clears search text and results
- [ ] Loading shimmer appears during search
- [ ] Error state shows retry option
- [ ] Confirmation bottom sheet shows destination name and distance

### 5.7.3 Integration Tests (Manual)
- [ ] Search "Aluva" → results appear from Ola API (if key set)
- [ ] Search "Aluva" → results appear from Nominatim (no key)
- [ ] Select a result → pin drops on map at correct location
- [ ] Long-press map → pin drops, address resolves
- [ ] Confirmation shows correct distance
- [ ] "Set Alert" navigates to Phase 06 screen

---

## ✅ Phase 05 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Search bar works with Ola API | Enter query → results from Ola |
| 2 | Search works with Nominatim fallback | Remove API key → results from Nominatim |
| 3 | Debounced search (no request per keystroke) | Type fast → only 1 API call after pause |
| 4 | Suggestion list shows place type icons | Bus/train icons visible |
| 5 | Map pin drop works | Long-press → pin appears |
| 6 | Reverse geocode resolves pin address | Long-press → address shown |
| 7 | Confirmation bottom sheet shows details | Select place → name + distance visible |
| 8 | Distance calculation is accurate | Compare with Google Maps straight-line |
| 9 | "Set Alert" navigates to config screen | Tap → transitions to Phase 06 |
| 10 | Recent destinations shown before search | Open search → recent items visible |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| Nominatim rate limiting (1 req/sec) | Add minimum 1s delay between Nominatim requests |
| Ola API returns no lat/lng in autocomplete | May need separate Place Details API call |
| Search results appear for wrong query (race condition) | Cancel previous request when new query typed (use Dio CancelToken) |
| Keyboard covers suggestion list | Use `Scaffold` with `resizeToAvoidBottomInset: true` |
| Very long place names truncate badly | Use `TextOverflow.ellipsis` with `maxLines: 1` for name, 2 for description |
