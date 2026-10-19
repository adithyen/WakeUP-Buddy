import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place_suggestion.dart';
import 'places_api_exception.dart';
import 'places_repository.dart';

class TomTomPlacesRepository implements PlacesRepository {
  final Dio _dio;
  final String _apiKey;

  static const String _baseUrl = 'https://api.tomtom.com/search/2/search';

  TomTomPlacesRepository({required Dio dio, required String apiKey})
      : _dio = dio,
        _apiKey = apiKey;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return <PlaceSuggestion>[];

    try {
      final String encodedQuery = Uri.encodeComponent(trimmed);
      final queryParams = <String, dynamic>{
        'key': _apiKey,
        'typeahead': true,
        'limit': 8,
      };

      if (nearLat != null && nearLng != null) {
        queryParams['lat'] = nearLat;
        queryParams['lon'] = nearLng;
        queryParams['radius'] = 50000; // 50km radius bias
      }

      final Response<dynamic> response = await _dio.get(
        '$_baseUrl/$encodedQuery.json',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final List<dynamic> rawResults =
            (response.data['results'] as List<dynamic>?) ?? <dynamic>[];

        final List<PlaceSuggestion> suggestions = <PlaceSuggestion>[];
        for (final item in rawResults) {
          if (item is! Map<String, dynamic>) continue;

          final String id = item['id'] as String? ?? '';
          final Map<String, dynamic>? poi = item['poi'] as Map<String, dynamic>?;
          final Map<String, dynamic>? address = item['address'] as Map<String, dynamic>?;
          final Map<String, dynamic>? position = item['position'] as Map<String, dynamic>?;

          final double lat = (position?['lat'] as num?)?.toDouble() ?? 0.0;
          final double lon = (position?['lon'] as num?)?.toDouble() ?? 0.0;
          if (lat == 0.0 && lon == 0.0) continue;

          // Prefer POI name; fall back to freeformAddress or street
          final String name = poi?['name'] as String? ??
              address?['freeformAddress'] as String? ??
              address?['streetName'] as String? ??
              trimmed;

          final String description = address?['freeformAddress'] as String? ??
              [
                address?['municipality'],
                address?['countrySubdivision'],
                address?['country']
              ].where((part) => part != null && part.toString().isNotEmpty).join(', ');

          final PlaceType type = _mapCategoriesToType(poi?['categories'] as List<dynamic>?);

          int? distanceMeters = (item['dist'] as num?)?.toInt();
          if (distanceMeters == null && nearLat != null && nearLng != null) {
            final straight = Geolocator.distanceBetween(nearLat, nearLng, lat, lon);
            distanceMeters = (straight * 1.35).round();
          }

          int? durationSeconds;
          if (distanceMeters != null && distanceMeters > 0) {
            durationSeconds = (distanceMeters / 7.78).round(); // ~28 km/h road transit avg
          }

          suggestions.add(
            PlaceSuggestion(
              placeId: id.isNotEmpty ? id : 'tomtom_${lat}_$lon',
              name: name,
              description: description.isNotEmpty ? description : name,
              latitude: lat,
              longitude: lon,
              type: type,
              source: PlaceSource.tomtom,
              formattedAddress: address?['freeformAddress'] as String?,
              distanceMeters: distanceMeters,
              durationSeconds: durationSeconds,
            ),
          );
        }
        return suggestions;
      }
      return <PlaceSuggestion>[];
    } on DioException catch (dioErr) {
      throw PlacesApiException('TomTom search failed: ${dioErr.message}');
    } catch (e) {
      throw PlacesApiException('Unexpected TomTom search error: $e');
    }
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://api.tomtom.com/search/2/reverseGeocode/$lat,$lng.json',
        queryParameters: {
          'key': _apiKey,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final addresses = response.data['addresses'] as List<dynamic>?;
        if (addresses != null && addresses.isNotEmpty) {
          final first = addresses.first['address'] as Map<String, dynamic>?;
          final freeform = first?['freeformAddress'] as String? ?? 'Pinned Location';
          return PlaceSuggestion(
            placeId: 'tomtom_rev_${lat}_$lng',
            name: freeform,
            description: freeform,
            latitude: lat,
            longitude: lng,
            type: PlaceType.other,
            source: PlaceSource.tomtom,
            formattedAddress: freeform,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  PlaceType _mapCategoriesToType(List<dynamic>? categories) {
    if (categories == null || categories.isEmpty) return PlaceType.other;
    final catLower = categories.map((c) => c.toString().toLowerCase()).join(' ');

    if (catLower.contains('hospital') || catLower.contains('clinic') || catLower.contains('doctor')) {
      return PlaceType.hospital;
    }
    if (catLower.contains('school') || catLower.contains('college') || catLower.contains('university')) {
      return PlaceType.college;
    }
    if (catLower.contains('temple') || catLower.contains('church') || catLower.contains('mosque') || catLower.contains('place of worship')) {
      return PlaceType.temple;
    }
    if (catLower.contains('bus stop') || catLower.contains('bus station')) {
      return PlaceType.busStop;
    }
    if (catLower.contains('railway') || catLower.contains('train station')) {
      return PlaceType.trainStation;
    }
    if (catLower.contains('metro') || catLower.contains('subway')) {
      return PlaceType.metroStation;
    }
    if (catLower.contains('airport')) {
      return PlaceType.airport;
    }
    if (catLower.contains('shop') || catLower.contains('mall') || catLower.contains('supermarket')) {
      return PlaceType.shopping;
    }
    if (catLower.contains('transit') || catLower.contains('public transport')) {
      return PlaceType.transit;
    }
    if (catLower.contains('landmark') || catLower.contains('tourist attraction')) {
      return PlaceType.landmark;
    }
    return PlaceType.other;
  }
}
