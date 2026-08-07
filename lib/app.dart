import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/accent_color_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/alarm/presentation/alarm_screen.dart';
import 'features/alarm/providers/alarm_provider.dart';
import 'features/permissions/presentation/permission_gate.dart';

/// Global navigator key so the alarm orchestrator can push AlarmScreen
/// without requiring a BuildContext in the provider.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class WakeUpBuddyApp extends ConsumerStatefulWidget {
  const WakeUpBuddyApp({super.key});

  @override
  ConsumerState<WakeUpBuddyApp> createState() => _WakeUpBuddyAppState();
}

class _WakeUpBuddyAppState extends ConsumerState<WakeUpBuddyApp> {
  bool _alarmScreenVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<AlarmState>(
        alarmOrchestratorProvider,
        (AlarmState? previous, AlarmState next) {
          if (next.phase == AlarmPhase.sounding && !_alarmScreenVisible) {
            _showAlarmScreen();
          }
          if (next.phase == AlarmPhase.dismissed || next.phase == AlarmPhase.idle) {
            _alarmScreenVisible = false;
          }
        },
      );
    });
  }

  void _showAlarmScreen() {
    _alarmScreenVisible = true;
    appNavigatorKey.currentState?.push<void>(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (BuildContext context, Animation<double> animation, _) =>
            FadeTransition(opacity: animation, child: const AlarmScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeOption themeOption = ref.watch(themeProvider);
    final Color accent = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'WakeUp Buddy',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.buildLightTheme(accent),
      darkTheme: AppTheme.buildDarkTheme(accent),
      themeMode: themeOption.themeMode,
      home: const PermissionGate(),
    );
  }
}