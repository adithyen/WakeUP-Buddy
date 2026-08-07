import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/permission_provider.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../home/presentation/home_screen.dart';
import 'permission_onboarding_screen.dart';

class PermissionGate extends ConsumerStatefulWidget {
  const PermissionGate({super.key});

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(permissionStateProvider.notifier).refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionStateProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PermissionState permissionState = ref.watch(permissionStateProvider);

    if (permissionState.isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    if (permissionState.allCriticalGranted && permissionState.onboardingCompleted) {
      return const HomeScreen();
    }

    return const PermissionOnboardingScreen();
  }
}