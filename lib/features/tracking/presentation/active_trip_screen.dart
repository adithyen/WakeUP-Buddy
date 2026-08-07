import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/accent_color_provider.dart';
import '../../alarm/providers/alarm_provider.dart';
import '../../home/providers/map_provider.dart';
import '../data/models/trip_state.dart';
import '../providers/tracking_provider.dart';
import 'trip_completed_screen.dart';
import 'widgets/gps_status_banner.dart';
import 'widgets/trip_cancel_dialog.dart';
import 'widgets/trip_map_view.dart';

/// v2 Active Trip Screen — dark map, speed gauge, lime accent, matching Active_trip.png design.
class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;

  // Glow animation for approaching state
  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _glowAnim =
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

  Timer? _elapsedTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<AlarmState>(
        alarmOrchestratorProvider,
        (AlarmState? previous, AlarmState next) {
          if (next.phase == AlarmPhase.dismissed && !_navigated && mounted) {
            _navigated = true;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder<void>(
                pageBuilder: (_, Animation<double> a, __) =>
                    FadeTransition(opacity: a, child: const TripCompletedScreen()),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final bool confirmed = await showCancelTripDialog(context);
    if (confirmed && mounted) {
      await ref.read(trackingProvider.notifier).stopTrip();
      if (mounted) Navigator.of(context).pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final TripState trip = ref.watch(trackingProvider);
    final Color accent = ref.watch(accentColorProvider);
    final double speedKmh = ref.watch(currentSpeedKmhProvider).valueOrNull ?? 0;

    final bool isApproaching = trip.status == TripStatus.approaching ||
        trip.status == TripStatus.alerting;

    if (isApproaching && !_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    } else if (!isApproaching && _glowCtrl.isAnimating) {
      _glowCtrl.stop();
      _glowCtrl.reset();
    }

    final String statusLabel = switch (trip.status) {
      TripStatus.starting    => 'STARTING',
      TripStatus.tracking    => 'TRACKING',
      TripStatus.approaching => 'APPROACHING',
      TripStatus.alerting    => 'ARRIVING!',
      TripStatus.stopped     => 'STOPPED',
      TripStatus.error       => 'ERROR',
      _                      => 'ACTIVE',
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, _) {
          if (!didPop) _onWillPop();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: <Widget>[
              // ── FULL-SCREEN MAP ──────────────────────────────────────────
              const Positioned.fill(child: TripMapView()),

              // ── APPROACHING GLOW OVERLAY ─────────────────────────────────
              if (isApproaching)
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 1.4,
                            colors: <Color>[
                              AppColors.warning
                                  .withAlpha((_glowAnim.value * 60).round()),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── GPS STATUS BANNERS ───────────────────────────────────────
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
                  ],
                ),
              ),

              // ── TOP BAR: back + destination + status badge ────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12,
                right: 12,
                child: _TopBar(
                  destinationName: trip.destination?.name ?? 'Active Trip',
                  statusLabel: statusLabel,
                  isApproaching: isApproaching,
                  accent: accent,
                  onBack: _onWillPop,
                ),
              ),

              // ── RIGHT FABs (layers + recenter) ──────────────────────────
              Positioned(
                right: 14,
                bottom: 240,
                child: Column(
                  children: <Widget>[
                    _TripFab(icon: Icons.layers_rounded, accent: accent),
                    const SizedBox(height: 10),
                    _TripFab(icon: Icons.my_location_rounded, accent: accent),
                  ],
                ),
              ),

              // ── SPEED GAUGE (bottom-left) ────────────────────────────────
              Positioned(
                left: 14,
                bottom: 230,
                child: _SpeedGauge(speedKmh: speedKmh, accent: accent),
              ),

              // ── BOTTOM PANEL ─────────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomPanel(
                  trip: trip,
                  now: _now,
                  accent: accent,
                  isApproaching: isApproaching,
                  speedKmh: speedKmh,
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
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String destinationName;
  final String statusLabel;
  final bool isApproaching;
  final Color accent;
  final Future<bool> Function() onBack;

  const _TopBar({
    required this.destinationName,
    required this.statusLabel,
    required this.isApproaching,
    required this.accent,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isApproaching ? AppColors.warning : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.location_on_rounded,
              color: AppColors.destinationPin, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              destinationName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: badgeColor, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Speed gauge (circular arc, bottom-left)
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedGauge extends StatelessWidget {
  final double speedKmh;
  final Color accent;
  const _SpeedGauge({required this.speedKmh, required this.accent});

  @override
  Widget build(BuildContext context) {
    final double displaySpeed = speedKmh.clamp(0, 200);
    final double fraction = displaySpeed / 120; // 120 km/h = full arc
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ArcPainter(
          fraction: fraction.clamp(0, 1),
          color: accent,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${displaySpeed.round()}',
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                'km/h',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _ArcPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 5;
    const double startAngle = math.pi * 0.75;
    const double sweepTotal = math.pi * 1.5;

    // Track (dim)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Fill (accent)
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * fraction,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip FAB button
// ─────────────────────────────────────────────────────────────────────────────

class _TripFab extends StatelessWidget {
  final IconData icon;
  final Color accent;
  const _TripFab({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
          ),
        ],
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel (destination info + metrics + cancel)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final TripState trip;
  final DateTime now;
  final Color accent;
  final bool isApproaching;
  final double speedKmh;
  final Future<bool> Function() onCancel;

  const _BottomPanel({
    required this.trip,
    required this.now,
    required this.accent,
    required this.isApproaching,
    required this.speedKmh,
    required this.onCancel,
  });

  String _formatEta(double? distM) {
    if (distM == null) return '--';
    // Use current speed if > 2 km/h, else fallback to 30 km/h road assumption
    final double effectiveKmh = speedKmh > 2 ? speedKmh : 30;
    final int minutes = (distM / (effectiveKmh / 3.6 * 60)).round();
    if (minutes >= 60) {
      return '${minutes ~/ 60}h ${minutes % 60}min';
    }
    return '$minutes min';
  }

  String _formatDist(double? m) {
    if (m == null) return '--';
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
  }

  String _formatElapsed() {
    if (trip.tripStartTime == null) return '--';
    final Duration d = now.difference(trip.tripStartTime!);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isApproaching ? AppColors.warning : accent;
    final String eta  = _formatEta(trip.currentDistanceMeters);
    final String dist = _formatDist(trip.currentDistanceMeters);
    final String alertAt = trip.alertSettings != null
        ? _formatDist(trip.alertSettings!.alertRadiusMeters)
        : '--';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isApproaching ? AppColors.warning : AppColors.border,
            width: isApproaching ? 1.5 : 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Destination row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                Icon(Icons.location_on_rounded,
                    color: AppColors.destinationPin, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.destination?.name ?? 'Destination',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isApproaching)
                  const Icon(Icons.notifications_active_rounded,
                      color: AppColors.warning, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Metrics row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                _PanelMetric(label: 'ETA', value: eta, accent: badgeColor),
                _Divider(),
                _PanelMetric(label: 'Distance', value: dist),
                _Divider(),
                _PanelMetric(label: 'Alert at', value: alertAt),
                _Divider(),
                _PanelMetric(label: 'Elapsed', value: _formatElapsed()),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cancel button
          Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: MediaQuery.of(context).padding.bottom + 18,
            ),
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error, width: 1.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.stop_circle_rounded,
                        color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Cancel Trip',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 16,
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
    );
  }
}

class _PanelMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  const _PanelMetric({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: accent ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: AppColors.border);
  }
}
