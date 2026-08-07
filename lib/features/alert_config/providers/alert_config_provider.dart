import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../data/models/alert_settings.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final alertConfigProvider = StateNotifierProvider<AlertConfigNotifier, AlertSettings>((ref) {
  return AlertConfigNotifier(ref.read(storageServiceProvider));
});

class AlertConfigNotifier extends StateNotifier<AlertSettings> {
  final StorageService _storageService;

  AlertConfigNotifier(this._storageService) : super(const AlertSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _storageService.loadAlertSettings();
  }

  Future<void> _save(AlertSettings settings) async {
    state = settings;
    await _storageService.saveAlertSettings(settings);
  }

  Future<void> setRadius(double radiusMeters) async {
    await _save(state.copyWith(alertRadiusMeters: radiusMeters));
  }

  Future<void> setSound({required String soundId, required AlarmSoundSource source, String? customPath}) async {
    await _save(state.copyWith(
      alarmSoundId: soundId,
      soundSource: source,
      customSoundPath: customPath,
    ));
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _save(state.copyWith(vibrateEnabled: enabled));
  }

  Future<void> setVibrationDuration(int durationMs) async {
    await _save(state.copyWith(vibrationDurationMs: durationMs));
  }

  Future<void> setAlarmVolume(double volume) async {
    await _save(state.copyWith(alarmVolume: volume));
  }

  Future<void> setLoopAlarm(bool enabled) async {
    await _save(state.copyWith(loopAlarm: enabled));
  }

  Future<void> setFullScreenAlert(bool enabled) async {
    await _save(state.copyWith(fullScreenAlert: enabled));
  }

  Future<void> setVibrationPreDelay(int delayMs) async {
    await _save(state.copyWith(vibrationPreDelayMs: delayMs));
  }

  Future<void> setWearableVolume(double volume) async {
    await _save(state.copyWith(wearableVolume: volume));
  }

  Future<void> setSnoozeRadius(double radiusMeters) async {
    await _save(state.copyWith(snoozeRadiusMeters: radiusMeters));
  }
}