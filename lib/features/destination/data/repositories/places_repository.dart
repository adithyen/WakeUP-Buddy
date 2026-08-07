import '../models/place_suggestion.dart';

abstract class PlacesRepository {
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  });

  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng);
}