enum PlaceType {
  temple,
  college,
  hospital,
  shopping,
  transit,
  busStop,
  trainStation,
  metroStation,
  airport,
  landmark,
  address,
  other,
}

enum PlaceSource { ola, nominatim }

class PlaceSuggestion {
  final String placeId;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String? formattedAddress;
  final PlaceType type;
  final PlaceSource source;
  final int? distanceMeters;
  final int? durationSeconds;
  final bool isFavorite;

  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.source,
    this.formattedAddress,
    this.distanceMeters,
    this.durationSeconds,
    this.isFavorite = false,
  });

  PlaceSuggestion copyWith({
    String? placeId,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    PlaceType? type,
    PlaceSource? source,
    int? distanceMeters,
    int? durationSeconds,
    bool? isFavorite,
  }) {
    return PlaceSuggestion(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      type: type ?? this.type,
      source: source ?? this.source,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}