import 'package:alarm/alarm.dart';

import '../../alert_config/data/models/alert_settings.dart';

/// Wraps the `alarm` package to play sounds on the USAGE_ALARM audio channel.
///
/// The alarm package internally uses AudioAttributes.USAGE_ALARM, which
/// overrides DND / Silent mode on Android for alarm-category audio.
class AlarmService {
  AlarmService._();

  /// Fixed alarm ID — only one proximity alarm can be active at a time.
  static const int _alarmId = 42;

  /// Must be called once at app startup before any other alarm operations.
  static Future<void> init() async {
    await Alarm.init();
  }

  /// Starts the alarm using the sound configured in [settings].
  ///
  /// [settings.soundSource] determines whether we use a bundled asset,
  /// a ringtone URI, or a custom file path.
  static Future<void> triggerAlarm(AlertSettings settings) async {
    final String audioPath = _resolveAudioPath(settings);

    final AlarmSettings alarmSettings = AlarmSettings(
      id: _alarmId,
      dateTime: DateTime.now(), // trigger immediately
      assetAudioPath: audioPath,
      loopAudio: settings.loopAlarm,
      vibrate: false, // vibration handled separately by VibrationService
      volumeSettings: VolumeSettings.fade(
        volume: settings.alarmVolume,
        fadeDuration: const Duration(seconds: 3),
        volumeEnforced: true,
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: settings.fullScreenAlert,
      notificationSettings: const NotificationSettings(
        title: '⏰ WakeUp Buddy',
        body: 'You are approaching your destination!',
        stopButton: 'Dismiss',
        icon: 'ic_launcher',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  /// Stops the currently ringing alarm (if any).
  static Future<void> stopAlarm() async {
    await Alarm.stop(_alarmId);
  }

  /// Returns true if the alarm with [_alarmId] is currently scheduled / ringing.
  static Future<bool> isRinging() async {
    final List<AlarmSettings> alarms = await Alarm.getAlarms();
    return alarms.any((AlarmSettings a) => a.id == _alarmId);
  }

  /// Stream that emits [AlarmSettings] each time an alarm starts ringing.
  // ignore: deprecated_member_use
  static Stream<AlarmSettings> get onRing => Alarm.ringStream.stream;

  // ---------------------------------------------------------------------------

  static String _resolveAudioPath(AlertSettings settings) {
    switch (settings.soundSource) {
      case AlarmSoundSource.bundled:
        return 'assets/sounds/${settings.alarmSoundId}.mp3';
      case AlarmSoundSource.ringtone:
        // customSoundPath holds the actual file path from the system ringtone scan
        if (settings.customSoundPath != null && settings.customSoundPath!.isNotEmpty) {
          return settings.customSoundPath!;
        }
        // fallback to default bundled tone
        return 'assets/sounds/freesound_community-alarm-clock-90867.mp3';
      case AlarmSoundSource.custom:
        if (settings.customSoundPath != null && settings.customSoundPath!.isNotEmpty) {
          return settings.customSoundPath!;
        }
        return 'assets/sounds/freesound_community-alarm-clock-90867.mp3';
    }
  }
}
