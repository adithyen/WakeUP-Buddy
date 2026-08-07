import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../data/models/alert_settings.dart';
import '../../providers/alert_config_provider.dart';

/// Provider that holds a shared AudioPlayer for previews.
/// Disposed when screen is closed.
final _previewPlayerProvider = Provider.autoDispose<AudioPlayer>((ref) {
  final AudioPlayer player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

class SoundPicker extends ConsumerStatefulWidget {
  const SoundPicker({super.key});

  @override
  ConsumerState<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends ConsumerState<SoundPicker> {
  String? _previewingId;
  Timer? _previewTimer;
  List<_RingtoneOption> _systemRingtones = <_RingtoneOption>[];

  @override
  void initState() {
    super.initState();
    _scanSystemRingtones();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  /// Scan /storage/emulated/0/Ringtones for playable files
  Future<void> _scanSystemRingtones() async {
    const String ringtoneDir = '/storage/emulated/0/Ringtones';
    final Directory dir = Directory(ringtoneDir);
    if (!dir.existsSync()) return;

    final List<FileSystemEntity> files = dir
        .listSync()
        .whereType<File>()
        .where((File f) {
          final String ext = p.extension(f.path).toLowerCase();
          return ext == '.mp3' || ext == '.ogg' || ext == '.m4a' || ext == '.wav';
        })
        .toList()
      ..sort((FileSystemEntity a, FileSystemEntity b) =>
          p.basename(a.path).compareTo(p.basename(b.path)));

    if (mounted) {
      setState(() {
        _systemRingtones = files
            .map((FileSystemEntity f) => _RingtoneOption(
                  id: f.path,
                  label: p.basenameWithoutExtension(f.path),
                  path: f.path,
                ))
            .toList();
      });
    }
  }

  /// Play a 5-second preview of the selected sound
  Future<void> _preview(String id, {required String assetOrPath, required bool isAsset}) async {
    final AudioPlayer player = ref.read(_previewPlayerProvider);

    // Stop any current preview
    _previewTimer?.cancel();
    await player.stop();

    setState(() => _previewingId = id);

    try {
      if (isAsset) {
        await player.setAsset(assetOrPath);
      } else {
        await player.setFilePath(assetOrPath);
      }
      await player.play();

      // Auto-stop after 5s
      _previewTimer = Timer(const Duration(seconds: 5), () async {
        await player.stop();
        if (mounted) setState(() => _previewingId = null);
      });
    } catch (_) {
      if (mounted) setState(() => _previewingId = null);
    }
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    await ref.read(_previewPlayerProvider).stop();
    if (mounted) setState(() => _previewingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AlertSettings settings = ref.watch(alertConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Alarm Sound', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Tap any tune to preview (5s). Changes take effect on next alarm.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.lg),

        // ── Bundled tones ──────────────────────────────────────────────────
        _SectionLabel(label: 'Bundled Tones', icon: Icons.library_music_rounded),
        const SizedBox(height: AppDimensions.sm),
        ...kBundledAlarmTunes.map((Map<String, String> tone) {
          final String id = tone['id']!;
          final String label = tone['label']!;
          final bool selected = settings.soundSource == AlarmSoundSource.bundled &&
              settings.alarmSoundId == id;
          final bool isPreviewing = _previewingId == id;

          return _SoundTile(
            id: id,
            label: label,
            icon: Icons.music_note_rounded,
            isSelected: selected,
            isPreviewing: isPreviewing,
            onTap: () async {
              ref.read(alertConfigProvider.notifier).setSound(
                    soundId: id,
                    source: AlarmSoundSource.bundled,
                  );
              if (isPreviewing) {
                await _stopPreview();
              } else {
                await _preview(id, assetOrPath: 'assets/sounds/$id.mp3', isAsset: true);
              }
            },
          );
        }),

        const SizedBox(height: AppDimensions.lg),

        // ── System ringtones ──────────────────────────────────────────────
        _SectionLabel(label: 'Device Ringtones', icon: Icons.phonelink_ring_rounded),
        const SizedBox(height: 4),
        Text(
          '/storage/emulated/0/Ringtones',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        if (_systemRingtones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No ringtones found in /storage/emulated/0/Ringtones',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._systemRingtones.map((_RingtoneOption rt) {
            final bool selected = settings.soundSource == AlarmSoundSource.ringtone &&
                settings.alarmSoundId == rt.id;
            final bool isPreviewing = _previewingId == rt.id;

            return _SoundTile(
              id: rt.id,
              label: rt.label,
              icon: Icons.ring_volume_rounded,
              isSelected: selected,
              isPreviewing: isPreviewing,
              onTap: () async {
                ref.read(alertConfigProvider.notifier).setSound(
                      soundId: rt.id,
                      source: AlarmSoundSource.ringtone,
                      customPath: rt.path,
                    );
                if (isPreviewing) {
                  await _stopPreview();
                } else {
                  await _preview(rt.id, assetOrPath: rt.path, isAsset: false);
                }
              },
            );
          }),

        const SizedBox(height: AppDimensions.lg),

        // ── Custom file ───────────────────────────────────────────────────
        _SectionLabel(label: 'Custom File', icon: Icons.upload_file_rounded),
        const SizedBox(height: AppDimensions.sm),
        if (settings.soundSource == AlarmSoundSource.custom && settings.customSoundPath != null)
          _SoundTile(
            id: settings.customSoundPath!,
            label: p.basenameWithoutExtension(settings.customSoundPath!),
            icon: Icons.audio_file_rounded,
            isSelected: true,
            isPreviewing: _previewingId == settings.customSoundPath,
            onTap: () async {
              final bool isPreviewing = _previewingId == settings.customSoundPath;
              if (isPreviewing) {
                await _stopPreview();
              } else {
                await _preview(settings.customSoundPath!,
                    assetOrPath: settings.customSoundPath!, isAsset: false);
              }
            },
          ),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          leading: const Icon(Icons.folder_open_rounded),
          title: const Text('Pick from storage'),
          subtitle: const Text('MP3, OGG, WAV, M4A'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            await _pickCustomFile(ref);
          },
        ),
      ],
    );
  }

  Future<void> _pickCustomFile(WidgetRef ref) async {
    final TextEditingController ctrl = TextEditingController();
    final String? path = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter audio file path',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Paste the full path to your audio file:',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: '/storage/emulated/0/Music/alarm.mp3',
                hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC8FF00), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Use file',
                style: TextStyle(
                    color: Color(0xFFC8FF00), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (path != null && path.isNotEmpty && mounted) {
      if (File(path).existsSync()) {
        ref.read(alertConfigProvider.notifier).setSound(
              soundId: path,
              source: AlarmSoundSource.custom,
              customPath: path,
            );
        await _preview(path, assetOrPath: path, isAsset: false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not found: $path'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SoundTile extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isPreviewing;
  final VoidCallback onTap;

  const _SoundTile({
    required this.id,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isPreviewing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? accent.withAlpha(15) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: isSelected ? accent : theme.colorScheme.outline.withAlpha(120),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withAlpha(20) : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPreviewing ? Icons.stop_circle_rounded : icon,
                    color: isSelected ? accent : theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? accent : null,
                          )),
                      if (isPreviewing)
                        Text('Playing preview...',
                            style: TextStyle(
                              fontSize: 12,
                              color: accent,
                            )),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 20)
                else
                  Icon(Icons.play_circle_outline_rounded,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}

class _RingtoneOption {
  final String id;
  final String label;
  final String path;
  const _RingtoneOption({required this.id, required this.label, required this.path});
}