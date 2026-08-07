import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/map_tile_provider.dart';
import '../../../../core/theme/accent_color_provider.dart';
import '../../providers/map_provider.dart';

class MapView extends ConsumerStatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final LatLng? destinationMarker;
  final double? alertRadius;
  final List<LatLng>? routePoints;
  final void Function(LatLng)? onTap;
  final void Function(LatLng)? onLongPress;
  final bool followUser;
  final bool showRadius;
  final bool isActiveTrip; // shows cyan dot instead of lime

  const MapView({
    super.key,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.destinationMarker,
    this.alertRadius,
    this.routePoints,
    this.onTap,
    this.onLongPress,
    this.followUser = true,
    this.showRadius = false,
    this.isActiveTrip = false,
  });

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView>
    with TickerProviderStateMixin {
  late final MapController _mapController = MapController();
  LatLng? _lastKnownLocation;

  // Pulsing animation for the location dot
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _mapController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MapTileConfig tileConfig = ref.watch(mapTileConfigProvider);
    final AsyncValue<LatLng?> currentLocation =
        ref.watch(currentLocationProvider);
    final Color accent = ref.watch(accentColorProvider);
    final Color dotColor =
        widget.isActiveTrip ? AppColors.currentLocationActive : accent;

    ref.listen<AsyncValue<LatLng?>>(
      currentLocationProvider,
      (AsyncValue<LatLng?>? previous, AsyncValue<LatLng?> next) {
        final LatLng? point = next.valueOrNull;
        if (point == null || point == _lastKnownLocation) return;
        _lastKnownLocation = point;
        if (widget.followUser) {
          try {
            _mapController.move(point, _mapController.camera.zoom);
          } catch (_) {}
        }
      },
    );

    final LatLng fallbackCenter = widget.initialCenter ??
        currentLocation.valueOrNull ??
        const LatLng(12.9716, 77.5946);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: fallbackCenter,
        initialZoom: widget.initialZoom,
        minZoom: 4,
        maxZoom: 19,
        onTap: (TapPosition tp, LatLng point) => widget.onTap?.call(point),
        onLongPress: (TapPosition tp, LatLng point) =>
            widget.onLongPress?.call(point),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: <Widget>[
        // ── Tile layer (Style1-Dark) ─────────────────────────────────────────
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

        // ── Route polyline ───────────────────────────────────────────────────
        if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: widget.routePoints!,
                strokeWidth: 5,
                color: accent,
                borderStrokeWidth: 1.5,
                borderColor: accent.withAlpha(60),
              ),
            ],
          ),

        // ── Alert radius circle ──────────────────────────────────────────────
        if (widget.showRadius &&
            widget.alertRadius != null &&
            widget.destinationMarker != null)
          CircleLayer(
            circles: <CircleMarker>[
              CircleMarker(
                point: widget.destinationMarker!,
                radius: widget.alertRadius!,
                useRadiusInMeter: true,
                color: AppColors.alertRadius,
                borderColor: AppColors.alertRadiusBorder,
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // ── Destination pin ──────────────────────────────────────────────────
        if (widget.destinationMarker != null)
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: widget.destinationMarker!,
                width: 48,
                height: 56,
                child: const _DestinationPin(),
              ),
            ],
          ),

        // ── Current location dot with pulsing glow ───────────────────────────
        if (currentLocation.valueOrNull != null)
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: currentLocation.valueOrNull!,
                width: 40,
                height: 40,
                child: _LocationDot(
                  pulseCtrl: _pulseCtrl,
                  dotColor: dotColor,
                ),
              ),
            ],
          ),

        // ── Attribution ──────────────────────────────────────────────────────
        const RichAttributionWidget(
          attributions: <SourceAttribution>[
            TextSourceAttribution('© Ola Maps'),
          ],
          alignment: AttributionAlignment.bottomLeft,
        ),
      ],
    );
  }
}

// ── Destination pin widget ─────────────────────────────────────────────────────

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.destinationPin,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.destinationPin.withAlpha(120),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.location_on_rounded,
              color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: AppColors.destinationPin),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final ui.Path path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// ── Location dot with glow pulse ──────────────────────────────────────────────

class _LocationDot extends StatelessWidget {
  final AnimationController pulseCtrl;
  final Color dotColor;

  const _LocationDot({required this.pulseCtrl, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (BuildContext context, _) {
        final double pulse = 0.5 + 0.5 * pulseCtrl.value;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Outer glow ring
              Container(
                width: 36 * pulse,
                height: 36 * pulse,
                decoration: BoxDecoration(
                  color: dotColor.withAlpha((80 * (1 - pulse + 0.3)).clamp(0, 255).round()),
                  shape: BoxShape.circle,
                ),
              ),
              // Inner dot
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: dotColor.withAlpha(160),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}