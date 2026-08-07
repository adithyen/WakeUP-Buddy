enum PlaceType {
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

  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.source,
    this.formattedAddress,
  });
}