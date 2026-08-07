import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:wakeup_buddy/core/services/battery_optimization_helper.dart';
import 'package:wakeup_buddy/core/services/permission_service.dart';

void main() {
  test('maps permission handler statuses to permission results', () {
    expect(PermissionService.mapStatus(PermissionStatus.granted), PermissionResult.granted);
    expect(PermissionService.mapStatus(PermissionStatus.limited), PermissionResult.granted);
    expect(PermissionService.mapStatus(PermissionStatus.denied), PermissionResult.denied);
    expect(
      PermissionService.mapStatus(PermissionStatus.permanentlyDenied),
      PermissionResult.permanentlyDenied,
    );
    expect(PermissionService.mapStatus(PermissionStatus.restricted), PermissionResult.restricted);
  });

  test('returns battery optimization advice for known manufacturers', () {
    expect(
      BatteryOptimizationHelper.instructionsForManufacturer('Samsung'),
      isNotNull,
    );
    expect(BatteryOptimizationHelper.instructionsForManufacturer('unknown'), isNull);
  });
}