import 'package:latlong2/latlong.dart';

/// A single route returned by the Ola Maps Directions API.
class RouteOption {
  final int index;
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> polylinePoints;
  final String summary;
  final List<RouteStep> steps;

  const RouteOption({
    required this.index,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polylinePoints,
    required this.summary,
    required this.steps,
  });

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceMeters m';
  }

  String get durationText {
    final int minutes = (durationSeconds / 60).round();
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int mins  = minutes % 60;
      return mins > 0 ? '$hours h $mins min' : '$hours h';
    }
    return '$minutes min';
  }

  RouteOption copyWith({int? distanceMeters, int? durationSeconds}) {
    return RouteOption(
      index: index,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      polylinePoints: polylinePoints,
      summary: summary,
      steps: steps,
    );
  }
}

/// A single navigation step within a route leg.
class RouteStep {
  final String instruction;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
  });
}
