import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/map_api_key_provider.dart';
import '../data/models/destination.dart';
import '../data/models/place_suggestion.dart';
import '../data/repositories/composite_places_repository.dart';
import '../data/repositories/nominatim_places_repository.dart';
import '../data/repositories/ola_places_repository.dart';
import '../data/repositories/places_repository.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final Dio dio = ref.watch(dioProvider);
  final String? apiKey = ref.watch(mapApiKeyProvider);

  final NominatimPlacesRepository nominatim = NominatimPlacesRepository(dio: dio);
  final OlaPlacesRepository? olaRepo = apiKey == null || apiKey.isEmpty ? null : OlaPlacesRepository(dio: dio, apiKey: apiKey);

  return CompositePlacesRepository(olaRepo: olaRepo, nominatimRepo: nominatim);
});

final destinationSearchProvider = StateNotifierProvider.autoDispose<DestinationSearchNotifier, DestinationSearchState>((ref) {
  return DestinationSearchNotifier(ref.watch(placesRepositoryProvider));
});

final selectedDestinationProvider = StateNotifierProvider<SelectedDestinationNotifier, Destination?>((ref) {
  return SelectedDestinationNotifier();
});

class DestinationSearchState {
  final String query;
  final List<PlaceSuggestion> suggestions;
  final bool isLoading;
  final String? errorMessage;

  const DestinationSearchState({
    this.query = '',
    this.suggestions = const <PlaceSuggestion>[],
    this.isLoading = false,
    this.errorMessage,
  });

  DestinationSearchState copyWith({
    String? query,
    List<PlaceSuggestion>? suggestions,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DestinationSearchState(
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DestinationSearchNotifier extends StateNotifier<DestinationSearchState> {
  final PlacesRepository _repository;
  Timer? _debounce;
  int _currentRequestId = 0;

  DestinationSearchNotifier(this._repository) : super(const DestinationSearchState());

  @override
  void dispose() {
    _debounce?.cancel();
    _currentRequestId++;
    super.dispose();
  }

  /// Called on each keystroke — debounces 350ms before firing the API call.
  void autocomplete(String query, {double? nearLat, double? nearLng}) {
    _debounce?.cancel();
    final String trimmed = query.trim();

    if (trimmed.isEmpty) {
      clear();
      return;
    }

    state = state.copyWith(query: trimmed, isLoading: true, clearError: true);

    final int reqId = ++_currentRequestId;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _doSearch(trimmed, reqId, nearLat: nearLat, nearLng: nearLng);
    });
  }

  Future<void> search(String query, {double? nearLat, double? nearLng}) async {
    _debounce?.cancel();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }
    final int reqId = ++_currentRequestId;
    state = state.copyWith(query: trimmed, isLoading: true, clearError: true);
    await _doSearch(trimmed, reqId, nearLat: nearLat, nearLng: nearLng);
  }

  Future<void> _doSearch(String query, int reqId, {double? nearLat, double? nearLng}) async {
    try {
      final List<PlaceSuggestion> suggestions = await _repository.searchPlaces(
        query,
        nearLat: nearLat,
        nearLng: nearLng,
      );
      // Discard responses if another search was triggered or if query was cleared
      if (!mounted || reqId != _currentRequestId || state.query.trim().isEmpty) {
        return;
      }
      state = state.copyWith(suggestions: suggestions, isLoading: false);
    } catch (error) {
      if (!mounted || reqId != _currentRequestId) {
        return;
      }
      state = state.copyWith(
        suggestions: const <PlaceSuggestion>[],
        isLoading: false,
        errorMessage: 'Unable to search places right now.',
      );
    }
  }

  void clear() {
    _debounce?.cancel();
    _currentRequestId++;
    state = const DestinationSearchState();
  }
}


class SelectedDestinationNotifier extends StateNotifier<Destination?> {
  SelectedDestinationNotifier() : super(null) {
    load();
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? name = prefs.getString('selected_destination_name');
    final double? latitude = prefs.getDouble('selected_destination_lat');
    final double? longitude = prefs.getDouble('selected_destination_lng');
    final String? description = prefs.getString('selected_destination_description');
    final String? source = prefs.getString('selected_destination_source');
    final String? id = prefs.getString('selected_destination_id');

    if (name == null || latitude == null || longitude == null || id == null || source == null) {
      return;
    }

    state = Destination(
      id: id,
      name: name,
      description: description,
      latitude: latitude,
      longitude: longitude,
      selectedAt: DateTime.now(),
      source: PlaceSource.values.firstWhere(
        (PlaceSource candidate) => candidate.name == source,
        orElse: () => PlaceSource.nominatim,
      ),
    );
  }

  Future<void> setDestinationFromSuggestion(PlaceSuggestion suggestion) async {
    final Destination destination = Destination.fromSuggestion(suggestion);
    state = destination;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_destination_id', destination.id);
    await prefs.setString('selected_destination_name', destination.name);
    await prefs.setString('selected_destination_description', destination.description ?? '');
    await prefs.setDouble('selected_destination_lat', destination.latitude);
    await prefs.setDouble('selected_destination_lng', destination.longitude);
    await prefs.setString('selected_destination_source', destination.source.name);
  }

  Future<void> select(Destination destination) async {
    state = destination;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_destination_id', destination.id);
    await prefs.setString('selected_destination_name', destination.name);
    await prefs.setString('selected_destination_description', destination.description ?? '');
    await prefs.setDouble('selected_destination_lat', destination.latitude);
    await prefs.setDouble('selected_destination_lng', destination.longitude);
    await prefs.setString('selected_destination_source', destination.source.name);
  }

  Future<void> clear() => clearDestination();

  Future<void> clearDestination() async {
    state = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_destination_id');
    await prefs.remove('selected_destination_name');
    await prefs.remove('selected_destination_description');
    await prefs.remove('selected_destination_lat');
    await prefs.remove('selected_destination_lng');
    await prefs.remove('selected_destination_source');
  }
}