import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/map_api_key_provider.dart';
import '../../../core/theme/accent_color_provider.dart';
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
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: ref.read(mapApiKeyProvider) ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? apiKey = ref.watch(mapApiKeyProvider);
    final Color accent = ref.watch(accentColorProvider);
    final int accentIndex = ref.watch(accentColorIndexProvider);
    final bool hasValidKey = apiKey != null && apiKey.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.xl),
        children: <Widget>[
          // ── Appearance ────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.palette_rounded,
            title: 'Appearance',
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Theme',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                const ThemeToggle(),
                const SizedBox(height: 20),
                Text(
                  'Accent color',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "This will change the app's primary color and highlights.",
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Color circles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    AppColors.accentPalette.length,
                    (int i) {
                      final Color c = AppColors.accentPalette[i];
                      final bool selected = i == accentIndex;
                      return GestureDetector(
                        onTap: () =>
                            ref.read(accentColorIndexProvider.notifier).setIndex(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: selected ? 38 : 32,
                          height: selected ? 38 : 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: selected
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: c.withAlpha(120),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                          child: selected
                              ? Icon(Icons.check_rounded,
                                  color: Colors.black, size: 16)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.xl),

          // ── Alert Configuration ───────────────────────────────────────────
          _SectionCard(
            icon: Icons.notifications_rounded,
            title: 'Alert configuration',
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Adjust the alert radius, sound, vibration, and full-screen behavior before starting a trip.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _LimeButton(
                  label: 'Open alert settings',
                  icon: Icons.tune_rounded,
                  accent: accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AlertConfigScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.xl),

          // ── Ola Maps API Key ──────────────────────────────────────────────
          _SectionCard(
            icon: Icons.key_rounded,
            title: 'Ola Maps API key',
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'If you add a valid key, the app will use Ola Maps tiles. Otherwise it falls back to OpenStreetMap.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'API key',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: TextField(
                    controller: _apiKeyController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Paste your Ola Maps key here',
                      hintStyle: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: _LimeButton(
                        label: 'Save key',
                        icon: Icons.save_rounded,
                        accent: accent,
                        onTap: () async {
                          await ref
                              .read(mapApiKeyProvider.notifier)
                              .setKey(_apiKeyController.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Ola Maps key saved'),
                                backgroundColor: accent.withAlpha(220),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OutlineButton(
                        label: 'Clear',
                        accent: accent,
                        onTap: () async {
                          _apiKeyController.clear();
                          await ref
                              .read(mapApiKeyProvider.notifier)
                              .setKey(null);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hasValidKey
                            ? AppColors.success
                            : AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasValidKey
                          ? 'Status: Ola Maps connected'
                          : 'Status: Using OpenStreetMap fallback',
                      style: TextStyle(
                        color: hasValidKey ? accent : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: hasValidKey
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.xl),

          // ── Data ─────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.storage_rounded,
            title: 'Data',
            accent: accent,
            child: Column(
              children: <Widget>[
                _DataRow(
                  icon: Icons.history_rounded,
                  label: 'Trip History',
                  accent: accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const HistoryScreen()),
                  ),
                ),
                Divider(height: 1, color: AppColors.divider),
                _DataRow(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Clear Trip History',
                  accent: accent,
                  onTap: () async {
                    final bool? ok = await _showConfirmDialog(
                      context,
                      'Clear trip history?',
                      'All trip records will be deleted permanently.',
                    );
                    if (ok == true) {
                      ref.read(tripHistoryProvider.notifier).clearAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('History cleared')),
                        );
                      }
                    }
                  },
                ),
                Divider(height: 1, color: AppColors.divider),
                _DataRow(
                  icon: Icons.bookmark_remove_rounded,
                  label: 'Clear Saved Destinations',
                  accent: accent,
                  onTap: () async {
                    final bool? ok = await _showConfirmDialog(
                      context,
                      'Clear saved destinations?',
                      'All saved destinations will be removed.',
                    );
                    if (ok == true) {
                      ref.read(savedDestinationsProvider.notifier).clearAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Saved destinations cleared')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.xl),

          // ── About ─────────────────────────────────────────────────────────
          Center(
            child: Text(
              'WakeUp Buddy v2.0.0',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context,
    String title,
    String content,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(content,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared components
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LimeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _LimeButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}