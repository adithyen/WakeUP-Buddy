import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/alert_settings.dart';
import '../../providers/alert_config_provider.dart';

class SoundPicker extends ConsumerStatefulWidget {
  const SoundPicker({super.key});

  @override
  ConsumerState<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends ConsumerState<SoundPicker> {
  final AudioPlayer _player = AudioPlayer();
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
    _player.dispose();
    super.dispose();
  }

  /// Scan /storage/emulated/0/Ringtones for playable files
  Future<void> _scanSystemRingtones() async {
    const String ringtoneDir = '/storage/emulated/0/Ringtones';
    final Directory dir = Directory(ringtoneDir);
    if (!dir.existsSync()) return;

    try {
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
    } catch (_) {}
  }

  /// Play a 5-second preview of the selected sound
  Future<void> _preview(String id, {required String assetOrPath, required bool isAsset}) async {
    _previewTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}

    setState(() => _previewingId = id);

    try {
      if (isAsset) {
        await _player.setAsset(assetOrPath);
      } else {
        await _player.setFilePath(assetOrPath);
      }
      await _player.setVolume(1.0);
      await _player.seek(Duration.zero);
      await _player.play();

      _previewTimer = Timer(const Duration(seconds: 5), () async {
        try {
          await _player.stop();
        } catch (_) {}
        if (mounted) setState(() => _previewingId = null);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _previewingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot preview sound: $e')),
        );
      }
    }
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) setState(() => _previewingId = null);
  }

  /// Native File Picker to select custom audio file
  Future<void> _pickAudioFile() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
      );

      if (file != null && file.path != null) {
        final String path = file.path!;
        ref.read(alertConfigProvider.notifier).setSound(
              soundId: path,
              source: AlarmSoundSource.custom,
              customPath: path,
            );
        await _preview(path, assetOrPath: path, isAsset: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AlertSettings settings = ref.watch(alertConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Bundled alarm tunes ──────────────────────────────────────────
        const _SectionLabel(label: 'Bundled Alarm Tunes', icon: Icons.album_rounded),
        const SizedBox(height: 10),
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
        const _SectionLabel(label: 'Device Ringtones', icon: Icons.phonelink_ring_rounded),
        const SizedBox(height: 4),
        Text(
          '/storage/emulated/0/Ringtones',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.appTextSecondary,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        if (_systemRingtones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No ringtones found in device Ringtones folder',
              style: TextStyle(color: context.appTextTertiary, fontSize: 13),
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

        // ── Custom file selection via FilePicker ──────────────────────────
        const _SectionLabel(label: 'Custom Audio File', icon: Icons.audio_file_rounded),
        const SizedBox(height: 10),
        if (settings.soundSource == AlarmSoundSource.custom && settings.customSoundPath != null)
          _SoundTile(
            id: settings.customSoundPath!,
            label: p.basename(settings.customSoundPath!),
            icon: Icons.music_note_rounded,
            isSelected: true,
            isPreviewing: _previewingId == settings.customSoundPath,
            onTap: () async {
              if (_previewingId == settings.customSoundPath) {
                await _stopPreview();
              } else {
                await _preview(
                  settings.customSoundPath!,
                  assetOrPath: settings.customSoundPath!,
                  isAsset: false,
                );
              }
            },
          ),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appAccent,
            side: BorderSide(color: context.appBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          icon: const Icon(Icons.folder_open_rounded, size: 20),
          label: const Text(
            'Choose audio file from device...',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: _pickAudioFile,
        ),
      ],
    );
  }
}

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
    final accent = context.appAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.12) : context.appCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? accent : context.appBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.2)
                        : context.appCardElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPreviewing ? Icons.stop_circle_rounded : icon,
                    color: isSelected ? accent : context.appTextSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? accent : context.appTextPrimary,
                          fontSize: 15,
                        ),
                      ),
                      if (isPreviewing)
                        Text(
                          'Playing 5s preview...',
                          style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 22)
                else
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: context.appTextSecondary,
                    size: 22,
                  ),
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
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: context.appAccent),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
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