import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Controller for interacting with the native Android Ola Map PlatformView.
class OlaMapController {
  final int viewId;
  final MethodChannel _channel;
  bool _isDisposed = false;

  OlaMapController(this.viewId)
      : _channel = MethodChannel('com.wakeupbuddy/ola_map_$viewId');

  Future<void> moveCamera({
    required double lat,
    required double lng,
    double zoom = 15.0,
    int duration = 400,
  }) async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('moveCamera', {
        'lat': lat,
        'lng': lng,
        'zoom': zoom,
        'duration': duration,
      });
    } catch (e) {
      debugPrint('[OlaMapController] moveCamera error: $e');
    }
  }

  Future<void> setStyleUrl(String styleUrl) async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('setStyleUrl', {'styleUrl': styleUrl});
    } catch (e) {
      debugPrint('[OlaMapController] setStyleUrl error: $e');
    }
  }

  Future<void> setDestination({
    required double lat,
    required double lng,
    required double radiusMeters,
    required String colorHex,
  }) async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('setDestination', {
        'lat': lat,
        'lng': lng,
        'radiusMeters': radiusMeters,
        'colorHex': colorHex,
      });
    } catch (e) {
      debugPrint('[OlaMapController] setDestination error: $e');
    }
  }

  Future<void> updateUserLocation({
    required double lat,
    required double lng,
    required String colorHex,
  }) async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('updateUserLocation', {
        'lat': lat,
        'lng': lng,
        'colorHex': colorHex,
      });
    } catch (e) {
      debugPrint('[OlaMapController] updateUserLocation error: $e');
    }
  }

  Future<void> drawRoute({
    required List<List<double>> points,
    required String colorHex,
    double width = 6.0,
  }) async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('drawRoute', {
        'points': points,
        'colorHex': colorHex,
        'width': width,
      });
    } catch (e) {
      debugPrint('[OlaMapController] drawRoute error: $e');
    }
  }

  Future<void> fitBounds({
    required List<List<double>> points,
    int padding = 120,
  }) async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('fitBounds', {
        'points': points,
        'padding': padding,
      });
    } catch (e) {
      debugPrint('[OlaMapController] fitBounds error: $e');
    }
  }

  Future<void> clearAll() async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod('clearAll');
    } catch (e) {
      debugPrint('[OlaMapController] clearAll error: $e');
    }
  }

  void dispose() {
    _isDisposed = true;
  }
}

/// Native Android Ola Map view widget embedding OlaMapSdk-1.8.4.aar
/// using PlatformViewLink + PlatformViewsService.initSurfaceAndroidView
/// matching the proven Nivara architecture.
class NativeOlaMapView extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final String apiKey;
  final String? styleUrl;
  final Widget? fallback;
  final void Function(OlaMapController controller)? onMapReady;
  final VoidCallback? onMapError;

  const NativeOlaMapView({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialZoom = 15.0,
    required this.apiKey,
    this.styleUrl,
    this.fallback,
    this.onMapReady,
    this.onMapError,
  });

  @override
  State<NativeOlaMapView> createState() => _NativeOlaMapViewState();
}

class _NativeOlaMapViewState extends State<NativeOlaMapView> {
  OlaMapController? _controller;
  bool _hasError = false;
  String? _lastStyleUrl;

  @override
  void didUpdateWidget(covariant NativeOlaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.styleUrl != null &&
        widget.styleUrl != _lastStyleUrl &&
        _controller != null) {
      _lastStyleUrl = widget.styleUrl;
      _controller?.setStyleUrl(widget.styleUrl!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final controller = OlaMapController(id);
    _controller = controller;

    controller._channel.setMethodCallHandler((call) async {
      if (call.method == 'onMapReady') {
        widget.onMapReady?.call(controller);
      } else if (call.method == 'onMapError') {
        debugPrint('[NativeOlaMapView] Native Map Error: ${call.arguments}');
        widget.onMapError?.call();
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid || _hasError) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    final creationParams = <String, dynamic>{
      'apiKey': widget.apiKey,
      'initialLat': widget.initialLat,
      'initialLng': widget.initialLng,
      'initialZoom': widget.initialZoom,
      if (widget.styleUrl != null) 'styleUrl': widget.styleUrl,
    };

    return PlatformViewLink(
      viewType: 'ola_native_map_view',
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              EagerGestureRecognizer.new,
            ),
          },
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: 'ola_native_map_view',
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
          ..create();
      },
    );
  }
}
