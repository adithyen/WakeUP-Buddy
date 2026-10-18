import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/map_api_key_provider.dart';
import '../../../core/services/map_renderer_provider.dart';
import '../../../core/services/ola_maps_service.dart';
import '../../../core/theme/accent_color_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../alert_config/presentation/alert_config_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../history/providers/history_provider.dart';
import '../../settings/presentation/theme_toggle.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _customStyleController;
  bool _obscureKey = true;
  bool? _isConnected;
  bool _isChecking = false;

  int _selectedAccentIndex = 0;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: ref.read(mapApiKeyProvider) ?? '',
    );
    _customStyleController = TextEditingController(
      text: ref.read(customMapStyleProvider) ?? '',
    );
    _testConnection();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customStyleController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isChecking = true);
    final service = ref.read(olaMapsServiceProvider);
    final ok = await service.verifyConnection(_apiKeyController.text.trim());
    if (mounted) {
      setState(() {
        _isConnected = ok;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = ref.watch(accentColorProvider);
    _selectedAccentIndex = activeAccent.id;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.appAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 1. APPEARANCE CARD (Matching Designs/settings.png) ─────────────
          _buildSettingsCard(
            context,
            icon: Icons.palette_outlined,
            title: 'Appearance',
            children: [
              Text(
                'Theme',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const ThemeToggle(),
              const SizedBox(height: 20),
              Text(
                'Accent color',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(availableAccents.length, (index) {
                  final accentOpt = availableAccents[index];
                  final isSelected = _selectedAccentIndex == index;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(accentColorProvider.notifier)
                          .setAccentIndex(index);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentOpt.color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accentOpt.color.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                "This will change the app's primary color and highlights.",
                style: TextStyle(color: context.appTextTertiary, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 2. ALERT CONFIGURATION CARD ──────────────────────────────────
          _buildSettingsCard(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Alert configuration',
            children: [
              Text(
                'Adjust the alert radius, sound, vibration, and full-screen behavior before starting a trip.',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AlertConfigScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.appCardElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: context.appAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Open alert settings',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.appTextSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 3. MAP RENDERING ENGINE (Ola Maps / Vela Maps / OSM) ─────────
          _buildSettingsCard(
            context,
            icon: Icons.map_outlined,
            title: 'Map rendering engine',
            children: [
              Text(
                'Choose how the map is rendered on your device. Vela uses native MapLibre vector tiles; OSM uses raster tiles.',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ...MapRendererType.values.map((renderer) {
                final isSelected = ref.watch(mapRendererProvider) == renderer;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(mapRendererProvider.notifier)
                          .setRenderer(renderer);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.appAccent.withValues(alpha: 0.12)
                            : context.appCardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? context.appAccent
                              : context.appBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? context.appAccent
                                : context.appTextTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  renderer.displayName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? context.appAccent
                                        : context.appTextPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  renderer.description,
                                  style: TextStyle(
                                    color: context.appTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 16),

          // ── 4. OLA MAPS API KEY & CUSTOM STYLE ────────────────────────────
          _buildSettingsCard(
            context,
            icon: Icons.vpn_key_outlined,
            title: 'Ola Maps API key',
            children: [
              Text(
                'If you add a valid key, the app will use Ola Maps vector tiles. Otherwise it falls back to OpenStreetMap.',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // API Key text input with obscured dots
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.appCardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureKey,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          letterSpacing: 2.0,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Ola Maps API key',
                          hintStyle: TextStyle(
                            color: context.appTextTertiary,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: context.appTextSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Save & Clear buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appAccent,
                        foregroundColor:
                            ThemeData.estimateBrightnessForColor(
                                  context.appAccent,
                                ) ==
                                Brightness.light
                            ? Colors.black
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text(
                        'Save key',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final key = _apiKeyController.text.trim();
                        await ref
                            .read(mapApiKeyProvider.notifier)
                            .setKey(key.isEmpty ? null : key);
                        await _testConnection();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Ola Maps API key updated!'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.appTextPrimary,
                        side: BorderSide(color: context.appBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        _apiKeyController.clear();
                        await ref.read(mapApiKeyProvider.notifier).setKey(null);
                        await _testConnection();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Live Status Dot
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isChecking
                          ? Colors.orange
                          : (_isConnected == true
                                ? AppColors.success
                                : AppColors.error),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isChecking
                        ? 'Status: Verifying connection...'
                        : (_isConnected == true
                              ? 'Status: Ola Maps connected'
                              : 'Status: Offline / Invalid API Key'),
                    style: TextStyle(
                      color: _isConnected == true
                          ? context.appAccent
                          : context.appTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Divider(color: context.appBorder),
              const SizedBox(height: 10),

              // Custom Style URL / ID input
              Text(
                'Custom Vector Style (e.g. Style1-Dark)',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.appCardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: TextField(
                        controller: _customStyleController,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Style1-Dark or published style URL',
                          hintStyle: TextStyle(
                            color: context.appTextTertiary,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appCardElevated,
                      foregroundColor: context.appAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.appBorder),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final style = _customStyleController.text.trim();
                      await ref
                          .read(customMapStyleProvider.notifier)
                          .setStyle(style.isEmpty ? null : style);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Custom map style configured!'),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Set Style',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 4. DATA MANAGEMENT CARD (Matching Designs/settings.png) ────────
          _buildSettingsCard(
            context,
            icon: Icons.storage_rounded,
            title: 'Data',
            children: [
              _buildDataTile(
                context,
                icon: Icons.history_rounded,
                title: 'Trip History',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  );
                },
              ),
              Divider(color: context.appBorder, height: 1),
              _buildDataTile(
                context,
                icon: Icons.delete_outline_rounded,
                title: 'Clear Trip History',
                isDestructive: true,
                onTap: () async {
                  final confirm = await _showConfirmDialog(
                    context,
                    title: 'Clear Trip History?',
                    message:
                        'All past trip records will be permanently removed.',
                  );
                  if (confirm == true) {
                    await ref.read(tripHistoryProvider.notifier).clearAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Trip history cleared.')),
                      );
                    }
                  }
                },
              ),
              Divider(color: context.appBorder, height: 1),
              _buildDataTile(
                context,
                icon: Icons.bookmark_border_rounded,
                title: 'Clear Saved Destinations',
                isDestructive: true,
                onTap: () async {
                  final confirm = await _showConfirmDialog(
                    context,
                    title: 'Clear Saved Destinations?',
                    message: 'All bookmarked destinations will be removed.',
                  );
                  if (confirm == true) {
                    await ref
                        .read(savedDestinationsProvider.notifier)
                        .clearAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved destinations cleared.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.3 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.appAccent, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? AppColors.coralAlert
                  : context.appTextSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive
                      ? AppColors.coralAlert
                      : context.appTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appCard,
        title: Text(title, style: TextStyle(color: context.appTextPrimary)),
        content: Text(
          message,
          style: TextStyle(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(color: context.appTextSecondary),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralAlert,
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }
}
