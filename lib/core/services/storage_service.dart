import 'dart:convert';

import 'package:hive/hive.dart';

import '../../features/alert_config/data/models/alert_settings.dart';

class StorageService {
  static const String _alertSettingsBoxName = 'alert_settings';
  static const String _settingsKey = 'current_settings';

  Future<void>? _initialization;

  Future<void> init() {
    _initialization ??= _initialize();
    return _initialization!;
  }

  Future<void> _initialize() async {
    if (!Hive.isBoxOpen(_alertSettingsBoxName)) {
      await Hive.openBox<String>(_alertSettingsBoxName);
    }
  }

  Future<void> saveAlertSettings(AlertSettings settings) async {
    await init();
    final Box<String> box = Hive.box<String>(_alertSettingsBoxName);
    await box.put(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<AlertSettings> loadAlertSettings() async {
    await init();
    final Box<String> box = Hive.box<String>(_alertSettingsBoxName);
    final String? encoded = box.get(_settingsKey);
    if (encoded == null || encoded.isEmpty) {
      return const AlertSettings();
    }

    return AlertSettings.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }
}