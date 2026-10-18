import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Provider for sensor-fused speed in km/h.
/// Provides smooth walking (1-5 km/h) and commute speed telemetry,
/// filtering out stationary GPS jitter (< 0.6 km/h) without suppressing real human walking.
final speedTelemetryProvider =
    StateNotifierProvider<SpeedTelemetryNotifier, SpeedTelemetryState>((ref) {
  return SpeedTelemetryNotifier();
});

class SpeedTelemetryState {
  final double speedKmh;
  final bool isMoving;
  final double accelerationMagnitude;

  const SpeedTelemetryState({
    required this.speedKmh,
    required this.isMoving,
    required this.accelerationMagnitude,
  });

  factory SpeedTelemetryState.initial() => const SpeedTelemetryState(
        speedKmh: 0.0,
        isMoving: false,
        accelerationMagnitude: 0.0,
      );

  SpeedTelemetryState copyWith({
    double? speedKmh,
    bool? isMoving,
    double? accelerationMagnitude,
  }) {
    return SpeedTelemetryState(
      speedKmh: speedKmh ?? this.speedKmh,
      isMoving: isMoving ?? this.isMoving,
      accelerationMagnitude: accelerationMagnitude ?? this.accelerationMagnitude,
    );
  }
}

class SpeedTelemetryNotifier extends StateNotifier<SpeedTelemetryState> {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _gpsSub;

  final List<double> _recentMagnitudes = [];
  static const int _windowSize = 12;
  static const double _stationaryThreshold = 0.08; // m/s^2 - truly sitting still

  double _filteredSpeedKmh = 0.0;
  static const double _smoothingFactor = 0.55; // Quick responsive smoothing

  SpeedTelemetryNotifier() : super(SpeedTelemetryState.initial()) {
    _initSensors();
  }

  void _initSensors() {
    // 1. User accelerometer monitors motion activity (walking stride dynamics)
    try {
      _accelSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
        final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        _recentMagnitudes.add(mag);
        if (_recentMagnitudes.length > _windowSize) {
          _recentMagnitudes.removeAt(0);
        }

        final avgMag = _recentMagnitudes.isNotEmpty
            ? _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length
            : 0.0;

        final bool moving = avgMag > _stationaryThreshold;

        // When truly resting on a flat surface and filtered speed is already negligible, settle to 0
        if (!moving && _filteredSpeedKmh < 0.6) {
          _filteredSpeedKmh = 0.0;
          state = state.copyWith(
            speedKmh: 0.0,
            isMoving: false,
            accelerationMagnitude: avgMag,
          );
        } else {
          state = state.copyWith(
            isMoving: moving,
            accelerationMagnitude: avgMag,
          );
        }
      }, onError: (_) {});
    } catch (_) {}

    // 2. High-precision GPS stream for accurate walking and transit speed
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1, // 1 meter resolution captures walking cadence
        ),
      ).listen((Position position) {
        double rawKmh = (position.speed >= 0 ? position.speed : 0.0) * 3.6;

        // Noise floor cutoff: stationary table drift is typically < 0.5 km/h
        if (rawKmh < 0.5 && !state.isMoving) {
          rawKmh = 0.0;
        }

        // Low-pass exponential moving average filter
        _filteredSpeedKmh =
            (_smoothingFactor * rawKmh) + ((1.0 - _smoothingFactor) * _filteredSpeedKmh);

        if (_filteredSpeedKmh < 0.4) {
          _filteredSpeedKmh = 0.0;
        }

        final double displaySpeed = double.parse(_filteredSpeedKmh.toStringAsFixed(1));

        state = state.copyWith(
          speedKmh: displaySpeed,
          isMoving: displaySpeed > 0.0 || state.isMoving,
        );
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}
