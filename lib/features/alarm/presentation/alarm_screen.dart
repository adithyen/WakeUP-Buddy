import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../alarm/providers/alarm_provider.dart';
import '../../tracking/providers/tracking_provider.dart';
import 'widgets/dismiss_slider.dart';

/// Full-screen alarm UI shown when the proximity threshold is reached.
///
/// Features:
///   • Renders over the lock screen (enabled via AndroidManifest flags set in Phase 7)
///   • Pulsing alarm bell icon (scale 1.0 → 1.15, looping)
///   • Destination name and remaining distance
///   • [DismissSlider] — requires >80 % drag to prevent pocket dismissal
///   • Snooze text button — silences alarm, tracking continues
///   • WillPopScope blocks hardware back button
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing scale animation for the alarm icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade-in for the whole screen content
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await ref.read(alarmOrchestratorProvider.notifier).dismissAlarm();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleSnooze() async {
    await ref.read(alarmOrchestratorProvider.notifier).snoozeAlarm();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(trackingProvider);
    final destination = tripState.destination;
    final distance = tripState.currentDistanceMeters;

    final String destinationName = destination?.name ?? 'Your Destination';
    final String distanceText = _formatDistance(distance);

    return PopScope(
      canPop: false, // block hardware back during alarm
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            // ── Animated background ────────────────────────────────────────
            _AnimatedBackground(pulseController: _pulseController),

            // ── Content ───────────────────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.xl,
                    vertical: AppDimensions.xxxl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      // Pulsing alarm icon
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0xFFFF9944),
                                Color(0xFFE17055),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.accentDanger.withAlpha(120),
                                blurRadius: 48,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.alarm_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Headline + destination
                      Column(
                        children: <Widget>[
                          const Text(
                            "You're Arriving!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: AppDimensions.xs),
                              Flexible(
                                child: Text(
                                  destinationName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.xxl),
                          // Distance hero number
                          Text(
                            distanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.0,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            'remaining',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),

                      // Dismiss + Snooze
                      Column(
                        children: <Widget>[
                          DismissSlider(
                            label: 'Slide to Dismiss',
                            onDismissed: _handleDismiss,
                          ),
                          const SizedBox(height: AppDimensions.xl),
                          TextButton.icon(
                            onPressed: _handleSnooze,
                            icon: const Icon(
                              Icons.snooze_rounded,
                              color: Colors.white60,
                              size: 20,
                            ),
                            label: const Text(
                              'Snooze (+500m)',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Background
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final AnimationController pulseController;

  const _AnimatedBackground({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (BuildContext context, Widget? _) {
        final double pulse = pulseController.value; // 0..1
        // Radial pulse: radius oscillates between 0.55 and 0.75
        final double radius = 0.55 + 0.20 * math.sin(pulse * math.pi);

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.25),
              radius: radius,
              colors: const <Color>[
                Color(0xFFE17055), // warm orange-red
                Color(0xFFB8480A), // deep amber
                Color(0xFF1A0A00), // near-black
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
