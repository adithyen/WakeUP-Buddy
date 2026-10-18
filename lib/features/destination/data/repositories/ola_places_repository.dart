import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/place_suggestion.dart';
import 'places_api_exception.dart';
import 'places_repository.dart';

class OlaPlacesRepository implements PlacesRepository {
  final Dio _dio;
  final String _apiKey;

  OlaPlacesRepository({required Dio dio, required String apiKey})
      : _dio = dio,
        _apiKey = apiKey;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        ApiConstants.olaAutocomplete,
        queryParameters: <String, dynamic>{
          'input': query,
          'api_key': _apiKey,
          if (nearLat != null && nearLng != null) 'location': '$nearLat,$nearLng',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> predictions = (response.data['predictions'] as List<dynamic>?) ?? <dynamic>[];

        // Fetch real by-road distance and duration from Ola Distance Matrix API in one batch call
        final Map<int, Map<String, int>> roadMetrics = {};
        if (nearLat != null && nearLng != null && predictions.isNotEmpty) {
          try {
            final validIndices = <int>[];
            final destStrings = <String>[];
            for (int i = 0; i < predictions.length; i++) {
              final p = predictions[i] as Map<String, dynamic>;
              final lat = _toDouble(p['geometry']?['location']?['lat']);
              final lng = _toDouble(p['geometry']?['location']?['lng']);
              if (lat != 0.0 && lng != 0.0) {
                validIndices.add(i);
                destStrings.add('$lat,$lng');
              }
            }

            if (destStrings.isNotEmpty) {
              final dmResp = await _dio.get(
                ApiConstants.olaDistanceMatrix,
                queryParameters: <String, dynamic>{
                  'origins': '$nearLat,$nearLng',
                  'destinations': destStrings.join('|'),
                  'api_key': _apiKey,
                },
              );

              if (dmResp.statusCode == 200 && dmResp.data is Map<String, dynamic>) {
                final rows = (dmResp.data['rows'] as List<dynamic>?) ?? [];
                if (rows.isNotEmpty) {
                  final elements = (rows.first['elements'] as List<dynamic>?) ?? [];
                  for (int i = 0; i < elements.length && i < validIndices.length; i++) {
                    final el = elements[i] as Map<String, dynamic>;
                    final dist = (el['distance'] as num?)?.toInt();
                    final dur = (el['duration'] as num?)?.toInt();
                    if (dist != null && dur != null) {
                      roadMetrics[validIndices[i]] = {'distance': dist, 'duration': dur};
                    }
                  }
                }
              }
            }
          } catch (_) {
            // Non-blocking fallback to road-curvature estimation below
          }
        }

        final List<PlaceSuggestion> results = <PlaceSuggestion>[];
        for (int i = 0; i < predictions.length; i++) {
          final Map<String, dynamic> p = predictions[i] as Map<String, dynamic>;
          final double lat = _toDouble(p['geometry']?['location']?['lat']);
          final double lng = _toDouble(p['geometry']?['location']?['lng']);

          final metric = roadMetrics[i];
          int? distanceMeters = metric?['distance'];
          int? durationSeconds = metric?['duration'];

          // Realistic by-road estimation fallback if distance matrix is offline
          if (distanceMeters == null && nearLat != null && nearLng != null && lat != 0.0 && lng != 0.0) {
            final straightMeters = Geolocator.distanceBetween(nearLat, nearLng, lat, lng);
            distanceMeters = (straightMeters * 1.35).round();
          }
          if (durationSeconds == null && distanceMeters != null && distanceMeters > 0) {
            durationSeconds = (distanceMeters / 7.78).round();
          }

          results.add(
            PlaceSuggestion(
              placeId: p['place_id']?.toString() ?? '',
              name: p['structured_formatting']?['main_text']?.toString() ?? p['description']?.toString() ?? '',
              description: p['structured_formatting']?['secondary_text']?.toString() ?? '',
              latitude: lat,
              longitude: lng,
              formattedAddress: p['description']?.toString(),
              type: _inferPlaceType(p['types'] as List<dynamic>?),
              source: PlaceSource.ola,
              distanceMeters: distanceMeters,
              durationSeconds: durationSeconds,
            ),
          );
        }
        return results;
      }

      return <PlaceSuggestion>[];
    } on DioException catch (error) {
      throw PlacesApiException('Ola API error: ${error.message}');
    }
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    try {
      final Response<dynamic> response = await _dio.get(
        ApiConstants.olaReverseGeocode,
        queryParameters: <String, dynamic>{
          'latlng': '$lat,$lng',
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = (response.data['results'] as List<dynamic>?) ?? <dynamic>[];
        if (results.isNotEmpty) {
          final Map<String, dynamic> first = results.first as Map<String, dynamic>;
          final String formattedAddress = first['formatted_address']?.toString() ?? 'Unknown Location';

          return PlaceSuggestion(
            placeId: first['place_id']?.toString() ?? '',
            name: formattedAddress,
            description: formattedAddress,
            latitude: lat,
            longitude: lng,
            formattedAddress: formattedAddress,
            type: PlaceType.address,
            source: PlaceSource.ola,
          );
        }
      }

      return null;
    } on DioException {
      return null;
    }
  }

  PlaceType _inferPlaceType(List<dynamic>? types) {
    if (types == null) {
      return PlaceType.other;
    }

    final Set<String> typeSet = types.map((dynamic value) => value.toString().toLowerCase()).toSet();
    if (typeSet.contains('hindu_temple') ||
        typeSet.contains('place_of_worship') ||
        typeSet.contains('church') ||
        typeSet.contains('mosque') ||
        typeSet.contains('synagogue')) {
      return PlaceType.temple;
    }
    if (typeSet.contains('hospital') ||
        typeSet.contains('doctor') ||
        typeSet.contains('health') ||
        typeSet.contains('pharmacy')) {
      return PlaceType.hospital;
    }
    if (typeSet.contains('university') ||
        typeSet.contains('college') ||
        typeSet.contains('school') ||
        typeSet.contains('secondary_school')) {
      return PlaceType.college;
    }
    if (typeSet.contains('shopping_mall') ||
        typeSet.contains('store') ||
        typeSet.contains('restaurant') ||
        typeSet.contains('food') ||
        typeSet.contains('cafe')) {
      return PlaceType.shopping;
    }
    if (typeSet.contains('bus_station') || typeSet.contains('bus_stop')) {
      return PlaceType.busStop;
    }
    if (typeSet.contains('train_station')) {
      return PlaceType.trainStation;
    }
    if (typeSet.contains('subway_station') || typeSet.contains('transit_station')) {
      return PlaceType.metroStation;
    }
    if (typeSet.contains('airport')) {
      return PlaceType.airport;
    }

    return PlaceType.other;
  }

  double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}