import 'package:geolocator/geolocator.dart';

import '../models/place_suggestion.dart';
import 'nominatim_places_repository.dart';
import 'ola_places_repository.dart';
import 'places_repository.dart';
import 'tomtom_places_repository.dart';

class CompositePlacesRepository implements PlacesRepository {
  final OlaPlacesRepository? _olaRepo;
  final TomTomPlacesRepository? _tomtomRepo;
  final NominatimPlacesRepository _nominatimRepo;

  CompositePlacesRepository({
    OlaPlacesRepository? olaRepo,
    TomTomPlacesRepository? tomtomRepo,
    required NominatimPlacesRepository nominatimRepo,
  })  : _olaRepo = olaRepo,
        _tomtomRepo = tomtomRepo,
        _nominatimRepo = nominatimRepo;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final List<Future<List<PlaceSuggestion>>> futures = [];

    if (_olaRepo != null) {
      futures.add(
        _olaRepo
            .searchPlaces(query, nearLat: nearLat, nearLng: nearLng)
            .catchError((_) => <PlaceSuggestion>[]),
      );
    }

    if (_tomtomRepo != null) {
      futures.add(
        _tomtomRepo
            .searchPlaces(query, nearLat: nearLat, nearLng: nearLng)
            .catchError((_) => <PlaceSuggestion>[]),
      );
    }

    final results = await Future.wait(futures);
    final List<PlaceSuggestion> olaList = results.isNotEmpty ? results[0] : <PlaceSuggestion>[];
    final List<PlaceSuggestion> tomtomList = results.length > 1 ? results[1] : <PlaceSuggestion>[];

    final List<PlaceSuggestion> combined = <PlaceSuggestion>[...olaList];

    // Merge TomTom results without duplicates
    for (final ttItem in tomtomList) {
      final bool isDuplicate = combined.any((existing) => _areDuplicates(existing, ttItem));
      if (!isDuplicate) {
        combined.add(ttItem);
      }
    }

    if (combined.isNotEmpty) {
      // Sort with slight priority to nearest places if coordinates are available
      if (nearLat != null && nearLng != null) {
        combined.sort((a, b) {
          final distA = a.distanceMeters ?? 99999999;
          final distB = b.distanceMeters ?? 99999999;
          return distA.compareTo(distB);
        });
      }
      return combined;
    }

    // Fall back to Nominatim/OSM if both primary providers returned nothing
    return _nominatimRepo.searchPlaces(
      query,
      nearLat: nearLat,
      nearLng: nearLng,
    );
  }

  bool _areDuplicates(PlaceSuggestion a, PlaceSuggestion b) {
    // 1. Precise coordinate proximity check (< 120m)
    final double dist = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    final String nameA = _cleanName(a.name);
    final String nameB = _cleanName(b.name);

    if (dist < 120) {
      // If within 120 meters, consider duplicate if names share any common token
      if (nameA == nameB || nameA.contains(nameB) || nameB.contains(nameA)) {
        return true;
      }
      final tokensA = nameA.split(' ').where((t) => t.length > 2).toSet();
      final tokensB = nameB.split(' ').where((t) => t.length > 2).toSet();
      if (tokensA.intersection(tokensB).isNotEmpty) {
        return true;
      }
    }

    // 2. Exact normalized title match within 500m
    if (dist < 500 && nameA == nameB && nameA.isNotEmpty) {
      return true;
    }

    return false;
  }

  String _cleanName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    if (_olaRepo != null) {
      try {
        final PlaceSuggestion? olaResult = await _olaRepo.reverseGeocode(lat, lng);
        if (olaResult != null) return olaResult;
      } catch (_) {}
    }

    return _nominatimRepo.reverseGeocode(lat, lng);
  }
}