import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Native MapLibre view for the Vela/OpenFreeMap vector basemap.
///
/// This deliberately has no Ola key or Ola SDK dependency. FlutterMap remains
/// the fallback for non-Android platforms and for future native failures.
class VelaMapController {
  final MethodChannel _channel;
  VelaMapController(int viewId)
    : _channel = MethodChannel('com.wakeupbuddy/vela_map_$viewId');

  Future<void> moveCamera({
    required double lat,
    required double lng,
    double zoom = 15,
  }) async {
    await _channel.invokeMethod('moveCamera', {
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
    });
  }

  Future<void> updateUserLocation({
    required double lat,
    required double lng,
    required String colorHex,
  }) async {
    await _channel.invokeMethod('updateUserLocation', {
      'lat': lat,
      'lng': lng,
      'colorHex': colorHex,
    });
  }

  Future<void> setDestination({
    required double lat,
    required double lng,
    required double radiusMeters,
    required String colorHex,
  }) async {
    await _channel.invokeMethod('setDestination', {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      'colorHex': colorHex,
    });
  }

  Future<void> drawRoute({
    required List<List<double>> points,
    required String colorHex,
    double width = 6,
  }) async {
    await _channel.invokeMethod('drawRoute', {
      'points': points,
      'colorHex': colorHex,
      'width': width,
    });
  }

  Future<void> fitBounds({
    required List<List<double>> points,
    int padding = 120,
  }) async {
    await _channel.invokeMethod('fitBounds', {
      'points': points,
      'padding': padding,
    });
  }

  Future<void> clearRoute() async {
    try {
      await _channel.invokeMethod('clearRoute');
    } catch (e) {
      debugPrint('[VelaMapController] clearRoute error: $e');
    }
  }

  Future<void> clearDestination() async {
    try {
      await _channel.invokeMethod('clearDestination');
    } catch (e) {
      debugPrint('[VelaMapController] clearDestination error: $e');
    }
  }

  Future<void> setStyleUrl(String styleUrl) async {
    try {
      await _channel.invokeMethod('setStyleUrl', {'styleUrl': styleUrl});
    } catch (e) {
      debugPrint('[VelaMapController] setStyleUrl error: $e');
    }
  }
}

class NativeVelaMapView extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final String styleUrl;
  final Widget fallback;
  final void Function(VelaMapController controller)? onMapReady;

  const NativeVelaMapView({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.initialZoom,
    required this.styleUrl,
    required this.fallback,
    this.onMapReady,
  });

  @override
  State<NativeVelaMapView> createState() => _NativeVelaMapViewState();
}

class _NativeVelaMapViewState extends State<NativeVelaMapView> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) return widget.fallback;

    final params = <String, dynamic>{
      'initialLat': widget.initialLat,
      'initialLng': widget.initialLng,
      'initialZoom': widget.initialZoom,
      'styleUrl': widget.styleUrl,
    };

    return PlatformViewLink(
      viewType: 'vela_native_map_view',
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (creationParams) {
        return PlatformViewsService.initSurfaceAndroidView(
            id: creationParams.id,
            viewType: 'vela_native_map_view',
            layoutDirection: TextDirection.ltr,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
          )
          ..addOnPlatformViewCreatedListener(
            creationParams.onPlatformViewCreated,
          )
          ..addOnPlatformViewCreatedListener((id) {
            widget.onMapReady?.call(VelaMapController(id));
          })
          ..create();
      },
    );
  }
}
