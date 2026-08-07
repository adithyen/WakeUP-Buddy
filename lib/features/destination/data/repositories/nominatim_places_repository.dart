import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/place_suggestion.dart';
import 'places_repository.dart';

class NominatimPlacesRepository implements PlacesRepository {
  final Dio _dio;

  NominatimPlacesRepository({required Dio dio}) : _dio = dio;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final Map<String, dynamic> queryParameters = <String, dynamic>{
        'q': query,
        'format': 'json',
        'limit': 10,
        'addressdetails': 1,
        'countrycodes': 'in',
      };

      if (nearLat != null && nearLng != null) {
        queryParameters.addAll(<String, dynamic>{
          'viewbox': '${nearLng - 0.5},${nearLat + 0.5},${nearLng + 0.5},${nearLat - 0.5}',
          'bounded': '0',
        });
      }

      final Response<dynamic> response = await _dio.get(
        ApiConstants.nominatimSearch,
        queryParameters: queryParameters,
        options: Options(headers: <String, dynamic>{
          'User-Agent': 'WakeUpBuddy/1.0 (contact: support@wakeupbuddy.app)',
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data as List<dynamic>;
        return results.map((dynamic raw) {
          final Map<String, dynamic> r = raw as Map<String, dynamic>;
          final List<String> parts = (r['display_name']?.toString() ?? '').split(',');
          final String primary = parts.isNotEmpty ? parts.first.trim() : 'Unknown';
          final String secondary = parts.length > 1 ? parts.skip(1).join(',').trim() : '';

          return PlaceSuggestion(
            placeId: r['place_id']?.toString() ?? '',
            name: primary,
            description: secondary,
            latitude: double.tryParse(r['lat']?.toString() ?? '') ?? 0,
            longitude: double.tryParse(r['lon']?.toString() ?? '') ?? 0,
            formattedAddress: r['display_name']?.toString(),
            type: _inferType(r['type']?.toString(), r['class']?.toString()),
            source: PlaceSource.nominatim,
          );
        }).toList(growable: false);
      }

      return <PlaceSuggestion>[];
    } catch (_) {
      return <PlaceSuggestion>[];
    }
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    try {
      final Response<dynamic> response = await _dio.get(
        ApiConstants.nominatimReverse,
        queryParameters: <String, dynamic>{
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
        options: Options(headers: <String, dynamic>{
          'User-Agent': 'WakeUpBuddy/1.0',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<String> parts = (data['display_name']?.toString() ?? '').split(',');

        return PlaceSuggestion(
          placeId: data['place_id']?.toString() ?? '',
          name: parts.isNotEmpty ? parts.first.trim() : 'Dropped Pin',
          description: data['display_name']?.toString() ?? '',
          latitude: lat,
          longitude: lng,
          formattedAddress: data['display_name']?.toString(),
          type: PlaceType.address,
          source: PlaceSource.nominatim,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  PlaceType _inferType(String? type, String? osmClass) {
    if (type == 'bus_stop') {
      return PlaceType.busStop;
    }
    if (type == 'station' && osmClass == 'railway') {
      return PlaceType.trainStation;
    }
    if (type == 'halt' && osmClass == 'railway') {
      return PlaceType.trainStation;
    }

    return PlaceType.other;
  }
}