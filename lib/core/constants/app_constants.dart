/// Core application constants
class AppConstants {
  // App Metadata
  static const String appName = 'WakeUp Buddy';
  static const String appVersion = '1.0.0';

  // Location & Radius
  static const double defaultAlertRadiusMeters = 500;
  static const double minAlertRadiusMeters = 100;
  static const double maxAlertRadiusMeters = 2000;

  // API Keys & Endpoints (placeholder - load from secure config)
  static const String olaApiBaseUrl = 'https://api.olamaps.io';

  // Timing
  static const Duration locationUpdateInterval = Duration(seconds: 3);
  static const Duration gpsTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String keyDestinations = 'recent_destinations';
  static const String keyAlertRadius = 'alert_radius';
  static const String keyAlertSound = 'alert_sound';
  static const String keyTripHistory = 'trip_history';
}
