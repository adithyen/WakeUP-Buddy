# Phase 07 — Location Tracking Engine

> **Goal:** Build the core location tracking engine using a foreground service and background isolate that continuously monitors the user's GPS position, calculates distance to the destination, and communicates updates to the UI — even when the app is minimized or the screen is locked.  
> **Dependencies:** Phase 03 (permissions), Phase 04 (map/location)  
> **Deliverable:** Real-time distance updates displayed in both foreground and background; persistent notification shows distance; service survives app minimization.

---

## 7.1 — Architecture Overview

### 7.1.1 System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      MAIN ISOLATE (UI)                        │
│                                                              │
│  ┌────────────────┐    ┌─────────────────┐                   │
│  │  Active Trip    │    │  Tracking        │                   │
│  │  Screen         │◄───│  Provider        │                   │
│  │  (Widget)       │    │  (Riverpod)      │                   │
│  └────────────────┘    └───────┬─────────┘                   │
│                                │                              │
│                     ┌──────────┴──────────┐                   │
│                     │ FlutterForegroundTask│                   │
│                     │ .receivePort()       │                   │
│                     │ (Listen for data)    │                   │
│                     └──────────┬──────────┘                   │
│                                │                              │
└────────────────────────────────┼──────────────────────────────┘
                                 │ Message Passing
                                 │ (SendPort ↔ ReceivePort)
┌────────────────────────────────┼──────────────────────────────┐
│                     BACKGROUND ISOLATE                        │
│                                │                              │
│  ┌─────────────────────────────┴──────────────────┐          │
│  │             LocationTaskHandler                 │          │
│  │                                                 │          │
│  │  onStart():                                     │          │
│  │    - Init Geolocator in isolate                │          │
│  │    - Load destination & radius from storage     │          │
│  │                                                 │          │
│  │  onRepeatEvent() [every 3-5 seconds]:           │          │
│  │    1. Get current GPS position                  │          │
│  │    2. Calculate distance to destination          │          │
│  │    3. Update notification text                   │          │
│  │    4. Send data to main isolate                  │          │
│  │    5. If distance <= radius → TRIGGER ALERT      │          │
│  │                                                 │          │
│  │  onDestroy():                                   │          │
│  │    - Clean up resources                         │          │
│  └─────────────────────────────────────────────────┘          │
│                                                              │
│  ┌──────────────────────────────────────────────┐            │
│  │  Android Foreground Service                    │            │
│  │  - Persistent notification                     │            │
│  │  - foregroundServiceType="location"           │            │
│  │  - Prevents OS from killing process            │            │
│  └──────────────────────────────────────────────┘            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.1.2 Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Background strategy | `flutter_foreground_task` | Maintains service even when app killed; persistent notification |
| GPS polling interval | 3–5 seconds (adaptive) | Balance between accuracy and battery |
| Distance calc method | Haversine (on-device) | No network dependency, instant calculation |
| Data communication | `SendPort` / `ReceivePort` | Only way to communicate between Dart isolates |
| State persistence | SharedPreferences in isolate | Isolates can't share memory; must store trip data |

---

## 7.2 — Foreground Service Configuration

### 7.2.1 Service Init — `lib/features/tracking/services/tracking_service.dart`

```dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../../core/constants/app_colors.dart';

class TrackingService {
  /// Initialize the foreground task service
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'wakeup_buddy_tracking',
        channelName: 'Trip Tracking',
        channelDescription: 'Tracks your distance to destination',
        channelImportance: NotificationChannelImportance.LOW,  // Silent notification
        priority: NotificationPriority.LOW,
        isSticky: true,            // Cannot be dismissed by user
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(
            id: 'stop_tracking',
            text: 'Stop Tracking',
          ),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(3000),  // 3 seconds
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Start tracking a trip
  static Future<bool> startTracking({
    required double destLat,
    required double destLng,
    required String destName,
    required double alertRadiusMeters,
    required String alarmSoundId,
    required String soundSource,
    required String? customSoundPath,
    required bool vibrateEnabled,
    required int vibrationDurationMs,
    required double alarmVolume,
    required bool loopAlarm,
  }) async {
    // Store trip data that the background isolate can read
    await FlutterForegroundTask.saveData(key: 'dest_lat', value: destLat);
    await FlutterForegroundTask.saveData(key: 'dest_lng', value: destLng);
    await FlutterForegroundTask.saveData(key: 'dest_name', value: destName);
    await FlutterForegroundTask.saveData(key: 'alert_radius', value: alertRadiusMeters);
    await FlutterForegroundTask.saveData(key: 'alarm_sound_id', value: alarmSoundId);
    await FlutterForegroundTask.saveData(key: 'sound_source', value: soundSource);
    await FlutterForegroundTask.saveData(key: 'custom_sound_path', value: customSoundPath ?? '');
    await FlutterForegroundTask.saveData(key: 'vibrate_enabled', value: vibrateEnabled);
    await FlutterForegroundTask.saveData(key: 'vibration_duration_ms', value: vibrationDurationMs);
    await FlutterForegroundTask.saveData(key: 'alarm_volume', value: alarmVolume);
    await FlutterForegroundTask.saveData(key: 'loop_alarm', value: loopAlarm);
    await FlutterForegroundTask.saveData(key: 'trip_active', value: true);

    return await FlutterForegroundTask.startService(
      notificationTitle: 'Tracking to $destName',
      notificationText: 'Calculating distance...',
      serviceId: 256,
      callback: startLocationTaskCallback,
    );
  }

  /// Stop tracking
  static Future<bool> stopTracking() async {
    await FlutterForegroundTask.saveData(key: 'trip_active', value: false);
    return await FlutterForegroundTask.stopService();
  }

  /// Check if tracking is currently active
  static Future<bool> isTrackingActive() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
```

---

## 7.3 — Background Task Handler

### 7.3.1 Task Callback — `lib/background/location_task_handler.dart`

```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

// TOP-LEVEL FUNCTION (required for isolate entry point)
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  // Trip parameters (loaded from storage)
  late double _destLat;
  late double _destLng;
  late String _destName;
  late double _alertRadius;
  late String _alarmSoundId;
  late bool _vibrateEnabled;

  // Tracking state
  double _lastDistance = double.infinity;
  int _consecutiveInRadius = 0;         // For debouncing false triggers
  static const int _triggerThreshold = 3; // Must be in radius for 3 consecutive checks
  bool _alertTriggered = false;

  // Adaptive polling
  int _pollIntervalMs = 3000;            // Start at 3s
  DateTime? _lastPollTime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Load trip data from shared storage
    _destLat = await FlutterForegroundTask.getData(key: 'dest_lat') as double;
    _destLng = await FlutterForegroundTask.getData(key: 'dest_lng') as double;
    _destName = await FlutterForegroundTask.getData(key: 'dest_name') as String;
    _alertRadius = await FlutterForegroundTask.getData(key: 'alert_radius') as double;
    _alarmSoundId = await FlutterForegroundTask.getData(key: 'alarm_sound_id') as String;
    _vibrateEnabled = await FlutterForegroundTask.getData(key: 'vibrate_enabled') as bool;
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_alertTriggered) return; // Already triggered, stop processing

    try {
      // 1. Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 2. Calculate distance (Haversine)
      final distance = _calculateDistance(
        position.latitude, position.longitude,
        _destLat, _destLng,
      );

      _lastDistance = distance;

      // 3. Check if within alert radius
      if (distance <= _alertRadius) {
        _consecutiveInRadius++;

        if (_consecutiveInRadius >= _triggerThreshold) {
          // ═══ TRIGGER ALERT ═══
          _alertTriggered = true;

          // Send alert trigger to main isolate
          FlutterForegroundTask.sendDataToMain({
            'type': 'ALERT_TRIGGERED',
            'distance': distance,
            'latitude': position.latitude,
            'longitude': position.longitude,
          });

          // Update notification
          await FlutterForegroundTask.updateService(
            notificationTitle: '⚠️ Approaching ${_destName}!',
            notificationText: '${_formatDistance(distance)} away - WAKE UP!',
          );

          return;
        }
      } else {
        _consecutiveInRadius = 0; // Reset counter when outside radius
      }

      // 4. Adaptive polling rate
      _updatePollingRate(distance);

      // 5. Update notification and send data to UI
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking to $_destName',
        notificationText: '${_formatDistance(distance)} remaining',
      );

      FlutterForegroundTask.sendDataToMain({
        'type': 'LOCATION_UPDATE',
        'distance': distance,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp?.millisecondsSinceEpoch,
      });

    } catch (e) {
      // GPS error — send error to UI but don't crash
      FlutterForegroundTask.sendDataToMain({
        'type': 'GPS_ERROR',
        'error': e.toString(),
      });

      await FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking to $_destName',
        notificationText: '⚠️ GPS signal lost - retrying...',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup
    _alertTriggered = false;
    _consecutiveInRadius = 0;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_tracking') {
      FlutterForegroundTask.sendDataToMain({
        'type': 'STOP_REQUESTED',
      });
    }
  }

  /// Adaptive polling — poll faster when closer to destination
  void _updatePollingRate(double distance) {
    if (distance > 10000) {
      _pollIntervalMs = 10000;  // 10s when > 10km
    } else if (distance > 5000) {
      _pollIntervalMs = 7000;   // 7s when 5-10km
    } else if (distance > 2000) {
      _pollIntervalMs = 5000;   // 5s when 2-5km
    } else if (distance > 1000) {
      _pollIntervalMs = 3000;   // 3s when 1-2km
    } else {
      _pollIntervalMs = 2000;   // 2s when < 1km (approaching!)
    }

    // Note: flutter_foreground_task doesn't support dynamic intervals
    // Alternative: Skip events if too frequent
    // Or: Reinitialize with new interval (complex)
  }

  /// Haversine distance calculation
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth radius in meters
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
      sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}
```

---

## 7.4 — Tracking State Provider

### 7.4.1 Trip State Model — `lib/features/tracking/data/models/trip_state.dart`

```dart
enum TripStatus {
  idle,          // No active trip
  starting,      // Service starting up
  tracking,      // Actively tracking
  approaching,   // Within 2x alert radius
  alerting,      // Alert triggered!
  completed,     // Trip ended (arrived)
  stopped,       // User manually stopped
  error,         // Service error
}

class TripState {
  final TripStatus status;
  final Destination? destination;
  final AlertSettings? alertSettings;
  final double? currentDistance;          // meters
  final double? currentLatitude;
  final double? currentLongitude;
  final double? currentSpeed;            // m/s
  final double? gpsAccuracy;             // meters
  final DateTime? lastUpdate;
  final DateTime? tripStartTime;
  final String? errorMessage;
  final List<LatLng> breadcrumbs;        // Trail of positions (for route display)

  const TripState({
    this.status = TripStatus.idle,
    this.destination,
    this.alertSettings,
    this.currentDistance,
    this.currentLatitude,
    this.currentLongitude,
    this.currentSpeed,
    this.gpsAccuracy,
    this.lastUpdate,
    this.tripStartTime,
    this.errorMessage,
    this.breadcrumbs = const [],
  });

  /// Estimated time of arrival based on current speed
  Duration? get estimatedTimeRemaining {
    if (currentDistance == null || currentSpeed == null || currentSpeed! <= 0) return null;
    final seconds = currentDistance! / currentSpeed!;
    return Duration(seconds: seconds.round());
  }

  /// Progress percentage (0.0 to 1.0) based on initial distance
  double? get progress {
    // Requires storing initial distance at trip start
    return null; // Calculated externally
  }

  TripState copyWith({...});
}
```

### 7.4.2 Tracking Provider — `lib/features/tracking/providers/tracking_provider.dart`

```dart
final trackingProvider = StateNotifierProvider<TrackingNotifier, TripState>((ref) {
  return TrackingNotifier();
});

class TrackingNotifier extends StateNotifier<TripState> {
  StreamSubscription? _dataSubscription;
  double? _initialDistance; // Distance at trip start

  TrackingNotifier() : super(const TripState()) {
    _listenToBackgroundData();
  }

  /// Start a new trip
  Future<void> startTrip(Destination destination, AlertSettings settings) async {
    state = TripState(
      status: TripStatus.starting,
      destination: destination,
      alertSettings: settings,
      tripStartTime: DateTime.now(),
    );

    final success = await TrackingService.startTracking(
      destLat: destination.latitude,
      destLng: destination.longitude,
      destName: destination.name,
      alertRadiusMeters: settings.alertRadiusMeters,
      alarmSoundId: settings.alarmSoundId,
      soundSource: settings.soundSource.name,
      customSoundPath: settings.customSoundPath,
      vibrateEnabled: settings.vibrateEnabled,
      vibrationDurationMs: settings.vibrationDurationMs,
      alarmVolume: settings.alarmVolume,
      loopAlarm: settings.loopAlarm,
    );

    if (success) {
      state = state.copyWith(status: TripStatus.tracking);
    } else {
      state = state.copyWith(
        status: TripStatus.error,
        errorMessage: 'Failed to start tracking service',
      );
    }
  }

  /// Stop current trip
  Future<void> stopTrip() async {
    await TrackingService.stopTracking();
    state = state.copyWith(status: TripStatus.stopped);
  }

  /// Listen for data from background isolate
  void _listenToBackgroundData() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveData);
  }

  void _onReceiveData(Object data) {
    if (data is Map) {
      final type = data['type'] as String?;

      switch (type) {
        case 'LOCATION_UPDATE':
          _handleLocationUpdate(data);
          break;
        case 'ALERT_TRIGGERED':
          _handleAlertTriggered(data);
          break;
        case 'GPS_ERROR':
          _handleGpsError(data);
          break;
        case 'STOP_REQUESTED':
          stopTrip();
          break;
      }
    }
  }

  void _handleLocationUpdate(Map data) {
    final distance = data['distance'] as double;
    final lat = data['latitude'] as double;
    final lng = data['longitude'] as double;

    // Store initial distance on first update
    _initialDistance ??= distance;

    // Determine if "approaching" (within 2x alert radius)
    final alertRadius = state.alertSettings?.alertRadiusMeters ?? 500;
    final isApproaching = distance <= alertRadius * 2;

    // Add to breadcrumbs (keep last 200 points)
    final updatedBreadcrumbs = [...state.breadcrumbs, LatLng(lat, lng)];
    if (updatedBreadcrumbs.length > 200) {
      updatedBreadcrumbs.removeRange(0, updatedBreadcrumbs.length - 200);
    }

    state = state.copyWith(
      status: isApproaching ? TripStatus.approaching : TripStatus.tracking,
      currentDistance: distance,
      currentLatitude: lat,
      currentLongitude: lng,
      currentSpeed: data['speed'] as double?,
      gpsAccuracy: data['accuracy'] as double?,
      lastUpdate: DateTime.now(),
      breadcrumbs: updatedBreadcrumbs,
    );
  }

  void _handleAlertTriggered(Map data) {
    state = state.copyWith(
      status: TripStatus.alerting,
      currentDistance: data['distance'] as double?,
      currentLatitude: data['latitude'] as double?,
      currentLongitude: data['longitude'] as double?,
    );
    // The alarm UI is triggered separately by watching this state
  }

  void _handleGpsError(Map data) {
    // Don't immediately error — could be transient
    state = state.copyWith(
      errorMessage: 'GPS signal weak',
      // Keep tracking status
    );
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveData);
    super.dispose();
  }
}
```

---

## 7.5 — Battery Optimization

### 7.5.1 Adaptive GPS Accuracy

| Distance to Destination | GPS Accuracy | Poll Interval | Battery Impact |
|--------------------------|-------------|---------------|---------------|
| > 10 km | `balanced` | 10s | ⚡ Low |
| 5–10 km | `balanced` | 7s | ⚡ Low |
| 2–5 km | `high` | 5s | ⚡⚡ Medium |
| 1–2 km | `high` | 3s | ⚡⚡ Medium |
| < 1 km | `best` | 2s | ⚡⚡⚡ High |

### 7.5.2 Distance Filter Optimization
Use `geolocator`'s `distanceFilter` to avoid processing updates when the user hasn't moved:

```dart
// When far away: only update after 50m of movement
// When close: update after 10m of movement
final distanceFilter = distance > 5000 ? 50.0 : (distance > 1000 ? 25.0 : 10.0);
```

### 7.5.3 Battery Usage Estimation
Show estimated battery usage in the UI:
- Low tracking (~10km away): ~2-3% per hour
- Active tracking (~1km away): ~5-8% per hour
- These are estimates; actual usage varies by device

---

## 7.6 — Service Recovery

### 7.6.1 Service Restart on Boot
If the app is killed by the system and restarted:

```dart
// In main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if a trip was active when app was killed
  final wasTracking = await FlutterForegroundTask.getData(key: 'trip_active') as bool? ?? false;
  if (wasTracking) {
    // Resume tracking automatically
    // Show active trip screen
  }

  // ...
}
```

### 7.6.2 Notification Actions
The persistent notification has a "Stop Tracking" button:
```
┌──────────────────────────────────┐
│ 📍 Tracking to Aluva Metro      │
│    4.2 km remaining              │
│    [Stop Tracking]               │
└──────────────────────────────────┘
```

When pressed → sends `STOP_REQUESTED` message → `TrackingNotifier` stops trip.

---

## 7.7 — Testing

### 7.7.1 Unit Tests
- [ ] `_calculateDistance` returns correct values for known coordinate pairs
- [ ] `TripState.estimatedTimeRemaining` calculates correctly (1000m at 10m/s = 100s)
- [ ] `TrackingNotifier._handleLocationUpdate` updates state correctly
- [ ] `TrackingNotifier._handleAlertTriggered` sets status to `alerting`
- [ ] Breadcrumbs are limited to 200 points
- [ ] Adaptive polling rate logic returns correct intervals

### 7.7.2 Widget Tests
- [ ] Starting trip shows "Starting..." state
- [ ] Location updates display in UI
- [ ] GPS error shows warning message
- [ ] "Stop Tracking" button stops the service

### 7.7.3 Integration Tests (PHYSICAL DEVICE REQUIRED)
- [ ] Start tracking → notification appears in notification shade
- [ ] Minimize app → notification persists, distance updates continue
- [ ] Lock screen → notification still visible and updating
- [ ] Walk towards a test destination → distance decreases
- [ ] Notification "Stop Tracking" button works
- [ ] Kill app (force stop) → service stops (expected behavior)
- [ ] Service survives 30+ minutes of background operation

### 7.7.4 Battery Tests
- [ ] Track for 1 hour → record battery consumption
- [ ] Compare with/without adaptive polling

---

## ✅ Phase 07 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Foreground service starts with notification | Notification appears in shade |
| 2 | GPS position updates received | Distance values change in UI |
| 3 | Distance calculation is accurate | Compare with Google Maps distance |
| 4 | Background tracking works | Minimize app → still tracking |
| 5 | Lock screen tracking works | Lock phone → notification updates |
| 6 | Notification shows current distance | "4.2 km remaining" visible |
| 7 | Notification "Stop" button works | Tap → service stops |
| 8 | Adaptive polling adjusts rate | Log poll intervals at different distances |
| 9 | Breadcrumb trail maintained | Route trail visible on map |
| 10 | GPS errors handled gracefully | Airplane mode → "GPS signal lost" shown |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| `@pragma('vm:entry-point')` missing | Background handler won't be found; crash |
| Handler must be TOP-LEVEL function | Cannot be a method or closure; must be `void callback()` |
| Isolate can't access provider state | Must use `FlutterForegroundTask.getData/saveData` |
| GPS timeout in tunnels | Set `timeLimit` on `getCurrentPosition`, handle timeout |
| Service killed by OEM | Battery optimization bypass (Phase 03); user education |
| Distance "jumps" wildly | Filter out readings with `accuracy > 100m` |
| `geolocator` crashes in isolate | Some versions require initialization; test on device |
