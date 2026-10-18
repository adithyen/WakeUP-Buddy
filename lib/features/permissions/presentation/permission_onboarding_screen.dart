import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/battery_optimization_helper.dart';
import '../../../core/services/permission_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/permission_rationale_sheet.dart';

/// Modern Permissions Dashboard adhering to 2026 UX & Taste standards.
/// Replaces the carousel with an in-place reactive dashboard that never resets on app resume.
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  bool _isRequesting = false;

  Future<void> _handlePermissionRequest(
    Future<PermissionResult> Function() requestFn,
    String title,
    String requiredRationale, {
    bool isBattery = false,
  }) async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    HapticFeedback.lightImpact();

    try {
      final result = await requestFn();

      if (!mounted) return;

      if (result == PermissionResult.granted) {
        HapticFeedback.mediumImpact();
        if (isBattery) {
          final instructions =
              await BatteryOptimizationHelper.getDeviceSpecificInstructions();
          if (instructions != null && mounted) {
            await showModalBottomSheet<void>(
              context: context,
              backgroundColor: context.appCard,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (ctx) => PermissionRationaleSheet(
                icon: Icons.tips_and_updates_rounded,
                title: 'Device Guidance',
                message: instructions,
                primaryLabel: 'Got It',
                onPrimary: () => Navigator.of(ctx).pop(),
              ),
            );
          }
        }
        return;
      }

      if (result == PermissionResult.permanentlyDenied) {
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: context.appCard,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => PermissionRationaleSheet(
            icon: Icons.settings_suggest_rounded,
            title: 'Permission Required in Settings',
            message:
                '$title is permanently denied. Tap below to open app settings and enable it.',
            primaryLabel: 'Open Settings',
            onPrimary: () {
              Navigator.of(ctx).pop();
              ref.read(permissionStateProvider.notifier).openSettingsAndRefresh();
            },
            secondaryLabel: 'Cancel',
            onSecondary: () => Navigator.of(ctx).pop(),
          ),
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionStateProvider);
    final notifier = ref.read(permissionStateProvider.notifier);
    final theme = Theme.of(context);
    final accent = context.appAccent;

    final int requiredGrantedCount = (permissionState.foregroundLocation ? 1 : 0) +
        (permissionState.notification ? 1 : 0);
    final bool canProceed = permissionState.foregroundLocation;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              'COMMUTE SHIELD',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.appCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.appBorder),
                        ),
                        child: Text(
                          '$requiredGrantedCount / 2 Required',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Permissions Setup',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'WakeUp Buddy requires precision telemetry to sound proximity alarms reliably while you rest.',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Cards List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _PermissionDashboardCard(
                    icon: Icons.my_location_rounded,
                    title: 'Location Access',
                    subtitle: 'Determines real-time distance to destination stop',
                    badge: 'REQUIRED',
                    isGranted: permissionState.foregroundLocation,
                    accentColor: accent,
                    onAllow: () => _handlePermissionRequest(
                      notifier.requestForegroundLocation,
                      'Location Access',
                      'Required for estimating distance to your stop.',
                    ),
                  ),
                  _PermissionDashboardCard(
                    icon: Icons.screen_lock_rotation_rounded,
                    title: 'Background Tracking',
                    subtitle: 'Allows commute alarms to ring while screen is locked',
                    badge: 'RECOMMENDED',
                    isGranted: permissionState.backgroundLocation,
                    accentColor: accent,
                    onAllow: () => _handlePermissionRequest(
                      notifier.requestBackgroundLocation,
                      'Background Tracking',
                      'Ensures tracking continues when phone is in pocket.',
                    ),
                  ),
                  _PermissionDashboardCard(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications',
                    subtitle: 'Keeps tracking service alive and displays status',
                    badge: 'REQUIRED',
                    isGranted: permissionState.notification,
                    accentColor: accent,
                    onAllow: () => _handlePermissionRequest(
                      notifier.requestNotification,
                      'Notifications',
                      'Required so Android does not kill the commute service.',
                    ),
                  ),
                  _PermissionDashboardCard(
                    icon: Icons.battery_saver_rounded,
                    title: 'Battery Optimization',
                    subtitle: 'Exempts app from aggressive OEM battery killing',
                    badge: 'RECOMMENDED',
                    isGranted: permissionState.batteryOptimization,
                    accentColor: accent,
                    onAllow: () => _handlePermissionRequest(
                      notifier.requestBatteryOptimization,
                      'Battery Optimization',
                      'Helps app stay alive on aggressive Android devices.',
                      isBattery: true,
                    ),
                  ),
                  _PermissionDashboardCard(
                    icon: Icons.alarm_rounded,
                    title: 'Exact Alarms',
                    subtitle: 'Fires wake-up alarms with sub-second accuracy',
                    badge: 'RECOMMENDED',
                    isGranted: permissionState.exactAlarm,
                    accentColor: accent,
                    onAllow: () => _handlePermissionRequest(
                      notifier.requestExactAlarm,
                      'Exact Alarms',
                      'Guarantees proximity alarm rings immediately on radius breach.',
                    ),
                  ),
                ],
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: AppButton(
                label: canProceed
                    ? 'Continue to WakeUp Buddy'
                    : 'Grant Location to Proceed',
                icon: canProceed ? Icons.arrow_forward_rounded : Icons.lock_open_rounded,
                variant: canProceed ? AppButtonVariant.primary : AppButtonVariant.secondary,
                onPressed: canProceed
                    ? () async {
                        HapticFeedback.selectionClick();
                        await notifier.completeOnboarding();
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool isGranted;
  final Color accentColor;
  final VoidCallback onAllow;

  const _PermissionDashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isGranted,
    required this.accentColor,
    required this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? accentColor.withValues(alpha: 0.28) : context.appBorder,
          width: 1.2,
        ),
        boxShadow: isGranted
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.06),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted
                  ? accentColor.withValues(alpha: 0.16)
                  : context.appBorder.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isGranted ? accentColor : context.appTextSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge == 'REQUIRED'
                            ? (isGranted
                                ? accentColor.withValues(alpha: 0.15)
                                : Colors.redAccent.withValues(alpha: 0.15))
                            : context.appBorder.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badge == 'REQUIRED'
                              ? (isGranted ? accentColor : Colors.redAccent)
                              : context.appTextTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    'Granted',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: onAllow,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Allow',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}