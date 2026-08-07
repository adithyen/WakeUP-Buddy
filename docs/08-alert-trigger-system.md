# Phase 08 — Alert Trigger System

> **Goal:** Implement the complete alert mechanism: vibration pattern → sound alarm → full-screen wake UI → dismiss flow, all working reliably when the phone is locked or in a pocket.  
> **Dependencies:** Phase 06 (alert config), Phase 07 (tracking engine)  
> **Deliverable:** When distance threshold is met → phone vibrates for 7s → alarm sound plays → full-screen "You're arriving!" UI shows over lock screen.

---

## 8.1 — Alert Trigger Flow

### 8.1.1 Sequence Diagram

```
Background Isolate                Main Isolate                  Device
     │                                │                            │
     │ distance <= radius             │                            │
     │ (3 consecutive checks)         │                            │
     │                                │                            │
     ├──── ALERT_TRIGGERED ──────────►│                            │
     │                                │                            │
     │                                ├─── Start Vibration ───────►│
     │                                │    (7s pattern)            │ VIBRATE
     │                                │                            │
     │                                │    [after 7 seconds]       │
     │                                │                            │
     │                                ├─── Start Alarm Sound ─────►│
     │                                │    (loop until dismiss)    │ PLAY AUDIO
     │                                │                            │
     │                                ├─── Wake Screen ───────────►│
     │                                │    (full screen intent)    │ SCREEN ON
     │                                │                            │
     │                                ├─── Show Alarm Screen ─────►│
     │                                │    (over lock screen)      │ UI VISIBLE
     │                                │                            │
     │                                │    [user dismisses]        │
     │                                │                            │
     │                                ├─── Stop Alarm ────────────►│
     │                                ├─── Stop Vibration ─────────│
     │◄── STOP_TRACKING ─────────────┤                            │
     │                                │                            │
```

---

## 8.2 — Vibration Service

### 8.2.1 Implementation — `lib/features/alarm/services/vibration_service.dart`

```dart
import 'package:vibration/vibration.dart';

class VibrationService {
  /// Check if device supports vibration
  static Future<bool> hasVibrator() async {
    return await Vibration.hasVibrator() ?? false;
  }

  /// Execute the pre-alarm vibration pattern
  /// Pattern: Vibrate 500ms, pause 300ms, repeat for ~7 seconds
  static Future<void> executePreAlarmVibration({
    int durationMs = 7000,
  }) async {
    if (!await hasVibrator()) return;

    // Pattern: [pause, vibrate, pause, vibrate, ...]
    // Each cycle: 500ms vibrate + 300ms pause = 800ms
    // 7000ms / 800ms = ~8.75 cycles → 9 cycles
    final int cycles = (durationMs / 800).ceil();

    final List<int> pattern = [];
    for (int i = 0; i < cycles; i++) {
      pattern.add(0);    // Wait 0ms (or 300ms gap)
      pattern.add(500);  // Vibrate 500ms
      if (i < cycles - 1) {
        pattern.add(300); // Pause 300ms
      }
    }

    // Intensities: escalating vibration
    final List<int> intensities = [];
    for (int i = 0; i < cycles; i++) {
      intensities.add(0);      // Pause
      intensities.add(128 + (i * 14).clamp(0, 127)); // 128 → 255
      if (i < cycles - 1) {
        intensities.add(0);    // Pause
      }
    }

    await Vibration.vibrate(
      pattern: pattern,
      intensities: intensities,
    );
  }

  /// Strong continuous vibration (for alarm)
  static Future<void> vibrateStrong() async {
    await Vibration.vibrate(duration: 1000, amplitude: 255);
  }

  /// Stop any ongoing vibration
  static Future<void> cancel() async {
    await Vibration.cancel();
  }
}
```

---

## 8.3 — Alarm Sound Service

### 8.3.1 Implementation — `lib/features/alarm/services/alarm_service.dart`

```dart
import 'package:alarm/alarm.dart';

class AlarmService {
  /// Initialize the alarm package
  static Future<void> init() async {
    await Alarm.init();
  }

  /// Set the proximity alarm
  static Future<void> triggerAlarm({
    required String soundId,
    required AlarmSoundSource soundSource,
    String? customSoundPath,
    required double volume,
    required bool loopAudio,
    required bool vibrate,
    required bool fullScreenIntent,
  }) async {
    // Determine audio path
    String audioPath;
    switch (soundSource) {
      case AlarmSoundSource.bundled:
        audioPath = 'assets/sounds/$soundId.mp3';
        break;
      case AlarmSoundSource.ringtone:
        audioPath = soundId; // URI from ringtone picker
        break;
      case AlarmSoundSource.custom:
        audioPath = customSoundPath ?? 'assets/sounds/gentle_chime.mp3';
        break;
    }

    final alarmSettings = AlarmSettings(
      id: 42,  // Fixed ID — only one alarm at a time
      dateTime: DateTime.now(), // Trigger immediately
      assetAudioPath: audioPath,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volume: volume,
      fadeDuration: 3.0,  // Fade in over 3 seconds
      warningNotificationOnKill: true,
      androidFullScreenIntent: fullScreenIntent,
      notificationSettings: const NotificationSettings(
        title: '⏰ WakeUp Buddy',
        body: 'You are approaching your destination!',
        stopButton: 'Dismiss',
        icon: 'ic_launcher',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  /// Stop the alarm
  static Future<void> stopAlarm() async {
    await Alarm.stop(42);
  }

  /// Check if alarm is currently ringing
  static Future<bool> isRinging() async {
    return Alarm.getAlarms().any((a) => a.id == 42);
  }

  /// Listen for alarm ring events
  static Stream<AlarmSettings> get onRing => Alarm.ringStream.stream;
}
```

### 8.3.2 Audio Channel Configuration
The alarm MUST play on the `USAGE_ALARM` audio stream to override silent/DND mode:

```xml
<!-- android/app/src/main/res/raw/alarm_channel.xml -->
<!-- The alarm package handles this internally, but verify: -->
<!-- AudioAttributes.Builder()
       .setUsage(AudioAttributes.USAGE_ALARM)
       .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
       .build() -->
```

---

## 8.4 — Alert Orchestrator

### 8.4.1 Coordinating Vibration → Sound — `lib/features/alarm/providers/alarm_provider.dart`

```dart
final alarmOrchestratorProvider = StateNotifierProvider<AlarmOrchestrator, AlarmState>((ref) {
  return AlarmOrchestrator(ref);
});

enum AlarmPhase { idle, vibrating, sounding, dismissed }

class AlarmState {
  final AlarmPhase phase;
  final DateTime? triggeredAt;
  final double? distanceAtTrigger;

  const AlarmState({
    this.phase = AlarmPhase.idle,
    this.triggeredAt,
    this.distanceAtTrigger,
  });
}

class AlarmOrchestrator extends StateNotifier<AlarmState> {
  final Ref _ref;
  Timer? _vibrationTimer;

  AlarmOrchestrator(this._ref) : super(const AlarmState()) {
    // Watch tracking state for alert trigger
    _ref.listen<TripState>(trackingProvider, (previous, next) {
      if (next.status == TripStatus.alerting && state.phase == AlarmPhase.idle) {
        _executeAlertSequence(next);
      }
    });
  }

  Future<void> _executeAlertSequence(TripState tripState) async {
    final settings = tripState.alertSettings!;

    state = AlarmState(
      phase: AlarmPhase.vibrating,
      triggeredAt: DateTime.now(),
      distanceAtTrigger: tripState.currentDistance,
    );

    // ═══ STEP 1: Vibration (7 seconds) ═══
    if (settings.vibrateEnabled) {
      await VibrationService.executePreAlarmVibration(
        durationMs: settings.vibrationDurationMs,
      );

      // Wait for vibration to complete
      _vibrationTimer = Timer(
        Duration(milliseconds: settings.vibrationDurationMs),
        () => _startAlarmSound(settings),
      );
    } else {
      // Skip vibration, go straight to sound
      await _startAlarmSound(settings);
    }
  }

  Future<void> _startAlarmSound(AlertSettings settings) async {
    // ═══ STEP 2: Alarm Sound ═══
    state = state.copyWith(phase: AlarmPhase.sounding);

    await AlarmService.triggerAlarm(
      soundId: settings.alarmSoundId,
      soundSource: settings.soundSource,
      customSoundPath: settings.customSoundPath,
      volume: settings.alarmVolume,
      loopAudio: settings.loopAlarm,
      vibrate: settings.vibrateEnabled,  // Continue vibrating with sound
      fullScreenIntent: settings.fullScreenAlert,
    );
  }

  /// User dismisses the alarm
  Future<void> dismissAlarm() async {
    _vibrationTimer?.cancel();
    await VibrationService.cancel();
    await AlarmService.stopAlarm();

    state = state.copyWith(phase: AlarmPhase.dismissed);

    // Stop tracking service
    await _ref.read(trackingProvider.notifier).stopTrip();
  }

  /// Snooze — add more distance before re-triggering
  Future<void> snoozeAlarm({double additionalMeters = 500}) async {
    _vibrationTimer?.cancel();
    await VibrationService.cancel();
    await AlarmService.stopAlarm();

    state = const AlarmState(phase: AlarmPhase.idle);

    // Update alert radius to current distance + additional
    // This allows re-triggering when even closer
    // Implementation: send new radius to background isolate
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    super.dispose();
  }
}
```

---

## 8.5 — Full-Screen Alarm UI

### 8.5.1 Alarm Screen — `lib/features/alarm/presentation/alarm_screen.dart`

```
┌──────────────────────────────────────────┐
│                                          │
│                                          │
│             ⏰                           │
│        (pulsing animation)               │
│                                          │
│                                          │
│      You're Arriving!                    │
│                                          │
│      📍 Aluva Metro Station              │
│                                          │
│      ~320m away                          │
│                                          │
│                                          │
│                                          │
│                                          │
│    ┌────────────────────────────┐        │
│    │  ←  Slide to Dismiss  →   │        │  ← Slide-to-dismiss
│    └────────────────────────────┘        │    (prevents accidental dismiss)
│                                          │
│         Snooze (+500m)                   │  ← Text button
│                                          │
└──────────────────────────────────────────┘
```

**Design details:**
- Full screen, over lock screen
- Background: dark with pulsing gradient (alertGradient)
- Large alarm icon with pulse animation (scale 1.0 → 1.1 → 1.0, looping)
- Destination name in large text (displaySmall)
- Distance in hero text (distanceHero)
- **Slide-to-dismiss** instead of tap button (prevents accidental dismiss while in pocket)
- Snooze option for "not yet, alert me again in 500m"

### 8.5.2 Slide-to-Dismiss Widget — `lib/features/alarm/presentation/widgets/dismiss_slider.dart`

```dart
class DismissSlider extends StatefulWidget {
  final VoidCallback onDismissed;

  // Implementation:
  // - Horizontal draggable slider
  // - Must drag > 80% of width to trigger dismiss
  // - Springs back if released before threshold
  // - Arrow indicators showing slide direction
  // - Haptic feedback at threshold
  // - Text: "Slide to Dismiss"
}
```

### 8.5.3 Showing Alarm Over Lock Screen

```dart
// In alarm_provider.dart, when alarm triggers:
void _showAlarmScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => const AlarmScreen(),
    ),
  );
}

// For showing over lock screen, the alarm package's
// androidFullScreenIntent: true handles this.
// The Activity flags are already set in AndroidManifest.xml:
// android:showWhenLocked="true"
// android:turnScreenOn="true"
```

---

## 8.6 — Silent Mode & DND Handling

### 8.6.1 Problem
If the user's phone is in Silent or Do Not Disturb mode, the alarm sound won't play.

### 8.6.2 Solution
The `alarm` package uses `AudioAttributes.USAGE_ALARM` which bypasses most DND settings. However, some scenarios require additional handling:

```dart
class AlarmModeChecker {
  /// Check current ringer mode
  static Future<RingerMode> getRingerMode() async {
    // Use platform channel or volume_controller package
    // Returns: normal, vibrate, silent
  }

  /// Request DND override permission
  /// On Android, USAGE_ALARM should bypass DND for alarms
  /// But verify on specific OEM devices
  static Future<void> ensureAlarmChannelAccess() async {
    // Check notification channel importance
    // Ensure alarm channel is not blocked by user
  }
}
```

### 8.6.3 Fallback Strategy

| Scenario | Behavior |
|----------|----------|
| Normal mode | Vibrate → Sound at set volume |
| Vibrate mode | Vibrate → Sound at set volume (USAGE_ALARM overrides) |
| Silent mode | Vibrate → Sound at set volume (USAGE_ALARM overrides) |
| DND - Alarms allowed | Vibrate → Sound plays |
| DND - Total silence | Vibrate only (sound blocked) → show visual alert |

---

## 8.7 — Alert Debouncing & False Trigger Prevention

### 8.7.1 Debouncing Logic (in background isolate)

```dart
// Must meet ALL conditions to trigger:
// 1. Distance <= alert radius
// 2. For 3 consecutive GPS readings (prevents single GPS spike)
// 3. GPS accuracy < 100m (prevents low-confidence readings)
// 4. Alert hasn't been triggered already for this trip

bool _shouldTriggerAlert(double distance, double accuracy) {
  if (_alertTriggered) return false;
  if (accuracy > 100) return false;  // GPS too inaccurate
  if (distance > _alertRadius) {
    _consecutiveInRadius = 0;
    return false;
  }

  _consecutiveInRadius++;
  return _consecutiveInRadius >= _triggerThreshold;
}
```

### 8.7.2 Hysteresis
Once an alert is triggered and dismissed, don't re-trigger unless:
- User explicitly snoozes (sets new, smaller radius)
- User starts a new trip

---

## 8.8 — Testing

### 8.8.1 Unit Tests
- [ ] `VibrationService.executePreAlarmVibration` generates correct pattern array
- [ ] `AlarmOrchestrator._executeAlertSequence` transitions through correct phases
- [ ] Vibration → Sound timing is correct (sound starts after vibration duration)
- [ ] `dismissAlarm` stops both vibration and sound
- [ ] `snoozeAlarm` resets state to idle
- [ ] Debouncing logic: single reading doesn't trigger, 3 consecutive does
- [ ] GPS accuracy filter: readings with accuracy > 100m don't count

### 8.8.2 Widget Tests
- [ ] Alarm screen shows destination name and distance
- [ ] Pulse animation runs on alarm icon
- [ ] Dismiss slider springs back when released before threshold
- [ ] Dismiss slider triggers callback at > 80% drag
- [ ] Snooze button is visible and tappable

### 8.8.3 Integration Tests (PHYSICAL DEVICE)
- [ ] Walk within radius of test destination → phone vibrates
- [ ] After vibration → alarm sound plays
- [ ] Alarm screen shows over lock screen
- [ ] Slide to dismiss → alarm stops, tracking stops
- [ ] Test in silent mode → alarm still plays
- [ ] Test in vibrate mode → vibration + alarm both work
- [ ] Test alarm from background (app minimized)
- [ ] Test alarm from lock screen

---

## ✅ Phase 08 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Vibration starts when distance <= radius | Walk towards test point |
| 2 | Vibration lasts ~7 seconds | Time with stopwatch |
| 3 | Alarm sound starts after vibration | Sound begins at ~7s mark |
| 4 | Alarm plays on alarm audio channel | Works in silent mode |
| 5 | Full-screen UI shows over lock screen | Lock phone → alarm triggers → UI visible |
| 6 | Slide-to-dismiss works | Slide → alarm stops |
| 7 | Snooze re-enables tracking | Snooze → alarm stops → tracking continues |
| 8 | False triggers prevented | Single GPS spike doesn't trigger |
| 9 | Alarm works from background | Minimize app → trigger → alarm plays |
| 10 | Tracking stops after dismiss | Dismiss → foreground service stops |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| Alarm doesn't play in background | Ensure `alarm` package's foreground service is configured |
| Lock screen UI doesn't show | Set `androidFullScreenIntent: true` + manifest flags |
| Vibration doesn't work on some devices | Check `Vibration.hasVibrator()` first; some emulators don't support it |
| Alarm plays at wrong volume | Use `USAGE_ALARM` stream; don't use media volume |
| Slide-to-dismiss too easy to trigger | Require > 80% slide distance + velocity threshold |
| Double alert trigger | Guard with `_alertTriggered` flag |
