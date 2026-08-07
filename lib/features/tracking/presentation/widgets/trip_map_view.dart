import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/map_tile_provider.dart';
import '../../../home/providers/map_provider.dart';
import '../../data/models/trip_state.dart';
import '../../providers/tracking_provider.dart';

/// Live map widget for the active trip screen.
///
/// Features:
///   • Follows user position with smooth animated camera moves
///   • Destination pin + alert radius circle centred on destination
///   • Purple breadcrumb trail (last 200 points)
///   • Auto-zoom based on distance to destination
///   • Fits both markers in view via [_fitBothMarkers] when far away
class TripMapView extends ConsumerStatefulWidget {
  const TripMapView({super.key});

  @override
  ConsumerState<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<TripMapView> {
  final MapController _mapController = MapController();
  LatLng? _lastPosition;
  bool _initialMoveCompleted = false;

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
    _mapController.move(position, _zoomForDistance(distance));
  }

  void _fitBothMarkers(LatLng user, LatLng dest) {
    final LatLngBounds bounds = LatLngBounds.fromPoints(<LatLng>[user, dest]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TripState trip = ref.watch(trackingProvider);
    final MapTileConfig tileConfig = ref.watch(mapTileConfigProvider);
    final AsyncValue<LatLng?> locationAsync = ref.watch(currentLocationProvider);

    final LatLng? userPos = trip.currentLatitude != null && trip.currentLongitude != null
        ? LatLng(trip.currentLatitude!, trip.currentLongitude!)
        : locationAsync.valueOrNull;

    final LatLng? destPos = trip.destination != null
        ? LatLng(trip.destination!.latitude, trip.destination!.longitude)
        : null;

    // Animate camera to follow user on each update
    if (userPos != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_initialMoveCompleted && destPos != null &&
            trip.currentDistanceMeters != null &&
            trip.currentDistanceMeters! > 2000) {
          _fitBothMarkers(userPos, destPos);
          _initialMoveCompleted = true;
        } else {
          _moveToUser(userPos, trip.currentDistanceMeters);
          _initialMoveCompleted = true;
        }
      });
    }

    final LatLng fallbackCenter = userPos ?? destPos ?? const LatLng(12.9716, 77.5946);

    return RepaintBoundary(
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
          // Base tile layer
          TileLayer(
            urlTemplate: tileConfig.urlTemplate,
            additionalOptions: tileConfig.additionalOptions,
            fallbackUrl: tileConfig.fallbackUrl,
            tileProvider: tileConfig.tileProvider,
            userAgentPackageName: 'com.wakeupbuddy.wakeup_buddy',
            maxNativeZoom: 18,
            keepBuffer: 2,
            panBuffer: 2,
            tileUpdateTransformer: TileUpdateTransformers.debounce(
              const Duration(milliseconds: 200),
            ),
          ),

          // Breadcrumb trail
          if (trip.breadcrumbs.length > 1)
            PolylineLayer(
              polylines: <Polyline>[
                Polyline(
                  points: trip.breadcrumbs,
                  strokeWidth: 3.5,
                  color: AppColors.currentLocationActive.withAlpha(180),
                ),
              ],
            ),

          // Alert radius circle around destination
          if (destPos != null && trip.alertSettings != null)
            CircleLayer(
              circles: <CircleMarker>[
                CircleMarker(
                  point: destPos,
                  radius: trip.alertSettings!.alertRadiusMeters,
                  useRadiusInMeter: true,
                  color: AppColors.alertRadius,
                  borderColor: AppColors.alertRadiusBorder,
                  borderStrokeWidth: 2,
                ),
              ],
            ),

          // Destination pin
          if (destPos != null)
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: destPos,
                  width: AppDimensions.mapPinSize,
                  height: AppDimensions.mapPinSize,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.destinationPin,
                    size: 44,
                  ),
                ),
              ],
            ),

          // Current location dot (pulsing effect via 2 stacked circles)
          if (userPos != null)
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: userPos,
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.currentLocationActive.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.currentLocationActive,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.currentLocationActive.withAlpha(120),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          RichAttributionWidget(
            attributions: <SourceAttribution>[
              TextSourceAttribution(tileConfig.attribution, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
