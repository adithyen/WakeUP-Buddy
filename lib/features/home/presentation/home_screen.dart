import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/accent_color_provider.dart';
import '../../alert_config/providers/alert_config_provider.dart';
import '../../destination/presentation/widgets/destination_search_sheet.dart';
import '../../destination/providers/destination_provider.dart';
import '../../history/data/local_database.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tracking/data/models/trip_state.dart';
import '../../tracking/presentation/active_trip_screen.dart';
import '../../tracking/providers/tracking_provider.dart';
import 'widgets/map_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(selectedDestinationProvider);
    final alertSettings = ref.watch(alertConfigProvider);
    final TripState trackingState = ref.watch(trackingProvider);
    final Color accent = ref.watch(accentColorProvider);
    final LatLng? destinationMarker = destination == null
        ? null
        : LatLng(destination.latitude, destination.longitude);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            // ── FULL-SCREEN MAP ──────────────────────────────────────────────
            Positioned.fill(
              child: MapView(
                initialZoom: 15.0,
                followUser: true,
                destinationMarker: destinationMarker,
                alertRadius: destinationMarker == null ? null : alertSettings.alertRadiusMeters,
                showRadius: destinationMarker != null,
              ),
            ),

            // ── TOP SEARCH PILL ──────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 72, // leave room for FABs on right
              child: _SearchPill(accent: accent),
            ),

            // ── RIGHT FAB STACK (Layers / Location / Settings) ────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: Column(
                children: <Widget>[
                  _MapFab(
                    icon: Icons.layers_rounded,
                    accent: accent,
                    onTap: () => _showLayerPicker(context),
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.my_location_rounded,
                    accent: accent,
                    onTap: () {}, // MapView re-centers on next location update
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.settings_rounded,
                    accent: accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),

            // ── BOTTOM SHEET (recent places / destination panel) ─────────────
            destination == null
                ? _RecentPlacesSheet(accent: accent)
                : AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _DestinationPanel(
                      destination: destination,
                      trackingState: trackingState,
                      accent: accent,
                      alertRadiusMeters: alertSettings.alertRadiusMeters,
                      onStartTrip: () async {
                        if (trackingState.isActive) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const ActiveTripScreen()),
                          );
                          return;
                        }
                        final bool success = await ref
                            .read(trackingProvider.notifier)
                            .startTrip(destination, alertSettings);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const ActiveTripScreen()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ref.read(trackingProvider).errorMessage ??
                                    'Unable to start tracking.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                      onClearDestination: () =>
                          ref.read(selectedDestinationProvider.notifier).clearDestination(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showLayerPicker(BuildContext context) {
    final Color accent = ref.read(accentColorProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LayerPickerSheet(accent: accent),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Search Pill (top bar)
// ──────────────────────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  final Color accent;
  const _SearchPill({required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => const DestinationSearchSheet(),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withAlpha(120), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, color: accent, size: 22),
            const SizedBox(width: 10),
            Text(
              'Where do you want to go?',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Map FAB button
// ──────────────────────────────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Recent Places Bottom Sheet (home state — no destination selected)
// ──────────────────────────────────────────────────────────────────────────────

class _RecentPlacesSheet extends ConsumerWidget {
  final Color accent;
  const _RecentPlacesSheet({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tripHistoryProvider);
    final recentTrips = history.take(5).toList();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Recent places header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recent places',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List of recent destinations
            if (recentTrips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Your trip history will appear here',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              )
            else
              ...recentTrips.map((trip) => _RecentTripRow(trip: trip, accent: accent)),

            // Swipe hint
            Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                children: <Widget>[
                  Icon(Icons.keyboard_arrow_up_rounded,
                      color: accent, size: 20),
                  Text(
                    'Swipe up to view all history',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTripRow extends StatelessWidget {
  final TripRecord trip;
  final Color accent;
  const _RecentTripRow({required this.trip, required this.accent});

  IconData _iconForName(String name) {
    final String l = name.toLowerCase();
    if (l.contains('hospital') || l.contains('medical') || l.contains('health')) {
      return Icons.local_hospital_rounded;
    } else if (l.contains('college') || l.contains('school') || l.contains('university')) {
      return Icons.school_rounded;
    } else if (l.contains('mall') || l.contains('market') || l.contains('shop')) {
      return Icons.shopping_bag_rounded;
    } else if (l.contains('station') || l.contains('bus') || l.contains('train')) {
      return Icons.directions_bus_rounded;
    }
    return Icons.location_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final String name = trip.destinationName;
    final String? address = trip.destinationDescription;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withAlpha(60), width: 1),
            ),
            child: Icon(_iconForName(name), color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address != null)
                  Text(
                    address,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Placeholder ETA (future: fetch from Distance Matrix API)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '-- min',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '-- km',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Destination selected panel (bottom)
// ──────────────────────────────────────────────────────────────────────────────

class _DestinationPanel extends StatelessWidget {
  final dynamic destination;
  final TripState trackingState;
  final Color accent;
  final double alertRadiusMeters;
  final VoidCallback onStartTrip;
  final VoidCallback onClearDestination;

  const _DestinationPanel({
    required this.destination,
    required this.trackingState,
    required this.accent,
    required this.alertRadiusMeters,
    required this.onStartTrip,
    required this.onClearDestination,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = trackingState.isActive;
    final int? distM = trackingState.currentDistanceMeters?.round();
    final String distText = distM == null
        ? '--'
        : distM < 1000
            ? '$distM m'
            : '${(distM / 1000).toStringAsFixed(1)} km';
    final int? etaMin = trackingState.estimatedTimeRemaining?.inMinutes;
    final String etaText = etaMin == null ? '--' : '${etaMin.clamp(1, 999)} min';
    final int alertM = alertRadiusMeters.round();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
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
          const SizedBox(height: 16),

          // Destination name row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Icon(Icons.location_on_rounded, color: accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destination.name as String? ?? 'Destination',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: accent, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TRACKING',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metrics row: ETA | Distance | Alert at
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                _MetricCell(
                  icon: Icons.timer_outlined,
                  label: 'ETA',
                  value: etaText,
                  accent: accent,
                  valueColor: accent,
                ),
                _Separator(),
                _MetricCell(
                  icon: Icons.alt_route_rounded,
                  label: 'Distance',
                  value: distText,
                  accent: accent,
                ),
                _Separator(),
                _MetricCell(
                  icon: Icons.notifications_none_rounded,
                  label: 'Alert at',
                  value: alertM >= 1000
                      ? '${(alertM / 1000).toStringAsFixed(1)} km'
                      : '$alertM m',
                  accent: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Buttons row
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Row(
              children: <Widget>[
                // Clear button
                GestureDetector(
                  onTap: onClearDestination,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),

                // Start/Open Trip button
                Expanded(
                  child: GestureDetector(
                    onTap: onStartTrip,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withAlpha(80),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            isActive
                                ? Icons.navigation_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'Open Trip' : 'Start Trip',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color? valueColor;

  const _MetricCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.border,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Layer picker sheet
// ──────────────────────────────────────────────────────────────────────────────

class _LayerPickerSheet extends StatelessWidget {
  final Color accent;
  const _LayerPickerSheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Map Style',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _LayerOption(
                label: 'Dark (Custom)',
                icon: Icons.dark_mode_rounded,
                accent: accent,
                selected: true,
              ),
              const SizedBox(width: 12),
              _LayerOption(
                label: 'Standard',
                icon: Icons.map_rounded,
                accent: accent,
                selected: false,
              ),
              const SizedBox(width: 12),
              _LayerOption(
                label: 'Satellite',
                icon: Icons.satellite_alt_rounded,
                accent: accent,
                selected: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LayerOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;

  const _LayerOption({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(30) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: selected ? accent : AppColors.textSecondary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
