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
    this.gpsSignalLost = false,
    this.gpsJustRecovered = false,
    this.gpsLostMessage,
  });

  bool get isActive =>
      status == TripStatus.starting ||
      status == TripStatus.tracking ||
      status == TripStatus.approaching ||
      status == TripStatus.alerting;

  Duration? get estimatedTimeRemaining {
    if (currentDistanceMeters == null || currentSpeedMs == null || currentSpeedMs! <= 0) {
      return null;
    }

    final double seconds = currentDistanceMeters! / currentSpeedMs!;
    return Duration(seconds: seconds.round());
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
      gpsSignalLost: gpsSignalLost ?? this.gpsSignalLost,
      gpsJustRecovered: gpsJustRecovered ?? this.gpsJustRecovered,
      gpsLostMessage: clearGpsLostMessage ? null : (gpsLostMessage ?? this.gpsLostMessage),
    );
  }
}