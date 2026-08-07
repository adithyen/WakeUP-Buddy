enum AlarmSoundSource { bundled, ringtone, custom }

/// All configurable alarm / alert parameters for a trip.
class AlertSettings {
  final double alertRadiusMeters;
  final String alarmSoundId;
  final AlarmSoundSource soundSource;
  final String? customSoundPath;
  final bool vibrateEnabled;
  final int vibrationDurationMs;
  /// Seconds to vibrate BEFORE playing alarm sound (0 = simultaneous).
  final int vibrationPreDelayMs;
  final double alarmVolume;
  /// Separate volume for Bluetooth wearables (TWS earbuds, watches).
  final double wearableVolume;
  final bool loopAlarm;
  final bool fullScreenAlert;
  /// Snooze radius in meters — alert re-triggers if user re-enters this radius.
  final double snoozeRadiusMeters;

  const AlertSettings({
    this.alertRadiusMeters = 500,
    this.alarmSoundId = 'freesound_community-alarm-clock-90867',
    this.soundSource = AlarmSoundSource.bundled,
    this.customSoundPath,
    this.vibrateEnabled = true,
    this.vibrationDurationMs = 7000,
    this.vibrationPreDelayMs = 6000, // 6s vibration before sound by default
    this.alarmVolume = 0.9,
    this.wearableVolume = 0.7,
    this.loopAlarm = true,
    this.fullScreenAlert = true,
    this.snoozeRadiusMeters = 500,
  });

  AlertSettings copyWith({
    double? alertRadiusMeters,
    String? alarmSoundId,
    AlarmSoundSource? soundSource,
    String? customSoundPath,
    bool? vibrateEnabled,
    int? vibrationDurationMs,
    int? vibrationPreDelayMs,
    double? alarmVolume,
    double? wearableVolume,
    bool? loopAlarm,
    bool? fullScreenAlert,
    double? snoozeRadiusMeters,
  }) {
    return AlertSettings(
      alertRadiusMeters: alertRadiusMeters ?? this.alertRadiusMeters,
      alarmSoundId: alarmSoundId ?? this.alarmSoundId,
      soundSource: soundSource ?? this.soundSource,
      customSoundPath: customSoundPath ?? this.customSoundPath,
      vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
      vibrationDurationMs: vibrationDurationMs ?? this.vibrationDurationMs,
      vibrationPreDelayMs: vibrationPreDelayMs ?? this.vibrationPreDelayMs,
      alarmVolume: alarmVolume ?? this.alarmVolume,
      wearableVolume: wearableVolume ?? this.wearableVolume,
      loopAlarm: loopAlarm ?? this.loopAlarm,
      fullScreenAlert: fullScreenAlert ?? this.fullScreenAlert,
      snoozeRadiusMeters: snoozeRadiusMeters ?? this.snoozeRadiusMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'alertRadiusMeters': alertRadiusMeters,
      'alarmSoundId': alarmSoundId,
      'soundSource': soundSource.name,
      'customSoundPath': customSoundPath,
      'vibrateEnabled': vibrateEnabled,
      'vibrationDurationMs': vibrationDurationMs,
      'vibrationPreDelayMs': vibrationPreDelayMs,
      'alarmVolume': alarmVolume,
      'wearableVolume': wearableVolume,
      'loopAlarm': loopAlarm,
      'fullScreenAlert': fullScreenAlert,
      'snoozeRadiusMeters': snoozeRadiusMeters,
    };
  }

  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    return AlertSettings(
      alertRadiusMeters: (json['alertRadiusMeters'] as num?)?.toDouble() ?? 500,
      alarmSoundId: json['alarmSoundId']?.toString() ?? 'freesound_community-alarm-clock-90867',
      soundSource: AlarmSoundSource.values.firstWhere(
        (AlarmSoundSource option) => option.name == json['soundSource']?.toString(),
        orElse: () => AlarmSoundSource.bundled,
      ),
      customSoundPath: json['customSoundPath']?.toString(),
      vibrateEnabled: json['vibrateEnabled'] as bool? ?? true,
      vibrationDurationMs: json['vibrationDurationMs'] as int? ?? 7000,
      vibrationPreDelayMs: json['vibrationPreDelayMs'] as int? ?? 6000,
      alarmVolume: (json['alarmVolume'] as num?)?.toDouble() ?? 0.9,
      wearableVolume: (json['wearableVolume'] as num?)?.toDouble() ?? 0.7,
      loopAlarm: json['loopAlarm'] as bool? ?? true,
      fullScreenAlert: json['fullScreenAlert'] as bool? ?? true,
      snoozeRadiusMeters: (json['snoozeRadiusMeters'] as num?)?.toDouble() ?? 500,
    );
  }
}

/// Bundled alarm tunes — filenames without extension in assets/sounds/
const List<Map<String, String>> kBundledAlarmTunes = <Map<String, String>>[
  <String, String>{'id': 'freesound_community-alarm-clock-90867', 'label': 'Classic Alarm'},
  <String, String>{'id': 'freesound_community-alarm-clock-short-6402', 'label': 'Short Alarm'},
  <String, String>{'id': 'universfield-digital-alarm-clock-151920', 'label': 'Digital Clock'},
  <String, String>{'id': 'universfield-digital-alarm-clock-02-151919', 'label': 'Digital Clock 2'},
  <String, String>{'id': 'lesiakower-oversimplified-alarm-clock-113180', 'label': 'Oversimplified'},
  <String, String>{'id': 'jeremayjimenez-philippines-eas-alarm-427006', 'label': 'Emergency Alert'},
  <String, String>{'id': 'jeremayjimenez-taiwan-eas-alarm-501825', 'label': 'Taiwan Alert'},
  <String, String>{'id': 'jeremayjimenez-austria-eas-alarm-486289', 'label': 'Austria Alert'},
  <String, String>{'id': 'gentle_chime', 'label': 'Gentle Chime'},
];