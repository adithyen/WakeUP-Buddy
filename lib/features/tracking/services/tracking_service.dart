import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../background/location_task_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../alert_config/data/models/alert_settings.dart';
import '../../destination/data/models/destination.dart';

class TrackingService {
  static const String stopButtonId = 'stop_tracking';
  static const String tripActiveKey = 'trip_active';
  static const String destinationIdKey = 'destination_id';
  static const String destinationNameKey = 'destination_name';
  static const String destinationDescriptionKey = 'destination_description';
  static const String destinationLatitudeKey = 'destination_latitude';
  static const String destinationLongitudeKey = 'destination_longitude';
  static const String destinationSourceKey = 'destination_source';
  static const String alertRadiusKey = 'alert_radius_meters';
  static const String alertSoundIdKey = 'alert_sound_id';
  static const String alertSoundSourceKey = 'alert_sound_source';
  static const String alertCustomSoundPathKey = 'alert_custom_sound_path';
  static const String alertVibrateEnabledKey = 'alert_vibrate_enabled';
  static const String alertVibrationDurationKey = 'alert_vibration_duration_ms';
  static const String alertVibrationPreDelayKey = 'alert_vibration_pre_delay_ms';
  static const String alertVolumeKey = 'alert_volume';
  static const String alertWearableVolumeKey = 'alert_wearable_volume';
  static const String alertLoopKey = 'alert_loop';
  static const String alertFullScreenKey = 'alert_full_screen';
  static const String alertSnoozeRadiusKey = 'alert_snooze_radius_meters';
  static const String tripStartedAtKey = 'trip_started_at_ms';

  static const int serviceId = 256;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'wakeup_buddy_tracking',
        channelName: 'Trip Tracking',
        channelDescription: 'Tracks distance to your selected destination',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(AppConstants.locationUpdateInterval.inMilliseconds),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> startTracking({
    required Destination destination,
    required AlertSettings alertSettings,
  }) async {
    await _saveTripData(destination: destination, alertSettings: alertSettings);

    final ServiceRequestResult result = await FlutterForegroundTask.startService(
      serviceId: serviceId,
      notificationTitle: 'Tracking to ${destination.name}',
      notificationText: 'Calculating distance...',
      notificationButtons: const <NotificationButton>[
        NotificationButton(
          id: stopButtonId,
          text: 'Stop Tracking',
        ),
      ],
      callback: startLocationTaskCallback,
    );

    return result is ServiceRequestSuccess;
  }

  static Future<bool> stopTracking() async {
    await clearTripData();

    final bool isRunning = await isTrackingActive();
    if (!isRunning) {
      return true;
    }

    final ServiceRequestResult result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  static Future<bool> isTrackingActive() async {
    return FlutterForegroundTask.isRunningService;
  }

  static Future<void> clearTripData() async {
    await FlutterForegroundTask.removeData(key: tripActiveKey);
    await FlutterForegroundTask.removeData(key: destinationIdKey);
    await FlutterForegroundTask.removeData(key: destinationNameKey);
    await FlutterForegroundTask.removeData(key: destinationDescriptionKey);
    await FlutterForegroundTask.removeData(key: destinationLatitudeKey);
    await FlutterForegroundTask.removeData(key: destinationLongitudeKey);
    await FlutterForegroundTask.removeData(key: destinationSourceKey);
    await FlutterForegroundTask.removeData(key: alertRadiusKey);
    await FlutterForegroundTask.removeData(key: alertSoundIdKey);
    await FlutterForegroundTask.removeData(key: alertSoundSourceKey);
    await FlutterForegroundTask.removeData(key: alertCustomSoundPathKey);
    await FlutterForegroundTask.removeData(key: alertVibrateEnabledKey);
    await FlutterForegroundTask.removeData(key: alertVibrationDurationKey);
    await FlutterForegroundTask.removeData(key: alertVibrationPreDelayKey);
    await FlutterForegroundTask.removeData(key: alertVolumeKey);
    await FlutterForegroundTask.removeData(key: alertWearableVolumeKey);
    await FlutterForegroundTask.removeData(key: alertLoopKey);
    await FlutterForegroundTask.removeData(key: alertFullScreenKey);
    await FlutterForegroundTask.removeData(key: alertSnoozeRadiusKey);
    await FlutterForegroundTask.removeData(key: tripStartedAtKey);
  }

  static Future<void> _saveTripData({
    required Destination destination,
    required AlertSettings alertSettings,
  }) async {
    await FlutterForegroundTask.saveData(key: tripActiveKey, value: true);
    await FlutterForegroundTask.saveData(key: destinationIdKey, value: destination.id);
    await FlutterForegroundTask.saveData(key: destinationNameKey, value: destination.name);
    await FlutterForegroundTask.saveData(key: destinationDescriptionKey, value: destination.description ?? '');
    await FlutterForegroundTask.saveData(key: destinationLatitudeKey, value: destination.latitude);
    await FlutterForegroundTask.saveData(key: destinationLongitudeKey, value: destination.longitude);
    await FlutterForegroundTask.saveData(key: destinationSourceKey, value: destination.source.name);
    await FlutterForegroundTask.saveData(key: alertRadiusKey, value: alertSettings.alertRadiusMeters);
    await FlutterForegroundTask.saveData(key: alertSoundIdKey, value: alertSettings.alarmSoundId);
    await FlutterForegroundTask.saveData(key: alertSoundSourceKey, value: alertSettings.soundSource.name);
    await FlutterForegroundTask.saveData(
      key: alertCustomSoundPathKey,
      value: alertSettings.customSoundPath ?? '',
    );
    await FlutterForegroundTask.saveData(key: alertVibrateEnabledKey, value: alertSettings.vibrateEnabled);
    await FlutterForegroundTask.saveData(key: alertVibrationDurationKey, value: alertSettings.vibrationDurationMs);
    await FlutterForegroundTask.saveData(key: alertVibrationPreDelayKey, value: alertSettings.vibrationPreDelayMs);
    await FlutterForegroundTask.saveData(key: alertVolumeKey, value: alertSettings.alarmVolume);
    await FlutterForegroundTask.saveData(key: alertWearableVolumeKey, value: alertSettings.wearableVolume);
    await FlutterForegroundTask.saveData(key: alertLoopKey, value: alertSettings.loopAlarm);
    await FlutterForegroundTask.saveData(key: alertFullScreenKey, value: alertSettings.fullScreenAlert);
    await FlutterForegroundTask.saveData(key: alertSnoozeRadiusKey, value: alertSettings.snoozeRadiusMeters);
    await FlutterForegroundTask.saveData(key: tripStartedAtKey, value: DateTime.now().millisecondsSinceEpoch);
  }
}