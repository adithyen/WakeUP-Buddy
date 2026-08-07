import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/battery_optimization_helper.dart';
import '../../../core/services/permission_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/permission_rationale_sheet.dart';

enum _PermissionStepType { foregroundLocation, backgroundLocation, notification, batteryOptimization, exactAlarm }

class _PermissionStep {
  final _PermissionStepType type;
  final IconData icon;
  final String title;
  final String description;
  final bool canSkip;
  final bool critical;

  const _PermissionStep({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    required this.canSkip,
    required this.critical,
  });
}

class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends ConsumerState<PermissionOnboardingScreen> {
  static const List<_PermissionStep> _steps = <_PermissionStep>[
    _PermissionStep(
      type: _PermissionStepType.foregroundLocation,
      icon: Icons.my_location_rounded,
      title: 'Allow location access',
      description: 'WakeUp Buddy uses your location to estimate how far you are from your destination stop.',
      canSkip: false,
      critical: true,
    ),
    _PermissionStep(
      type: _PermissionStepType.backgroundLocation,
      icon: Icons.screen_lock_rotation_rounded,
      title: 'Allow background tracking',
      description: 'Keep tracking active when the phone is in your pocket or the screen is off.',
      canSkip: true,
      critical: true,
    ),
    _PermissionStep(
      type: _PermissionStepType.notification,
      icon: Icons.notifications_active_rounded,
      title: 'Enable notifications',
      description: 'We show a persistent notification while tracking so Android keeps the service alive.',
      canSkip: false,
      critical: true,
    ),
    _PermissionStep(
      type: _PermissionStepType.batteryOptimization,
      icon: Icons.battery_saver_rounded,
      title: 'Disable battery optimization',
      description: 'Some phones aggressively stop background work. This helps WakeUp Buddy stay reliable.',
      canSkip: true,
      critical: false,
    ),
    _PermissionStep(
      type: _PermissionStepType.exactAlarm,
      icon: Icons.alarm_rounded,
      title: 'Allow exact alarms',
      description: 'Exact alarms keep wake-up timing precise when your destination is approaching.',
      canSkip: true,
      critical: false,
    ),
  ];

  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestCurrentStep() async {
    final PermissionStateNotifier notifier = ref.read(permissionStateProvider.notifier);
    final _PermissionStep step = _steps[_pageIndex];

    final PermissionResult result = switch (step.type) {
      _PermissionStepType.foregroundLocation => await notifier.requestForegroundLocation(),
      _PermissionStepType.backgroundLocation => await notifier.requestBackgroundLocation(),
      _PermissionStepType.notification => await notifier.requestNotification(),
      _PermissionStepType.batteryOptimization => await notifier.requestBatteryOptimization(),
      _PermissionStepType.exactAlarm => await notifier.requestExactAlarm(),
    };

    if (!mounted) {
      return;
    }

    if (result == PermissionResult.granted) {
      if (step.type == _PermissionStepType.batteryOptimization) {
        final String? instructions = await BatteryOptimizationHelper.getDeviceSpecificInstructions();
        if (instructions != null && mounted) {
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: false,
            isScrollControlled: true,
            builder: (BuildContext context) => PermissionRationaleSheet(
              icon: Icons.tips_and_updates_rounded,
              title: 'Device-specific guidance',
              message: instructions,
              primaryLabel: 'Got it',
              onPrimary: () => Navigator.of(context).pop(),
            ),
          );
        }
      }

      await _advanceOrFinish();
      return;
    }

    if (result == PermissionResult.permanentlyDenied) {
      await _showDeniedSheet(
        title: 'Permission permanently denied',
        message: 'Android will not show the permission dialog again. Open settings and turn it on manually.',
        onPrimary: () async {
          Navigator.of(context).pop();
          await notifier.openSettingsAndRefresh();
        },
        primaryLabel: 'Open Settings',
      );
      return;
    }

    await _showDeniedSheet(
      title: 'Permission needed',
      message: step.critical
          ? 'This permission is required for the app to work correctly.'
          : 'You can continue without this permission, but the experience will be less reliable.',
      onPrimary: () => Navigator.of(context).pop(),
      primaryLabel: 'Try Again',
      secondaryLabel: step.canSkip ? 'Skip for now' : null,
      onSecondary: step.canSkip
          ? () {
              Navigator.of(context).pop();
              _advanceOrFinish();
            }
          : null,
    );
  }

  Future<void> _advanceOrFinish() async {
    if (_pageIndex >= _steps.length - 1) {
      await ref.read(permissionStateProvider.notifier).completeOnboarding();
      return;
    }

    _goNext();
  }

  Future<void> _showDeniedSheet({
    required String title,
    required String message,
    required VoidCallback onPrimary,
    required String primaryLabel,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) => PermissionRationaleSheet(
        icon: Icons.warning_rounded,
        title: title,
        message: message,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      ),
    );
  }

  void _goNext() {
    if (_pageIndex >= _steps.length - 1) {
      return;
    }

    setState(() {
      _pageIndex += 1;
    });
    _pageController.animateToPage(
      _pageIndex,
      duration: AppDimensions.animMedium,
      curve: Curves.easeOutCubic,
    );
  }

  void _goPrevious() {
    if (_pageIndex == 0) {
      return;
    }

    setState(() {
      _pageIndex -= 1;
    });
    _pageController.animateToPage(
      _pageIndex,
      duration: AppDimensions.animMedium,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildProgressDots(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(_steps.length, (int index) {
        final bool selected = index == _pageIndex;
        return AnimatedContainer(
          duration: AppDimensions.animFast,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : colorScheme.outline,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PermissionState permissionState = ref.watch(permissionStateProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.brightness == Brightness.dark
                ? const [AppColors.darkBackground, AppColors.darkSurface]
                : const [AppColors.lightBackground, AppColors.lightSurface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.xl,
                  AppDimensions.xl,
                  AppDimensions.xl,
                  AppDimensions.lg,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: AppDimensions.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Permissions setup', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'We ask for these permissions in order so tracking and alerts work reliably.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _steps.length,
                  onPageChanged: (int index) {
                    setState(() {
                      _pageIndex = index;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _PermissionStep step = _steps[index];
                    final bool granted = switch (step.type) {
                      _PermissionStepType.foregroundLocation => permissionState.foregroundLocation,
                      _PermissionStepType.backgroundLocation => permissionState.backgroundLocation,
                      _PermissionStepType.notification => permissionState.notification,
                      _PermissionStepType.batteryOptimization => permissionState.batteryOptimization,
                      _PermissionStepType.exactAlarm => permissionState.exactAlarm,
                    };

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Icon(step.icon, size: 56, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: AppDimensions.xxl),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppDimensions.xl),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.lg,
                              vertical: AppDimensions.md,
                            ),
                            decoration: BoxDecoration(
                              color: granted
                                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            child: Text(
                              granted ? 'Already granted' : step.critical ? 'Required' : 'Optional',
                              style: theme.textTheme.labelLarge?.copyWith(
                                    color: granted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
                child: Column(
                  children: [
                    _buildProgressDots(theme.colorScheme),
                    const SizedBox(height: AppDimensions.lg),
                    AppButton(
                      label: _steps[_pageIndex].critical ? 'Allow' : 'Allow or continue',
                      icon: Icons.check_circle_rounded,
                      onPressed: _requestCurrentStep,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      children: [
                        if (_pageIndex > 0)
                          Expanded(
                            child: AppButton(
                              label: 'Back',
                              variant: AppButtonVariant.ghost,
                              onPressed: _goPrevious,
                            ),
                          ),
                        if (_pageIndex > 0) const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: AppButton(
                            label: _pageIndex == _steps.length - 1
                                ? 'Finish'
                                : (_steps[_pageIndex].canSkip ? 'Skip' : 'Continue'),
                            variant: _steps[_pageIndex].canSkip ? AppButtonVariant.secondary : AppButtonVariant.primary,
                            onPressed: _steps[_pageIndex].canSkip
                                ? _advanceOrFinish
                                : _requestCurrentStep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}