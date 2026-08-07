import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../tracking/data/models/trip_state.dart';
import '../../tracking/providers/tracking_provider.dart';

/// Celebration screen shown after a trip alarm is dismissed.
///
/// Displays trip duration, approximate distance travelled, and a
/// "Back to Home" CTA. Optionally saves to history (Phase 11).
class TripCompletedScreen extends ConsumerWidget {
  const TripCompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripState trip = ref.read(trackingProvider);
    final ThemeData theme = Theme.of(context);

    final String destName = trip.destination?.name ?? 'Your Destination';
    final String duration = trip.tripStartTime != null
        ? _formatDuration(DateTime.now().difference(trip.tripStartTime!))
        : '--';
    final String distance = trip.initialDistanceMeters != null
        ? _formatDistance(trip.initialDistanceMeters!)
        : '--';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF0D1A1A),
                  Color(0xFF001A10),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.xxl,
                vertical: AppDimensions.xxxl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  // ── Celebration icon ──────────────────────────────────
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (BuildContext ctx, double v, Widget? _) =>
                        Transform.scale(
                      scale: v,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              Color(0xFF00E5A0),
                              Color(0xFF00B894),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Color(0x5500B894),
                              blurRadius: 48,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.celebration_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // ── Headline ─────────────────────────────────────────
                  Column(
                    children: <Widget>[
                      const Text(
                        "You've Arrived!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.location_on_rounded,
                              color: Colors.white60, size: 18),
                          const SizedBox(width: AppDimensions.xs),
                          Flexible(
                            child: Text(
                              destName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Trip stats ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.xl),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatColumn(
                            icon: Icons.timer_rounded,
                            label: 'Duration',
                            value: duration,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 48,
                          color: Colors.white.withAlpha(40),
                        ),
                        Expanded(
                          child: _StatColumn(
                            icon: Icons.straighten_rounded,
                            label: 'Distance',
                            value: distance,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── CTAs ─────────────────────────────────────────────
                  Column(
                    children: <Widget>[
                      AppButton(
                        label: 'Back to Home',
                        icon: Icons.home_rounded,
                        onPressed: () {
                          // Pop back to Home (root)
                          Navigator.of(context).popUntil(
                            (Route<dynamic> route) => route.isFirst,
                          );
                        },
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      TextButton.icon(
                        onPressed: () {
                          // Phase 11 — save to history
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Trip saved to history.'),
                            ),
                          );
                          Navigator.of(context).popUntil(
                            (Route<dynamic> route) => route.isFirst,
                          );
                        },
                        icon: const Icon(Icons.bookmark_add_rounded,
                            color: Colors.white60, size: 18),
                        label: const Text(
                          'Save to History',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds}s';
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: AppColors.success, size: 22),
        const SizedBox(height: AppDimensions.xs),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
