import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/alert_config_provider.dart';
import 'widgets/radius_slider.dart';
import 'widgets/sound_picker.dart';

class AlertConfigScreen extends ConsumerWidget {
  const AlertConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final settings = ref.watch(alertConfigProvider);
    final notifier = ref.read(alertConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: <Widget>[

          // ── SECTION: Alert Radius ────────────────────────────────────────
          _SectionCard(
            title: 'Alert Radius',
            icon: Icons.radar_rounded,
            child: const RadiusSlider(),
          ),
          const SizedBox(height: 16),

          // ── SECTION: Snooze Radius ───────────────────────────────────────
          _SectionCard(
            title: 'Snooze Radius',
            icon: Icons.snooze_rounded,
            subtitle: 'Re-trigger radius after snooze',
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('100 m'),
                    _ValueChip(label: '${settings.snoozeRadiusMeters.round()} m'),
                    const Text('2000 m'),
                  ],
                ),
                Slider(
                  value: settings.snoozeRadiusMeters.clamp(100, 2000),
                  min: 100,
                  max: 2000,
                  divisions: 38,
                  label: '${settings.snoozeRadiusMeters.round()} m',
                  onChanged: (double v) => notifier.setSnoozeRadius(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── SECTION: Sound ────────────────────────────────────────────────
          _SectionCard(
            title: 'Alarm Sound',
            icon: Icons.music_note_rounded,
            child: const SoundPicker(),
          ),
          const SizedBox(height: 16),

          // ── SECTION: Volume ───────────────────────────────────────────────
          _SectionCard(
            title: 'Volume',
            icon: Icons.volume_up_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Speaker volume
                Text('Speaker / Headphone',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Row(
                  children: <Widget>[
                    const Icon(Icons.volume_down_rounded, size: 18),
                    Expanded(
                      child: Slider(
                        value: settings.alarmVolume,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        label: '${(settings.alarmVolume * 100).round()}%',
                        onChanged: (double v) => notifier.setAlarmVolume(v),
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded, size: 18),
                    const SizedBox(width: 8),
                    _ValueChip(label: '${(settings.alarmVolume * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),

                // Wearable volume
                Text('Bluetooth / Wearables (TWS)',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Row(
                  children: <Widget>[
                    const Icon(Icons.headphones_rounded, size: 18),
                    Expanded(
                      child: Slider(
                        value: settings.wearableVolume,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        label: '${(settings.wearableVolume * 100).round()}%',
                        onChanged: (double v) => notifier.setWearableVolume(v),
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded, size: 18),
                    const SizedBox(width: 8),
                    _ValueChip(label: '${(settings.wearableVolume * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── SECTION: Vibration ────────────────────────────────────────────
          _SectionCard(
            title: 'Vibration',
            icon: Icons.vibration_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: settings.vibrateEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable vibration'),
                  onChanged: (bool v) => notifier.setVibrationEnabled(v),
                ),

                if (settings.vibrateEnabled) ...<Widget>[
                  const SizedBox(height: 8),

                  // Vibration pre-delay (0-12s)
                  Text('Vibrate before sound — delay',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    settings.vibrationPreDelayMs == 0
                        ? 'Sound and vibration start simultaneously'
                        : 'Vibrate for ${(settings.vibrationPreDelayMs / 1000).round()}s, then play sound',
                    style: theme.textTheme.bodySmall,
                  ),
                  Row(
                    children: <Widget>[
                      const Text('0s'),
                      Expanded(
                        child: Slider(
                          value: (settings.vibrationPreDelayMs / 1000).clamp(0, 12).toDouble(),
                          min: 0,
                          max: 12,
                          divisions: 12,
                          label: '${(settings.vibrationPreDelayMs / 1000).round()}s',
                          onChanged: (double v) =>
                              notifier.setVibrationPreDelay((v * 1000).round()),
                        ),
                      ),
                      const Text('12s'),
                      const SizedBox(width: 8),
                      _ValueChip(label: '${(settings.vibrationPreDelayMs / 1000).round()}s'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── SECTION: Behaviour ─────────────────────────────────────────────
          _SectionCard(
            title: 'Behaviour',
            icon: Icons.tune_rounded,
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: settings.loopAlarm,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Loop alarm'),
                  subtitle: const Text('Repeat until dismissed'),
                  onChanged: (bool v) => notifier.setLoopAlarm(v),
                ),
                SwitchListTile.adaptive(
                  value: settings.fullScreenAlert,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Full-screen alert'),
                  subtitle: const Text('Show on lock screen when triggered'),
                  onChanged: (bool v) => notifier.setFullScreenAlert(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(50)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  const _ValueChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}