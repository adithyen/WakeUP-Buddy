class PlacesApiException implements Exception {
  final String message;

  const PlacesApiException(this.message);

  @override
  String toString() => message;
}