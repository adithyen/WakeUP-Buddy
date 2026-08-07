# Phase 10 — Edge Cases & Resilience

> **Goal:** Handle all real-world failure modes: GPS loss, destination overshoot, silent mode, battery optimization killing the service, and app lifecycle events — ensuring the alarm NEVER fails to trigger.  
> **Dependencies:** Phase 07 (tracking), Phase 08 (alert), Phase 09 (trip screen)  
> **Deliverable:** App handles all failure modes gracefully; alarm triggers reliably in adversarial conditions.

---

## 10.1 — GPS Signal Loss

### 10.1.1 Scenarios
| Scenario | Cause | Duration |
|----------|-------|----------|
| Tunnel | Train/bus enters tunnel | 30s–10min |
| Indoor | Station, building | 1min–indefinite |
| Dense urban | Skyscraper canyon | 5s–30s |
| Airplane mode | User toggled | Indefinite |
| Location service disabled | User turned off GPS | Indefinite |

### 10.1.2 Detection

```dart
class GpsHealthMonitor {
  DateTime? _lastSuccessfulFix;
  int _consecutiveFailures = 0;
  static const int _maxRetries = 5;
  static const Duration _staleThreshold = Duration(seconds: 30);

  GpsSignalQuality assessSignal(Position? position) {
    if (position == null) {
      _consecutiveFailures++;
      return GpsSignalQuality.lost;
    }

    _lastSuccessfulFix = DateTime.now();
    _consecutiveFailures = 0;

    if (position.accuracy > 100) return GpsSignalQuality.poor;
    if (position.accuracy > 50) return GpsSignalQuality.fair;
    if (position.accuracy > 20) return GpsSignalQuality.good;
    return GpsSignalQuality.excellent;
  }

  bool get isStale {
    if (_lastSuccessfulFix == null) return true;
    return DateTime.now().difference(_lastSuccessfulFix!) > _staleThreshold;
  }

  bool get shouldShowWarning => _consecutiveFailures >= 3;
  bool get isCritical => _consecutiveFailures >= _maxRetries;
}

enum GpsSignalQuality { excellent, good, fair, poor, lost }
```

### 10.1.3 Recovery Strategy

```dart
// In LocationTaskHandler.onRepeatEvent():

Future<void> _handleGpsLoss() async {
  // 1. Use last known position
  final lastKnown = await Geolocator.getLastKnownPosition();
  if (lastKnown != null) {
    final age = DateTime.now().difference(lastKnown.timestamp!);
    if (age < const Duration(minutes: 2)) {
      // Use last known position with degraded confidence
      _processPosition(lastKnown, isStale: true);
      return;
    }
  }

  // 2. Notify UI of GPS loss
  FlutterForegroundTask.sendDataToMain({
    'type': 'GPS_SIGNAL_LOST',
    'lastKnownLat': lastKnown?.latitude,
    'lastKnownLng': lastKnown?.longitude,
    'duration': _gpsLostDuration.inSeconds,
  });

  // 3. Update notification
  await FlutterForegroundTask.updateService(
    notificationTitle: '⚠️ GPS Signal Lost',
    notificationText: 'Last known: ${_formatDistance(_lastDistance)} from destination',
  );

  // 4. Try different accuracy levels
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // Wider search, uses cell towers
        timeLimit: Duration(seconds: 15),
      ),
    );
    _processPosition(position, isStale: false);
  } catch (e) {
    // Still no fix — continue waiting
  }
}
```

### 10.1.4 GPS Loss UI

```
┌──────────────────────────────────────────┐
│  ┌──────────────────────────────────┐    │
│  │  ⚠️ GPS Signal Lost              │    │
│  │                                  │    │
│  │  Last position was 4.2km from    │    │
│  │  your destination                │    │
│  │                                  │    │
│  │  Don't worry — alert will        │    │
│  │  trigger once GPS is recovered.  │    │
│  │                                  │    │
│  │  Trying to reconnect...  ◌      │    │  ← Spinner
│  └──────────────────────────────────┘    │
│                                          │
│           [MAP - frozen on last pos]     │
│                                          │
└──────────────────────────────────────────┘
```

---

## 10.2 — Destination Overshoot

### 10.2.1 Problem
User enters alert radius → alarm triggers → but bus/train doesn't stop → user exits alert radius from the OTHER side → alarm was dismissed but they passed their stop.

### 10.2.2 Detection

```dart
class OvershootDetector {
  double? _minDistanceReached;
  bool _wasInRadius = false;
  bool _hasExitedRadius = false;

  OvershootResult checkForOvershoot(double currentDistance, double alertRadius) {
    // Track minimum distance reached
    if (_minDistanceReached == null || currentDistance < _minDistanceReached!) {
      _minDistanceReached = currentDistance;
    }

    // Was in radius, now exiting
    if (_wasInRadius && currentDistance > alertRadius) {
      _hasExitedRadius = true;
      return OvershootResult.overshooting;
    }

    if (currentDistance <= alertRadius) {
      _wasInRadius = true;
    }

    // Increasing distance pattern: 3+ consecutive increases
    // while distance > min reached + 500m
    if (_hasExitedRadius && currentDistance > _minDistanceReached! + 500) {
      return OvershootResult.confirmed;
    }

    return OvershootResult.none;
  }

  void reset() {
    _minDistanceReached = null;
    _wasInRadius = false;
    _hasExitedRadius = false;
  }
}

enum OvershootResult { none, overshooting, confirmed }
```

### 10.2.3 Response

| Overshoot State | Action |
|----------------|--------|
| Entering radius | Trigger alarm (normal flow) |
| Exiting radius (alarm active) | Keep alarm ringing (don't auto-dismiss) |
| Exiting radius (alarm dismissed) | Show warning: "You may have passed your stop" |
| Confirmed overshoot (500m past) | Re-trigger softer alert: "Did you miss your stop?" |

### 10.2.4 Overshoot Warning UI

```
┌─────────────────────────────────┐
│  ⚠️ You may have passed your     │
│  destination!                    │
│                                  │
│  You are now 800m past           │
│  Aluva Metro Station            │
│                                  │
│  ┌────────────────────────┐      │
│  │   I got off — dismiss   │      │
│  └────────────────────────┘      │
│                                  │
│  ┌────────────────────────┐      │
│  │   Alert me again        │      │  ← Reverse direction alert
│  └────────────────────────┘      │
└─────────────────────────────────┘
```

---

## 10.3 — Silent Mode & DND

### 10.3.1 Audio Channel Priority

```
┌────────────────────────────────────────┐
│   Audio Channels (Android Priority)     │
│                                        │
│   USAGE_ALARM ← WakeUp Buddy alarm    │
│     ↑ Overrides silent/vibrate mode    │
│     ↑ Overrides DND (if "alarms" allowed)│
│                                        │
│   USAGE_NOTIFICATION                    │
│     ↑ Blocked by silent mode           │
│                                        │
│   USAGE_MEDIA                          │
│     ↑ Blocked by silent mode           │
└────────────────────────────────────────┘
```

### 10.3.2 DND Scenarios

| DND Setting | Alarm Behavior | Vibration |
|-------------|---------------|-----------|
| DND Off | ✅ Sound + Vibration | ✅ |
| DND: Priority only (alarms allowed) | ✅ Sound | ✅ |
| DND: Alarms only | ✅ Sound | ✅ |
| DND: Total silence | ❌ Sound blocked | ✅ Vibration still works |

### 10.3.3 Fallback for Total Silence

```dart
Future<void> _handleSilentMode() async {
  // If sound can't play:
  // 1. Maximum intensity vibration pattern (continuous)
  // 2. Flash screen (if supported)
  // 3. Full-screen visual alert with large pulsing text
  // 4. Notification with maximum importance

  await Vibration.vibrate(
    pattern: [0, 1000, 500, 1000, 500, 1000],  // Aggressive pattern
    intensities: [0, 255, 0, 255, 0, 255],
    repeat: 0,  // Loop
  );
}
```

---

## 10.4 — App Backgrounded / Screen Locked

### 10.4.1 Service Persistence Checklist

| Condition | Handling |
|-----------|---------|
| App minimized | Foreground service continues; notification visible |
| Screen locked | Service continues; notification on lock screen |
| App killed by user (swipe away) | Service MAY be killed — depends on OEM |
| App killed by system (low memory) | Service should restart via `isSticky` |
| Device reboot | Trip data persisted; user must restart manually |
| Battery saver mode | May throttle GPS; show warning |

### 10.4.2 App Lifecycle Handling

```dart
class AppLifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background
        // Verify foreground service is still running
        _verifyServiceRunning();
        break;

      case AppLifecycleState.resumed:
        // App returning to foreground
        // 1. Re-sync with background service state
        // 2. Re-check permissions
        // 3. Update UI with latest tracking data
        _syncWithService();
        _checkPermissions();
        break;

      case AppLifecycleState.detached:
        // App being killed
        // Save current state for recovery
        _saveRecoveryState();
        break;

      default:
        break;
    }
  }
}
```

### 10.4.3 Service Health Check

```dart
Future<void> _verifyServiceRunning() async {
  final isRunning = await FlutterForegroundTask.isRunningService;
  if (!isRunning && _tripShouldBeActive) {
    // Service was killed! Try to restart
    await _restartTrackingService();

    // Notify user
    _showServiceRestartedNotification();
  }
}
```

---

## 10.5 — Battery Optimization Killers

### 10.5.1 OEM-Specific Behaviors

| OEM | Behavior | Workaround |
|-----|----------|-----------|
| **Samsung** | Sleeping apps killed after 3 days | Add to "Never sleeping apps" |
| **Xiaomi/MIUI** | Autostart restricted by default | Grant Autostart permission |
| **Huawei/EMUI** | Protected apps killed aggressively | Add to "Protected apps" |
| **OnePlus/OOS** | Battery optimization aggressive | Disable for app |
| **Oppo/ColorOS** | Background restriction | Allow background activity |
| **Vivo/FuntouchOS** | Auto-kill after screen lock | Allow background running |

### 10.5.2 Battery Warning System

```dart
class BatteryWarningService {
  final _batteryLevel = StreamController<int>();

  void startMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (_) async {
      final level = await Battery().batteryLevel;

      if (level <= 15) {
        _showWarning('Low battery ($level%). '
          'Your alarm may not trigger if the phone shuts down.');
      } else if (level <= 5) {
        _showCriticalWarning('Critical battery! '
          'Plug in your phone to ensure your alarm works.');
      }
    });
  }
}
```

---

## 10.6 — GPS Confidence Filtering

### 10.6.1 Problem
GPS readings can be wildly inaccurate — a reading might show you 200m from destination when you're actually 2km away. This causes false triggers.

### 10.6.2 Solution: Kalman-like Filtering

```dart
class PositionFilter {
  Position? _lastValidPosition;
  static const double _maxSpeedMps = 50; // 180 km/h max (fast train)
  static const double _minAccuracy = 100; // Reject readings worse than 100m

  /// Returns filtered position, or null if reading is invalid
  Position? filter(Position newPosition) {
    // 1. Reject low-accuracy readings
    if (newPosition.accuracy > _minAccuracy) {
      return null;
    }

    // 2. Reject impossibly fast movements (teleportation)
    if (_lastValidPosition != null) {
      final timeDiff = newPosition.timestamp!.difference(
        _lastValidPosition!.timestamp!,
      ).inSeconds;

      if (timeDiff > 0) {
        final distance = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );
        final speed = distance / timeDiff;

        if (speed > _maxSpeedMps) {
          // Impossible speed — GPS spike
          return null;
        }
      }
    }

    _lastValidPosition = newPosition;
    return newPosition;
  }
}
```

---

## 10.7 — Network Connectivity

### 10.7.1 Offline Behavior
The tracking engine works 100% offline (GPS + Haversine on-device). However:

| Feature | Online | Offline |
|---------|--------|---------|
| GPS Tracking | ✅ | ✅ |
| Distance Calculation | ✅ | ✅ |
| Alert Trigger | ✅ | ✅ |
| Map Tiles | ✅ | ❌ Cached tiles only |
| Search | ✅ | ❌ Show recent destinations |

### 10.7.2 Offline Map Handling

```dart
// When map tiles fail to load, show:
// 1. Last cached tiles (if available)
// 2. Simple distance + direction indicator (compass-like)
// 3. "Map unavailable — tracking continues" message

class OfflineMapFallback extends StatelessWidget {
  final double distance;
  final double bearing;

  // Shows a simple compass-like arrow pointing toward destination
  // with distance text overlay
}
```

---

## 10.8 — Error Recovery Matrix

### 10.8.1 Comprehensive Error Handling

| Error | Detection | Recovery | User Notification |
|-------|-----------|----------|-------------------|
| GPS timeout | `TimeoutException` | Retry with lower accuracy | "GPS searching..." |
| GPS disabled | `isLocationServiceEnabled` | Prompt to enable | "Turn on GPS" dialog |
| Permission revoked | `Permission.status` check | Re-request flow | Permission dialog |
| Service killed | `isRunningService` check | Auto-restart | "Tracking restarted" snackbar |
| Out of memory | `FlutterError` handler | Reduce breadcrumb buffer | Silent |
| Battery critical (<5%) | Battery level monitor | Save state, warn user | "Charge your phone!" alert |
| Network lost | `Connectivity` check | Switch to offline mode | "Offline — tracking continues" |
| App crash | `runZonedGuarded` | Save state, restart service | "Something went wrong" |

---

## 10.9 — Testing

### 10.9.1 Scenario Tests (Physical Device Required)

| Test | Steps | Expected |
|------|-------|----------|
| Tunnel entry | Start tracking → enter tunnel (GPS off) | "GPS lost" shown, resumes after exit |
| Airplane mode | Start tracking → enable airplane mode | GPS works (no cell, but GPS antenna active), map tiles fail |
| Silent mode | Set silent → trigger alarm | Vibration works, USAGE_ALARM plays |
| DND Total Silence | Set DND → trigger alarm | Vibration works, visual alert |
| App swipe kill | Start tracking → swipe app away | Notification persists (or shows restart) |
| Lock screen | Start tracking → lock phone → approach destination | Alarm screen shows over lock screen |
| Low battery | Drain to 15% → tracking active | Warning shown |
| GPS spike | GPS jump (hard to simulate) | Filtered out, no false trigger |
| Overshoot | Enter radius → dismiss → pass destination | "You may have passed your stop" warning |
| Force stop | Settings → Force Stop app | Service killed (acceptable, cannot prevent) |

---

## ✅ Phase 10 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | GPS loss handled | Airplane mode → graceful degradation |
| 2 | Overshoot detected | Pass destination → warning shown |
| 3 | Silent mode alarm works | Set silent → alarm plays |
| 4 | Background service survives | Minimize for 30min → still tracking |
| 5 | Lock screen alarm works | Lock phone → alarm triggers → UI visible |
| 6 | Battery warning shows | 15% battery → warning |
| 7 | GPS spikes filtered | Bad readings don't cause false alerts |
| 8 | Offline tracking works | Airplane mode → distance still updates (GPS only) |
| 9 | Service restart works | Kill app → service auto-restarts |
| 10 | Error states show recovery options | Any error → clear message + action |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| GPS works in airplane mode (most devices) | GPS doesn't require cell/wifi, just satellite |
| OEM kills foreground service | Only solvable via user education + battery settings |
| Kalman filter too aggressive | Tune parameters based on real-world testing |
| Overshoot detector triggers on GPS bounce | Require 500m+ distance increase to confirm |
| DND blocks even USAGE_ALARM | Some OEMs override; only vibration as fallback |
