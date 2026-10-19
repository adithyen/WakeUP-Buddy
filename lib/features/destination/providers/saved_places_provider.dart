import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/saved_place.dart';
import '../data/repositories/saved_places_repository.dart';

final savedPlacesRepositoryProvider = Provider<SavedPlacesRepository>((ref) {
  return SavedPlacesRepository();
});

final savedPlacesProvider =
    StateNotifierProvider<SavedPlacesNotifier, List<SavedPlace>>((ref) {
  final repo = ref.watch(savedPlacesRepositoryProvider);
  return SavedPlacesNotifier(repo);
});

class SavedPlacesNotifier extends StateNotifier<List<SavedPlace>> {
  final SavedPlacesRepository _repo;

  SavedPlacesNotifier(this._repo) : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final places = await _repo.loadPlaces();
    state = places;
  }

  Future<void> updatePlaceLocation({
    required String id,
    required String address,
    required double latitude,
    required double longitude,
    String? customName,
  }) async {
    final updatedList = state.map((p) {
      if (p.id == id) {
        return p.copyWith(
          isSet: true,
          address: address,
          customName: customName,
          latitude: latitude,
          longitude: longitude,
          updatedAt: DateTime.now(),
        );
      }
      return p;
    }).toList();

    state = updatedList;
    final updatedPlace = updatedList.firstWhere((p) => p.id == id);
    await _repo.savePlace(updatedPlace);
  }

  Future<void> addCustomPlace({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    String iconType = 'location',
  }) async {
    final newPlace = SavedPlace(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      address: address,
      latitude: latitude,
      longitude: longitude,
      iconType: iconType,
      isSet: true,
      updatedAt: DateTime.now(),
    );

    final updated = [...state, newPlace];
    state = updated;
    await _repo.savePlace(newPlace);
  }

  Future<void> clearPlace(String id) async {
    await _repo.clearPlace(id);
    await _load();
  }
}
