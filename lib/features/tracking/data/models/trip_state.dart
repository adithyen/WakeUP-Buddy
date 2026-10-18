import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../../alert_config/data/models/alert_settings.dart';
import '../../../destination/data/models/destination.dart';

enum TripStatus {
  idle,
  starting,
  tracking,
  approaching,
  alerting,
  completed,
  stopped,
  error,
}

class TripState {
  final TripStatus status;
  final Destination? destination;
  final AlertSettings? alertSettings;
  final double? initialDistanceMeters;
  final double? currentDistanceMeters;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? currentSpeedMs;
  final double? gpsAccuracyMeters;
  final DateTime? lastUpdate;
  final DateTime? tripStartTime;
  final String? errorMessage;
  final List<LatLng> breadcrumbs;
  final List<LatLng> routePolyline;
  final int? routeDurationSeconds;
  final int? routeDistanceMeters;
  final bool isOffRoute;
  final bool gpsSignalLost;
  final bool gpsJustRecovered;
  final String? gpsLostMessage;

  const TripState({
    this.status = TripStatus.idle,
    this.destination,
    this.alertSettings,
    this.initialDistanceMeters,
    this.currentDistanceMeters,
    this.currentLatitude,
    this.currentLongitude,
    this.currentSpeedMs,
    this.gpsAccuracyMeters,
    this.lastUpdate,
    this.tripStartTime,
    this.errorMessage,
    this.breadcrumbs = const <LatLng>[],
    this.routePolyline = const <LatLng>[],
    this.routeDurationSeconds,
    this.routeDistanceMeters,
    this.isOffRoute = false,
    this.gpsSignalLost = false,
    this.gpsJustRecovered = false,
    this.gpsLostMessage,
  });

  bool get isActive =>
      status == TripStatus.starting ||
      status == TripStatus.tracking ||
      status == TripStatus.approaching ||
      status == TripStatus.alerting;

  /// Traffic-aware ETA: Dynamically updates as remaining distance and live speed change
  Duration? get estimatedTimeRemaining {
    if (currentDistanceMeters == null || currentDistanceMeters! <= 0) {
      return Duration.zero;
    }

    // 1. Scale route duration by remaining distance ratio
    if (routeDurationSeconds != null &&
        routeDurationSeconds! > 0 &&
        initialDistanceMeters != null &&
        initialDistanceMeters! > 0) {
      final double ratio =
          (currentDistanceMeters! / initialDistanceMeters!).clamp(0.0, 1.0);
      final double scaledRouteSeconds = routeDurationSeconds! * ratio;

      // If moving at vehicle speed (> 2.5 m/s = 9 km/h), blend live GPS speed
      if (currentSpeedMs != null && currentSpeedMs! > 2.5) {
        final double speedBasedSeconds = currentDistanceMeters! / currentSpeedMs!;
        final double blended =
            (scaledRouteSeconds * 0.6) + (speedBasedSeconds * 0.4);
        return Duration(seconds: max(1, blended.round()));
      }

      return Duration(seconds: max(1, scaledRouteSeconds.round()));
    }

    // 2. Fallback when route duration is unavailable
    final double effectiveSpeed =
        (currentSpeedMs != null && currentSpeedMs! > 1.5)
            ? currentSpeedMs!
            : 6.94;
    final double seconds = currentDistanceMeters! / effectiveSpeed;
    return Duration(seconds: max(1, seconds.round()));
  }

  double? get progress {
    if (initialDistanceMeters == null || initialDistanceMeters! <= 0 || currentDistanceMeters == null) {
      return null;
    }

    final double completed = 1 - (currentDistanceMeters! / initialDistanceMeters!);
    return completed.clamp(0.0, 1.0);
  }

  TripState copyWith({
    TripStatus? status,
    Destination? destination,
    AlertSettings? alertSettings,
    double? initialDistanceMeters,
    double? currentDistanceMeters,
    double? currentLatitude,
    double? currentLongitude,
    double? currentSpeedMs,
    double? gpsAccuracyMeters,
    DateTime? lastUpdate,
    DateTime? tripStartTime,
    String? errorMessage,
    bool clearError = false,
    List<LatLng>? breadcrumbs,
    List<LatLng>? routePolyline,
    int? routeDurationSeconds,
    int? routeDistanceMeters,
    bool? isOffRoute,
    bool? gpsSignalLost,
    bool? gpsJustRecovered,
    String? gpsLostMessage,
    bool clearGpsLostMessage = false,
  }) {
    return TripState(
      status: status ?? this.status,
      destination: destination ?? this.destination,
      alertSettings: alertSettings ?? this.alertSettings,
      initialDistanceMeters: initialDistanceMeters ?? this.initialDistanceMeters,
      currentDistanceMeters: currentDistanceMeters ?? this.currentDistanceMeters,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      tripStartTime: tripStartTime ?? this.tripStartTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      routePolyline: routePolyline ?? this.routePolyline,
      routeDurationSeconds: routeDurationSeconds ?? this.routeDurationSeconds,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      gpsSignalLost: gpsSignalLost ?? this.gpsSignalLost,
      gpsJustRecovered: gpsJustRecovered ?? this.gpsJustRecovered,
      gpsLostMessage: clearGpsLostMessage ? null : (gpsLostMessage ?? this.gpsLostMessage),
    );
  }
}