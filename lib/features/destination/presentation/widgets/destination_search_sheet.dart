import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/accent_color_provider.dart';
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
      PlaceType.busStop => Icons.directions_bus_rounded,
      PlaceType.trainStation => Icons.train_rounded,
      PlaceType.metroStation => Icons.directions_subway_rounded,
      PlaceType.airport => Icons.flight_rounded,
      PlaceType.landmark => Icons.account_balance_rounded,
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
    final Color accent = ref.watch(accentColorProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Handle ───────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: <Widget>[
                  const Text(
                    'Where to?',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search field ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: accent.withAlpha(120), width: 1.5),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search places, landmarks, addresses...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Icon(Icons.search_rounded, color: accent, size: 22),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                    suffixIcon: searchState.isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            ),
                          )
                        : _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textSecondary, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(destinationSearchProvider.notifier)
                                      .clear();
                                  setState(() {});
                                },
                              )
                            : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (String value) {
                    setState(() {});
                    ref
                        .read(destinationSearchProvider.notifier)
                        .autocomplete(
                          value,
                          nearLat: currentLocation?.latitude,
                          nearLng: currentLocation?.longitude,
                        );
                  },
                  onSubmitted: (String value) {
                    ref.read(destinationSearchProvider.notifier).search(
                          value,
                          nearLat: currentLocation?.latitude,
                          nearLng: currentLocation?.longitude,
                        );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Error ────────────────────────────────────────────────────────
            if (searchState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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

            const SizedBox(height: 4),

            // ── Results list ─────────────────────────────────────────────────
            Flexible(
              child: searchState.suggestions.isEmpty && !searchState.isLoading
                  ? _EmptyState(
                      hasQuery: _controller.text.isNotEmpty, accent: accent)
                  : ListView.separated(
                      padding: const EdgeInsets.only(
                          left: 20, right: 20, bottom: 32),
                      itemCount: searchState.suggestions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final PlaceSuggestion suggestion =
                            searchState.suggestions[index];
                        return _SuggestionTile(
                          suggestion: suggestion,
                          icon: _iconForType(suggestion.type),
                          accent: accent,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final PlaceSuggestion suggestion;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: accent.withAlpha(20),
      highlightColor: accent.withAlpha(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            // Icon circle
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withAlpha(60), width: 1),
              ),
              child: Icon(icon, color: accent, size: 20),
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
                      color: AppColors.textPrimary,
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
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Favorite star (placeholder)
            const Icon(
              Icons.star_border_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final Color accent;
  const _EmptyState({required this.hasQuery, required this.accent});

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
                color: accent.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.travel_explore_rounded,
                color: accent.withAlpha(180),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No results found' : 'Start typing to search',
              style: const TextStyle(
                color: AppColors.textPrimary,
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
                color: AppColors.textSecondary,
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