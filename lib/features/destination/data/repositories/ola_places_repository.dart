import 'package:dio/dio.dart';

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
        return predictions.map((dynamic raw) {
          final Map<String, dynamic> p = raw as Map<String, dynamic>;
          return PlaceSuggestion(
            placeId: p['place_id']?.toString() ?? '',
            name: p['structured_formatting']?['main_text']?.toString() ?? p['description']?.toString() ?? '',
            description: p['structured_formatting']?['secondary_text']?.toString() ?? '',
            latitude: _toDouble(p['geometry']?['location']?['lat']),
            longitude: _toDouble(p['geometry']?['location']?['lng']),
            formattedAddress: p['description']?.toString(),
            type: _inferPlaceType(p['types'] as List<dynamic>?),
            source: PlaceSource.ola,
          );
        }).toList(growable: false);
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

    final Set<String> typeSet = types.map((dynamic value) => value.toString()).toSet();
    if (typeSet.contains('bus_station') || typeSet.contains('transit_station')) {
      return PlaceType.busStop;
    }
    if (typeSet.contains('train_station')) {
      return PlaceType.trainStation;
    }
    if (typeSet.contains('subway_station')) {
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