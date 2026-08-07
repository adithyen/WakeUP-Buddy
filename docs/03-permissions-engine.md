# Phase 03 — Permissions Engine

> **Goal:** Build a robust, user-friendly permission request flow that handles all required Android permissions with graceful degradation, clear rationale dialogs, and persistent state tracking.  
> **Dependencies:** Phase 01  
> **Deliverable:** All permissions (location, notification, battery) granted with proper UX flow; denied permissions show rationale and settings redirect.

---

## 3.1 — Permission Inventory

### 3.1.1 Required Permissions Matrix

| Permission | Android API | When Needed | Criticality | Fallback if Denied |
|------------|-------------|-------------|-------------|-------------------|
| `ACCESS_FINE_LOCATION` | All | Map, tracking | **Critical** | App cannot function |
| `ACCESS_COARSE_LOCATION` | All | Fallback | Important | Reduced accuracy |
| `ACCESS_BACKGROUND_LOCATION` | 29+ | Background tracking | **Critical** | Must request separately after foreground |
| `FOREGROUND_SERVICE` | 26+ | Keep-alive service | **Critical** | Auto-granted on older APIs |
| `FOREGROUND_SERVICE_LOCATION` | 34+ (14+) | Service type declaration | **Critical** | Manifest-only, no runtime prompt |
| `POST_NOTIFICATIONS` | 33+ (13+) | Foreground service notification | **Critical** | No notification channel |
| `WAKE_LOCK` | All | Screen wake on alarm | Important | Manifest-only, auto-granted |
| `VIBRATE` | All | Vibration alert | Important | Manifest-only, auto-granted |
| `USE_FULL_SCREEN_INTENT` | 34+ (14+) | Alarm over lock screen | **Critical** | Must check & request on 14+ |
| `SCHEDULE_EXACT_ALARM` | 31+ (12+) | Precise alarm scheduling | Important | Use inexact alarm fallback |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | All | Prevent OEM killing service | Important | User education fallback |
| `INTERNET` | All | Map tiles, API calls | Required | Manifest-only |

### 3.1.2 Permission Request Order
Permissions must be requested in a specific sequence due to Android restrictions:

```
1. Location (foreground) → ACCESS_FINE_LOCATION
       ↓ (granted)
2. Background Location → ACCESS_BACKGROUND_LOCATION
       ↓ (granted or skipped)
3. Notifications → POST_NOTIFICATIONS (Android 13+)
       ↓
4. Battery Optimization → REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
       ↓
5. Exact Alarm → SCHEDULE_EXACT_ALARM (Android 12+)
       ↓
6. Full Screen Intent → USE_FULL_SCREEN_INTENT (Android 14+)
```

> ⚠️ **Android Rule:** `ACCESS_BACKGROUND_LOCATION` can ONLY be requested AFTER `ACCESS_FINE_LOCATION` is already granted. Requesting both simultaneously will silently fail.

---

## 3.2 — Permission Service

### 3.2.1 Core Service — `lib/core/services/permission_service.dart`

```dart
import 'package:permission_handler/permission_handler.dart';

enum PermissionResult { granted, denied, permanentlyDenied, restricted }

class PermissionService {
  /// Check current status of all required permissions
  Future<Map<Permission, PermissionStatus>> checkAll() async {
    return await [
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  /// Request foreground location permission
  Future<PermissionResult> requestForegroundLocation() async {
    final status = await Permission.locationWhenInUse.request();
    return _mapStatus(status);
  }

  /// Request background location (MUST be called after foreground is granted)
  Future<PermissionResult> requestBackgroundLocation() async {
    // Verify foreground is already granted
    final foreground = await Permission.locationWhenInUse.status;
    if (!foreground.isGranted) {
      return PermissionResult.denied;
    }

    final status = await Permission.locationAlways.request();
    return _mapStatus(status);
  }

  /// Request notification permission (Android 13+)
  Future<PermissionResult> requestNotification() async {
    final status = await Permission.notification.request();
    return _mapStatus(status);
  }

  /// Request battery optimization exemption
  Future<PermissionResult> requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return _mapStatus(status);
  }

  /// Request exact alarm permission (Android 12+)
  Future<PermissionResult> requestExactAlarm() async {
    final status = await Permission.scheduleExactAlarm.request();
    return _mapStatus(status);
  }

  /// Check if location services are enabled on device
  Future<bool> isLocationServiceEnabled() async {
    return await Permission.locationWhenInUse.serviceStatus.isEnabled;
  }

  /// Open app settings (for permanently denied permissions)
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Check if all critical permissions are granted
  Future<bool> hasAllCriticalPermissions() async {
    final location = await Permission.locationWhenInUse.isGranted;
    final bgLocation = await Permission.locationAlways.isGranted;
    final notification = await Permission.notification.isGranted;
    return location && bgLocation && notification;
  }

  PermissionResult _mapStatus(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted || PermissionStatus.limited => PermissionResult.granted,
      PermissionStatus.permanentlyDenied => PermissionResult.permanentlyDenied,
      PermissionStatus.restricted => PermissionResult.restricted,
      _ => PermissionResult.denied,
    };
  }
}
```

### 3.2.2 Permission State Provider — `lib/core/services/permission_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final permissionServiceProvider = Provider((ref) => PermissionService());

/// Tracks the overall permission state
final permissionStateProvider = StateNotifierProvider<PermissionStateNotifier, PermissionState>((ref) {
  return PermissionStateNotifier(ref.read(permissionServiceProvider));
});

class PermissionState {
  final bool foregroundLocation;
  final bool backgroundLocation;
  final bool notification;
  final bool batteryOptimization;
  final bool exactAlarm;
  final bool isLoading;

  const PermissionState({
    this.foregroundLocation = false,
    this.backgroundLocation = false,
    this.notification = false,
    this.batteryOptimization = false,
    this.exactAlarm = false,
    this.isLoading = true,
  });

  bool get allCriticalGranted =>
    foregroundLocation && backgroundLocation && notification;

  bool get allGranted =>
    allCriticalGranted && batteryOptimization && exactAlarm;

  PermissionState copyWith({...});
}
```

---

## 3.3 — Permission Onboarding Flow

### 3.3.1 Flow Architecture

```
┌──────────────────────────────────┐
│  App Launch                      │
│  Check: All permissions granted? │
└──────────────┬───────────────────┘
               │
        ┌──────┴──────┐
        │ Yes         │ No
        ▼             ▼
   Home Screen   Permission Onboarding
                      │
                      ▼
              ┌───────────────┐
              │ Step 1:       │
              │ Location      │    "We need your location to
              │ Permission    │     track your proximity to
              │               │     your destination stop"
              └───────┬───────┘
                      │
               ┌──────┴──────┐
               │ Granted     │ Denied
               ▼             ▼
          ┌──────────┐  Rationale Dialog
          │ Step 2:  │  → Retry or Skip
          │ Background│
          │ Location  │    "Allow 'All the time' to
          └────┬─────┘     keep tracking when your
               │           phone is in your pocket"
               ▼
          ┌──────────┐
          │ Step 3:  │
          │ Notifi-  │    "We need to show a
          │ cation   │     notification while
          └────┬─────┘     tracking your trip"
               │
               ▼
          ┌──────────┐
          │ Step 4:  │
          │ Battery  │    "Disable battery optimization
          │ Opt-out  │     so we don't lose track while
          └────┬─────┘     you sleep"
               │
               ▼
          ┌──────────┐
          │ Step 5:  │
          │ Exact    │    "Allow exact alarms to
          │ Alarm    │     wake you at precisely
          └────┬─────┘     the right moment"
               │
               ▼
           Home Screen
```

### 3.3.2 Onboarding Screen — `lib/features/permissions/presentation/permission_onboarding_screen.dart`

**Design spec:**
- Full-screen page view (swipeable)
- Each step has:
  - Large illustration/icon (animated)
  - Title text (headlineLarge)
  - Explanation text (bodyLarge, 2-3 sentences max)
  - "Allow" button (primary)
  - "Skip" text button (ghost) — only for non-critical permissions
- Progress dots at bottom
- Skip to home if all critical permissions already granted

### 3.3.3 Rationale Dialogs

When a permission is denied, show a contextual bottom sheet:

```
┌─────────────────────────────────┐
│        ⚠️ Location Required     │
│                                 │
│  WakeUp Buddy needs location    │
│  access to alert you when       │
│  you're near your destination.  │
│                                 │
│  Without this, the app cannot   │
│  function.                      │
│                                 │
│  ┌─────────────────────────┐    │
│  │   Open Settings          │    │
│  └─────────────────────────┘    │
│                                 │
│         Try Again               │
└─────────────────────────────────┘
```

### 3.3.4 Permanently Denied Handler
If a permission is permanently denied (user checked "Don't ask again"):
- Show explanation dialog
- "Open Settings" button → `openAppSettings()`
- On return from settings, re-check permission status
- Use `WidgetsBindingObserver.didChangeAppLifecycleState` to detect return

---

## 3.4 — Runtime Permission Checks

### 3.4.1 Guard Widget — `lib/core/widgets/permission_guard.dart`
A widget that wraps features requiring specific permissions:

```dart
class PermissionGuard extends ConsumerWidget {
  final Widget child;
  final List<Permission> required;
  final Widget Function(BuildContext, List<Permission> missing) onDenied;

  // If any required permission is not granted,
  // show onDenied widget instead of child
}
```

### 3.4.2 Pre-Trip Permission Check
Before starting a tracking session:
1. Re-verify all critical permissions
2. Check if location services are enabled
3. If any permission was revoked, show inline prompt
4. Only proceed to tracking if all checks pass

```dart
Future<bool> preStartChecks() async {
  // 1. Location service enabled?
  if (!await permissionService.isLocationServiceEnabled()) {
    // Show "Enable GPS" dialog
    return false;
  }

  // 2. Foreground location?
  if (!await Permission.locationWhenInUse.isGranted) {
    // Re-request
    return false;
  }

  // 3. Background location?
  if (!await Permission.locationAlways.isGranted) {
    // Show rationale + request
    return false;
  }

  // 4. Notification?
  if (!await Permission.notification.isGranted) {
    // Request
    return false;
  }

  return true;
}
```

---

## 3.5 — OEM Battery Killer Handling

### 3.5.1 The Problem
Android OEMs (Samsung, Xiaomi, Huawei, OnePlus, Oppo, Vivo) have aggressive battery management that kills background services even with foreground service running.

### 3.5.2 Solution: Device-Specific Guidance
After battery optimization exemption:
- Detect device manufacturer via `DeviceInfoPlugin`
- Show device-specific instructions:
  - **Samsung:** Settings → Battery → App Power Management → disable for WakeUp Buddy
  - **Xiaomi/MIUI:** Settings → Battery → App Battery Saver → No restrictions
  - **OnePlus/OxygenOS:** Settings → Battery → Battery optimization → Don't optimize
- Link to [dontkillmyapp.com](https://dontkillmyapp.com) for comprehensive guides

### 3.5.3 Implementation
```dart
class BatteryOptimizationHelper {
  static Future<String?> getDeviceSpecificInstructions() async {
    final manufacturer = (await DeviceInfoPlugin().androidInfo).manufacturer;
    return switch (manufacturer?.toLowerCase()) {
      'samsung' => 'Go to Settings → Battery → Background usage limits → Remove WakeUp Buddy',
      'xiaomi' || 'redmi' || 'poco' => 'Go to Settings → Battery → App Battery Saver → Set WakeUp Buddy to "No restrictions"',
      'oneplus' => 'Go to Settings → Battery → Battery optimization → Select WakeUp Buddy → Don\'t optimize',
      'huawei' || 'honor' => 'Go to Settings → Battery → App launch → Set WakeUp Buddy to "Manage manually" with all toggles ON',
      'oppo' || 'realme' => 'Go to Settings → Battery → More Settings → Optimize battery use → Disable for WakeUp Buddy',
      'vivo' => 'Go to Settings → Battery → Background power consumption management → Disable for WakeUp Buddy',
      _ => null,  // Generic advice
    };
  }
}
```

---

## 3.6 — Persistence & Recovery

### 3.6.1 Permission State Cache
Store last-known permission state in SharedPreferences:
- Track which permissions were previously granted
- Detect revocations on app resume
- Show targeted re-request dialogs

### 3.6.2 App Lifecycle Listener
```dart
class AppLifecyclePermissionChecker extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions
      // If critical permission was revoked during background:
      //   - Pause tracking if active
      //   - Show permission recovery dialog
    }
  }
}
```

---

## 3.7 — Testing

### 3.7.1 Unit Tests
- [ ] `PermissionService._mapStatus` correctly maps all `PermissionStatus` values
- [ ] `PermissionState.allCriticalGranted` returns correct boolean
- [ ] `PermissionState.copyWith` works correctly
- [ ] `BatteryOptimizationHelper` returns correct strings per manufacturer

### 3.7.2 Widget Tests
- [ ] `PermissionOnboardingScreen` displays correct step for each permission
- [ ] "Allow" button triggers correct permission request
- [ ] "Skip" button is hidden for critical permissions
- [ ] Rationale dialog shows when permission is denied
- [ ] "Open Settings" button calls `openAppSettings()`

### 3.7.3 Integration Tests (Manual — Physical Device)
- [ ] Fresh install → all permissions requested in correct order
- [ ] Deny foreground location → cannot proceed past step 1
- [ ] Deny background location → warning shown, can skip
- [ ] Kill app → relaunch → permissions remembered
- [ ] Revoke permission in system settings → re-request shown on resume

---

## ✅ Phase 03 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | All manifest permissions declared | AndroidManifest.xml has all 12 permissions |
| 2 | Permission onboarding flow works | Fresh install → onboarding → all granted |
| 3 | Denied permissions show rationale | Deny a permission → dialog appears |
| 4 | Permanently denied redirects to settings | Check "Don't ask again" → settings link works |
| 5 | Permission state persists | Kill/relaunch → doesn't re-ask granted permissions |
| 6 | Battery optimization guidance shown | Samsung/Xiaomi device → specific instructions |
| 7 | Pre-trip check catches revocations | Revoke in settings → alert shown before trip start |
| 8 | Background location requested after foreground | Correct sequence enforced |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| Background location request silently fails | MUST request `locationWhenInUse` first, get grant, THEN request `locationAlways` |
| Android 14 crashes on foreground service | Declare `android:foregroundServiceType="location"` in manifest |
| Permission dialog doesn't show twice | After permanent deny, must redirect to Settings |
| Battery optimization varies wildly by OEM | Use device detection + dontkillmyapp.com guidance |
| `POST_NOTIFICATIONS` crashes on API < 33 | Wrap in API version check, only request on 33+ |
