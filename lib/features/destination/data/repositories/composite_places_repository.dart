import '../models/place_suggestion.dart';
import 'nominatim_places_repository.dart';
import 'ola_places_repository.dart';
import 'places_repository.dart';

class CompositePlacesRepository implements PlacesRepository {
  final OlaPlacesRepository? _olaRepo;
  final NominatimPlacesRepository _nominatimRepo;

  CompositePlacesRepository({
    OlaPlacesRepository? olaRepo,
    required NominatimPlacesRepository nominatimRepo,
  })  : _olaRepo = olaRepo,
        _nominatimRepo = nominatimRepo;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    if (_olaRepo != null) {
      try {
        final List<PlaceSuggestion> olaResults = await _olaRepo.searchPlaces(
          query,
          nearLat: nearLat,
          nearLng: nearLng,
        );
        if (olaResults.isNotEmpty) {
          return olaResults;
        }
      } catch (_) {
        // fall through to Nominatim
      }
    }

    return _nominatimRepo.searchPlaces(
      query,
      nearLat: nearLat,
      nearLng: nearLng,
    );
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    if (_olaRepo != null) {
      final PlaceSuggestion? olaResult = await _olaRepo.reverseGeocode(lat, lng);
      if (olaResult != null) {
        return olaResult;
      }
    }

    return _nominatimRepo.reverseGeocode(lat, lng);
  }
}