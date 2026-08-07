import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../data/models/trip_state.dart';
import '../../providers/tracking_provider.dart';

/// A 2-column grid of live trip metrics: alert distance, ETA, speed, trip
/// duration, GPS signal bars, and accuracy.
class TripInfoPanel extends ConsumerStatefulWidget {
  const TripInfoPanel({super.key});

  @override
  ConsumerState<TripInfoPanel> createState() => _TripInfoPanelState();
}

class _TripInfoPanelState extends ConsumerState<TripInfoPanel> {
  /// Ticks every second to refresh trip duration — properly cancelled on dispose.
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TripState trip = ref.watch(trackingProvider);
    final ThemeData theme = Theme.of(context);

    final String eta = _formatETA(
      trip.currentDistanceMeters,
      trip.currentSpeedMs,
    );
    final String speed = trip.currentSpeedMs != null
        ? '${(trip.currentSpeedMs! * 3.6).round()} km/h'
        : '--';
    final String alertAt = trip.alertSettings != null
        ? _formatDistance(trip.alertSettings!.alertRadiusMeters)
        : '--';
    final String duration = trip.tripStartTime != null
        ? _formatDuration(_now.difference(trip.tripStartTime!))
        : '--';
    final int signalBars = _accuracyToBars(trip.gpsAccuracyMeters);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _InfoCell(
                icon: Icons.notifications_active_rounded,
                label: 'Alert at',
                value: alertAt,
                iconColor: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: _InfoCell(
                icon: Icons.access_time_rounded,
                label: 'ETA',
                value: eta,
                iconColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _InfoCell(
                icon: Icons.speed_rounded,
                label: 'Speed',
                value: speed,
                iconColor: AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: _InfoCell(
                icon: Icons.timer_outlined,
                label: 'Tracking for',
                value: duration,
                iconColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _GpsSignalCell(bars: signalBars, accuracy: trip.gpsAccuracyMeters),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: _InfoCell(
                icon: Icons.gps_fixed_rounded,
                label: 'Accuracy',
                value: trip.gpsAccuracyMeters != null
                    ? '±${trip.gpsAccuracyMeters!.round()}m'
                    : '--',
                iconColor: _accuracyColor(trip.gpsAccuracyMeters),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _formatETA(double? distanceM, double? speedMs) {
    if (distanceM == null || speedMs == null || speedMs <= 0.5) return '--';
    final Duration d = Duration(seconds: (distanceM / speedMs).round());
    if (d.inHours > 0) return '~${d.inHours}h ${d.inMinutes % 60}min';
    if (d.inMinutes > 0) return '~${d.inMinutes} min';
    return '<1 min';
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds}s';
  }

  static int _accuracyToBars(double? accuracy) {
    if (accuracy == null) return 0;
    if (accuracy <= 10) return 5;
    if (accuracy <= 25) return 4;
    if (accuracy <= 50) return 3;
    if (accuracy <= 100) return 2;
    return 1;
  }

  static Color _accuracyColor(double? accuracy) {
    if (accuracy == null) return AppColors.error;
    if (accuracy <= 25) return AppColors.success;
    if (accuracy <= 75) return AppColors.warning;
    return AppColors.error;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: AppDimensions.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: theme.textTheme.labelSmall),
                Text(
                  value,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsSignalCell extends StatelessWidget {
  final int bars;
  final double? accuracy;

  const _GpsSignalCell({required this.bars, required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = bars >= 4
        ? AppColors.success
        : bars >= 2
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.signal_cellular_alt_rounded, color: color, size: 18),
          const SizedBox(width: AppDimensions.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('GPS Signal', style: theme.textTheme.labelSmall),
                Row(
                  children: List<Widget>.generate(5, (int i) {
                    return Container(
                      width: 5,
                      height: 5 + (i * 2.0),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: i < bars ? color : color.withAlpha(50),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
