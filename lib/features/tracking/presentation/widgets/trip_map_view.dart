import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/map_api_key_provider.dart';
import '../../../../core/services/map_renderer_provider.dart';
import '../../../../core/services/map_tile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/widgets/native_ola_map_view.dart';
import '../../../home/presentation/widgets/native_vela_map_view.dart';
import '../../../home/providers/map_provider.dart';
import '../../data/models/trip_state.dart';
import '../../providers/tracking_provider.dart';

/// Live map widget for the active trip screen.
/// Renders native Ola Map on Android when selected, or high-performance FlutterMap (Vela/OSM).
class TripMapView extends ConsumerStatefulWidget {
  const TripMapView({super.key});

  @override
  ConsumerState<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<TripMapView> {
  final MapController _mapController = MapController();
  OlaMapController? _nativeOlaController;
  VelaMapController? _nativeVelaController;
  LatLng? _lastPosition;
  bool _initialMoveCompleted = false;
  bool _nativeOlaHasError = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  double _zoomForDistance(double? meters) {
    if (meters == null) return 15;
    if (meters > 10000) return 10;
    if (meters > 5000) return 12;
    if (meters > 1000) return 14;
    if (meters > 500) return 16;
    return 17;
  }

  void _moveToUser(LatLng position, double? distance) {
    if (position == _lastPosition) return;
    _lastPosition = position;
    if (ref.read(mapRendererProvider) != MapRendererType.vela) {
      _mapController.move(position, _zoomForDistance(distance));
    }
    _nativeOlaController?.moveCamera(
      lat: position.latitude,
      lng: position.longitude,
      zoom: _zoomForDistance(distance),
    );
  }

  void _fitBothMarkers(LatLng user, LatLng dest) {
    final LatLngBounds bounds = LatLngBounds.fromPoints(<LatLng>[user, dest]);
    if (ref.read(mapRendererProvider) != MapRendererType.vela) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            left: 60,
            right: 60,
            top: 100,
            bottom: 220,
          ),
          maxZoom: 16,
        ),
      );
    }
    _nativeOlaController?.fitBounds(
      points: [
        [user.latitude, user.longitude],
        [dest.latitude, dest.longitude],
      ],
      padding: 120,
    );
  }

  void _syncNativeOlaState(TripState trip, Color accent) {
    if (_nativeOlaController == null) return;
    final hex =
        '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    if (trip.destination != null) {
      final double radius = (trip.alertSettings?.alertRadiusMeters ?? 500)
          .toDouble();
      _nativeOlaController!.setDestination(
        lat: trip.destination!.latitude,
        lng: trip.destination!.longitude,
        radiusMeters: radius,
        colorHex: hex,
      );
    }

    if (trip.currentLatitude != null && trip.currentLongitude != null) {
      _nativeOlaController!.updateUserLocation(
        lat: trip.currentLatitude!,
        lng: trip.currentLongitude!,
        colorHex: hex,
      );
    }

    if (trip.routePolyline.isNotEmpty) {
      final points = trip.routePolyline
          .map((p) => <double>[p.latitude, p.longitude])
          .toList(growable: false);
      _nativeOlaController!.drawRoute(
        points: points,
        colorHex: hex,
        width: 6.0,
      );
    }
  }

  void _syncNativeVelaState(TripState trip, Color accent) {
    final controller = _nativeVelaController;
    if (controller == null) return;
    final hex =
        '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    if (trip.destination != null) {
      controller.setDestination(
        lat: trip.destination!.latitude,
        lng: trip.destination!.longitude,
        radiusMeters: (trip.alertSettings?.alertRadiusMeters ?? 500).toDouble(),
        colorHex: hex,
      );
    }
    final user = trip.currentLatitude != null && trip.currentLongitude != null
        ? LatLng(trip.currentLatitude!, trip.currentLongitude!)
        : null;
    if (user != null) {
      controller.updateUserLocation(
        lat: user.latitude,
        lng: user.longitude,
        colorHex: hex,
      );
    }
    if (trip.routePolyline.isNotEmpty) {
      controller.drawRoute(
        points: trip.routePolyline
            .map((p) => <double>[p.latitude, p.longitude])
            .toList(growable: false),
        colorHex: hex,
        width: 6,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TripState trip = ref.watch(trackingProvider);
    final MapRendererType renderer = ref.watch(mapRendererProvider);
    final MapTileConfig tileConfig = ref.watch(mapTileConfigProvider);
    final AsyncValue<LatLng?> locationAsync = ref.watch(
      currentLocationProvider,
    );
    final String apiKey =
        ref.watch(mapApiKeyProvider) ?? ApiConstants.defaultOlaApiKey;
    final bool isDark = ref.watch(isDarkMapProvider);
    final Color accent = context.appAccent;

    final LatLng? userPos =
        trip.currentLatitude != null && trip.currentLongitude != null
        ? LatLng(trip.currentLatitude!, trip.currentLongitude!)
        : locationAsync.valueOrNull;

    final LatLng? destPos = trip.destination != null
        ? LatLng(trip.destination!.latitude, trip.destination!.longitude)
        : null;

    // Follow user with camera
    if (userPos != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (!_initialMoveCompleted &&
            destPos != null &&
            trip.currentDistanceMeters != null &&
            trip.currentDistanceMeters! > 2000) {
          _fitBothMarkers(userPos, destPos);
          _initialMoveCompleted = true;
        } else {
          _moveToUser(userPos, trip.currentDistanceMeters);
          _initialMoveCompleted = true;
        }
        _syncNativeOlaState(trip, accent);
        _syncNativeVelaState(trip, accent);
      });
    }

    final LatLng fallbackCenter =
        userPos ?? destPos ?? const LatLng(8.5241, 76.9366);

    final Widget flutterMapFallback = RepaintBoundary(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: fallbackCenter,
          initialZoom: _zoomForDistance(trip.currentDistanceMeters),
          minZoom: 4,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: tileConfig.urlTemplate,
            additionalOptions: tileConfig.additionalOptions,
            fallbackUrl: tileConfig.fallbackUrl,
            tileProvider: tileConfig.tileProvider,
            userAgentPackageName: 'com.wakeupbuddy.wakeup_buddy',
            maxNativeZoom: 18,
            keepBuffer: 2,
            panBuffer: 2,
          ),

          // Route polyline with dynamic accent color
          if (trip.routePolyline.isNotEmpty)
            PolylineLayer(
              polylines: <Polyline>[
                Polyline(
                  points: trip.routePolyline,
                  strokeWidth: 5.5,
                  color: accent,
                ),
              ],
            ),

          // Breadcrumb trail
          if (trip.breadcrumbs.length > 1)
            PolylineLayer(
              polylines: <Polyline>[
                Polyline(
                  points: trip.breadcrumbs,
                  strokeWidth: 3.5,
                  color: accent.withValues(alpha: 0.65),
                ),
              ],
            ),

          // Alert radius circle around destination
          if (destPos != null)
            CircleLayer(
              circles: <CircleMarker>[
                CircleMarker(
                  point: destPos,
                  radius: (trip.alertSettings?.alertRadiusMeters ?? 500)
                      .toDouble(),
                  useRadiusInMeter: true,
                  color: accent.withValues(alpha: 0.16),
                  borderColor: accent,
                  borderStrokeWidth: 2.2,
                ),
              ],
            ),

          // Destination pin
          if (destPos != null)
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: destPos,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.7),
                          blurRadius: 14,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),

          // User live location marker
          if (userPos != null)
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: userPos,
                  width: 28,
                  height: 28,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          RichAttributionWidget(
            attributions: <SourceAttribution>[
              TextSourceAttribution(tileConfig.attribution),
            ],
            alignment: AttributionAlignment.bottomLeft,
          ),
        ],
      ),
    );

    // If user selected Ola Maps and is running on Android, use genuine native Ola SDK
    if (renderer == MapRendererType.vela && !kIsWeb && Platform.isAndroid) {
      return NativeVelaMapView(
        initialLat: fallbackCenter.latitude,
        initialLng: fallbackCenter.longitude,
        initialZoom: _zoomForDistance(trip.currentDistanceMeters),
        styleUrl: isDark
            ? ApiConstants.velaDarkStyle
            : ApiConstants.velaLightStyle,
        fallback: flutterMapFallback,
        onMapReady: (controller) {
          _nativeVelaController = controller;
          _syncNativeVelaState(trip, accent);
        },
      );
    }

    // If user selected Ola Maps and is running on Android, use genuine native Ola SDK
    if (renderer == MapRendererType.ola &&
        !kIsWeb &&
        Platform.isAndroid &&
        !_nativeOlaHasError) {
      final baseStyleUrl = isDark
          ? ApiConstants.olaVectorStyleDark
          : ApiConstants.olaVectorStyleLight;
      final styleUrl = ApiConstants.olaStyleUrlWithApiKey(baseStyleUrl, apiKey);

      return NativeOlaMapView(
        initialLat: fallbackCenter.latitude,
        initialLng: fallbackCenter.longitude,
        initialZoom: _zoomForDistance(trip.currentDistanceMeters),
        apiKey: apiKey,
        styleUrl: styleUrl,
        fallback: flutterMapFallback,
        onMapReady: (controller) {
          _nativeOlaController = controller;
          _syncNativeOlaState(trip, accent);
        },
        onMapError: () {
          if (mounted) {
            setState(() {
              _nativeOlaHasError = true;
            });
          }
        },
      );
    }

    return flutterMapFallback;
  }
}
