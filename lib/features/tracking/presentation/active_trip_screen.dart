import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/sensor_speed_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../destination/providers/destination_provider.dart';
import '../../destination/providers/route_selection_provider.dart';
import '../data/models/trip_state.dart';
import '../providers/tracking_provider.dart';
import 'widgets/gps_status_banner.dart';
import 'widgets/hud_speedometer.dart';
import 'widgets/trip_cancel_dialog.dart';
import 'widgets/trip_map_view.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;

  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _glowAnim = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<TripState>(
        trackingProvider,
        (TripState? previous, TripState next) {
          if (next.status == TripStatus.idle && !_navigated && mounted) {
            _navigated = true;
            ref.read(selectedDestinationProvider.notifier).clear();
            ref.read(routeSelectionProvider.notifier).clear();
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final bool confirmed = await showCancelTripDialog(context);
    if (confirmed && mounted) {
      await ref.read(trackingProvider.notifier).stopTrip();
      ref.read(selectedDestinationProvider.notifier).clear();
      ref.read(routeSelectionProvider.notifier).clear();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final TripState trip = ref.watch(trackingProvider);
    final SpeedTelemetryState speedTelemetry = ref.watch(speedTelemetryProvider);
    final double liveSpeedKmh = speedTelemetry.speedKmh;
    final MotionPhase motionPhase = speedTelemetry.motionPhase;
    final bool isDark = context.isDarkMode;
    final Color accent = context.appAccent;

    final bool isApproaching = trip.status == TripStatus.approaching ||
        trip.status == TripStatus.alerting;

    if (isApproaching && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!isApproaching && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.reset();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, _) {
          if (!didPop) _onWillPop();
        },
        child: Scaffold(
          backgroundColor: context.appBackground,
          body: Stack(
            children: <Widget>[
              // 1. FULL-SCREEN MAP
              const Positioned.fill(child: TripMapView()),

              // 2. RADIAL GLOW FOR APPROACHING / ARRIVING
              if (isApproaching)
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (BuildContext context, Widget? _) => Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 1.4,
                            colors: <Color>[
                              accent.withValues(
                                alpha: _glowAnim.value * 0.25,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. GPS STATUS / DIVERSION BANNER
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GpsStatusBanner(
                      isVisible: trip.gpsSignalLost,
                      message: trip.gpsLostMessage ??
                          'GPS signal lost — tracking continues with last known location.',
                    ),
                    GpsStatusBanner(
                      isVisible: !trip.gpsSignalLost && trip.gpsJustRecovered,
                      message: 'GPS signal restored ✅',
                      isError: false,
                    ),
                    if (trip.isOffRoute)
                      Container(
                        margin: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 60,
                          left: 20,
                          right: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.orangeWarning.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.alt_route_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Route diversion detected. Updating route...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 4. TOP TRACKING FLOATING CAPSULE
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                child: _TopTrackingBar(
                  destinationName: trip.destination?.name ?? 'Active Destination',
                  accentColor: accent,
                  onBack: _onWillPop,
                ),
              ),

              // 5. HUD SPEEDOMETER
              Positioned(
                left: 20,
                bottom: 215,
                child: HudSpeedometer(
                  speedKmh: liveSpeedKmh,
                  motionPhase: motionPhase,
                ),
              ),

              // 6. MAP ACTION BUTTONS
              Positioned(
                right: 20,
                bottom: 215,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundMapFab(
                      icon: Icons.layers_rounded,
                      accentColor: accent,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _RoundMapFab(
                      icon: Icons.my_location_rounded,
                      accentColor: accent,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              // 7. BOTTOM METRIC CARD
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ActiveTripBottomCard(
                  trip: trip,
                  accentColor: accent,
                  onCancel: _onWillPop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar matching Designs/Active_trip.png
// ─────────────────────────────────────────────────────────────────────────────

class _TopTrackingBar extends StatelessWidget {
  final String destinationName;
  final Color accentColor;
  final Future<bool> Function() onBack;

  const _TopTrackingBar({
    required this.destinationName,
    required this.accentColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.appCard.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.appTextPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Location pin in accent color
          Icon(
            Icons.location_on_rounded,
            color: accentColor,
            size: 20,
          ),
          const SizedBox(width: 6),

          // Destination title
          Expanded(
            child: Text(
              destinationName,
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),

          // TRACKING badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor,
                width: 1.2,
              ),
            ),
            child: Text(
              'TRACKING',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Map Circular Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _RoundMapFab extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoundMapFab({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.appCard.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: accentColor, size: 22),
        onPressed: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sliding Card matching Designs/Active_trip.png
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveTripBottomCard extends StatelessWidget {
  final TripState trip;
  final Color accentColor;
  final Future<bool> Function() onCancel;

  const _ActiveTripBottomCard({
    required this.trip,
    required this.accentColor,
    required this.onCancel,
  });

  String _formatETA() {
    final dur = trip.estimatedTimeRemaining;
    if (dur != null) {
      if (dur.inMinutes >= 60) {
        return '${dur.inHours}h ${dur.inMinutes % 60}m';
      }
      return '${dur.inMinutes} min';
    }
    return '-- min';
  }

  String _formatDistance() {
    final meters = trip.currentDistanceMeters;
    if (meters != null) {
      if (meters < 1000) {
        return '${meters.toInt()} m';
      }
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '-- km';
  }

  @override
  Widget build(BuildContext context) {
    final alertRadius = trip.alertSettings?.alertRadiusMeters.toInt() ?? 500;

    return Container(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.5 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Destination name with accent pin
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.destination?.name ?? 'Active Destination',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 4-Column Metric Grid matching Designs/Active_trip.png
          Row(
            children: [
              // Column 1: ETA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: accentColor, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          'ETA',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatETA(),
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Container(width: 1, height: 38, color: context.appBorder),

              // Column 2: Distance
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.alt_route_rounded, color: accentColor, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            'Distance',
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDistance(),
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(width: 1, height: 38, color: context.appBorder),

              // Column 3: Alert at
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFD600), size: 15),
                          const SizedBox(width: 4),
                          Text(
                            'Alert at',
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$alertRadius m',
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(width: 1, height: 38, color: context.appBorder),

              // Column 4: Cancel Trip
              Expanded(
                child: InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.stop_circle_outlined,
                          color: AppColors.coralAlert,
                          size: 24,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Cancel Trip',
                          style: TextStyle(
                            color: AppColors.coralAlert,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
