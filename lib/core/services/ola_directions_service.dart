import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../features/tracking/data/models/route_model.dart';

/// Wrapper around the Ola Maps Directions API.
///
/// Endpoint: POST https://api.olamaps.io/routing/v1/directions
/// Docs: https://maps.olakrutrim.com/docs/routing-apis/directions-api
class OlaDirectionsService {
  OlaDirectionsService({required String apiKey}) : _apiKey = apiKey;

  final String _apiKey;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Fetch up to 3 route alternatives between [origin] and [destination].
  Future<List<RouteOption>> getRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final String originStr      = '${origin.latitude},${origin.longitude}';
      final String destinationStr = '${destination.latitude},${destination.longitude}';

      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>(
        ApiConstants.olaDirections,
        queryParameters: <String, dynamic>{'api_key': _apiKey},
        data: <String, dynamic>{
          'origin': originStr,
          'destination': destinationStr,
          'alternatives': true,
          'steps': true,
          'overview': 'full',
          'language': 'en',
        },
      );

      final Map<String, dynamic> body = response.data ?? <String, dynamic>{};
      final List<dynamic> rawRoutes   = body['routes'] as List<dynamic>? ?? <dynamic>[];

      return rawRoutes
          .asMap()
          .entries
          .map((MapEntry<int, dynamic> e) => _parseRoute(e.key, e.value as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list — caller handles gracefully
      return <RouteOption>[];
    }
  }

  /// Get the distance and duration for [origin] → [destination] without polyline.
  /// Used for Distance Matrix queries (recent places ETA on home screen).
  Future<({int distanceM, int durationS})> getDistance({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
        ApiConstants.olaDistanceMatrix,
        queryParameters: <String, dynamic>{
          'api_key': _apiKey,
          'origins': '${origin.latitude},${origin.longitude}',
          'destinations': '${destination.latitude},${destination.longitude}',
        },
      );
      final Map<String, dynamic> body = response.data ?? <String, dynamic>{};
      final List<dynamic> rows = body['rows'] as List<dynamic>? ?? <dynamic>[];
      if (rows.isNotEmpty) {
        final List<dynamic> elements = (rows[0] as Map<String, dynamic>)['elements'] as List<dynamic>? ?? <dynamic>[];
        if (elements.isNotEmpty) {
          final Map<String, dynamic> el = elements[0] as Map<String, dynamic>;
          final int distM = (el['distance']?['value'] as num?)?.toInt() ?? 0;
          final int durS  = (el['duration']?['value'] as num?)?.toInt() ?? 0;
          return (distanceM: distM, durationS: durS);
        }
      }
    } catch (_) {}
    return (distanceM: 0, durationS: 0);
  }

  // ──────────────────────────────────────────────────────────────────────────

  RouteOption _parseRoute(int index, Map<String, dynamic> route) {
    // Distance / duration from first leg summary
    final List<dynamic> legs = route['legs'] as List<dynamic>? ?? <dynamic>[];
    int totalDistanceM = 0;
    int totalDurationS = 0;
    final List<RouteStep> steps = <RouteStep>[];

    for (final dynamic leg in legs) {
      final Map<String, dynamic> legMap = leg as Map<String, dynamic>;
      totalDistanceM += (legMap['distance']?['value'] as num?)?.toInt() ?? 0;
      totalDurationS += (legMap['duration']?['value'] as num?)?.toInt() ?? 0;

      final List<dynamic> legSteps = legMap['steps'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic step in legSteps) {
        final Map<String, dynamic> s = step as Map<String, dynamic>;
        final Map<String, dynamic>? startLoc = s['start_location'] as Map<String, dynamic>?;
        final Map<String, dynamic>? endLoc   = s['end_location']   as Map<String, dynamic>?;
        steps.add(RouteStep(
          instruction:     (s['html_instructions'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), ''),
          distanceMeters:  (s['distance']?['value'] as num?)?.toInt() ?? 0,
          durationSeconds: (s['duration']?['value'] as num?)?.toInt() ?? 0,
          startLocation: LatLng(
            (startLoc?['lat'] as num?)?.toDouble() ?? 0,
            (startLoc?['lng'] as num?)?.toDouble() ?? 0,
          ),
          endLocation: LatLng(
            (endLoc?['lat'] as num?)?.toDouble() ?? 0,
            (endLoc?['lng'] as num?)?.toDouble() ?? 0,
          ),
        ));
      }
    }

    // Decode overview polyline
    final String encoded = (route['overview_polyline'] as Map<String, dynamic>?)?['points'] as String? ?? '';
    final List<LatLng> points = _decodePolyline(encoded);

    final String summary = route['summary'] as String? ?? 'Route ${index + 1}';

    return RouteOption(
      index: index,
      distanceMeters: totalDistanceM,
      durationSeconds: totalDurationS,
      polylinePoints: points,
      summary: summary,
      steps: steps,
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return <LatLng>[];
    try {
      final PolylinePoints decoder = PolylinePoints();
      final List<PointLatLng> pts  = decoder.decodePolyline(encoded);
      return pts.map((PointLatLng p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (_) {
      return <LatLng>[];
    }
  }

  /// Calculate remaining route distance from [currentPos] along [routePoints].
  /// Finds the nearest point on the route and sums remaining segment distances.
  static int remainingDistanceMeters(LatLng currentPos, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0;
    if (routePoints.length == 1) {
      return _haversineM(currentPos, routePoints.first).round();
    }

    // Find closest segment index
    int nearestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final double d = _haversineM(currentPos, routePoints[i]);
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    // Sum remaining segment lengths from nearestIdx to end
    double remaining = 0;
    for (int i = nearestIdx; i < routePoints.length - 1; i++) {
      remaining += _haversineM(routePoints[i], routePoints[i + 1]);
    }
    return remaining.round();
  }

  static double _haversineM(LatLng a, LatLng b) {
    const double r = 6371000; // Earth radius metres
    final double lat1 = a.latitudeInRad;
    final double lat2 = b.latitudeInRad;
    final double dLat = lat2 - lat1;
    final double dLon = b.longitudeInRad - a.longitudeInRad;
    final double h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
