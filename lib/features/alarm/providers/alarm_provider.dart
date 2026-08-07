import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../alert_config/data/models/alert_settings.dart';
import '../../history/data/local_database.dart';
import '../../history/providers/history_provider.dart';
import '../../tracking/data/models/trip_state.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../services/alarm_service.dart';
import '../services/vibration_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum AlarmPhase { idle, vibrating, sounding, dismissed }

class AlarmState {
  final AlarmPhase phase;
  final DateTime? triggeredAt;
  final double? distanceAtTrigger;

  const AlarmState({
    this.phase = AlarmPhase.idle,
    this.triggeredAt,
    this.distanceAtTrigger,
  });

  AlarmState copyWith({
    AlarmPhase? phase,
    DateTime? triggeredAt,
    double? distanceAtTrigger,
  }) {
    return AlarmState(
      phase: phase ?? this.phase,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      distanceAtTrigger: distanceAtTrigger ?? this.distanceAtTrigger,
    );
  }

  @override
  String toString() =>
      'AlarmState(phase: $phase, triggeredAt: $triggeredAt, distanceAtTrigger: $distanceAtTrigger)';
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final alarmOrchestratorProvider =
    StateNotifierProvider<AlarmOrchestrator, AlarmState>((ref) {
  return AlarmOrchestrator(ref);
});

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------

/// Coordinates the full alert sequence: vibration + sound simultaneously → dismiss.
///
/// Sequence:
///   1. Receives [TripStatus.alerting] from [trackingProvider]
///   2. Fires vibration AND alarm sound simultaneously (Future.wait)
///   3. [dismissAlarm] stops both, saves trip as COMPLETED to history, stops service
///   4. [snoozeAlarm] silences alarm but keeps tracking active
class AlarmOrchestrator extends StateNotifier<AlarmState> {
  final Ref _ref;
  Timer? _vibrationTimer;
  late final ProviderSubscription<TripState> _trackingSubscription;

  AlarmOrchestrator(this._ref) : super(const AlarmState()) {
    _trackingSubscription = _ref.listen<TripState>(
      trackingProvider,
      (TripState? previous, TripState next) {
        if (next.status == TripStatus.alerting &&
            state.phase == AlarmPhase.idle) {
          unawaited(_executeAlertSequence(next));
        }
      },
    );
  }

  // -------------------------------------------------------------------------
  // Internal sequence
  // -------------------------------------------------------------------------

  Future<void> _executeAlertSequence(TripState tripState) async {
    final AlertSettings settings =
        tripState.alertSettings ?? const AlertSettings();

    state = AlarmState(
      phase: AlarmPhase.sounding,
      triggeredAt: DateTime.now(),
      distanceAtTrigger: tripState.currentDistanceMeters,
    );

    final int preDelayMs = settings.vibrationPreDelayMs;

    if (preDelayMs > 0 && settings.vibrateEnabled) {
      // Vibrate first, then start sound after delay
      unawaited(VibrationService.executePreAlarmVibration(
        durationMs: settings.vibrationDurationMs,
      ));
      _vibrationTimer = Timer(Duration(milliseconds: preDelayMs), () {
        unawaited(AlarmService.triggerAlarm(settings));
      });
    } else {
      // Fire both simultaneously
      await Future.wait(<Future<void>>[
        AlarmService.triggerAlarm(settings),
        if (settings.vibrateEnabled)
          VibrationService.executePreAlarmVibration(
            durationMs: settings.vibrationDurationMs,
          ),
      ]);
    }
  }

  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------

  /// Dismisses the alarm: stops vibration + sound, saves completed trip to
  /// history, then stops the tracking foreground service.
  Future<void> dismissAlarm() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    await VibrationService.cancel();
    await AlarmService.stopAlarm();

    // Save COMPLETED trip to history before stopping
    final TripState trip = _ref.read(trackingProvider);
    await _saveCompletedTrip(trip);

    state = state.copyWith(phase: AlarmPhase.dismissed);

    // Stop the background foreground service
    await _ref.read(trackingProvider.notifier).stopTrip();
  }

  /// Snoozes: silences alarm but keeps tracking active for re-trigger.
  Future<void> snoozeAlarm() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    await VibrationService.cancel();
    await AlarmService.stopAlarm();

    state = const AlarmState(phase: AlarmPhase.idle);
  }

  // -------------------------------------------------------------------------
  // History helper
  // -------------------------------------------------------------------------

  Future<void> _saveCompletedTrip(TripState trip) async {
    if (trip.destination == null) return;

    final TripRecord record = TripRecord(
      id: const Uuid().v4(),
      destinationName: trip.destination!.name,
      destinationDescription: trip.destination!.description,
      destinationLat: trip.destination!.latitude,
      destinationLng: trip.destination!.longitude,
      alertRadiusMeters: trip.alertSettings?.alertRadiusMeters ?? 500,
      startTime: trip.tripStartTime ?? state.triggeredAt ?? DateTime.now(),
      endTime: DateTime.now(),
      outcome: TripOutcome.completed,
      initialDistanceMeters: trip.initialDistanceMeters,
      alarmSoundId: trip.alertSettings?.alarmSoundId,
    );

    await _ref.read(tripHistoryProvider.notifier).addTrip(record);
  }

  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    _trackingSubscription.close();
    super.dispose();
  }
}
