import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../alert_config/data/models/alert_settings.dart';
import '../../destination/data/models/destination.dart';
import '../../destination/data/models/place_suggestion.dart';
import '../data/models/trip_state.dart';
import '../services/tracking_service.dart';

final trackingProvider = StateNotifierProvider<TrackingNotifier, TripState>((ref) {
  return TrackingNotifier();
});

class TrackingNotifier extends StateNotifier<TripState> {
  TrackingNotifier() : super(const TripState()) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    unawaited(_restoreActiveTrip());
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<bool> startTrip(Destination destination, AlertSettings alertSettings) async {
    if (state.isActive) {
      return true;
    }

    state = TripState(
      status: TripStatus.starting,
      destination: destination,
      alertSettings: alertSettings,
      tripStartTime: DateTime.now(),
    );

    final bool started = await TrackingService.startTracking(
      destination: destination,
      alertSettings: alertSettings,
    );

    if (!started) {
      state = state.copyWith(
        status: TripStatus.error,
        errorMessage: 'Failed to start tracking service.',
      );
      return false;
    }

    state = state.copyWith(status: TripStatus.tracking, clearError: true);
    return true;
  }

  Future<bool> stopTrip() async {
    final bool stopped = await TrackingService.stopTracking();
    if (stopped) {
      state = state.copyWith(status: TripStatus.stopped, clearError: true);
    } else {
      state = state.copyWith(
        status: TripStatus.error,
        errorMessage: 'Failed to stop tracking service.',
      );
    }

    return stopped;
  }

  void _onTaskData(Object data) {
    if (data is! Map) {
      return;
    }

    final String? type = data['type'] as String?;
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
        unawaited(stopTrip());
        break;
      default:
        break;
    }
  }

  void _handleLocationUpdate(Map data) {
    final double? distance = _toDouble(data['distance']);
    final double? latitude = _toDouble(data['latitude']);
    final double? longitude = _toDouble(data['longitude']);
    final double? speed = _toDouble(data['speed']);
    final double? accuracy = _toDouble(data['accuracy']);
    final DateTime? timestamp = _toDateTime(data['timestamp']);

    if (distance == null || latitude == null || longitude == null) {
      return;
    }

    final double alertRadius = state.alertSettings?.alertRadiusMeters ?? 500;
    final TripStatus nextStatus = distance <= alertRadius * 2
        ? TripStatus.approaching
        : TripStatus.tracking;

    final List<LatLng> breadcrumbs = <LatLng>[
      ...state.breadcrumbs,
      LatLng(latitude, longitude),
    ];

    state = state.copyWith(
      status: nextStatus,
      currentDistanceMeters: distance,
      initialDistanceMeters: state.initialDistanceMeters ?? distance,
      currentLatitude: latitude,
      currentLongitude: longitude,
      currentSpeedMs: speed,
      gpsAccuracyMeters: accuracy,
      lastUpdate: timestamp ?? DateTime.now(),
      breadcrumbs: breadcrumbs.length > 200
          ? breadcrumbs.sublist(breadcrumbs.length - 200)
          : breadcrumbs,
      clearError: true,
    );
  }

  void _handleAlertTriggered(Map data) {
    final double? distance = _toDouble(data['distance']);
    final double? latitude = _toDouble(data['latitude']);
    final double? longitude = _toDouble(data['longitude']);

    state = state.copyWith(
      status: TripStatus.alerting,
      currentDistanceMeters: distance ?? state.currentDistanceMeters,
      currentLatitude: latitude ?? state.currentLatitude,
      currentLongitude: longitude ?? state.currentLongitude,
      clearError: true,
    );
  }

  void _handleGpsError(Map data) {
    state = state.copyWith(
      status: TripStatus.error,
      errorMessage: data['error']?.toString() ?? 'GPS signal lost.',
    );
  }

  Future<void> _restoreActiveTrip() async {
    final bool serviceRunning = await TrackingService.isTrackingActive();
    if (!serviceRunning) {
      return;
    }

    final Map<String, Object> data = await FlutterForegroundTask.getAllData();
    if (data[TrackingService.tripActiveKey] != true) {
      return;
    }

    final Destination? destination = _destinationFromData(data);
    final AlertSettings? alertSettings = _alertSettingsFromData(data);
    if (destination == null || alertSettings == null) {
      return;
    }

    state = TripState(
      status: TripStatus.tracking,
      destination: destination,
      alertSettings: alertSettings,
      tripStartTime: _toDateTime(data[TrackingService.tripStartedAtKey]) ?? DateTime.now(),
    );
  }

  Destination? _destinationFromData(Map<String, Object> data) {
    final String? id = data[TrackingService.destinationIdKey]?.toString();
    final String? name = data[TrackingService.destinationNameKey]?.toString();
    final double? latitude = _toDouble(data[TrackingService.destinationLatitudeKey]);
    final double? longitude = _toDouble(data[TrackingService.destinationLongitudeKey]);
    final String? sourceName = data[TrackingService.destinationSourceKey]?.toString();

    if (id == null || name == null || latitude == null || longitude == null || sourceName == null) {
      return null;
    }

    final String? description = data[TrackingService.destinationDescriptionKey]?.toString();

    return Destination(
      id: id,
      name: name,
      description: description == null || description.isEmpty ? null : description,
      latitude: latitude,
      longitude: longitude,
      selectedAt: DateTime.now(),
      source: PlaceSource.values.firstWhere(
        (PlaceSource option) => option.name == sourceName,
        orElse: () => PlaceSource.nominatim,
      ),
    );
  }

  AlertSettings? _alertSettingsFromData(Map<String, Object> data) {
    final double? radius = _toDouble(data[TrackingService.alertRadiusKey]);
    final String? soundSource = data[TrackingService.alertSoundSourceKey]?.toString();

    if (radius == null) {
      return null;
    }

    return AlertSettings(
      alertRadiusMeters: radius,
      alarmSoundId: data[TrackingService.alertSoundIdKey]?.toString() ?? 'freesound_community-alarm-clock-90867',
      soundSource: AlarmSoundSource.values.firstWhere(
        (AlarmSoundSource option) => option.name == soundSource,
        orElse: () => AlarmSoundSource.bundled,
      ),
      customSoundPath: data[TrackingService.alertCustomSoundPathKey]?.toString(),
      vibrateEnabled: data[TrackingService.alertVibrateEnabledKey] as bool? ?? true,
      vibrationDurationMs: (data[TrackingService.alertVibrationDurationKey] as num?)?.toInt() ?? 7000,
      vibrationPreDelayMs: (data[TrackingService.alertVibrationPreDelayKey] as num?)?.toInt() ?? 6000,
      alarmVolume: _toDouble(data[TrackingService.alertVolumeKey]) ?? 0.9,
      wearableVolume: _toDouble(data[TrackingService.alertWearableVolumeKey]) ?? 0.7,
      loopAlarm: data[TrackingService.alertLoopKey] as bool? ?? true,
      fullScreenAlert: data[TrackingService.alertFullScreenKey] as bool? ?? true,
      snoozeRadiusMeters: _toDouble(data[TrackingService.alertSnoozeRadiusKey]) ?? 500,
    );
  }

  double? _toDouble(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  DateTime? _toDateTime(Object? value) {
    final int? milliseconds = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (milliseconds == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}