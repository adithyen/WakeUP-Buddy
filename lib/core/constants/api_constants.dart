abstract final class ApiConstants {
  static const String defaultOlaApiKey =
      'CFuHbUzDL9ntSuuVkAg3rowBOA3vf7bhZotfvRdy';

  static const String olaBaseUrl = 'https://api.olamaps.io';

  // Places APIs
  static const String olaAutocomplete = '$olaBaseUrl/places/v1/autocomplete';
  static const String olaPlaceDetails = '$olaBaseUrl/places/v1/details';
  static const String olaNearbySearch = '$olaBaseUrl/places/v1/nearbysearch';
  static const String olaReverseGeocode =
      '$olaBaseUrl/places/v1/reverse-geocode';
  static const String olaGeocode = '$olaBaseUrl/places/v1/geocode';

  // Routing & Roads APIs
  static const String olaDirections = '$olaBaseUrl/routing/v1/directions';
  static const String olaDirectionsBasic =
      '$olaBaseUrl/routing/v1/directions/basic';
  static const String olaDistanceMatrix =
      '$olaBaseUrl/routing/v1/distanceMatrix';
  static const String olaNearestRoads = '$olaBaseUrl/routing/v1/nearestRoads';
  static const String olaSnapToRoad = '$olaBaseUrl/routing/v1/snapToRoad';

  // Vector Styles (MapLibre style.json)
  static const String olaVectorStyleDark =
      '$olaBaseUrl/tiles/vector/v1/styles/default-dark-standard/style.json';
  static const String olaVectorStyleLight =
      '$olaBaseUrl/tiles/vector/v1/styles/default-light-standard/style.json';
  static const String olaVectorStyleSatellite =
      '$olaBaseUrl/tiles/vector/v1/styles/default-dark-standard-satellite/style.json';

  /// The Ola native SDK needs the key on the style request as well as in
  /// getMap(). Without it, nested style resources can be rejected and the
  /// native view appears as a blank/grey map.
  static String olaStyleUrlWithApiKey(String styleUrl, String apiKey) {
    if (apiKey.isEmpty || styleUrl.contains('?')) return styleUrl;
    return '$styleUrl?api_key=${Uri.encodeQueryComponent(apiKey)}';
  }

  // High-performance raster tile endpoints (CartoDB & OpenStreetMap)
  static const String cartoDarkTiles =
      'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
  static const String cartoLightTiles =
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String cartoDarkSubdomainTiles =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
  static const String cartoLightSubdomainTiles =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String olaTilesLight = cartoLightTiles;
  static const String olaTilesDark = cartoDarkTiles;

  // OpenStreetMap fallback styles
  static const String osmStyle = 'https://tiles.openfreemap.org/styles/bright';
  static const String osmDarkStyle =
      'https://tiles.openfreemap.org/styles/dark';
  static const String osmTiles =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // OpenStreetMap Nominatim Fallbacks
  static const String nominatimSearch =
      'https://nominatim.openstreetmap.org/search';
  static const String nominatimReverse =
      'https://nominatim.openstreetmap.org/reverse';

  // Storage Keys
  static const String olaApiKeyStorageKey = 'ola_maps_api_key';
  static const String olaCustomStyleStorageKey = 'ola_maps_custom_style';
}
