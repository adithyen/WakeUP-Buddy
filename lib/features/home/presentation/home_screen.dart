import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../alert_config/providers/alert_config_provider.dart';
import '../../destination/data/models/destination.dart';
import '../../destination/data/models/place_suggestion.dart';
import '../../destination/presentation/search_screen.dart';
import '../../destination/providers/destination_provider.dart';
import '../../destination/providers/route_selection_provider.dart';
import '../../history/data/local_database.dart';
import '../../history/presentation/history_screen.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tracking/data/models/trip_state.dart';
import '../../tracking/presentation/active_trip_screen.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../providers/map_provider.dart';
import 'widgets/map_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestLocationIfNeeded();
  }

  Future<void> _requestLocationIfNeeded() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(selectedDestinationProvider);
    final alertSettings = ref.watch(alertConfigProvider);
    final TripState trackingState = ref.watch(trackingProvider);
    final recentTrips = ref.watch(tripHistoryProvider);
    final LatLng? currentLocation = ref.watch(currentLocationProvider).valueOrNull;

    final LatLng? destinationMarker = destination == null
        ? null
        : LatLng(destination.latitude, destination.longitude);

    final routeState = ref.watch(routeSelectionProvider);
    final bool isDark = context.isDarkMode;
    final Color accent = context.appAccent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: destination == null,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (destination != null) {
            HapticFeedback.lightImpact();
            ref.read(selectedDestinationProvider.notifier).clear();
            ref.read(routeSelectionProvider.notifier).clear();
          }
        },
        child: Scaffold(
          backgroundColor: context.appBackground,
          body: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

            return Stack(
              children: <Widget>[
                // ── 1. FULL-SCREEN VECTOR MAP ──────────────────────────────
                Positioned.fill(
                  child: MapView(
                    initialZoom: 15.0,
                    followUser: destination == null,
                    destinationMarker: destinationMarker,
                    alertRadius: destinationMarker == null
                        ? null
                        : alertSettings.alertRadiusMeters,
                    showRadius: destinationMarker != null,
                    routePoints: routeState.selectedRoute?.polyline,
                  ),
                ),

                // ── 2. TOP FLOATING SEARCH CAPSULE ─────────────────────────
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: isLandscape ? 80 : 20,
                  right: isLandscape ? 80 : 20,
                  child: _TopSearchCapsule(
                    accentColor: accent,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                    },
                  ),
                ),

                // ── 3. RIGHT FLOATING BUTTON GROUP ─────────────────────────
                Positioned(
                  right: 20,
                  top: MediaQuery.of(context).padding.top + 90,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FloatingCircleButton(
                        icon: Icons.layers_rounded,
                        accentColor: accent,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          final current = ref.read(isDarkMapProvider);
                          ref.read(isDarkMapProvider.notifier).state = !current;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(!current ? 'Dark Map Style Active' : 'Light Map Style Active'),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _FloatingCircleButton(
                        icon: Icons.my_location_rounded,
                        accentColor: accent,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          ref.read(recenterMapTriggerProvider.notifier).state++;

                          final LatLng? loc = ref.read(currentLocationProvider).valueOrNull;
                          if (loc == null) {
                            try {
                              await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                  accuracy: LocationAccuracy.high,
                                  timeLimit: Duration(seconds: 4),
                                ),
                              );
                              ref.read(recenterMapTriggerProvider.notifier).state++;
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Locating your position... Please check GPS permission.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _FloatingCircleButton(
                        icon: Icons.settings_rounded,
                        iconColor: accent,
                        accentColor: accent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ── 4. BOTTOM DRAGGABLE RECENT PLACES OR ROUTE PANEL ──────
                if (destination != null)
                  _buildDestinationRoutePanel(
                    context,
                    ref,
                    destination,
                    routeState,
                    trackingState,
                    isLandscape,
                    accent,
                  )
                else
                  _buildRecentPlacesSheet(
                    context,
                    ref,
                    recentTrips,
                    currentLocation,
                    isLandscape,
                    accent,
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom Sheet: Recent Places (Strictly Dynamic, Matching Designs/)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecentPlacesSheet(
    BuildContext context,
    WidgetRef ref,
    List<TripRecord> recentTrips,
    LatLng? currentLocation,
    bool isLandscape,
    Color accent,
  ) {
    // Deduplicate trips by name and coordinates
    final uniqueTrips = <TripRecord>[];
    final seen = <String>{};
    for (final trip in recentTrips) {
      final key =
          '${trip.destinationName.trim().toLowerCase()}_${trip.destinationLat.toStringAsFixed(3)}_${trip.destinationLng.toStringAsFixed(3)}';
      if (seen.add(key)) {
        uniqueTrips.add(trip);
      }
    }
    final displayTrips = uniqueTrips.take(3).toList();

    void openHistory() {
      HapticFeedback.lightImpact();
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
      );
    }

    return Positioned(
      left: isLandscape ? MediaQuery.of(context).size.width * 0.15 : 0,
      right: isLandscape ? MediaQuery.of(context).size.width * 0.15 : 0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -80) {
            openHistory();
          }
        },
        child: Container(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 16),
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

              // Header: "Recent places" with clock icon
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent places',
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Dynamic List or Polished Empty State for New User
              if (displayTrips.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildNewUserEmptyState(context, accent),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < displayTrips.length; i++) ...[
                      if (i > 0)
                        Divider(
                          color: context.appBorder.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      _buildRecentPlaceTile(
                        context,
                        ref,
                        displayTrips[i],
                        currentLocation,
                        accent,
                      ),
                    ],
                  ],
                ),

              // "Swipe up to view all history" footer
              InkWell(
                onTap: openHistory,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.keyboard_arrow_up_rounded, color: accent, size: 20),
                        Text(
                          'Swipe up to view all history',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildRecentPlaceTile(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    LatLng? currentLocation,
    Color accent,
  ) {
    int? distKm;
    int? etaMin;
    if (currentLocation != null) {
      final straightMeters = const Distance().as(
        LengthUnit.Meter,
        currentLocation,
        LatLng(trip.destinationLat, trip.destinationLng),
      );
      final roadMeters = (straightMeters * 1.35).round();
      distKm = (roadMeters / 1000).round();
      etaMin = ((roadMeters / 7.78) / 60).round();
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        final dest = Destination(
          id: trip.id,
          name: trip.destinationName,
          description: trip.destinationDescription,
          latitude: trip.destinationLat,
          longitude: trip.destinationLng,
          selectedAt: DateTime.now(),
          source: PlaceSource.ola,
        );
        ref.read(selectedDestinationProvider.notifier).select(dest);

        if (currentLocation != null) {
          ref.read(routeSelectionProvider.notifier).fetchRoutes(
                origin: currentLocation,
                destination: LatLng(trip.destinationLat, trip.destinationLng),
              );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Category Icon in circle avatar with accent border
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appCardElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Icon(
                _inferCategoryIcon(trip.destinationName),
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Destination Name & Address
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.destinationName,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    trip.destinationDescription ?? 'Saved Destination',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ETA and Distance
            if (etaMin != null && distKm != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$etaMin min',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$distKm km',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  IconData _inferCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('college') || lower.contains('school') || lower.contains('university')) {
      return Icons.school_rounded;
    }
    if (lower.contains('mall') || lower.contains('market') || lower.contains('bazaar')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('health')) {
      return Icons.medical_services_rounded;
    }
    if (lower.contains('temple') || lower.contains('church') || lower.contains('mosque')) {
      return Icons.temple_hindu_rounded;
    }
    return Icons.place_rounded;
  }

  Widget _buildNewUserEmptyState(BuildContext context, Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            color: accent,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            'No recent places yet',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search a destination above to start your commute alarm',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Destination Route Selector Panel (When destination is chosen)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDestinationRoutePanel(
    BuildContext context,
    WidgetRef ref,
    Destination destination,
    RouteSelectionState routeState,
    TripState trackingState,
    bool isLandscape,
    Color accent,
  ) {
    final alertSettings = ref.read(alertConfigProvider);

    return Positioned(
      left: isLandscape ? MediaQuery.of(context).size.width * 0.15 : 0,
      right: isLandscape ? MediaQuery.of(context).size.width * 0.15 : 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
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
            // Destination Name & Clear
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destination.name,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.appTextSecondary),
                  onPressed: () {
                    ref.read(selectedDestinationProvider.notifier).clear();
                    ref.read(routeSelectionProvider.notifier).clear();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route Alternatives Selector (from Ola Directions API)
            if (routeState.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                ),
              )
            else if (routeState.routes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(routeState.routes.length, (idx) {
                    final r = routeState.routes[idx];
                    final isSelected = routeState.selectedIndex == idx;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => ref.read(routeSelectionProvider.notifier).selectRoute(idx),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent.withValues(alpha: 0.15)
                                : context.appCardElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? accent : context.appBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                color: isSelected ? accent : context.appTextSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Route ${idx + 1}',
                                    style: TextStyle(
                                      color: isSelected ? accent : context.appTextPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${r.readableDuration} • ${r.readableDistance}',
                                    style: TextStyle(
                                      color: context.appTextSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            const SizedBox(height: 16),

            // Start Trip CTA Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(accent) == Brightness.light
                          ? Colors.black
                          : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: const Text(
                  'Start Trip & Tracking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  if (trackingState.isActive) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ActiveTripScreen()),
                    );
                    return;
                  }

                  final bool success = await ref.read(trackingProvider.notifier).startTrip(
                        destination,
                        alertSettings,
                        chosenRoute: routeState.selectedRoute,
                      );

                  if (context.mounted && success) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ActiveTripScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Floating Search Capsule
// ─────────────────────────────────────────────────────────────────────────────

class _TopSearchCapsule extends StatelessWidget {
  final VoidCallback onTap;
  final Color accentColor;

  const _TopSearchCapsule({
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: context.appCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: accentColor,
            width: 1.4,
          ),
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
            Icon(
              Icons.search_rounded,
              color: accentColor,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Where do you want to go?',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingCircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _FloatingCircleButton({
    required this.icon,
    this.iconColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.appCard.withValues(alpha: 0.92),
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
        icon: Icon(
          icon,
          color: iconColor ?? accentColor,
          size: 22,
        ),
        onPressed: onTap,
      ),
    );
  }
}
