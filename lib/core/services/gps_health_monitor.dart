import 'package:geolocator/geolocator.dart';

/// Tracks GPS signal health: categorises quality, detects staleness, and
/// rejects physically-impossible position jumps (GPS spikes).
class GpsHealthMonitor {
  static const Duration _staleThreshold = Duration(seconds: 30);
  static const double _maxSpeedMps = 55.6; // ~200 km/h (fast train)
  static const double _maxAccuracyMeters = 100;

  DateTime? _lastSuccessfulFix;
  int _consecutiveFailures = 0;
  Position? _lastValidPosition;

  /// Evaluates [position] for quality and spike rejection.
  /// Returns [GpsSignalQuality.lost] for `null` positions.
  GpsSignalQuality assess(Position? position) {
    if (position == null) {
      _consecutiveFailures++;
      return GpsSignalQuality.lost;
    }

    // Reject GPS spikes
    if (_lastValidPosition != null) {
      final double dist = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final int timeDiffSeconds = position.timestamp
          .difference(_lastValidPosition!.timestamp)
          .inSeconds;
      if (timeDiffSeconds > 0 && dist / timeDiffSeconds > _maxSpeedMps) {
        // GPS spike — reject and treat as stale
        _consecutiveFailures++;
        return GpsSignalQuality.poor;
      }
    }

    _lastSuccessfulFix = DateTime.now();
    _consecutiveFailures = 0;
    _lastValidPosition = position;

    final double accuracy = position.accuracy;
    if (accuracy > _maxAccuracyMeters) return GpsSignalQuality.poor;
    if (accuracy > 50) return GpsSignalQuality.fair;
    if (accuracy > 20) return GpsSignalQuality.good;
    return GpsSignalQuality.excellent;
  }

  bool get isStale =>
      _lastSuccessfulFix == null ||
      DateTime.now().difference(_lastSuccessfulFix!) > _staleThreshold;

  bool get shouldShowWarning => _consecutiveFailures >= 3;
  bool get isCritical => _consecutiveFailures >= 5;

  void reset() {
    _lastSuccessfulFix = null;
    _consecutiveFailures = 0;
    _lastValidPosition = null;
  }
}

enum GpsSignalQuality { excellent, good, fair, poor, lost }

// ─────────────────────────────────────────────────────────────────────────────
// Overshoot Detector
// ─────────────────────────────────────────────────────────────────────────────

/// Detects when a user has passed (overshot) their destination stop.
class OvershootDetector {
  double? _minDistanceReached;
  bool _wasInRadius = false;
  bool _hasExitedRadius = false;

  OvershootResult check(double currentDistanceM, double alertRadiusM) {
    if (_minDistanceReached == null ||
        currentDistanceM < _minDistanceReached!) {
      _minDistanceReached = currentDistanceM;
    }

    if (currentDistanceM <= alertRadiusM) {
      _wasInRadius = true;
    }

    // Was in radius, now outside — started exiting
    if (_wasInRadius && currentDistanceM > alertRadiusM) {
      _hasExitedRadius = true;
    }

    // Still moving away — 500m past min reached
    if (_hasExitedRadius &&
        currentDistanceM > (_minDistanceReached ?? 0) + 500) {
      return OvershootResult.confirmed;
    }

    if (_hasExitedRadius) return OvershootResult.exiting;
    return OvershootResult.none;
  }

  void reset() {
    _minDistanceReached = null;
    _wasInRadius = false;
    _hasExitedRadius = false;
  }
}

enum OvershootResult { none, exiting, confirmed }
