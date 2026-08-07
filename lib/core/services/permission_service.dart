import 'package:permission_handler/permission_handler.dart';

enum PermissionResult { granted, denied, permanentlyDenied, restricted }

class PermissionService {
  static const List<Permission> criticalPermissions = <Permission>[
    Permission.locationWhenInUse,
    Permission.locationAlways,
    Permission.notification,
  ];

  static const List<Permission> allPermissions = <Permission>[
    Permission.locationWhenInUse,
    Permission.locationAlways,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
    Permission.scheduleExactAlarm,
  ];

  Future<Map<Permission, PermissionStatus>> checkAll() async {
    final Map<Permission, PermissionStatus> statuses = <Permission, PermissionStatus>{};

    for (final Permission permission in allPermissions) {
      statuses[permission] = await permission.status;
    }

    return statuses;
  }

  Future<Map<Permission, PermissionStatus>> checkCritical() async {
    final Map<Permission, PermissionStatus> statuses = <Permission, PermissionStatus>{};

    for (final Permission permission in criticalPermissions) {
      statuses[permission] = await permission.status;
    }

    return statuses;
  }

  Future<List<Permission>> missingPermissions(List<Permission> required) async {
    final List<Permission> missing = <Permission>[];

    for (final Permission permission in required) {
      if (!await permission.isGranted) {
        missing.add(permission);
      }
    }

    return missing;
  }

  Future<PermissionResult> requestForegroundLocation() async {
    final PermissionStatus status = await Permission.locationWhenInUse.request();
    return mapStatus(status);
  }

  Future<PermissionResult> requestBackgroundLocation() async {
    if (!await Permission.locationWhenInUse.isGranted) {
      return PermissionResult.denied;
    }

    final PermissionStatus status = await Permission.locationAlways.request();
    return mapStatus(status);
  }

  Future<PermissionResult> requestNotification() async {
    final PermissionStatus status = await Permission.notification.request();
    return mapStatus(status);
  }

  Future<PermissionResult> requestBatteryOptimization() async {
    final PermissionStatus status = await Permission.ignoreBatteryOptimizations.request();
    return mapStatus(status);
  }

  Future<PermissionResult> requestExactAlarm() async {
    final PermissionStatus status = await Permission.scheduleExactAlarm.request();
    return mapStatus(status);
  }

  Future<bool> isLocationServiceEnabled() async {
    final ServiceStatus serviceStatus = await Permission.locationWhenInUse.serviceStatus;
    return serviceStatus.isEnabled;
  }

  Future<bool> openSettings() async {
    return openAppSettings();
  }

  Future<bool> hasAllCriticalPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await checkCritical();
    return statuses.values.every((PermissionStatus status) => status.isGranted || status.isLimited);
  }

  static PermissionResult mapStatus(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted || PermissionStatus.limited => PermissionResult.granted,
      PermissionStatus.permanentlyDenied => PermissionResult.permanentlyDenied,
      PermissionStatus.restricted => PermissionResult.restricted,
      _ => PermissionResult.denied,
    };
  }
}