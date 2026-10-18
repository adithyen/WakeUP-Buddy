import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/ola_maps_service.dart';

final routeSelectionProvider =
    StateNotifierProvider<RouteSelectionNotifier, RouteSelectionState>((ref) {
  final olaService = ref.watch(olaMapsServiceProvider);
  return RouteSelectionNotifier(olaService: olaService);
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

  RouteSelectionNotifier({required OlaMapsService olaService})
      : _olaService = olaService,
        super(const RouteSelectionState());

  Future<void> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final routes = await _olaService.getDirections(
        origin: origin,
        destination: destination,
        alternatives: true,
      );

      if (routes.isNotEmpty) {
        state = state.copyWith(
          routes: routes,
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
