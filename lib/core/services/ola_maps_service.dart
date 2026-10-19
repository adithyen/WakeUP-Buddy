import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../constants/api_constants.dart';
import 'map_api_key_provider.dart';

/// Models for Ola Maps APIs

class OlaPlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String description;
  final double? latitude;
  final double? longitude;
  final List<String> types;

  const OlaPlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.description,
    this.latitude,
    this.longitude,
    this.types = const [],
  });

  factory OlaPlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    final lat = location?['lat'] is num ? (location!['lat'] as num).toDouble() : null;
    final lng = location?['lng'] is num ? (location!['lng'] as num).toDouble() : null;

    final rawTypes = json['types'] as List<dynamic>?;
    final typesList = rawTypes?.map((e) => e.toString()).toList() ?? <String>[];

    return OlaPlaceSuggestion(
      placeId: json['place_id']?.toString() ?? '',
      mainText: structured?['main_text']?.toString() ?? json['description']?.toString() ?? '',
      secondaryText: structured?['secondary_text']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      types: typesList,
    );
  }
}

class OlaRouteStep {
  final String instructions;
  final String maneuver;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;

  const OlaRouteStep({
    required this.instructions,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
  });

  factory OlaRouteStep.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'] as Map<String, dynamic>? ?? {};
    final endLoc = json['end_location'] as Map<String, dynamic>? ?? {};

    return OlaRouteStep(
      instructions: json['instructions']?.toString() ?? '',
      maneuver: json['maneuver']?.toString() ?? '',
      distanceMeters: (json['distance'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      startLocation: LatLng(
        (startLoc['lat'] as num?)?.toDouble() ?? 0.0,
        (startLoc['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      endLocation: LatLng(
        (endLoc['lat'] as num?)?.toDouble() ?? 0.0,
        (endLoc['lng'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }
}

class OlaRoute {
  final String summary;
  final List<LatLng> polyline;
  final int distanceMeters;
  final int durationSeconds;
  final String readableDistance;
  final String readableDuration;
  final List<OlaRouteStep> steps;
  final bool isDiverted;
  final String? diversionReason;

  const OlaRoute({
    required this.summary,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.readableDistance,
    required this.readableDuration,
    required this.steps,
    this.isDiverted = false,
    this.diversionReason,
  });

  factory OlaRoute.fromJson(Map<String, dynamic> json) {
    final legs = (json['legs'] as List<dynamic>?) ?? [];
    int totalDist = 0;
    int totalDur = 0;
    String readDist = '';
    String readDur = '';
    final stepsList = <OlaRouteStep>[];

    if (legs.isNotEmpty) {
      final firstLeg = legs.first as Map<String, dynamic>;
      totalDist = (firstLeg['distance'] as num?)?.toInt() ?? 0;
      totalDur = (firstLeg['duration'] as num?)?.toInt() ?? 0;
      readDist = firstLeg['readable_distance']?.toString() ?? '';
      readDur = firstLeg['readable_duration']?.toString() ?? '';

      final rawSteps = firstLeg['steps'] as List<dynamic>? ?? [];
      for (final s in rawSteps) {
        if (s is Map<String, dynamic>) {
          stepsList.add(OlaRouteStep.fromJson(s));
        }
      }
    }

    final polyString = json['overview_polyline']?.toString() ?? '';
    final decodedPoly = decodePolyline(polyString);

    return OlaRoute(
      summary: json['summary']?.toString() ?? '',
      polyline: decodedPoly,
      distanceMeters: totalDist,
      durationSeconds: totalDur,
      readableDistance: readDist.isNotEmpty ? readDist : '${(totalDist / 1000).toStringAsFixed(1)} km',
      readableDuration: readDur.isNotEmpty ? readDur : '${(totalDur / 60).round()} min',
      steps: stepsList,
    );
  }

  OlaRoute copyWith({
    String? summary,
    List<LatLng>? polyline,
    int? distanceMeters,
    int? durationSeconds,
    String? readableDistance,
    String? readableDuration,
    List<OlaRouteStep>? steps,
    bool? isDiverted,
    String? diversionReason,
  }) {
    return OlaRoute(
      summary: summary ?? this.summary,
      polyline: polyline ?? this.polyline,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      readableDistance: readableDistance ?? this.readableDistance,
      readableDuration: readableDuration ?? this.readableDuration,
      steps: steps ?? this.steps,
      isDiverted: isDiverted ?? this.isDiverted,
      diversionReason: diversionReason ?? this.diversionReason,
    );
  }
}

class OlaDistanceMatrixElement {
  final int distanceMeters;
  final int durationSeconds;
  final String status;

  const OlaDistanceMatrixElement({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.status,
  });
}

/// Decode standard Google Encoded Polyline format
List<LatLng> decodePolyline(String encoded) {
  if (encoded.isEmpty) return const [];
  final List<LatLng> poly = [];
  int index = 0;
  final int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < len);
    final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      if (index >= len) break;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < len);
    final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    poly.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return poly;
}

final olaMapsServiceProvider = Provider<OlaMapsService>((ref) {
  final apiKey = ref.watch(mapApiKeyProvider);
  return OlaMapsService(apiKey: apiKey);
});

class OlaMapsService {
  final String? apiKey;
  final Dio _dio;

  OlaMapsService({required this.apiKey})
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'User-Agent': 'WakeUpBuddy/1.0'},
          ),
        );

  String get _effectiveKey =>
      (apiKey != null && apiKey!.trim().isNotEmpty) ? apiKey!.trim() : ApiConstants.defaultOlaApiKey;

  /// Places Autocomplete API
  Future<List<OlaPlaceSuggestion>> autocomplete(
    String query, {
    LatLng? location,
    int radius = 50000,
  }) async {
    if (query.trim().isEmpty) return const [];

    try {
      final Map<String, dynamic> queryParams = {
        'input': query.trim(),
        'api_key': _effectiveKey,
      };

      if (location != null) {
        queryParams['location'] = '${location.latitude},${location.longitude}';
        queryParams['radius'] = radius.toString();
      }

      final response = await _dio.get(
        ApiConstants.olaAutocomplete,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        return predictions
            .whereType<Map<String, dynamic>>()
            .map((e) => OlaPlaceSuggestion.fromJson(e))
            .toList();
      }
    } catch (_) {
      // Fallback or handle offline
    }
    return const [];
  }

  /// Places Details API
  Future<OlaPlaceSuggestion?> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(
        ApiConstants.olaPlaceDetails,
        queryParameters: {
          'place_id': placeId,
          'api_key': _effectiveKey,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          final geom = result['geometry'] as Map<String, dynamic>?;
          final loc = geom?['location'] as Map<String, dynamic>?;
          final lat = (loc?['lat'] as num?)?.toDouble();
          final lng = (loc?['lng'] as num?)?.toDouble();

          final rawTypes = result['types'] as List<dynamic>? ?? [];
          final typesList = rawTypes.map((e) => e.toString()).toList();

          return OlaPlaceSuggestion(
            placeId: placeId,
            mainText: result['name']?.toString() ?? '',
            secondaryText: result['formatted_address']?.toString() ?? '',
            description: result['formatted_address']?.toString() ?? '',
            latitude: lat,
            longitude: lng,
            types: typesList,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Reverse Geocode API
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        ApiConstants.olaReverseGeocode,
        queryParameters: {
          'latlng': '$lat,$lng',
          'api_key': _effectiveKey,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final name = first['name']?.toString();
          final address = first['formatted_address']?.toString();
          if (name != null && name.isNotEmpty && name != 'NA') {
            return name;
          }
          return address;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Directions API (POST) with multi-route alternatives
  Future<List<OlaRoute>> getDirections({
    required LatLng origin,
    required LatLng destination,
    bool alternatives = true,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.olaDirections,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'alternatives': alternatives.toString(),
          'steps': 'true',
          'overview': 'full',
          'api_key': _effectiveKey,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>? ?? [];
        return routes
            .whereType<Map<String, dynamic>>()
            .map((r) => OlaRoute.fromJson(r))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Distance Matrix API (GET)
  Future<OlaDistanceMatrixElement?> getDistanceMatrix({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.olaDistanceMatrix,
        queryParameters: {
          'origins': '${origin.latitude},${origin.longitude}',
          'destinations': '${destination.latitude},${destination.longitude}',
          'api_key': _effectiveKey,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rows = data['rows'] as List<dynamic>? ?? [];
        if (rows.isNotEmpty) {
          final firstRow = rows.first as Map<String, dynamic>;
          final elements = firstRow['elements'] as List<dynamic>? ?? [];
          if (elements.isNotEmpty) {
            final el = elements.first as Map<String, dynamic>;
            return OlaDistanceMatrixElement(
              distanceMeters: (el['distance'] as num?)?.toInt() ?? 0,
              durationSeconds: (el['duration'] as num?)?.toInt() ?? 0,
              status: el['status']?.toString() ?? 'OK',
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Nearest Roads API (GET)
  Future<LatLng?> getNearestRoad(LatLng point) async {
    try {
      final response = await _dio.get(
        ApiConstants.olaNearestRoads,
        queryParameters: {
          'points': '${point.latitude},${point.longitude}',
          'api_key': _effectiveKey,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final lat = (first['lat'] as num?)?.toDouble();
          final lng = (first['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Connectivity Health Check
  Future<bool> verifyConnection([String? testKey]) async {
    final keyToTest = (testKey != null && testKey.trim().isNotEmpty)
        ? testKey.trim()
        : _effectiveKey;
    try {
      final response = await _dio.get(
        ApiConstants.olaReverseGeocode,
        queryParameters: {
          'latlng': '12.9314,77.6164',
          'api_key': keyToTest,
        },
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
