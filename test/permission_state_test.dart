import 'package:flutter_test/flutter_test.dart';

import 'package:wakeup_buddy/core/services/permission_provider.dart';

void main() {
  test('permission state derives critical and total completion correctly', () {
    const PermissionState initial = PermissionState(
      foregroundLocation: true,
      backgroundLocation: true,
      notification: true,
      batteryOptimization: false,
      exactAlarm: false,
      locationServiceEnabled: true,
      onboardingCompleted: false,
      isLoading: false,
    );

    expect(initial.allCriticalGranted, isTrue);
    expect(initial.allGranted, isFalse);

    final PermissionState completed = initial.copyWith(
      batteryOptimization: true,
      exactAlarm: true,
      onboardingCompleted: true,
    );

    expect(completed.allGranted, isTrue);
    expect(completed.onboardingCompleted, isTrue);
  });
}