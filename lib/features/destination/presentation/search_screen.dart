import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../history/data/local_database.dart';
import '../../history/providers/history_provider.dart';
import '../../home/providers/map_provider.dart';
import '../data/models/destination.dart';
import '../data/models/place_suggestion.dart';
import '../providers/destination_provider.dart';
import '../providers/route_selection_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    final LatLng? userPos = ref.read(currentLocationProvider).valueOrNull;
    ref.read(destinationSearchProvider.notifier).autocomplete(
          query,
          nearLat: userPos?.latitude,
          nearLng: userPos?.longitude,
        );
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    HapticFeedback.lightImpact();

    final dest = Destination(
      id: const Uuid().v4(),
      name: suggestion.name,
      description: suggestion.description,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      selectedAt: DateTime.now(),
      source: PlaceSource.ola,
    );

    ref.read(selectedDestinationProvider.notifier).select(dest);

    final LatLng? userPos = ref.read(currentLocationProvider).valueOrNull;
    if (userPos != null) {
      ref.read(routeSelectionProvider.notifier).fetchRoutes(
            origin: userPos,
            destination: LatLng(suggestion.latitude, suggestion.longitude),
          );
    }

    Navigator.of(context).pop();
  }

  IconData _iconForType(PlaceType type) {
    switch (type) {
      case PlaceType.busStop:
      case PlaceType.transit:
        return Icons.directions_bus_rounded;
      case PlaceType.trainStation:
      case PlaceType.metroStation:
        return Icons.train_rounded;
      case PlaceType.college:
        return Icons.school_rounded;
      case PlaceType.airport:
        return Icons.flight_rounded;
      case PlaceType.hospital:
        return Icons.local_hospital_rounded;
      case PlaceType.shopping:
        return Icons.shopping_bag_rounded;
      case PlaceType.temple:
        return Icons.temple_hindu_rounded;
      case PlaceType.landmark:
        return Icons.location_city_rounded;
      case PlaceType.address:
      case PlaceType.other:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedDestinations = ref.watch(savedDestinationsProvider);
    final searchState = ref.watch(destinationSearchProvider);
    final suggestions = searchState.suggestions;
    final isLoading = searchState.isLoading;
    final accent = context.appAccent;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Where to?',
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.appCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Input Capsule
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 18, right: 12),
                      child: Icon(
                        Icons.search_rounded,
                        color: accent,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onQueryChanged,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Where do you want to go?',
                          hintStyle: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 16,
                          ),
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.cancel_rounded,
                          color: context.appTextSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          _controller.clear();
                          ref.read(destinationSearchProvider.notifier).clear();
                        },
                      ),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Results List
            Expanded(
              child: suggestions.isEmpty && !isLoading
                  ? _buildEmptyOrInitialState(savedDestinations, accent)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => Divider(
                        color: context.appBorder.withValues(alpha: 0.5),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        final isSaved = savedDestinations.any((s) =>
                            s.name.toLowerCase() == suggestion.name.toLowerCase() ||
                            (s.latitude == suggestion.latitude && s.longitude == suggestion.longitude));

                        return InkWell(
                          onTap: () => _selectSuggestion(suggestion),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                // Left Category Avatar Circle
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: context.appCardElevated,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    _iconForType(suggestion.type),
                                    color: accent,
                                    size: 22,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Title, Subtitle, and Distance/Duration ETA
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.appTextPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        suggestion.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.appTextSecondary,
                                          fontSize: 12,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (suggestion.distanceMeters != null || suggestion.durationSeconds != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (suggestion.distanceMeters != null) ...[
                                              Icon(
                                                Icons.near_me_rounded,
                                                size: 13,
                                                color: accent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                suggestion.distanceMeters! >= 1000
                                                    ? '${(suggestion.distanceMeters! / 1000).toStringAsFixed(1)} km'
                                                    : '${suggestion.distanceMeters} m',
                                                style: TextStyle(
                                                  color: accent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                            if (suggestion.distanceMeters != null && suggestion.durationSeconds != null)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text('•', style: TextStyle(color: context.appTextTertiary, fontSize: 11)),
                                              ),
                                            if (suggestion.durationSeconds != null) ...[
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 13,
                                                color: context.appTextSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${(suggestion.durationSeconds! / 60).round()} min',
                                                style: TextStyle(
                                                  color: context.appTextSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Favorite Star Button
                                IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: isSaved ? const Color(0xFFFFD600) : context.appTextTertiary,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    if (isSaved) {
                                      final existing = savedDestinations.firstWhere((s) =>
                                          s.name.toLowerCase() == suggestion.name.toLowerCase());
                                      ref.read(savedDestinationsProvider.notifier).delete(existing.id);
                                    } else {
                                      final newSaved = SavedDestination(
                                        id: const Uuid().v4(),
                                        name: suggestion.name,
                                        description: suggestion.description,
                                        latitude: suggestion.latitude,
                                        longitude: suggestion.longitude,
                                        savedAt: DateTime.now(),
                                      );
                                      ref.read(savedDestinationsProvider.notifier).save(newSaved);
                                    }
                                  },
                                ),

                                // ETA and Distance Badges
                                if (suggestion.durationSeconds != null && suggestion.distanceMeters != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(suggestion.durationSeconds! / 60).round()} min',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(suggestion.distanceMeters! / 1000).toStringAsFixed(1)} km',
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
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrInitialState(List<SavedDestination> savedDestinations, Color accent) {
    if (_controller.text.isNotEmpty) {
      return Center(
        child: Text(
          'No matching places found.\nTry a different search term.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appTextSecondary, fontSize: 14),
        ),
      );
    }

    if (savedDestinations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appCard,
                shape: BoxShape.circle,
                border: Border.all(color: context.appBorder),
              ),
              child: Icon(
                Icons.search_rounded,
                color: accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Search Any Destination',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type a place, bus stand, metro station or shop name',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // If user has saved/bookmarked places, show them!
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Saved places',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...savedDestinations.map(
          (dest) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appCard,
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.star_rounded, color: Color(0xFFFFD600), size: 22),
            ),
            title: Text(
              dest.name,
              style: TextStyle(color: context.appTextPrimary, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              dest.description ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12),
            ),
            onTap: () {
              ref.read(selectedDestinationProvider.notifier).select(
                    Destination(
                      id: dest.id,
                      name: dest.name,
                      description: dest.description,
                      latitude: dest.latitude,
                      longitude: dest.longitude,
                      selectedAt: DateTime.now(),
                      source: PlaceSource.ola,
                    ),
                  );
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}
