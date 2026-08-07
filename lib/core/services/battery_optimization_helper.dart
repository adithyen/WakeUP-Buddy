import 'package:device_info_plus/device_info_plus.dart';

class BatteryOptimizationHelper {
  static Future<String?> getDeviceSpecificInstructions() async {
    final String manufacturer = (await DeviceInfoPlugin().androidInfo).manufacturer.toLowerCase();
    return instructionsForManufacturer(manufacturer);
  }

  static String? instructionsForManufacturer(String? manufacturer) {
    final String normalized = manufacturer?.toLowerCase().trim() ?? '';

    return switch (normalized) {
      'samsung' => 'Go to Settings > Battery > Background usage limits and remove WakeUp Buddy.',
      'xiaomi' || 'redmi' || 'poco' => 'Go to Settings > Battery > App Battery Saver and set WakeUp Buddy to No restrictions.',
      'oneplus' => 'Go to Settings > Battery > Battery optimization and choose Don\'t optimize for WakeUp Buddy.',
      'huawei' || 'honor' => 'Go to Settings > Battery > App launch and enable Manage manually for WakeUp Buddy.',
      'oppo' || 'realme' => 'Go to Settings > Battery > More settings and disable battery optimization for WakeUp Buddy.',
      'vivo' => 'Go to Settings > Battery > Background power consumption management and disable restrictions for WakeUp Buddy.',
      _ => null,
    };
  }
}