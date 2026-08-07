abstract final class ApiConstants {
  static const String olaBaseUrl = 'https://api.olamaps.io';

  // ── Map Tiles ─────────────────────────────────────────────────────────────
  // Custom dark style created in Ola Maps Style Editor
  static const String olaCustomStyleId   = 'Style1-Dark';
  static const String olaTilesCustomDark =
      '$olaBaseUrl/tiles/v1/styles/$olaCustomStyleId/tiles/{z}/{x}/{y}.png';
  // Built-in styles (fallback options)
  static const String olaTilesLight =
      '$olaBaseUrl/tiles/v1/styles/default-light/tiles/{z}/{x}/{y}.png';
  static const String olaTilesDark =
      '$olaBaseUrl/tiles/v1/styles/default-dark/tiles/{z}/{x}/{y}.png';

  // ── Places APIs ───────────────────────────────────────────────────────────
  static const String olaAutocomplete    = '$olaBaseUrl/places/v1/autocomplete';
  static const String olaReverseGeocode  = '$olaBaseUrl/places/v1/reverse-geocode';
  static const String olaGeocode         = '$olaBaseUrl/places/v1/geocode';
  static const String olaPlaceDetails    = '$olaBaseUrl/places/v1/details';
  static const String olaNearbySearch    = '$olaBaseUrl/places/v1/nearbysearch';

  // ── Routing APIs ──────────────────────────────────────────────────────────
  static const String olaDirections      = '$olaBaseUrl/routing/v1/directions';
  static const String olaDirectionsBasic = '$olaBaseUrl/routing/v1/directions/basic';
  static const String olaDistanceMatrix  = '$olaBaseUrl/routing/v1/distanceMatrix';
  static const String olaRouteOptimizer  = '$olaBaseUrl/routing/v1/routeOptimizer';

  // ── Roads APIs ────────────────────────────────────────────────────────────
  static const String olaSnapToRoad      = '$olaBaseUrl/roads/v1/snapToRoads';
  static const String olaNearestRoads    = '$olaBaseUrl/roads/v1/nearestRoads';
  static const String olaSpeedLimits     = '$olaBaseUrl/roads/v1/speedLimits';

  // ── Fallback (OpenStreetMap / Nominatim geocoding) ────────────────────────
  static const String osmTiles         = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmDarkTiles     =
      'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
  // Nominatim geocoding (fallback when Ola Maps key not set)
  static const String nominatimSearch  = 'https://nominatim.openstreetmap.org/search';
  static const String nominatimReverse = 'https://nominatim.openstreetmap.org/reverse';

  // ── Storage keys ──────────────────────────────────────────────────────────
  static const String olaApiKeyStorageKey = 'ola_maps_api_key';
}