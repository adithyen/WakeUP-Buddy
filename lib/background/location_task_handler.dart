import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../features/tracking/services/tracking_service.dart';

@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  double _destinationLatitude = 0;
  double _destinationLongitude = 0;
  String _destinationName = 'your destination';
  double _alertRadiusMeters = 500;
  bool _alertTriggered = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _destinationLatitude = await FlutterForegroundTask.getData<double>(key: TrackingService.destinationLatitudeKey) ?? 0;
    _destinationLongitude = await FlutterForegroundTask.getData<double>(key: TrackingService.destinationLongitudeKey) ?? 0;
    _destinationName = await FlutterForegroundTask.getData<String>(key: TrackingService.destinationNameKey) ?? 'your destination';
    _alertRadiusMeters = await FlutterForegroundTask.getData<double>(key: TrackingService.alertRadiusKey) ?? 500;

    // Immediately do a first check on start (don't wait for first repeat tick)
    unawaited(_handleRepeatEvent());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_handleRepeatEvent());
  }

  Future<void> _handleRepeatEvent() async {
    if (_alertTriggered) return;

    try {
      // Request fresh high-accuracy position fix every cycle
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) return;

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _destinationLatitude,
        _destinationLongitude,
      );

      // INSTANT trigger — fire on first detection, no debounce delay
      if (distance <= _alertRadiusMeters && !_alertTriggered) {
        _alertTriggered = true;
        FlutterForegroundTask.sendDataToMain(<String, Object?>{
          'type': 'ALERT_TRIGGERED',
          'distance': distance,
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
      }

      await FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking to $_destinationName',
        notificationText: '${_formatDistance(distance)} remaining',
      );

      FlutterForegroundTask.sendDataToMain(<String, Object?>{
        'type': 'LOCATION_UPDATE',
        'distance': distance,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
      });
    } catch (error) {
      FlutterForegroundTask.sendDataToMain(<String, Object?>{
        'type': 'GPS_ERROR',
        'error': error.toString(),
      });

      await FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking to $_destinationName',
        notificationText: 'GPS signal lost - retrying...',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _alertTriggered = false;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == TrackingService.stopButtonId) {
      FlutterForegroundTask.sendDataToMain(<String, Object?>{
        'type': 'STOP_REQUESTED',
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}