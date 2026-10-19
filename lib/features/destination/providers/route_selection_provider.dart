import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/ola_maps_service.dart';
import '../../../core/services/tomtom_traffic_service.dart';
import '../../tracking/data/models/traffic_incident_model.dart';

final routeSelectionProvider =
    StateNotifierProvider<RouteSelectionNotifier, RouteSelectionState>((ref) {
  final olaService = ref.watch(olaMapsServiceProvider);
  final tomtomService = ref.watch(tomtomTrafficServiceProvider);
  return RouteSelectionNotifier(
    olaService: olaService,
    tomtomService: tomtomService,
  );
});

class RouteSelectionState {
  final List<OlaRoute> routes;
  final int selectedIndex;
  final bool isLoading;
  final String? errorMessage;

  const RouteSelectionState({
    this.routes = const [],
    this.selectedIndex = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  OlaRoute? get selectedRoute =>
      (routes.isNotEmpty && selectedIndex >= 0 && selectedIndex < routes.length)
          ? routes[selectedIndex]
          : null;

  RouteSelectionState copyWith({
    List<OlaRoute>? routes,
    int? selectedIndex,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RouteSelectionState(
      routes: routes ?? this.routes,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class RouteSelectionNotifier extends StateNotifier<RouteSelectionState> {
  final OlaMapsService _olaService;
  final TomTomTrafficService _tomtomService;

  RouteSelectionNotifier({
    required OlaMapsService olaService,
    required TomTomTrafficService tomtomService,
  })  : _olaService = olaService,
        _tomtomService = tomtomService,
        super(const RouteSelectionState());

  Future<void> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Query live road closures along the trip corridor
      final double minLat = origin.latitude < destination.latitude ? origin.latitude : destination.latitude;
      final double maxLat = origin.latitude > destination.latitude ? origin.latitude : destination.latitude;
      final double minLng = origin.longitude < destination.longitude ? origin.longitude : destination.longitude;
      final double maxLng = origin.longitude > destination.longitude ? origin.longitude : destination.longitude;
      final liveIncidents = await _tomtomService.fetchIncidentsInBbox(
        minLon: minLng - 0.03,
        minLat: minLat - 0.03,
        maxLon: maxLng + 0.03,
        maxLat: maxLat + 0.03,
      ).catchError((_) => <TrafficIncident>[]);
      final closedPoints = liveIncidents.where((i) => i.isRoadClosed).map((i) => i.point).toList();

      // 2. Fetch routes in parallel (with closure avoidance if closures are detected)
      final futures = await Future.wait([
        _olaService.getDirections(
          origin: origin,
          destination: destination,
          alternatives: true,
        ).catchError((_) => <OlaRoute>[]),
        _tomtomService.calculateTrafficAwareRoute(
          origin: origin,
          destination: destination,
          avoidRoadClosures: closedPoints,
        ).catchError((_) => null),
      ]);

      final List<OlaRoute> olaRoutes = futures[0] as List<OlaRoute>;
      final TomTomRouteResult? ttRoute = futures[1] as TomTomRouteResult?;

      // 3. Collision check: Does route pass within 45m of an active road closure?
      bool crossesRoadClosure(List<LatLng> polyline) {
        if (polyline.isEmpty || closedPoints.isEmpty) return false;
        const distance = Distance();
        for (final cp in closedPoints) {
          for (final pt in polyline) {
            if (distance.as(LengthUnit.Meter, pt, cp) <= 45.0) {
              return true;
            }
          }
        }
        return false;
      }

      final List<OlaRoute> safeOlaRoutes = [];
      final List<OlaRoute> blockedOlaRoutes = [];

      for (final r in olaRoutes) {
        if (crossesRoadClosure(r.polyline)) {
          blockedOlaRoutes.add(r.copyWith(
            summary: '${r.summary} (Blocked by Road Closure)',
            isDiverted: false,
            diversionReason: 'Caution: This route passes through an active road closure',
          ));
        } else {
          safeOlaRoutes.add(r);
        }
      }

      final List<OlaRoute> combinedRoutes = [];

      // If a detour route was calculated that avoids the road closures, prioritize it as Route 1!
      if (ttRoute != null && ttRoute.polyline.isNotEmpty) {
        final bool ttCrossesClosure = crossesRoadClosure(ttRoute.polyline);
        final bool isDetour = ttRoute.isDiverted || (closedPoints.isNotEmpty && !ttCrossesClosure);

        final tomtomConverted = OlaRoute(
          summary: isDetour
              ? 'Detour (Bypassing Road Closure)'
              : 'Live Traffic Route',
          polyline: ttRoute.polyline,
          distanceMeters: ttRoute.distanceMeters,
          durationSeconds: ttRoute.travelTimeSeconds,
          readableDistance: '${(ttRoute.distanceMeters / 1000).toStringAsFixed(1)} km',
          readableDuration: '${(ttRoute.travelTimeSeconds / 60).round()} min',
          steps: const [],
          isDiverted: isDetour,
          diversionReason: isDetour
              ? 'Route automatically diverted to bypass active road closures'
              : ttRoute.diversionReason,
        );

        // Put detour route as #1
        combinedRoutes.add(tomtomConverted);
      }

      // Add safe Ola routes next
      combinedRoutes.addAll(safeOlaRoutes);

      // Only add blocked routes at the very end if no safe routes exist
      if (combinedRoutes.isEmpty) {
        combinedRoutes.addAll(blockedOlaRoutes);
      }

      if (combinedRoutes.isNotEmpty) {
        state = state.copyWith(
          routes: combinedRoutes,
          selectedIndex: 0,
          isLoading: false,
        );
      } else {
        // Fallback straight line polyline if offline
        final fallbackRoute = OlaRoute(
          summary: 'Direct route',
          polyline: [origin, destination],
          distanceMeters: const Distance().as(LengthUnit.Meter, origin, destination).toInt(),
          durationSeconds: ((const Distance().as(LengthUnit.Meter, origin, destination) / 8.33)).round(),
          readableDistance: '${(const Distance().as(LengthUnit.Kilometer, origin, destination)).toStringAsFixed(1)} km',
          readableDuration: '${((const Distance().as(LengthUnit.Meter, origin, destination) / 500)).round()} min',
          steps: const [],
        );
        state = state.copyWith(
          routes: [fallbackRoute],
          selectedIndex: 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to calculate routes: $e',
      );
    }
  }

  void selectRoute(int index) {
    if (index >= 0 && index < state.routes.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  void clear() {
    state = const RouteSelectionState();
  }
}
