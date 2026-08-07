import 'package:uuid/uuid.dart';

import 'place_suggestion.dart';

class Destination {
  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final DateTime selectedAt;
  final PlaceSource source;

  const Destination({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.selectedAt,
    required this.source,
    this.description,
  });

  factory Destination.fromSuggestion(PlaceSuggestion suggestion) {
    return Destination(
      id: const Uuid().v4(),
      name: suggestion.name,
      description: suggestion.description,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      selectedAt: DateTime.now(),
      source: suggestion.source,
    );
  }
}