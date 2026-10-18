import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/map_api_key_provider.dart';
import '../../../../core/services/map_renderer_provider.dart';
import '../../../../core/services/map_tile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/map_provider.dart';
import 'native_ola_map_view.dart';
import 'native_vela_map_view.dart';

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
  });

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  late final MapController _mapController = MapController();
  OlaMapController? _nativeOlaController;
  VelaMapController? _nativeVelaController;
  LatLng? _lastKnownLocation;
  bool _nativeOlaHasError = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _syncNativeOlaState(Color accent, [LatLng? userLocation]) {
    if (_nativeOlaController == null) return;
    final hex =
        '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    // Destination pin & alert radius
    if (widget.destinationMarker != null) {
      _nativeOlaController!.setDestination(
        lat: widget.destinationMarker!.latitude,
        lng: widget.destinationMarker!.longitude,
        radiusMeters: widget.alertRadius ?? 500,
        colorHex: hex,
      );
    } else {
      _nativeOlaController!.clearDestination();
    }

    // Route points polyline
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final points = widget.routePoints!
          .map((p) => <double>[p.latitude, p.longitude])
          .toList(growable: false);
      _nativeOlaController!.drawRoute(
        points: points,
        colorHex: hex,
        width: 6.0,
      );
      _nativeOlaController!.fitBounds(points: points, padding: 120);
    } else {
      _nativeOlaController!.clearRoute();
    }

    // User location
    final userPos = userLocation ?? _lastKnownLocation;
    if (userPos != null) {
      _lastKnownLocation = userPos;
      _nativeOlaController!.updateUserLocation(
        lat: userPos.latitude,
        lng: userPos.longitude,
        colorHex: hex,
      );
    } else {
      Geolocator.getLastKnownPosition().then((pos) {
        if (pos != null && _nativeOlaController != null) {
          _lastKnownLocation = LatLng(pos.latitude, pos.longitude);
          _nativeOlaController!.updateUserLocation(
            lat: pos.latitude,
            lng: pos.longitude,
            colorHex: hex,
          );
        }
      });
    }
  }

  void _syncNativeVelaState(Color accent, [LatLng? userLocation]) {
    final controller = _nativeVelaController;
    if (controller == null) return;
    final hex =
        '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    if (widget.destinationMarker != null) {
      controller.setDestination(
        lat: widget.destinationMarker!.latitude,
        lng: widget.destinationMarker!.longitude,
        radiusMeters: widget.alertRadius ?? 500,
        colorHex: hex,
      );
    } else {
      controller.clearDestination();
    }
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final points = widget.routePoints!
          .map((p) => <double>[p.latitude, p.longitude])
          .toList(growable: false);
      controller.drawRoute(points: points, colorHex: hex, width: 6);
      controller.fitBounds(points: points, padding: 120);
    } else {
      controller.clearRoute();
    }
    final userPos = userLocation ?? _lastKnownLocation;
    if (userPos != null) {
      _lastKnownLocation = userPos;
      controller.updateUserLocation(
        lat: userPos.latitude,
        lng: userPos.longitude,
        colorHex: hex,
      );
    } else {
      Geolocator.getLastKnownPosition().then((pos) {
        if (pos != null && _nativeVelaController != null) {
          _lastKnownLocation = LatLng(pos.latitude, pos.longitude);
          _nativeVelaController!.updateUserLocation(
            lat: pos.latitude,
            lng: pos.longitude,
            colorHex: hex,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final accent = context.appAccent;
    _syncNativeOlaState(accent);
    _syncNativeVelaState(accent);

    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(widget.routePoints!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(mapRendererProvider) == MapRendererType.osm) {
          try {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.only(
                  left: 60,
                  right: 60,
                  top: 100,
                  bottom: 260,
                ),
              ),
            );
          } catch (_) {}
        }
      });
    } else if (widget.destinationMarker != null &&
        widget.destinationMarker != oldWidget.destinationMarker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(mapRendererProvider) == MapRendererType.osm) {
          try {
            _mapController.move(widget.destinationMarker!, widget.initialZoom);
          } catch (_) {}
        }
        _nativeOlaController?.moveCamera(
          lat: widget.destinationMarker!.latitude,
          lng: widget.destinationMarker!.longitude,
          zoom: widget.initialZoom,
        );
        _nativeVelaController?.moveCamera(
          lat: widget.destinationMarker!.latitude,
          lng: widget.destinationMarker!.longitude,
          zoom: widget.initialZoom,
        );
      });
    } else if (oldWidget.destinationMarker != null &&
        widget.destinationMarker == null) {
      // Destination cleared! Center back on user location
      if (_lastKnownLocation != null) {
        if (ref.read(mapRendererProvider) == MapRendererType.osm) {
          try {
            _mapController.move(_lastKnownLocation!, 15.0);
          } catch (_) {}
        }
        _nativeOlaController?.moveCamera(
          lat: _lastKnownLocation!.latitude,
          lng: _lastKnownLocation!.longitude,
          zoom: 15.0,
        );
        _nativeVelaController?.moveCamera(
          lat: _lastKnownLocation!.latitude,
          lng: _lastKnownLocation!.longitude,
          zoom: 15.0,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MapRendererType renderer = ref.watch(mapRendererProvider);
    final MapTileConfig tileConfig = ref.watch(mapTileConfigProvider);
    final AsyncValue<LatLng?> currentLocation = ref.watch(
      currentLocationProvider,
    );
    final String apiKey =
        ref.watch(mapApiKeyProvider) ?? ApiConstants.defaultOlaApiKey;
    final bool isDark = ref.watch(isDarkMapProvider);
    final ThemeData theme = Theme.of(context);
    final Color accent = context.appAccent;

    // Listen to GPS position updates
    ref.listen<AsyncValue<LatLng?>>(currentLocationProvider, (
      AsyncValue<LatLng?>? previous,
      AsyncValue<LatLng?> next,
    ) {
      final LatLng? point = next.valueOrNull;
      if (point == null) return;
      _lastKnownLocation = point;
      if (widget.followUser && widget.destinationMarker == null) {
        if (renderer == MapRendererType.osm) {
          try {
            _mapController.move(point, _mapController.camera.zoom);
          } catch (_) {}
        }
        _nativeOlaController?.moveCamera(
          lat: point.latitude,
          lng: point.longitude,
          zoom: 15.0,
        );
        _nativeVelaController?.moveCamera(
          lat: point.latitude,
          lng: point.longitude,
          zoom: 15.0,
        );
      }
      final hex =
          '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      _nativeOlaController?.updateUserLocation(
        lat: point.latitude,
        lng: point.longitude,
        colorHex: hex,
      );
      _nativeVelaController?.updateUserLocation(
        lat: point.latitude,
        lng: point.longitude,
        colorHex: hex,
      );
    });

    // Listen to recenter button click
    ref.listen<int>(recenterMapTriggerProvider, (_, __) async {
      LatLng? point = currentLocation.valueOrNull ?? _lastKnownLocation;
      if (point == null) {
        try {
          final pos =
              await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: Duration(seconds: 4),
                ),
              );
          point = LatLng(pos.latitude, pos.longitude);
        } catch (_) {}
      }
      if (point != null) {
        _lastKnownLocation = point;
        final hex =
            '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
        _nativeOlaController?.updateUserLocation(
          lat: point.latitude,
          lng: point.longitude,
          colorHex: hex,
        );
        _nativeVelaController?.updateUserLocation(
          lat: point.latitude,
          lng: point.longitude,
          colorHex: hex,
        );
        if (renderer == MapRendererType.osm) {
          try {
            _mapController.move(point, 16.0);
          } catch (_) {}
        }
        _nativeOlaController?.moveCamera(
          lat: point.latitude,
          lng: point.longitude,
          zoom: 16.0,
        );
        _nativeVelaController?.moveCamera(
          lat: point.latitude,
          lng: point.longitude,
          zoom: 16.0,
        );
      }
    });

    final LatLng fallbackCenter =
        widget.destinationMarker ??
        widget.initialCenter ??
        currentLocation.valueOrNull ??
        const LatLng(8.5241, 76.9366);

    final String baseStyleUrl = isDark
        ? ApiConstants.olaVectorStyleDark
        : ApiConstants.olaVectorStyleLight;
    final String styleUrl = ApiConstants.olaStyleUrlWithApiKey(
      baseStyleUrl,
      apiKey,
    );

    final Widget flutterMapFallback = _buildFlutterMap(
      context,
      tileConfig,
      currentLocation,
      fallbackCenter,
      theme,
      accent,
    );

    final LatLng? liveLoc = currentLocation.valueOrNull;
    if (liveLoc != null && liveLoc != _lastKnownLocation) {
      _lastKnownLocation = liveLoc;
      final hex =
          '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      _nativeOlaController?.updateUserLocation(
        lat: liveLoc.latitude,
        lng: liveLoc.longitude,
        colorHex: hex,
      );
      _nativeVelaController?.updateUserLocation(
        lat: liveLoc.latitude,
        lng: liveLoc.longitude,
        colorHex: hex,
      );
    }

    if (renderer == MapRendererType.vela && !kIsWeb && Platform.isAndroid) {
      return NativeVelaMapView(
        initialLat: fallbackCenter.latitude,
        initialLng: fallbackCenter.longitude,
        initialZoom: widget.initialZoom,
        styleUrl: isDark
            ? ApiConstants.velaDarkStyle
            : ApiConstants.velaLightStyle,
        fallback: flutterMapFallback,
        onMapReady: (controller) async {
          _nativeVelaController = controller;
          LatLng? userLoc = currentLocation.valueOrNull ?? _lastKnownLocation;
          if (userLoc == null) {
            try {
              final pos = await Geolocator.getLastKnownPosition() ??
                  await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                      timeLimit: Duration(seconds: 4),
                    ),
                  );
              userLoc = LatLng(pos.latitude, pos.longitude);
              _lastKnownLocation = userLoc;
            } catch (_) {}
          }
          final hex =
              '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          if (userLoc != null) {
            controller.updateUserLocation(
              lat: userLoc.latitude,
              lng: userLoc.longitude,
              colorHex: hex,
            );
            if (widget.destinationMarker == null) {
              controller.moveCamera(
                lat: userLoc.latitude,
                lng: userLoc.longitude,
                zoom: widget.initialZoom,
              );
            }
          }
          _syncNativeVelaState(accent, userLoc);
        },
      );
    }

    // If user selected Ola Maps and is running on Android, use genuine native Ola SDK
    if (renderer == MapRendererType.ola &&
        !kIsWeb &&
        Platform.isAndroid &&
        !_nativeOlaHasError) {
      return NativeOlaMapView(
        initialLat: fallbackCenter.latitude,
        initialLng: fallbackCenter.longitude,
        initialZoom: widget.initialZoom,
        apiKey: apiKey,
        styleUrl: styleUrl,
        fallback: flutterMapFallback,
        onMapReady: (controller) async {
          _nativeOlaController = controller;
          LatLng? userLoc = currentLocation.valueOrNull ?? _lastKnownLocation;
          if (userLoc == null) {
            try {
              final pos = await Geolocator.getLastKnownPosition() ??
                  await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                      timeLimit: Duration(seconds: 4),
                    ),
                  );
              userLoc = LatLng(pos.latitude, pos.longitude);
              _lastKnownLocation = userLoc;
            } catch (_) {}
          }
          final hex =
              '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
          if (userLoc != null) {
            controller.updateUserLocation(
              lat: userLoc.latitude,
              lng: userLoc.longitude,
              colorHex: hex,
            );
            if (widget.destinationMarker == null) {
              controller.moveCamera(
                lat: userLoc.latitude,
                lng: userLoc.longitude,
                zoom: widget.initialZoom,
              );
            }
          }
          _syncNativeOlaState(accent, userLoc);
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

    // Otherwise render high-speed FlutterMap with selected tile engine (Vela / OSM)
    return flutterMapFallback;
  }

  Widget _buildFlutterMap(
    BuildContext context,
    MapTileConfig tileConfig,
    AsyncValue<LatLng?> currentLocation,
    LatLng fallbackCenter,
    ThemeData theme,
    Color accent,
  ) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: fallbackCenter,
        initialZoom: widget.initialZoom,
        minZoom: 4,
        maxZoom: 19,
        onTap: (TapPosition tapPosition, LatLng point) =>
            widget.onTap?.call(point),
        onLongPress: (TapPosition tapPosition, LatLng point) =>
            widget.onLongPress?.call(point),
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
        if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: widget.routePoints!,
                strokeWidth: 5.5,
                color: accent,
              ),
            ],
          ),

        // Alert radius circle centred on destination
        if (widget.showRadius &&
            widget.alertRadius != null &&
            widget.destinationMarker != null)
          CircleLayer(
            circles: <CircleMarker>[
              CircleMarker(
                point: widget.destinationMarker!,
                radius: widget.alertRadius!,
                useRadiusInMeter: true,
                color: accent.withValues(alpha: 0.16),
                borderColor: accent,
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // Destination pin in accent color
        if (widget.destinationMarker != null)
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: widget.destinationMarker!,
                width: 48,
                height: 48,
                child: _DestinationPin(accentColor: accent),
              ),
            ],
          ),

        // Current location dot
        if (currentLocation.valueOrNull != null)
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: currentLocation.valueOrNull!,
                width: 32,
                height: 32,
                child: _CurrentLocationDot(accentColor: accent),
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
    );
  }
}

class _DestinationPin extends StatelessWidget {
  final Color accentColor;

  const _DestinationPin({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accentColor.withAlpha(120),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.black,
            size: 20,
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: accentColor),
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
  bool shouldRepaint(_PinTailPainter oldDelegate) => oldDelegate.color != color;
}

class _CurrentLocationDot extends StatefulWidget {
  final Color accentColor;
  const _CurrentLocationDot({required this.accentColor});

  @override
  State<_CurrentLocationDot> createState() => _CurrentLocationDotState();
}

class _CurrentLocationDotState extends State<_CurrentLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 1.0 + (_controller.value * 0.35);
        final opacity = 0.4 - (_controller.value * 0.25);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withValues(alpha: opacity),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: opacity * 1.5),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: widget.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
