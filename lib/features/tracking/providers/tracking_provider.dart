import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/ola_maps_service.dart';
import '../../alert_config/data/models/alert_settings.dart';
import '../../destination/data/models/destination.dart';
import '../../destination/data/models/place_suggestion.dart';
import '../data/models/trip_state.dart';
import '../services/tracking_service.dart';

final trackingProvider = StateNotifierProvider<TrackingNotifier, TripState>((ref) {
  final olaService = ref.watch(olaMapsServiceProvider);
  return TrackingNotifier(olaService: olaService);
});

class TrackingNotifier extends StateNotifier<TripState> {
  final OlaMapsService _olaService;
  DateTime? _lastRerouteTime;
  bool _isRerouting = false;

  TrackingNotifier({required OlaMapsService olaService})
      : _olaService = olaService,
        super(const TripState()) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    unawaited(_restoreActiveTrip());
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<bool> startTrip(
    Destination destination,
    AlertSettings alertSettings, {
    OlaRoute? chosenRoute,
  }) async {
    if (state.isActive) {
      return true;
    }

    state = TripState(
      status: TripStatus.starting,
      destination: destination,
      alertSettings: alertSettings,
      tripStartTime: DateTime.now(),
      routePolyline: chosenRoute?.polyline ?? const [],
      routeDurationSeconds: chosenRoute?.durationSeconds,
      routeDistanceMeters: chosenRoute?.distanceMeters,
      initialDistanceMeters: chosenRoute?.distanceMeters.toDouble(),
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
    final double? rawDistance = _toDouble(data['distance']);
    final double? latitude = _toDouble(data['latitude']);
    final double? longitude = _toDouble(data['longitude']);
    final double? speed = _toDouble(data['speed']);
    final double? accuracy = _toDouble(data['accuracy']);
    final DateTime? timestamp = _toDateTime(data['timestamp']);

    if (rawDistance == null || latitude == null || longitude == null) {
      return;
    }

    final currentPos = LatLng(latitude, longitude);

    // 1. Calculate route-based remaining distance
    double effectiveDistance = rawDistance;
    if (state.routePolyline.isNotEmpty) {
      effectiveDistance = _calculateRemainingRouteDistance(currentPos, state.routePolyline);

      // 2. Off-route / bus diversion check
      _checkAndRerouteIfDiverted(currentPos);
    }

    final double alertRadius = state.alertSettings?.alertRadiusMeters ?? 500;
    final TripStatus nextStatus;
    if (effectiveDistance <= alertRadius) {
      nextStatus = TripStatus.alerting;
    } else if (effectiveDistance <= alertRadius * 2) {
      nextStatus = TripStatus.approaching;
    } else {
      nextStatus = TripStatus.tracking;
    }

    final List<LatLng> breadcrumbs = <LatLng>[
      ...state.breadcrumbs,
      currentPos,
    ];

    state = state.copyWith(
      status: nextStatus,
      currentDistanceMeters: effectiveDistance,
      initialDistanceMeters: state.initialDistanceMeters ?? effectiveDistance,
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

  double _calculateRemainingRouteDistance(LatLng current, List<LatLng> polyline) {
    if (polyline.isEmpty) return 0.0;
    if (polyline.length == 1) {
      return const Distance().as(LengthUnit.Meter, current, polyline.first);
    }

    const dist = Distance();
    int closestIdx = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < polyline.length; i++) {
      final d = dist.as(LengthUnit.Meter, current, polyline[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIdx = i;
      }
    }

    double total = dist.as(LengthUnit.Meter, current, polyline[closestIdx]);
    for (int i = closestIdx; i < polyline.length - 1; i++) {
      total += dist.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
    }
    return total;
  }

  void _checkAndRerouteIfDiverted(LatLng currentPos) {
    if (_isRerouting || state.destination == null) return;

    final dest = LatLng(state.destination!.latitude, state.destination!.longitude);
    const dist = Distance();

    // Check distance to closest polyline vertex
    double minVertexDist = double.infinity;
    for (final pt in state.routePolyline) {
      final d = dist.as(LengthUnit.Meter, currentPos, pt);
      if (d < minVertexDist) {
        minVertexDist = d;
      }
    }

    // If diverged by more than 75m, trigger dynamic rerouting
    if (minVertexDist > 75.0) {
      final now = DateTime.now();
      if (_lastRerouteTime == null || now.difference(_lastRerouteTime!).inSeconds > 15) {
        _lastRerouteTime = now;
        _performDynamicReroute(currentPos, dest);
      }
    }
  }

  Future<void> _performDynamicReroute(LatLng currentPos, LatLng destination) async {
    _isRerouting = true;
    try {
      final routes = await _olaService.getDirections(
        origin: currentPos,
        destination: destination,
        alternatives: false,
      );

      if (routes.isNotEmpty) {
        final newRoute = routes.first;
        state = state.copyWith(
          routePolyline: newRoute.polyline,
          routeDurationSeconds: newRoute.durationSeconds,
          routeDistanceMeters: newRoute.distanceMeters,
          isOffRoute: false,
        );
      }
    } catch (_) {
      state = state.copyWith(isOffRoute: true);
    } finally {
      _isRerouting = false;
    }
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
        (PlaceSource s) => s.name == sourceName,
        orElse: () => PlaceSource.ola,
      ),
    );
  }

  AlertSettings? _alertSettingsFromData(Map<String, Object> data) {
    final double? radius = _toDouble(data[TrackingService.alertRadiusKey]);
    final String? soundId = data[TrackingService.alertSoundIdKey]?.toString();
    final String? soundSource = data[TrackingService.alertSoundSourceKey]?.toString();
    final String? customPath = data[TrackingService.alertCustomSoundPathKey]?.toString();
    final bool? vibrate = data[TrackingService.alertVibrateEnabledKey] as bool?;

    return AlertSettings(
      alertRadiusMeters: radius ?? 500,
      alarmSoundId: soundId ?? 'freesound_community-alarm-clock-90867',
      soundSource: AlarmSoundSource.values.firstWhere(
        (e) => e.name == soundSource,
        orElse: () => AlarmSoundSource.bundled,
      ),
      customSoundPath: customPath,
      vibrateEnabled: vibrate ?? true,
    );
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? _toDateTime(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}