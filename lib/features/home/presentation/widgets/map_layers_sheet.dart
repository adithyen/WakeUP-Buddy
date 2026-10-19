import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/map_renderer_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/map_layers_config.dart';
import '../../providers/map_layers_provider.dart';

void showMapLayersSheet(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext ctx) => const MapLayersSheet(),
  );
}

class MapLayersSheet extends ConsumerWidget {
  const MapLayersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MapLayersConfig config = ref.watch(mapLayersConfigProvider);
    final MapLayersNotifier notifier = ref.read(mapLayersConfigProvider.notifier);
    final MapRendererType currentRenderer = ref.watch(mapRendererProvider);
    final Color accent = context.appAccent;
    final bool isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: context.appBorder.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Map type & details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.appTextSecondary),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 1: Map Type
          Text(
            'Map type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTypeCard(
                title: 'Default',
                icon: Icons.map_outlined,
                isSelected: config.mapStyleType == 'standard',
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setMapStyleType('standard');
                },
              ),
              const SizedBox(width: 12),
              _buildTypeCard(
                title: 'Dark theme',
                icon: Icons.dark_mode_rounded,
                isSelected: config.mapStyleType == 'dark',
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setMapStyleType('dark');
                },
              ),
              const SizedBox(width: 12),
              _buildTypeCard(
                title: 'Satellite',
                icon: Icons.satellite_alt_rounded,
                isSelected: config.mapStyleType == 'satellite',
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setMapStyleType('satellite');
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: context.appBorder.withValues(alpha: 0.4), height: 1),
          const SizedBox(height: 16),

          // Section 2: Map Details / Overlays
          Text(
            'Map details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDetailToggle(
                title: 'Traffic',
                subtitle: 'Live flow',
                icon: Icons.traffic_rounded,
                iconColor: const Color(0xFF4CAF50),
                isActive: config.showTrafficFlow,
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.toggleTrafficFlow();
                },
              ),
              const SizedBox(width: 12),
              _buildDetailToggle(
                title: 'Road Closures',
                subtitle: 'Barricades',
                icon: Icons.block_rounded,
                iconColor: const Color(0xFFE53935),
                isActive: config.showRoadClosures,
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.toggleRoadClosures();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildDetailToggle(
                title: 'Delay Badges',
                subtitle: 'Live delays',
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFFFF9800),
                isActive: config.showDelayBadges,
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.toggleDelayBadges();
                },
              ),
              const SizedBox(width: 12),
              _buildDetailToggle(
                title: 'Incidents',
                subtitle: 'Accidents & works',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFFFB300),
                isActive: config.showIncidents,
                accentColor: accent,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.toggleIncidents();
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: context.appBorder.withValues(alpha: 0.4), height: 1),
          const SizedBox(height: 16),

          // Section 3: Map Provider Engine
          Text(
            'Map engine',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildEngineChip(
                  title: 'Ola Maps',
                  renderer: MapRendererType.ola,
                  current: currentRenderer,
                  accentColor: accent,
                  onSelect: () {
                    HapticFeedback.selectionClick();
                    ref.read(mapRendererProvider.notifier).setRenderer(MapRendererType.ola);
                  },
                ),
                const SizedBox(width: 8),
                _buildEngineChip(
                  title: 'TomTom Maps',
                  renderer: MapRendererType.tomtom,
                  current: currentRenderer,
                  accentColor: accent,
                  onSelect: () {
                    HapticFeedback.selectionClick();
                    ref.read(mapRendererProvider.notifier).setRenderer(MapRendererType.tomtom);
                  },
                ),
                const SizedBox(width: 8),
                _buildEngineChip(
                  title: 'OpenStreetMap',
                  renderer: MapRendererType.osm,
                  current: currentRenderer,
                  accentColor: accent,
                  onSelect: () {
                    HapticFeedback.selectionClick();
                    ref.read(mapRendererProvider.notifier).setRenderer(MapRendererType.osm);
                  },
                ),
                const SizedBox(width: 8),
                _buildEngineChip(
                  title: 'Vela Maps',
                  renderer: MapRendererType.vela,
                  current: currentRenderer,
                  accentColor: accent,
                  onSelect: () {
                    HapticFeedback.selectionClick();
                    ref.read(mapRendererProvider.notifier).setRenderer(MapRendererType.vela);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 78,
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: isDark ? 0.18 : 0.12)
                : (isDark ? const Color(0xFF1E232A) : const Color(0xFFF1F3F5)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? accentColor : (isDark ? Colors.white70 : Colors.black87),
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? accentColor : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0xFF1C2B36) : const Color(0xFFE8F5E9))
                : (isDark ? const Color(0xFF1E232A) : const Color(0xFFF1F3F5)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? accentColor : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(Icons.check_circle_rounded, color: accentColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngineChip({
    required String title,
    required MapRendererType renderer,
    required MapRendererType current,
    required Color accentColor,
    required VoidCallback onSelect,
  }) {
    final isSelected = renderer == current;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : null,
          ),
        ),
      ),
    );
  }
}
