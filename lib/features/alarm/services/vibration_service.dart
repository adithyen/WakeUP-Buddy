import 'package:vibration/vibration.dart';

/// Handles all device vibration for the alarm sequence.
///
/// Pattern design:
///   • Pre-alarm  → escalating pulses for [durationMs] (~7 000 ms default)
///   • Strong     → single 1 s burst at full amplitude (used alongside sound)
class VibrationService {
  VibrationService._();

  /// Returns whether the device has a vibration motor.
  static Future<bool> hasVibrator() async {
    return Vibration.hasVibrator();
  }

  /// Executes the pre-alarm escalating vibration pattern.
  ///
  /// Each cycle is 800 ms (500 ms on + 300 ms pause).
  /// Amplitude ramps from 128 up to 255 across all cycles.
  static Future<void> executePreAlarmVibration({
    int durationMs = 7000,
  }) async {
    if (!await hasVibrator()) return;

    // Each cycle = 500 ms vibrate + 300 ms gap = 800 ms
    final int cycles = (durationMs / 800).ceil();

    // Pattern array: [delay, vibrate, gap, vibrate, gap, ...]
    final List<int> pattern = <int>[];
    // Intensities array mirrors the pattern array lengths
    final List<int> intensities = <int>[];

    for (int i = 0; i < cycles; i++) {
      // Initial pause before each vibrate (0 for first, then 300 ms gap)
      final int gap = i == 0 ? 0 : 300;
      pattern.add(gap);
      intensities.add(0); // no vibration during gap

      // Vibration burst
      pattern.add(500);
      // Amplitude: linearly ramp from 128 → 255 across cycles
      final int amplitude = (128 + ((127 / cycles.clamp(1, cycles)) * i)).round().clamp(0, 255);
      intensities.add(amplitude);
    }

    await Vibration.vibrate(
      pattern: pattern,
      intensities: intensities,
    );
  }

  /// Short strong vibration (1 s at full amplitude) — used when alarm sound starts.
  static Future<void> vibrateStrong() async {
    if (!await hasVibrator()) return;
    await Vibration.vibrate(duration: 1000, amplitude: 255);
  }

  /// Cancels any ongoing vibration immediately.
  static Future<void> cancel() async {
    await Vibration.cancel();
  }
}
