import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/tracking/data/models/traffic_incident_model.dart';
import '../constants/api_constants.dart';

final tomtomTrafficServiceProvider = Provider<TomTomTrafficService>((ref) {
  return TomTomTrafficService(
    dio: Dio(),
    apiKey: ApiConstants.defaultTomTomApiKey,
  );
});

final liveIncidentsProvider = FutureProvider.family<List<TrafficIncident>, LatLng>((ref, center) async {
  final service = ref.watch(tomtomTrafficServiceProvider);
  // Query 20km around the center
  final minLat = center.latitude - 0.18;
  final maxLat = center.latitude + 0.18;
  final minLon = center.longitude - 0.18;
  final maxLon = center.longitude + 0.18;

  return service.fetchIncidentsInBbox(
    minLon: minLon,
    minLat: minLat,
    maxLon: maxLon,
    maxLat: maxLat,
  );
});

class TomTomRouteResult {
  final List<LatLng> polyline;
  final int distanceMeters;
  final int travelTimeSeconds;
  final int trafficDelaySeconds;
  final bool hasRoadClosure;
  final bool isDiverted;
  final String? diversionReason;

  const TomTomRouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.travelTimeSeconds,
    required this.trafficDelaySeconds,
    this.hasRoadClosure = false,
    this.isDiverted = false,
    this.diversionReason,
  });
}

class TomTomTrafficService {
  final Dio _dio;
  final String _apiKey;

  TomTomTrafficService({required Dio dio, required String apiKey})
      : _dio = dio,
        _apiKey = apiKey;

  String getMapStylesV2Url({bool isDark = false}) {
    return ApiConstants.tomtomMapStyleV2(apiKey: _apiKey, isDark: isDark);
  }

  String getRasterFlowTileUrl() {
    return 'https://api.tomtom.com/traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?key=$_apiKey';
  }

  String getRasterIncidentTileUrl({bool isDark = false}) {
    final style = isDark ? 's0-dark' : 's0';
    return 'https://api.tomtom.com/traffic/map/4/tile/incidents/$style/{z}/{x}/{y}.png?key=$_apiKey';
  }

  Future<List<TrafficIncident>> fetchIncidentsInBbox({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.tomtomIncidentDetails,
        queryParameters: {
          'key': _apiKey,
          'bbox': '$minLon,$minLat,$maxLon,$maxLat',
          'language': 'en-GB',
          'timeValidityFilter': 'present',
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final List<dynamic> rawIncidents =
            (response.data['incidents'] as List<dynamic>?) ?? [];

        final List<TrafficIncident> incidents = [];
        for (int i = 0; i < rawIncidents.length; i++) {
          final item = rawIncidents[i];
          if (item is Map<String, dynamic>) {
            incidents.add(TrafficIncident.fromJson(item, i));
          }
        }
        return incidents;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<TomTomRouteResult?> calculateTrafficAwareRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? avoidRoadClosures,
  }) async {
    try {
      final locations =
          '${origin.latitude},${origin.longitude}:${destination.latitude},${destination.longitude}';
      final Map<String, dynamic> queryParams = {
        'key': _apiKey,
        'traffic': true,
        'routeType': 'fastest',
        'computeTravelTimeFor': 'all',
      };

      if (avoidRoadClosures != null && avoidRoadClosures.isNotEmpty) {
        final areas = avoidRoadClosures.take(6).map((pt) {
          final minLon = (pt.longitude - 0.0008).toStringAsFixed(6);
          final maxLon = (pt.longitude + 0.0008).toStringAsFixed(6);
          final minLat = (pt.latitude - 0.0008).toStringAsFixed(6);
          final maxLat = (pt.latitude + 0.0008).toStringAsFixed(6);
          return 'rect:$minLon,$minLat,$maxLon,$maxLat';
        }).join(':');
        queryParams['avoidAreas'] = areas;
      }

      final response = await _dio.get(
        '${ApiConstants.tomtomCalculateRoute}/$locations/json',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final routes = (response.data['routes'] as List<dynamic>?) ?? [];
        if (routes.isEmpty) return null;

        final firstRoute = routes.first as Map<String, dynamic>;
        final summary = firstRoute['summary'] as Map<String, dynamic>? ?? {};

        final int distance = (summary['lengthInMeters'] as num?)?.toInt() ?? 0;
        final int travelTime = (summary['travelTimeInSeconds'] as num?)?.toInt() ?? 0;
        final int trafficDelay = (summary['trafficDelayInSeconds'] as num?)?.toInt() ?? 0;

        final legs = (firstRoute['legs'] as List<dynamic>?) ?? [];
        final List<LatLng> points = [];

        for (final leg in legs) {
          final legPoints = (leg['points'] as List<dynamic>?) ?? [];
          for (final pt in legPoints) {
            if (pt is Map<String, dynamic>) {
              final lat = (pt['latitude'] as num?)?.toDouble();
              final lng = (pt['longitude'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                points.add(LatLng(lat, lng));
              }
            }
          }
        }

        // Check sections for traffic/road closures
        final sections = (firstRoute['sections'] as List<dynamic>?) ?? [];
        bool hasRoadClosure = false;
        String? diversionReason;

        for (final sec in sections) {
          final secType = sec['sectionType']?.toString().toUpperCase();
          final simpleCategory = sec['simpleCategory']?.toString().toUpperCase();
          if (secType == 'TRAFFIC' || simpleCategory == 'ROAD_CLOSURE' || sec['delayInSeconds'] != null) {
            if (simpleCategory == 'ROAD_CLOSURE' || (sec['magnitude'] as num?)?.toInt() == 4) {
              hasRoadClosure = true;
              diversionReason = 'Route automatically diverted to bypass road closure';
            }
          }
        }

        final bool isDiverted = hasRoadClosure || trafficDelay > 180; // >3 min delay avoided

        return TomTomRouteResult(
          polyline: points,
          distanceMeters: distance,
          travelTimeSeconds: travelTime,
          trafficDelaySeconds: trafficDelay,
          hasRoadClosure: hasRoadClosure,
          isDiverted: isDiverted,
          diversionReason: diversionReason ?? (isDiverted ? 'Route optimized for live traffic delay' : null),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
