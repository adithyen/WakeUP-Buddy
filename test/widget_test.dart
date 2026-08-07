// ignore: unnecessary_import — kept for widget testing context
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:wakeup_buddy/app.dart';
import 'package:wakeup_buddy/core/services/permission_provider.dart';
import 'package:wakeup_buddy/core/services/permission_service.dart';

class _FakePermissionService extends PermissionService {
  @override
  Future<Map<Permission, PermissionStatus>> checkAll() async {
    return <Permission, PermissionStatus>{};
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<PermissionResult> requestBackgroundLocation() async => PermissionResult.denied;

  @override
  Future<PermissionResult> requestBatteryOptimization() async => PermissionResult.denied;

  @override
  Future<PermissionResult> requestExactAlarm() async => PermissionResult.denied;

  @override
  Future<PermissionResult> requestForegroundLocation() async => PermissionResult.denied;

  @override
  Future<PermissionResult> requestNotification() async => PermissionResult.denied;
}

class _TestPermissionNotifier extends PermissionStateNotifier {
  _TestPermissionNotifier()
      : super(_FakePermissionService()) {
    state = const PermissionState(
      foregroundLocation: false,
      backgroundLocation: false,
      notification: false,
      batteryOptimization: false,
      exactAlarm: false,
      locationServiceEnabled: true,
      onboardingCompleted: false,
      isLoading: false,
    );
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('renders the permissions onboarding gate', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionStateProvider.overrideWith((ref) => _TestPermissionNotifier()),
        ],
        child: const WakeUpBuddyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Permissions setup'), findsOneWidget);
    expect(find.text('Allow location access'), findsOneWidget);
    expect(find.text('Allow'), findsWidgets);
  });
}
