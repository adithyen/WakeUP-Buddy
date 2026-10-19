import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_place.dart';

class SavedPlacesRepository {
  static const String _storageKey = 'saved_places_v1';

  static List<SavedPlace> _defaultPlaces() => [
        SavedPlace(
          id: 'home',
          label: 'Home',
          iconType: 'home',
          isSet: false,
          updatedAt: DateTime.now(),
        ),
        SavedPlace(
          id: 'work',
          label: 'Work',
          iconType: 'work',
          isSet: false,
          updatedAt: DateTime.now(),
        ),
        SavedPlace(
          id: 'gym',
          label: 'Gym',
          iconType: 'gym',
          isSet: false,
          updatedAt: DateTime.now(),
        ),
        SavedPlace(
          id: 'school',
          label: 'School',
          iconType: 'school',
          isSet: false,
          updatedAt: DateTime.now(),
        ),
      ];

  Future<List<SavedPlace>> loadPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        final defaults = _defaultPlaces();
        await saveAllPlaces(defaults);
        return defaults;
      }
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => SavedPlace.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultPlaces();
    }
  }

  Future<void> saveAllPlaces(List<SavedPlace> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(places.map((p) => p.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<void> savePlace(SavedPlace place) async {
    final places = await loadPlaces();
    final index = places.indexWhere((p) => p.id == place.id);
    if (index >= 0) {
      places[index] = place;
    } else {
      places.add(place);
    }
    await saveAllPlaces(places);
  }

  Future<void> clearPlace(String id) async {
    final places = await loadPlaces();
    final index = places.indexWhere((p) => p.id == id);
    if (index >= 0) {
      // If it's a default place, mark as unset
      if (['home', 'work', 'gym', 'school'].contains(id)) {
        places[index] = places[index].copyWith(
          isSet: false,
          address: null,
          customName: null,
          latitude: null,
          longitude: null,
          updatedAt: DateTime.now(),
        );
      } else {
        places.removeAt(index);
      }
      await saveAllPlaces(places);
    }
  }
}
