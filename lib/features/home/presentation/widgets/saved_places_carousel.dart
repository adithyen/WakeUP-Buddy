import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../destination/data/models/destination.dart';
import '../../../destination/data/models/place_suggestion.dart';
import '../../../destination/data/models/saved_place.dart';
import '../../../destination/presentation/search_screen.dart';
import '../../../destination/providers/destination_provider.dart';
import '../../../destination/providers/route_selection_provider.dart';
import '../../../destination/providers/saved_places_provider.dart';
import '../../providers/map_provider.dart';
import 'map_location_picker_screen.dart';

class SavedPlacesCarousel extends ConsumerWidget {
  const SavedPlacesCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SavedPlace> places = ref.watch(savedPlacesProvider);
    final Color accent = context.appAccent;
    final bool isDark = context.isDarkMode;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: places.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index < places.length) {
            final place = places[index];
            return _SavedPlaceCard(
              place: place,
              accentColor: accent,
              isDark: isDark,
              onTap: () => _handlePlaceTap(context, ref, place),
              onLongPress: () => _showPlaceOptionsModal(context, ref, place),
            );
          } else {
            // "+ Add Place" button
            return _AddPlaceButton(
              accentColor: accent,
              isDark: isDark,
              onTap: () => _showAddNewPlaceModal(context, ref),
            );
          }
        },
      ),
    );
  }

  void _handlePlaceTap(
    BuildContext context,
    WidgetRef ref,
    SavedPlace place,
  ) {
    HapticFeedback.lightImpact();
    if (place.isSet && place.latitude != null && place.longitude != null) {
      // Destination is already configured! Instantly set and plan route
      final dest = Destination(
        id: place.id,
        name: place.customName ?? place.label,
        description: place.address,
        latitude: place.latitude!,
        longitude: place.longitude!,
        selectedAt: DateTime.now(),
        source: PlaceSource.tomtom,
      );

      ref.read(selectedDestinationProvider.notifier).select(dest);

      final origin = ref.read(currentLocationProvider).valueOrNull ??
          const LatLng(8.5241, 76.9366);

      ref.read(routeSelectionProvider.notifier).fetchRoutes(
            origin: origin,
            destination: LatLng(dest.latitude, dest.longitude),
          );
    } else {
      // Unset: open prompt to choose location
      _showSetLocationPrompt(context, ref, place);
    }
  }

  void _showSetLocationPrompt(
    BuildContext context,
    WidgetRef ref,
    SavedPlace place,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set ${place.label}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ctx.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you would like to set this location:',
                style: TextStyle(
                  fontSize: 13,
                  color: ctx.appTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ctx.appAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded, color: ctx.appAccent),
                ),
                title: Text(
                  'Search for an address',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ctx.appTextPrimary,
                  ),
                ),
                subtitle: const Text('Type a place, landmark or street name'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final selected = await Navigator.of(context).push<Destination?>(
                    MaterialPageRoute(
                      builder: (_) => const SearchScreen(),
                    ),
                  );
                  if (selected != null) {
                    ref.read(savedPlacesProvider.notifier).updatePlaceLocation(
                          id: place.id,
                          address: selected.description ?? selected.name,
                          latitude: selected.latitude,
                          longitude: selected.longitude,
                          customName: selected.name,
                        );
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_rounded, color: Color(0xFF00C853)),
                ),
                title: Text(
                  'Choose location on map',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ctx.appTextPrimary,
                  ),
                ),
                subtitle: const Text('Drop a pin with live address geocoding'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final result = await Navigator.of(context).push<MapLocationResult?>(
                    MaterialPageRoute(
                      builder: (_) => MapLocationPickerScreen(
                        title: 'Set ${place.label}',
                      ),
                    ),
                  );
                  if (result != null) {
                    ref.read(savedPlacesProvider.notifier).updatePlaceLocation(
                          id: place.id,
                          address: result.address,
                          latitude: result.latitude,
                          longitude: result.longitude,
                        );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlaceOptionsModal(
    BuildContext context,
    WidgetRef ref,
    SavedPlace place,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                place.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ctx.appTextPrimary,
                ),
              ),
              if (place.address != null) ...[
                const SizedBox(height: 4),
                Text(
                  place.address!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ctx.appTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_location_alt_rounded),
                title: const Text('Change Location'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showSetLocationPrompt(context, ref, place);
                },
              ),
              if (place.isSet)
                ListTile(
                  leading: const Icon(Icons.clear_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Remove Saved Location',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(savedPlacesProvider.notifier).clearPlace(place.id);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddNewPlaceModal(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogCtx.appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Custom Place'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Place Label',
              hintText: 'e.g. Library, Beach, Parents House',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = textController.text.trim();
                if (label.isEmpty) return;
                Navigator.of(dialogCtx).pop();

                // Now pick location for this custom place
                final result = await Navigator.of(context).push<MapLocationResult?>(
                  MaterialPageRoute(
                    builder: (_) => MapLocationPickerScreen(
                      title: 'Set $label',
                    ),
                  ),
                );
                if (result != null) {
                  ref.read(savedPlacesProvider.notifier).addCustomPlace(
                        label: label,
                        address: result.address,
                        latitude: result.latitude,
                        longitude: result.longitude,
                      );
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  final SavedPlace place;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SavedPlaceCard({
    required this.place,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = place.isSet;
    final addressText = isSet
        ? (place.customName ?? place.address ?? place.label)
        : 'Set ${place.label.toLowerCase()}';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E232A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSet ? accentColor.withValues(alpha: 0.7) : (isDark ? Colors.white12 : Colors.black12),
            width: isSet ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSet
                    ? accentColor.withValues(alpha: 0.2)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                place.iconData,
                color: isSet ? accentColor : (isDark ? Colors.white70 : Colors.black54),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  addressText,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isSet
                        ? (isDark ? Colors.white60 : Colors.black54)
                        : accentColor,
                    fontWeight: isSet ? FontWeight.normal : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPlaceButton extends StatelessWidget {
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _AddPlaceButton({
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E232A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 18),
            const SizedBox(width: 6),
            Text(
              'Add Place',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
