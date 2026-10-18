import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final permissionStateProvider = StateNotifierProvider<PermissionStateNotifier, PermissionState>((ref) {
  return PermissionStateNotifier(ref.read(permissionServiceProvider));
});

class PermissionState {
  static const String _foregroundKey = 'permission_foreground_location';
  static const String _backgroundKey = 'permission_background_location';
  static const String _notificationKey = 'permission_notification';
  static const String _batteryKey = 'permission_battery_optimization';
  static const String _exactAlarmKey = 'permission_exact_alarm';
  static const String _locationServiceKey = 'permission_location_service_enabled';
  static const String _onboardingCompleteKey = 'permission_onboarding_complete';

  final bool foregroundLocation;
  final bool backgroundLocation;
  final bool notification;
  final bool batteryOptimization;
  final bool exactAlarm;
  final bool locationServiceEnabled;
  final bool onboardingCompleted;
  final bool isLoading;

  const PermissionState({
    this.foregroundLocation = false,
    this.backgroundLocation = false,
    this.notification = false,
    this.batteryOptimization = false,
    this.exactAlarm = false,
    this.locationServiceEnabled = false,
    this.onboardingCompleted = false,
    this.isLoading = true,
  });

  factory PermissionState.fromPreferences(SharedPreferences prefs) {
    return PermissionState(
      foregroundLocation: prefs.getBool(_foregroundKey) ?? false,
      backgroundLocation: prefs.getBool(_backgroundKey) ?? false,
      notification: prefs.getBool(_notificationKey) ?? false,
      batteryOptimization: prefs.getBool(_batteryKey) ?? false,
      exactAlarm: prefs.getBool(_exactAlarmKey) ?? false,
      locationServiceEnabled: prefs.getBool(_locationServiceKey) ?? false,
      onboardingCompleted: prefs.getBool(_onboardingCompleteKey) ?? false,
      isLoading: true,
    );
  }

  bool get allCriticalGranted => foregroundLocation && backgroundLocation && notification;

  bool get allGranted => allCriticalGranted && batteryOptimization && exactAlarm;

  PermissionState copyWith({
    bool? foregroundLocation,
    bool? backgroundLocation,
    bool? notification,
    bool? batteryOptimization,
    bool? exactAlarm,
    bool? locationServiceEnabled,
    bool? onboardingCompleted,
    bool? isLoading,
  }) {
    return PermissionState(
      foregroundLocation: foregroundLocation ?? this.foregroundLocation,
      backgroundLocation: backgroundLocation ?? this.backgroundLocation,
      notification: notification ?? this.notification,
      batteryOptimization: batteryOptimization ?? this.batteryOptimization,
      exactAlarm: exactAlarm ?? this.exactAlarm,
      locationServiceEnabled: locationServiceEnabled ?? this.locationServiceEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool(_foregroundKey, foregroundLocation);
    await prefs.setBool(_backgroundKey, backgroundLocation);
    await prefs.setBool(_notificationKey, notification);
    await prefs.setBool(_batteryKey, batteryOptimization);
    await prefs.setBool(_exactAlarmKey, exactAlarm);
    await prefs.setBool(_locationServiceKey, locationServiceEnabled);
    await prefs.setBool(_onboardingCompleteKey, onboardingCompleted);
  }
}

class PermissionStateNotifier extends StateNotifier<PermissionState> {
  final PermissionService _service;

  PermissionStateNotifier(this._service) : super(const PermissionState()) {
    refresh();
  }

  Future<SharedPreferences> _prefs() async {
    return SharedPreferences.getInstance();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    final SharedPreferences prefs = await _prefs();
    final bool onboardingCompleted = prefs.getBool(PermissionState._onboardingCompleteKey) ?? false;
    Map<Permission, PermissionStatus> statuses = <Permission, PermissionStatus>{};
    bool locationServiceEnabled = false;

    try {
      statuses = await _service.checkAll();
      locationServiceEnabled = await _service.isLocationServiceEnabled();
    } catch (_) {
      statuses = <Permission, PermissionStatus>{};
      locationServiceEnabled = false;
    }

    state = PermissionState(
      foregroundLocation: statuses[Permission.locationWhenInUse]?.isGranted ?? false,
      backgroundLocation: statuses[Permission.locationAlways]?.isGranted ?? false,
      notification: statuses[Permission.notification]?.isGranted ?? false,
      batteryOptimization: statuses[Permission.ignoreBatteryOptimizations]?.isGranted ?? false,
      exactAlarm: statuses[Permission.scheduleExactAlarm]?.isGranted ?? false,
      locationServiceEnabled: locationServiceEnabled,
      onboardingCompleted: onboardingCompleted,
      isLoading: false,
    );

    await state.save(prefs);
  }

  Future<PermissionResult> requestForegroundLocation() async {
    final PermissionResult result = await _service.requestForegroundLocation();
    await refresh();
    return result;
  }

  Future<PermissionResult> requestBackgroundLocation() async {
    final PermissionResult result = await _service.requestBackgroundLocation();
    await refresh();
    return result;
  }

  Future<PermissionResult> requestNotification() async {
    final PermissionResult result = await _service.requestNotification();
    await refresh();
    return result;
  }

  Future<PermissionResult> requestBatteryOptimization() async {
    final PermissionResult result = await _service.requestBatteryOptimization();
    await refresh();
    return result;
  }

  Future<PermissionResult> requestExactAlarm() async {
    final PermissionResult result = await _service.requestExactAlarm();
    await refresh();
    return result;
  }

  Future<bool> openSettingsAndRefresh() async {
    final bool opened = await _service.openSettings();
    if (opened) {
      await refresh();
    }

    return opened;
  }

  Future<void> completeOnboarding() async {
    if (!state.foregroundLocation) {
      return;
    }

    state = state.copyWith(onboardingCompleted: true);
    final SharedPreferences prefs = await _prefs();
    await state.save(prefs);
  }
}