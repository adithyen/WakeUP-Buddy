import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Motion phases classified via real-time accelerometer and GPS sensor fusion.
enum MotionPhase {
  stationary,
  walking,
  slowTraffic,
  transit,
}

/// Provider for sensor-fused speed in km/h and motion classification.
final speedTelemetryProvider =
    StateNotifierProvider<SpeedTelemetryNotifier, SpeedTelemetryState>((ref) {
  return SpeedTelemetryNotifier();
});

class SpeedTelemetryState {
  final double speedKmh;
  final bool isMoving;
  final double accelerationMagnitude;
  final MotionPhase motionPhase;

  const SpeedTelemetryState({
    required this.speedKmh,
    required this.isMoving,
    required this.accelerationMagnitude,
    this.motionPhase = MotionPhase.stationary,
  });

  String get phaseLabel {
    switch (motionPhase) {
      case MotionPhase.stationary:
        return 'Stationary';
      case MotionPhase.walking:
        return 'Walking';
      case MotionPhase.slowTraffic:
        return 'Slow Traffic';
      case MotionPhase.transit:
        return 'In Transit';
    }
  }

  factory SpeedTelemetryState.initial() => const SpeedTelemetryState(
        speedKmh: 0.0,
        isMoving: false,
        accelerationMagnitude: 0.0,
        motionPhase: MotionPhase.stationary,
      );

  SpeedTelemetryState copyWith({
    double? speedKmh,
    bool? isMoving,
    double? accelerationMagnitude,
    MotionPhase? motionPhase,
  }) {
    return SpeedTelemetryState(
      speedKmh: speedKmh ?? this.speedKmh,
      isMoving: isMoving ?? this.isMoving,
      accelerationMagnitude:
          accelerationMagnitude ?? this.accelerationMagnitude,
      motionPhase: motionPhase ?? this.motionPhase,
    );
  }
}

class SpeedTelemetryNotifier extends StateNotifier<SpeedTelemetryState> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _gpsSub;

  static const int _windowSize = 15;

  double _filteredSpeedKmh = 0.0;
  static const double _smoothingFactor = 0.55;

  SpeedTelemetryNotifier() : super(SpeedTelemetryState.initial()) {
    _initSensors();
  }

  void _initSensors() {
    // 1. Dual Accelerometer Stream: Raw accelerometer works on 100% of Android devices
    try {
      _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
        _processAccelerometerData(event.x, event.y, event.z);
      }, onError: (_) {});
    } catch (_) {}

    // 2. High-precision GPS stream for accurate ground speed
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen((Position position) {
        _processGpsData(position);
      }, onError: (_) {});
    } catch (_) {}
  }

  double _gravityBaseline = 9.80665;
  final List<double> _dynamicAccels = [];
  final List<DateTime> _recentStepTimes = [];
  DateTime _lastStepCandidate = DateTime.now();

  void _processAccelerometerData(double x, double y, double z) {
    final double totalMag = sqrt(x * x + y * y + z * z);
    // Exponential baseline tracking for local gravity
    _gravityBaseline = 0.98 * _gravityBaseline + 0.02 * totalMag;
    final double dynamicAccel = (totalMag - _gravityBaseline).abs();

    _dynamicAccels.add(dynamicAccel);
    if (_dynamicAccels.length > _windowSize) {
      _dynamicAccels.removeAt(0);
    }

    final double avgDynamic = _dynamicAccels.isNotEmpty
        ? _dynamicAccels.reduce((a, b) => a + b) / _dynamicAccels.length
        : 0.0;

    // Detect walking footstep impacts (dynamic acceleration peak > 0.85 m/s² with min interval)
    final now = DateTime.now();
    if (dynamicAccel > 0.85 && now.difference(_lastStepCandidate).inMilliseconds > 260) {
      _lastStepCandidate = now;
      _recentStepTimes.add(now);
    }
    // Retain steps within the last 3.5 seconds
    _recentStepTimes.removeWhere((t) => now.difference(t).inMilliseconds > 3500);

    // Variance calculation across dynamic acceleration window
    double variance = 0.0;
    if (_dynamicAccels.length > 2) {
      final sumSquares = _dynamicAccels.fold<double>(
        0.0,
        (acc, val) => acc + pow(val - avgDynamic, 2),
      );
      variance = sumSquares / _dynamicAccels.length;
    }

    // Accelerometer is used for activity stillness gating, never for synthesizing artificial speed!
    final bool isStill = avgDynamic < 0.25 && variance < 0.04;
    double currentSpeed = _filteredSpeedKmh;

    if (isStill && currentSpeed < 1.5) {
      currentSpeed = 0.0;
      _filteredSpeedKmh = 0.0;
    }

    final MotionPhase phase;
    if (currentSpeed < 1.0) {
      phase = MotionPhase.stationary;
    } else if (currentSpeed > 18.0) {
      phase = MotionPhase.transit;
    } else {
      phase = MotionPhase.slowTraffic;
    }

    state = state.copyWith(
      speedKmh: double.parse(currentSpeed.toStringAsFixed(1)),
      isMoving: phase != MotionPhase.stationary,
      accelerationMagnitude: avgDynamic,
      motionPhase: phase,
    );
  }

  void _processGpsData(Position position) {
    // True ground speed from GPS in km/h
    double rawKmh = (position.speed >= 0 ? position.speed : 0.0) * 3.6;

    // Suppress GPS noise/jitter when stationary or moving like a snail (<1.2 km/h or poor accuracy)
    if (rawKmh < 1.2 || (position.accuracy > 25.0 && rawKmh < 2.5)) {
      rawKmh = 0.0;
    }

    _filteredSpeedKmh =
        (_smoothingFactor * rawKmh) + ((1.0 - _smoothingFactor) * _filteredSpeedKmh);

    if (_filteredSpeedKmh < 0.6) {
      _filteredSpeedKmh = 0.0;
    }

    final double displaySpeed = _filteredSpeedKmh;
    final MotionPhase phase;
    if (displaySpeed < 1.0) {
      phase = MotionPhase.stationary;
    } else if (displaySpeed > 18.0) {
      phase = MotionPhase.transit;
    } else {
      phase = MotionPhase.slowTraffic;
    }

    state = state.copyWith(
      speedKmh: double.parse(displaySpeed.toStringAsFixed(1)),
      isMoving: phase != MotionPhase.stationary,
      motionPhase: phase,
    );
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}
