# Phase 06 — Alert Configuration

> **Goal:** Build the alert configuration screen where users set their alert radius, choose alarm sounds (pre-bundled, device ringtones, or custom import), and preview settings before starting a trip.  
> **Dependencies:** Phase 02 (design system), Phase 05 (destination selected)  
> **Deliverable:** User can configure radius + sound → see visual preview → settings persist across restarts.

---

## 6.1 — Alert Settings Model

### 6.1.1 Data Model — `lib/features/alert_config/data/models/alert_settings.dart`

```dart
import 'package:hive/hive.dart';

part 'alert_settings.g.dart';  // Hive type adapter

@HiveType(typeId: 0)
class AlertSettings {
  @HiveField(0)
  final double alertRadiusMeters;      // Default: 500

  @HiveField(1)
  final String alarmSoundId;            // Sound identifier

  @HiveField(2)
  final AlarmSoundSource soundSource;   // bundled, ringtone, custom

  @HiveField(3)
  final String? customSoundPath;        // Path if custom file

  @HiveField(4)
  final bool vibrateEnabled;           // Default: true

  @HiveField(5)
  final int vibrationDurationMs;       // Default: 7000 (7 seconds)

  @HiveField(6)
  final double alarmVolume;             // 0.0 to 1.0, Default: 0.8

  @HiveField(7)
  final bool loopAlarm;                // Default: true

  @HiveField(8)
  final bool fullScreenAlert;          // Show over lock screen, Default: true

  const AlertSettings({
    this.alertRadiusMeters = 500,
    this.alarmSoundId = 'gentle_chime',
    this.soundSource = AlarmSoundSource.bundled,
    this.customSoundPath,
    this.vibrateEnabled = true,
    this.vibrationDurationMs = 7000,
    this.alarmVolume = 0.8,
    this.loopAlarm = true,
    this.fullScreenAlert = true,
  });

  AlertSettings copyWith({...});
}

@HiveType(typeId: 1)
enum AlarmSoundSource {
  @HiveField(0) bundled,
  @HiveField(1) ringtone,
  @HiveField(2) custom,
}
```

---

## 6.2 — Alert Radius Configuration

### 6.2.1 Radius Slider UI

```
┌─────────────────────────────────────────┐
│                                         │
│  Alert Radius                           │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │    ───────●────────────         │    │  ← Slider
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  200m    500m    1km    2km    5km       │  ← Quick-select presets
│          [●]                            │    (500m selected)
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  🔔 You'll be alerted when you │    │
│  │  are within 500m of your stop  │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ── Visual Preview (Mini Map) ──────── │
│                                         │
│    [Map showing destination pin with    │
│     translucent purple circle of        │
│     current radius]                     │
│                                         │
└─────────────────────────────────────────┘
```

### 6.2.2 Radius Slider Implementation — `lib/features/alert_config/presentation/widgets/radius_slider.dart`

```dart
class RadiusSlider extends ConsumerStatefulWidget {
  // Features:
  // - Custom slider with snapping to preset values
  // - Logarithmic scale (more precision at lower distances)
  // - Haptic feedback on snap points
  // - Live preview on map (radius circle updates in real-time)
  // - Preset quick-select chips below slider
}
```

### 6.2.3 Radius Presets & Scale

| Preset | Value | Use Case |
|--------|-------|----------|
| 200m | 200 | Urban, frequent stops |
| 500m | 500 | **Default** — general use |
| 1 km | 1000 | Suburban, fewer stops |
| 2 km | 2000 | Highway, need lead time |
| 5 km | 5000 | Long-distance travel |

**Slider behavior:**
- Range: 100m to 5000m
- Logarithmic scale: `log(100)` to `log(5000)`
- Snap to presets when within 50m of preset value
- Custom values allowed between presets
- Display value: "500 m" or "1.5 km"

```dart
// Logarithmic slider mapping
double _sliderToRadius(double sliderValue) {
  // sliderValue: 0.0 to 1.0
  const double minLog = 2.0;  // log10(100)
  const double maxLog = 3.699; // log10(5000)
  final double logValue = minLog + sliderValue * (maxLog - minLog);
  return pow(10, logValue).toDouble();
}

double _radiusToSlider(double radius) {
  const double minLog = 2.0;
  const double maxLog = 3.699;
  final double logValue = log(radius) / ln10;
  return (logValue - minLog) / (maxLog - minLog);
}
```

---

## 6.3 — Alarm Sound Configuration

### 6.3.1 Pre-Bundled Sounds

| Sound ID | File | Description | Duration |
|----------|------|-------------|----------|
| `gentle_chime` | `assets/sounds/gentle_chime.mp3` | Soft bell chime (default) | ~3s |
| `bell_ring` | `assets/sounds/bell_ring.mp3` | Traditional bell | ~2s |
| `digital_alarm` | `assets/sounds/digital_alarm.mp3` | Digital beep pattern | ~3s |
| `train_horn` | `assets/sounds/train_horn.mp3` | Train horn (for train travel) | ~2s |
| `bus_bell` | `assets/sounds/bus_bell.mp3` | Bus bell/ding | ~1s |
| `wake_up_tone` | `assets/sounds/wake_up_tone.mp3` | Escalating wake tone | ~5s |
| `vibrant_pulse` | `assets/sounds/vibrant_pulse.mp3` | Modern pulsing alarm | ~3s |
| `marimba` | `assets/sounds/marimba.mp3` | Calm marimba melody | ~4s |

### 6.3.2 Sound Picker UI

```
┌─────────────────────────────────────────┐
│                                         │
│  Alarm Sound                            │
│                                         │
│  ── Bundled Sounds ──────────────────── │
│                                         │
│  🔊 Gentle Chime                   ▶ ✓ │  ← Selected, play preview
│  🔊 Bell Ring                      ▶   │
│  🔊 Digital Alarm                  ▶   │
│  🔊 Train Horn                     ▶   │
│  🔊 Bus Bell                       ▶   │
│  🔊 Wake Up Tone                   ▶   │
│  🔊 Vibrant Pulse                  ▶   │
│  🔊 Marimba                        ▶   │
│                                         │
│  ── Device Ringtones ────────────────── │
│                                         │
│  🔔 Pick from device ringtones    →     │
│                                         │
│  ── Custom Sound ────────────────────── │
│                                         │
│  📁 Import audio file             →     │
│     (MP3, WAV, OGG)                     │
│                                         │
└─────────────────────────────────────────┘
```

### 6.3.3 Sound Picker Implementation — `lib/features/alert_config/presentation/widgets/sound_picker.dart`

```dart
class SoundPicker extends ConsumerStatefulWidget {
  // Features:
  // - List of bundled sounds with play/preview button
  // - Currently playing sound highlighted with animation
  // - Tap sound → select it
  // - ▶ icon → preview (play 3s sample)
  // - ✓ checkmark on selected sound
  // - "Pick from device ringtones" → opens system ringtone picker
  // - "Import audio file" → opens file picker (MP3, WAV, OGG)
}
```

### 6.3.4 Audio Preview Service — `lib/features/alarm/services/audio_service.dart`

```dart
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// Play a bundled sound preview
  Future<void> previewBundledSound(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play();
    // Auto-stop after 3 seconds
    Future.delayed(const Duration(seconds: 3), () => _player.stop());
  }

  /// Play a custom sound file preview
  Future<void> previewCustomSound(String filePath) async {
    await _player.setFilePath(filePath);
    await _player.play();
    Future.delayed(const Duration(seconds: 3), () => _player.stop());
  }

  /// Play a device ringtone preview
  Future<void> previewRingtone(String uri) async {
    await _player.setUrl(uri);
    await _player.play();
    Future.delayed(const Duration(seconds: 3), () => _player.stop());
  }

  void stopPreview() {
    _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
```

### 6.3.5 Custom Sound Import

```dart
Future<String?> importCustomSound() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
    allowMultiple: false,
  );

  if (result != null && result.files.single.path != null) {
    final sourceFile = File(result.files.single.path!);
    final appDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${appDir.path}/custom_sounds');
    if (!await soundsDir.exists()) await soundsDir.create(recursive: true);

    final destPath = '${soundsDir.path}/${result.files.single.name}';
    await sourceFile.copy(destPath);
    return destPath;
  }
  return null;
}
```

---

## 6.4 — Additional Settings

### 6.4.1 Vibration Toggle
```
┌─────────────────────────────────────┐
│                                     │
│  Vibration                          │
│  ┌─────────────────────────────┐    │
│  │ Vibrate before alarm   [●] │    │  ← Toggle switch
│  │ Duration: 7 seconds        │    │
│  └─────────────────────────────┘    │
│                                     │
│  Volume                             │
│  ───────────●───────                │  ← 80%
│  Quiet          Loud                │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Loop alarm until dismissed  [●] │ │
│  │ Full-screen alert          [●] │ │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

---

## 6.5 — Settings Persistence

### 6.5.1 Storage Service — `lib/core/services/storage_service.dart`

```dart
class StorageService {
  static const String _alertSettingsBox = 'alert_settings';
  static const String _settingsKey = 'current_settings';

  Future<void> init() async {
    Hive.registerAdapter(AlertSettingsAdapter());
    Hive.registerAdapter(AlarmSoundSourceAdapter());
    await Hive.openBox<AlertSettings>(_alertSettingsBox);
  }

  /// Save alert settings
  Future<void> saveAlertSettings(AlertSettings settings) async {
    final box = Hive.box<AlertSettings>(_alertSettingsBox);
    await box.put(_settingsKey, settings);
  }

  /// Load alert settings (returns defaults if none saved)
  AlertSettings loadAlertSettings() {
    final box = Hive.box<AlertSettings>(_alertSettingsBox);
    return box.get(_settingsKey) ?? const AlertSettings();
  }
}
```

### 6.5.2 Alert Config Provider — `lib/features/alert_config/providers/alert_config_provider.dart`

```dart
final alertConfigProvider = StateNotifierProvider<AlertConfigNotifier, AlertSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AlertConfigNotifier(storage);
});

class AlertConfigNotifier extends StateNotifier<AlertSettings> {
  final StorageService _storage;

  AlertConfigNotifier(this._storage) : super(_storage.loadAlertSettings());

  void setRadius(double meters) {
    state = state.copyWith(alertRadiusMeters: meters);
    _save();
  }

  void setSound(String soundId, AlarmSoundSource source, {String? customPath}) {
    state = state.copyWith(
      alarmSoundId: soundId,
      soundSource: source,
      customSoundPath: customPath,
    );
    _save();
  }

  void setVibration(bool enabled) {
    state = state.copyWith(vibrateEnabled: enabled);
    _save();
  }

  void setVolume(double volume) {
    state = state.copyWith(alarmVolume: volume);
    _save();
  }

  void setLoopAlarm(bool loop) {
    state = state.copyWith(loopAlarm: loop);
    _save();
  }

  void setFullScreenAlert(bool enabled) {
    state = state.copyWith(fullScreenAlert: enabled);
    _save();
  }

  Future<void> _save() async {
    await _storage.saveAlertSettings(state);
  }
}
```

---

## 6.6 — Alert Configuration Screen

### 6.6.1 Full Screen Layout — `lib/features/alert_config/presentation/alert_config_screen.dart`

```
┌─────────────────────────────────────────────┐
│  ← Back              Set Alert              │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  📍 Aluva Metro Station             │    │  ← Destination card
│  │  ~45 km away                         │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  [Mini map with radius preview]     │    │  ← Live radius preview
│  │  Circle updates as slider changes   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Alert Radius                               │
│  ──────────●────────────                    │
│  200m    500m    1km    2km    5km           │
│                                             │
│  Alarm Sound                                │
│  🔊 Gentle Chime                        →   │  ← Tap to open picker
│                                             │
│  Vibration before alarm              [●]    │
│  Loop alarm until dismissed          [●]    │
│  Full-screen alert on lock screen    [●]    │
│                                             │
│  Volume                                     │
│  ──────────────●───────                     │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │   🚀 Start Tracking                 │    │  ← Primary CTA → Phase 07
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.6.2 Settings Summary Card
Before the "Start Tracking" button, show a summary:

```
┌─────────────────────────────────────┐
│  📋 Trip Summary                    │
│                                     │
│  Destination:  Aluva Metro Station  │
│  Distance:     ~45.2 km            │
│  Alert at:     500m radius          │
│  Sound:        Gentle Chime         │
│  Vibration:    7s before alarm      │
│                                     │
└─────────────────────────────────────┘
```

---

## 6.7 — Testing

### 6.7.1 Unit Tests
- [ ] `AlertSettings` default values are correct
- [ ] `AlertSettings.copyWith` updates only specified fields
- [ ] Logarithmic slider mapping: `_sliderToRadius(0.0)` → 100, `_sliderToRadius(1.0)` → 5000
- [ ] `_radiusToSlider(500)` returns correct position
- [ ] Hive serialization/deserialization roundtrip
- [ ] `AlertConfigNotifier.setRadius` updates state and persists
- [ ] `AlertConfigNotifier` loads saved settings on init

### 6.7.2 Widget Tests
- [ ] Radius slider shows correct initial value
- [ ] Dragging slider updates displayed radius text
- [ ] Preset chips highlight when slider matches their value
- [ ] Sound picker lists all 8 bundled sounds
- [ ] Tapping a sound selects it (checkmark appears)
- [ ] Play preview button triggers audio
- [ ] Volume slider updates volume value
- [ ] Toggle switches update state
- [ ] "Start Tracking" button is enabled only with valid config

### 6.7.3 Integration Tests
- [ ] Set radius → kill app → relaunch → radius preserved
- [ ] Set custom sound → kill app → relaunch → sound preserved
- [ ] Import custom audio file → file copied to app directory
- [ ] Preview sound plays for ~3 seconds then stops
- [ ] Mini map shows radius circle updating in real-time

---

## ✅ Phase 06 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Radius slider works with logarithmic scale | 200m–5km range, more precision at lower values |
| 2 | Preset chips snap correctly | Tap 1km → slider moves, value shows "1.0 km" |
| 3 | Radius preview on map updates live | Drag slider → circle grows/shrinks |
| 4 | All 8 bundled sounds listed | Sound picker shows all sounds |
| 5 | Sound preview plays | Tap ▶ → sound plays for 3s |
| 6 | Device ringtone picker works | Opens system picker → returns selection |
| 7 | Custom audio import works | Pick file → file copied, appears in list |
| 8 | Settings persist | Kill app → relaunch → settings restored |
| 9 | Summary card shows correct info | All trip details accurate |
| 10 | "Start Tracking" navigates to Phase 07 | Tap → transitions to tracking |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| Hive type adapter not generated | Run `dart run build_runner build` |
| Custom sound file deleted after app update | Copy to app documents dir, not cache |
| Volume slider doesn't affect system volume | `alarmVolume` only controls in-app audio player volume |
| Ringtone picker not available on all devices | Wrap in try-catch, show "not available" gracefully |
| Slider janky on rapid dragging | Use `onChangeEnd` for API calls, `onChanged` for UI |
