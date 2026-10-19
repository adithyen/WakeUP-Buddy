import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/map_tile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../destination/presentation/search_screen.dart';
import '../../../destination/providers/destination_provider.dart';
import '../../providers/map_provider.dart';

class MapLocationResult {
  final String address;
  final double latitude;
  final double longitude;

  const MapLocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class MapLocationPickerScreen extends ConsumerStatefulWidget {
  final LatLng? initialCenter;
  final String title;

  const MapLocationPickerScreen({
    super.key,
    this.initialCenter,
    this.title = 'Choose location on map',
  });

  @override
  ConsumerState<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState
    extends ConsumerState<MapLocationPickerScreen> {
  late final MapController _mapController = MapController();
  late LatLng _currentCenter;
  String _currentAddress = 'Locating address...';
  bool _isGeocoding = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialCenter ?? const LatLng(8.5241, 76.9366);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
  }

  Future<void> _initLocation() async {
    final live = ref.read(currentLocationProvider).valueOrNull;
    if (live != null) {
      setState(() => _currentCenter = live);
      _mapController.move(live, 16.0);
      _reverseGeocode(live);
    } else {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          final target = LatLng(pos.latitude, pos.longitude);
          setState(() => _currentCenter = target);
          _mapController.move(target, 16.0);
          _reverseGeocode(target);
        }
      } catch (_) {}
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _currentCenter = camera.center;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _reverseGeocode(_currentCenter);
      });
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final repo = ref.read(placesRepositoryProvider);
      final place = await repo.reverseGeocode(point.latitude, point.longitude);
      if (mounted) {
        final addressStr = place?.formattedAddress ?? place?.description ?? place?.name ?? '';
        setState(() {
          _currentAddress = addressStr.isNotEmpty
              ? addressStr
              : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isGeocoding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentAddress =
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isGeocoding = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MapTileConfig tileConfig = ref.watch(mapTileConfigProvider);
    final Color accent = context.appAccent;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.0,
              minZoom: 4,
              maxZoom: 19,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileConfig.urlTemplate,
                additionalOptions: tileConfig.additionalOptions,
                fallbackUrl: tileConfig.fallbackUrl,
                tileProvider: tileConfig.tileProvider,
                userAgentPackageName: 'com.wakeupbuddy.wakeup_buddy',
                maxNativeZoom: 18,
              ),
              // TomTom Live Traffic Flow overlay
              TileLayer(
                urlTemplate: ApiConstants.tomtomTrafficFlowTiles(
                  ApiConstants.defaultTomTomApiKey,
                ),
                userAgentPackageName: 'com.wakeupbuddy.wakeup_buddy',
                maxNativeZoom: 18,
              ),
            ],
          ),

          // 2. Central Pin Drop with Glowing Target (Matching 1bfd4743-27d3-4a85-b174-ff37b1373ab8.jpg)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing radial pulse
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00E676).withValues(alpha: 0.55),
                          const Color(0xFF00B0FF).withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Inner solid cyan/emerald pin
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Floating Search Capsule
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: context.appTextPrimary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final result = await Navigator.of(context).push<dynamic>(
                          MaterialPageRoute(builder: (_) => const SearchScreen()),
                        );
                        if (result != null && mounted) {
                          if (!context.mounted) return;
                          Navigator.of(context).pop(result);
                        }
                      },
                      child: Text(
                        'Search city, landmark or road...',
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 14.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),

          // 4. Floating Recenter GPS Button
          Positioned(
            right: 18,
            bottom: 230,
            child: FloatingActionButton.small(
              backgroundColor: context.appSurface,
              foregroundColor: accent,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () async {
                HapticFeedback.selectionClick();
                final live = ref.read(currentLocationProvider).valueOrNull;
                if (live != null) {
                  _mapController.move(live, 16.5);
                  _reverseGeocode(live);
                }
              },
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // 5. Bottom Confirmation Card (Matching Reference 1bfd4743-27d3-4a85-b174-ff37b1373ab8.jpg)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address info card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Color(0xFF00C853),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isGeocoding ? 'Detecting address...' : _currentAddress,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: context.appTextPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_currentCenter.latitude.toStringAsFixed(5)}° N, ${_currentCenter.longitude.toStringAsFixed(5)}° E',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm Selected Location Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop(
                          MapLocationResult(
                            address: _currentAddress,
                            latitude: _currentCenter.latitude,
                            longitude: _currentCenter.longitude,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Selected Location',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
