# Phase 11 — Local Data & History

> **Goal:** Implement persistent local data storage using Hive for recent destinations, trip history, favorite destinations, and user preferences. Enable quick re-selection of frequent destinations.  
> **Dependencies:** Phase 05 (destination), Phase 06 (alert config)  
> **Deliverable:** Recent destinations show in search; trip history viewable; favorites saveable; all data persists across restarts.

---

## 11.1 — Data Schema

### 11.1.1 Data Models

```dart
// ─── Trip Record ───
@HiveType(typeId: 2)
class TripRecord {
  @HiveField(0) final String id;
  @HiveField(1) final String destinationName;
  @HiveField(2) final String? destinationDescription;
  @HiveField(3) final double destinationLat;
  @HiveField(4) final double destinationLng;
  @HiveField(5) final double alertRadiusMeters;
  @HiveField(6) final DateTime startTime;
  @HiveField(7) final DateTime? endTime;
  @HiveField(8) final TripOutcome outcome;         // completed, cancelled, failed
  @HiveField(9) final double? initialDistance;
  @HiveField(10) final double? finalDistance;
  @HiveField(11) final String? alarmSoundId;

  Duration? get duration => endTime != null ? endTime!.difference(startTime) : null;
}

@HiveType(typeId: 3)
enum TripOutcome {
  @HiveField(0) completed,      // Alarm triggered & dismissed
  @HiveField(1) cancelled,      // User manually cancelled
  @HiveField(2) failed,         // Service error
}

// ─── Saved Destination (Favorite) ───
@HiveType(typeId: 4)
class SavedDestination {
  @HiveField(0) final String id;
  @HiveField(1) final String name;
  @HiveField(2) final String? description;
  @HiveField(3) final double latitude;
  @HiveField(4) final double longitude;
  @HiveField(5) final DateTime savedAt;
  @HiveField(6) final int useCount;             // How many times used
  @HiveField(7) final DateTime? lastUsedAt;
  @HiveField(8) final double? defaultRadius;    // User's preferred radius for this stop
  @HiveField(9) final String? emoji;            // Custom emoji label (🏠 🏢 🚂)
  @HiveField(10) final String? nickname;        // Custom nickname ("Home", "Office")
}

// ─── Recent Search Query ───
@HiveType(typeId: 5)
class RecentSearch {
  @HiveField(0) final String query;
  @HiveField(1) final DateTime searchedAt;
  @HiveField(2) final String? selectedPlaceId;   // What they ended up selecting
}
```

---

## 11.2 — Storage Layer

### 11.2.1 Hive Box Configuration

```dart
class LocalDatabase {
  static const String _tripHistoryBox = 'trip_history';
  static const String _savedDestinationsBox = 'saved_destinations';
  static const String _recentSearchesBox = 'recent_searches';
  static const String _alertSettingsBox = 'alert_settings';

  static Future<void> init() async {
    // Register all adapters
    Hive.registerAdapter(TripRecordAdapter());
    Hive.registerAdapter(TripOutcomeAdapter());
    Hive.registerAdapter(SavedDestinationAdapter());
    Hive.registerAdapter(RecentSearchAdapter());
    Hive.registerAdapter(AlertSettingsAdapter());
    Hive.registerAdapter(AlarmSoundSourceAdapter());

    // Open all boxes
    await Hive.openBox<TripRecord>(_tripHistoryBox);
    await Hive.openBox<SavedDestination>(_savedDestinationsBox);
    await Hive.openBox<RecentSearch>(_recentSearchesBox);
    await Hive.openBox<AlertSettings>(_alertSettingsBox);
  }
}
```

### 11.2.2 Trip History Repository

```dart
class TripHistoryRepository {
  Box<TripRecord> get _box => Hive.box<TripRecord>(LocalDatabase._tripHistoryBox);

  /// Save a completed/cancelled trip
  Future<void> saveTripRecord(TripRecord record) async {
    await _box.put(record.id, record);
  }

  /// Get all trips, sorted by most recent
  List<TripRecord> getAllTrips() {
    return _box.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Get trips to a specific destination
  List<TripRecord> getTripsToDestination(double lat, double lng, {double thresholdMeters = 200}) {
    return getAllTrips().where((trip) {
      final distance = DistanceCalculator.calculateDistance(
        lat, lng, trip.destinationLat, trip.destinationLng,
      );
      return distance < thresholdMeters;
    }).toList();
  }

  /// Get recent N trips
  List<TripRecord> getRecentTrips({int limit = 10}) {
    return getAllTrips().take(limit).toList();
  }

  /// Get trip count stats
  TripStats getStats() {
    final all = getAllTrips();
    return TripStats(
      totalTrips: all.length,
      completedTrips: all.where((t) => t.outcome == TripOutcome.completed).length,
      cancelledTrips: all.where((t) => t.outcome == TripOutcome.cancelled).length,
      totalDuration: all.fold(Duration.zero, (sum, t) => sum + (t.duration ?? Duration.zero)),
    );
  }

  /// Delete a trip record
  Future<void> deleteTripRecord(String id) async {
    await _box.delete(id);
  }

  /// Clear all trip history
  Future<void> clearAll() async {
    await _box.clear();
  }
}

class TripStats {
  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;
  final Duration totalDuration;
}
```

### 11.2.3 Saved Destinations Repository

```dart
class SavedDestinationsRepository {
  Box<SavedDestination> get _box => Hive.box<SavedDestination>(LocalDatabase._savedDestinationsBox);

  /// Save a destination as favorite
  Future<void> saveDestination(SavedDestination dest) async {
    await _box.put(dest.id, dest);
  }

  /// Get all saved destinations, sorted by use count
  List<SavedDestination> getAllSaved() {
    return _box.values.toList()
      ..sort((a, b) => b.useCount.compareTo(a.useCount));
  }

  /// Increment use count when destination is used for a trip
  Future<void> incrementUseCount(String id) async {
    final dest = _box.get(id);
    if (dest != null) {
      await _box.put(id, dest.copyWith(
        useCount: dest.useCount + 1,
        lastUsedAt: DateTime.now(),
      ));
    }
  }

  /// Find nearby saved destination (for auto-suggestions)
  SavedDestination? findNearby(double lat, double lng, {double thresholdMeters = 500}) {
    for (final dest in _box.values) {
      final distance = DistanceCalculator.calculateDistance(
        lat, lng, dest.latitude, dest.longitude,
      );
      if (distance < thresholdMeters) return dest;
    }
    return null;
  }

  /// Delete a saved destination
  Future<void> deleteDestination(String id) async {
    await _box.delete(id);
  }
}
```

### 11.2.4 Recent Searches Repository

```dart
class RecentSearchesRepository {
  Box<RecentSearch> get _box => Hive.box<RecentSearch>(LocalDatabase._recentSearchesBox);
  static const int _maxRecent = 20;

  /// Add a recent search
  Future<void> addSearch(String query, {String? selectedPlaceId}) async {
    // Remove duplicate
    final existing = _box.values.where((s) => s.query.toLowerCase() == query.toLowerCase());
    for (final s in existing) {
      await _box.delete(s.key);
    }

    await _box.add(RecentSearch(
      query: query,
      searchedAt: DateTime.now(),
      selectedPlaceId: selectedPlaceId,
    ));

    // Trim to max
    if (_box.length > _maxRecent) {
      final oldest = _box.keys.first;
      await _box.delete(oldest);
    }
  }

  /// Get recent searches
  List<RecentSearch> getRecent({int limit = 10}) {
    return _box.values.toList()
      ..sort((a, b) => b.searchedAt.compareTo(a.searchedAt))
      ..take(limit);
  }

  /// Clear recent searches
  Future<void> clearAll() async {
    await _box.clear();
  }
}
```

---

## 11.3 — Trip History Screen

### 11.3.1 Layout — `lib/features/history/presentation/history_screen.dart`

```
┌──────────────────────────────────────────┐
│  ← Back              Trip History        │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  🏆 Trip Stats                    │    │
│  │  12 trips · 8 completed · 520 km │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ── Today ────────────────────────────── │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  📍 Aluva Metro Station           │    │
│  │  ✅ Completed · 47 min            │    │
│  │  4:32 PM                          │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ── Yesterday ────────────────────────── │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  📍 Kochi Boat Jetty              │    │
│  │  ❌ Cancelled · 12 min            │    │
│  │  8:15 AM                          │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  📍 Fort Kochi Bus Stand          │    │
│  │  ✅ Completed · 1h 23min          │    │
│  │  6:45 AM                          │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ── May 22 ──────────────────────────── │
│  ...                                     │
│                                          │
└──────────────────────────────────────────┘
```

### 11.3.2 Trip Card — `lib/features/history/presentation/widgets/trip_card.dart`

```dart
class TripCard extends StatelessWidget {
  final TripRecord trip;

  // Shows:
  // - Destination name (headlineSmall)
  // - Status icon + text (✅ Completed / ❌ Cancelled)
  // - Duration
  // - Time of trip
  // - Tap → trip detail view (optional)
  // - Swipe left → delete
  // - Long press → "Start trip here again" option
}
```

### 11.3.3 Group by Date
Group trips by date sections using `intl` package:

```dart
Map<String, List<TripRecord>> groupTripsByDate(List<TripRecord> trips) {
  final grouped = <String, List<TripRecord>>{};
  for (final trip in trips) {
    final dateKey = _getDateLabel(trip.startTime);
    grouped.putIfAbsent(dateKey, () => []).add(trip);
  }
  return grouped;
}

String _getDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tripDay = DateTime(date.year, date.month, date.day);

  if (tripDay == today) return 'Today';
  if (tripDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}
```

---

## 11.4 — Saved Destinations (Favorites)

### 11.4.1 Save Destination Flow

After selecting a destination or completing a trip:

```
┌─────────────────────────────────┐
│  ⭐ Save this destination?      │
│                                 │
│  📍 Aluva Metro Station         │
│                                 │
│  Nickname (optional):           │
│  ┌─────────────────────────┐    │
│  │  My Metro Stop           │    │
│  └─────────────────────────┘    │
│                                 │
│  Emoji:                         │
│  🚇 🚌 🚂 🏠 🏢 📍 ⭐ 🎯    │
│                                 │
│  Default alert radius:          │
│  ───●──────── 500m              │
│                                 │
│  ┌─────────────────────────┐    │
│  │   Save                   │    │
│  └─────────────────────────┘    │
└─────────────────────────────────┘
```

### 11.4.2 Favorites in Search Screen

Show saved destinations at the top of the search screen before recent searches:

```
┌───────────────────────────────────────────┐
│  ┌─────────────────────────────────────┐  │
│  │  🔍  Search destination...           │  │
│  └─────────────────────────────────────┘  │
│                                           │
│  ── ⭐ Saved Destinations ────────────── │
│                                           │
│  🚇 My Metro Stop                    →   │
│     Aluva Metro Station                  │
│                                           │
│  🏠 Home                             →   │
│     Kakkanad, Kochi                      │
│                                           │
│  ── 🕐 Recent ──────────────────────── │
│                                           │
│  📍 Fort Kochi Bus Stand                 │
│  📍 Ernakulam South Station              │
│                                           │
└───────────────────────────────────────────┘
```

### 11.4.3 Quick-Start from Favorites
Tapping a saved destination pre-fills:
- Destination coordinates
- Alert radius (saved default)
- Skips search step → goes directly to alert config

---

## 11.5 — Data Migration & Cleanup

### 11.5.1 Automatic Cleanup
- Keep last 100 trip records
- Delete trips older than 6 months
- Clear recent searches older than 30 days

```dart
Future<void> cleanupOldData() async {
  final cutoffDate = DateTime.now().subtract(const Duration(days: 180));
  final tripBox = Hive.box<TripRecord>('trip_history');

  final toDelete = tripBox.values
    .where((trip) => trip.startTime.isBefore(cutoffDate))
    .map((trip) => trip.id)
    .toList();

  for (final id in toDelete) {
    await tripBox.delete(id);
  }

  // Also trim to 100 most recent
  if (tripBox.length > 100) {
    final sorted = tripBox.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final excess = sorted.take(sorted.length - 100);
    for (final trip in excess) {
      await tripBox.delete(trip.id);
    }
  }
}
```

### 11.5.2 Export Data (Future Enhancement)
Allow user to export trip history as JSON/CSV.

---

## 11.6 — Settings Screen

### 11.6.1 Layout — `lib/features/settings/presentation/settings_screen.dart`

```
┌──────────────────────────────────────────┐
│  ← Back              Settings            │
│                                          │
│  ── Appearance ──────────────────────── │
│  Theme                                   │
│  ┌──────────────────────────────┐        │
│  │  ☀️ Light │ 🌙 Dark │ 🔄 Auto │        │
│  └──────────────────────────────┘        │
│                                          │
│  ── Maps ────────────────────────────── │
│  Ola Maps API Key                        │
│  ┌──────────────────────────────┐        │
│  │ ●●●●●●●●●●●●●●●●  ✏️        │        │
│  └──────────────────────────────┘        │
│  Status: ✅ Connected                    │
│                                          │
│  ── Default Alert ───────────────────── │
│  Default Radius: 500m                    │
│  Default Sound: Gentle Chime             │
│  Vibration: On                           │
│  Volume: 80%                             │
│                                          │
│  ── Data ────────────────────────────── │
│  Clear Trip History                  →   │
│  Clear Saved Destinations            →   │
│  Clear Recent Searches               →   │
│                                          │
│  ── About ───────────────────────────── │
│  Version: 1.0.0                          │
│  Battery Optimization Guide         →   │
│  Privacy Policy                      →   │
│  Open Source Licenses                →   │
│                                          │
└──────────────────────────────────────────┘
```

---

## 11.7 — Testing

### 11.7.1 Unit Tests
- [ ] `TripRecord` Hive serialization roundtrip
- [ ] `SavedDestination` Hive serialization roundtrip
- [ ] `TripHistoryRepository.getRecentTrips` returns correct limit
- [ ] `TripHistoryRepository.getTripsToDestination` finds nearby trips
- [ ] `SavedDestinationsRepository.findNearby` matches within threshold
- [ ] `RecentSearchesRepository` trims to max 20 entries
- [ ] Date grouping logic (Today, Yesterday, formatted date)
- [ ] Cleanup removes old data correctly

### 11.7.2 Widget Tests
- [ ] History screen shows trips grouped by date
- [ ] Trip card shows correct status icon and duration
- [ ] Empty state shows "No trips yet" message
- [ ] Saved destination appears at top of search
- [ ] Tapping saved destination pre-fills config
- [ ] Settings screen renders all sections
- [ ] Theme toggle changes theme
- [ ] Clear data shows confirmation dialog

### 11.7.3 Integration Tests
- [ ] Complete a trip → appears in history
- [ ] Cancel a trip → appears as cancelled in history
- [ ] Save a destination → appears in favorites
- [ ] Kill app → relaunch → all data persisted
- [ ] Clear history → history empty
- [ ] Trip history > 100 entries → oldest trimmed

---

## ✅ Phase 11 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Trip history records all trips | Complete & cancel trips → both appear |
| 2 | History grouped by date | Today, Yesterday, dates visible |
| 3 | Save destination as favorite | Save → appears in search top |
| 4 | Quick-start from favorite | Tap favorite → pre-filled config |
| 5 | Recent searches shown | Search something → appears as recent |
| 6 | Data persists across restarts | Kill app → data still there |
| 7 | Settings screen functional | All toggles and inputs work |
| 8 | API key entry works | Enter key → "Connected" shown |
| 9 | Clear data works | Clear → data removed |
| 10 | Auto-cleanup runs | Old data removed on startup |
