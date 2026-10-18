import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/place_suggestion.dart';
import '../../../home/providers/map_provider.dart';
import '../../providers/destination_provider.dart';

class DestinationSearchSheet extends ConsumerStatefulWidget {
  const DestinationSearchSheet({super.key});

  @override
  ConsumerState<DestinationSearchSheet> createState() =>
      _DestinationSearchSheetState();
}

class _DestinationSearchSheetState
    extends ConsumerState<DestinationSearchSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    ref.read(destinationSearchProvider.notifier).clear();
    // Auto-focus keyboard when sheet opens
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

  IconData _iconForType(PlaceType type) {
    return switch (type) {
      PlaceType.temple => Icons.temple_hindu_rounded,
      PlaceType.college => Icons.school_rounded,
      PlaceType.hospital => Icons.local_hospital_rounded,
      PlaceType.shopping => Icons.shopping_bag_rounded,
      PlaceType.transit => Icons.directions_transit_rounded,
      PlaceType.busStop => Icons.directions_bus_rounded,
      PlaceType.trainStation => Icons.train_rounded,
      PlaceType.metroStation => Icons.directions_subway_rounded,
      PlaceType.airport => Icons.flight_rounded,
      PlaceType.landmark => Icons.place_rounded,
      PlaceType.address => Icons.home_rounded,
      PlaceType.other => Icons.location_on_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final DestinationSearchState searchState =
        ref.watch(destinationSearchProvider);
    final LatLng? currentLocation =
        ref.watch(currentLocationProvider).valueOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Handle ─────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: <Widget>[
                      const Text(
                        'Where to?',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: Color(0xFF374151)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Search field ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search stations, landmarks, cities...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 16, right: 12),
                          child: Icon(Icons.search_rounded,
                              color: AppColors.primaryDark, size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(),
                        suffixIcon: searchState.isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              )
                            : _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        color: Color(0xFF9CA3AF), size: 20),
                                    onPressed: () {
                                      _controller.clear();
                                      ref
                                          .read(destinationSearchProvider
                                              .notifier)
                                          .clear();
                                    },
                                  )
                                : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onChanged: (String value) {
                        setState(() {}); // refresh suffixIcon
                        if (value.trim().isEmpty) {
                          ref
                              .read(destinationSearchProvider.notifier)
                              .clear();
                          return;
                        }
                        ref
                            .read(destinationSearchProvider.notifier)
                            .autocomplete(
                              value,
                              nearLat: currentLocation?.latitude,
                              nearLng: currentLocation?.longitude,
                            );
                      },
                      onSubmitted: (String value) {
                        if (value.trim().isEmpty) {
                          ref
                              .read(destinationSearchProvider.notifier)
                              .clear();
                          return;
                        }
                        ref.read(destinationSearchProvider.notifier).search(
                              value,
                              nearLat: currentLocation?.latitude,
                              nearLng: currentLocation?.longitude,
                            );
                      },
                    ),
                  ),
                ),

                // ── Error message ────────────────────────────────────────────
                if (searchState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            searchState.errorMessage!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Results list ─────────────────────────────────────────────
                Flexible(
                  child: (_controller.text.trim().isEmpty ||
                          (searchState.suggestions.isEmpty &&
                              !searchState.isLoading))
                      ? _EmptyState(hasQuery: _controller.text.trim().isNotEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, bottom: 32),
                          itemCount: _controller.text.trim().isNotEmpty
                              ? searchState.suggestions.length
                              : 0,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (BuildContext context, int index) {
                            final PlaceSuggestion suggestion =
                                searchState.suggestions[index];
                            return _SuggestionTile(
                              suggestion: suggestion,
                              icon: _iconForType(suggestion.type),
                              onTap: () async {
                                await ref
                                    .read(selectedDestinationProvider.notifier)
                                    .setDestinationFromSuggestion(suggestion);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final PlaceSuggestion suggestion;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 20),
            ),
            const SizedBox(width: 14),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    suggestion.name,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.description.isEmpty
                        ? (suggestion.formattedAddress ?? '')
                        : suggestion.description,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Arrow
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFFD1D5DB), size: 14),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withAlpha(12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.travel_explore_rounded,
                color: AppColors.primaryDark.withAlpha(120),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No results found' : 'Start typing to search',
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Search for stations, landmarks, or any address',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}