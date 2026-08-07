import 'dart:convert';

import 'package:hive/hive.dart';

/// Lightweight JSON-encoded persistence for trip records.
/// Uses the existing Hive Box<String> pattern (no code generation needed).
class TripRecord {
  final String id;
  final String destinationName;
  final String? destinationDescription;
  final double destinationLat;
  final double destinationLng;
  final double alertRadiusMeters;
  final DateTime startTime;
  final DateTime? endTime;
  final TripOutcome outcome;
  final double? initialDistanceMeters;
  final String? alarmSoundId;

  const TripRecord({
    required this.id,
    required this.destinationName,
    this.destinationDescription,
    required this.destinationLat,
    required this.destinationLng,
    required this.alertRadiusMeters,
    required this.startTime,
    this.endTime,
    required this.outcome,
    this.initialDistanceMeters,
    this.alarmSoundId,
  });

  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'destinationName': destinationName,
        'destinationDescription': destinationDescription,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'alertRadiusMeters': alertRadiusMeters,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'outcome': outcome.name,
        'initialDistanceMeters': initialDistanceMeters,
        'alarmSoundId': alarmSoundId,
      };

  factory TripRecord.fromJson(Map<String, dynamic> j) => TripRecord(
        id: j['id'] as String,
        destinationName: j['destinationName'] as String,
        destinationDescription: j['destinationDescription'] as String?,
        destinationLat: (j['destinationLat'] as num).toDouble(),
        destinationLng: (j['destinationLng'] as num).toDouble(),
        alertRadiusMeters: (j['alertRadiusMeters'] as num).toDouble(),
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: j['endTime'] != null
            ? DateTime.parse(j['endTime'] as String)
            : null,
        outcome: TripOutcome.values.firstWhere(
          (TripOutcome o) => o.name == j['outcome'],
          orElse: () => TripOutcome.cancelled,
        ),
        initialDistanceMeters:
            (j['initialDistanceMeters'] as num?)?.toDouble(),
        alarmSoundId: j['alarmSoundId'] as String?,
      );
}

enum TripOutcome { completed, cancelled, failed }

// ─────────────────────────────────────────────────────────────────────────────

class SavedDestination {
  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final DateTime savedAt;
  final int useCount;
  final DateTime? lastUsedAt;
  final double? defaultRadius;
  final String? emoji;
  final String? nickname;

  const SavedDestination({
    required this.id,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
    this.useCount = 0,
    this.lastUsedAt,
    this.defaultRadius,
    this.emoji,
    this.nickname,
  });

  SavedDestination copyWith({
    int? useCount,
    DateTime? lastUsedAt,
    String? nickname,
    String? emoji,
    double? defaultRadius,
  }) =>
      SavedDestination(
        id: id,
        name: name,
        description: description,
        latitude: latitude,
        longitude: longitude,
        savedAt: savedAt,
        useCount: useCount ?? this.useCount,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        defaultRadius: defaultRadius ?? this.defaultRadius,
        emoji: emoji ?? this.emoji,
        nickname: nickname ?? this.nickname,
      );

  String get displayName => nickname ?? name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'savedAt': savedAt.toIso8601String(),
        'useCount': useCount,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'defaultRadius': defaultRadius,
        'emoji': emoji,
        'nickname': nickname,
      };

  factory SavedDestination.fromJson(Map<String, dynamic> j) => SavedDestination(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        savedAt: DateTime.parse(j['savedAt'] as String),
        useCount: j['useCount'] as int? ?? 0,
        lastUsedAt: j['lastUsedAt'] != null
            ? DateTime.parse(j['lastUsedAt'] as String)
            : null,
        defaultRadius: (j['defaultRadius'] as num?)?.toDouble(),
        emoji: j['emoji'] as String?,
        nickname: j['nickname'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class TripStats {
  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;
  final Duration totalDuration;

  const TripStats({
    required this.totalTrips,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.totalDuration,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Repositories
// ─────────────────────────────────────────────────────────────────────────────

class TripHistoryRepository {
  static const String _boxName = 'trip_history_v1';

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  Future<void> save(TripRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async => _box.clear();

  List<TripRecord> getAll() {
    final List<TripRecord> records = _box.values
        .map<TripRecord?>((String raw) {
          try {
            return TripRecord.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<TripRecord>()
        .toList()
      ..sort((TripRecord a, TripRecord b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  List<TripRecord> getRecent({int limit = 10}) =>
      getAll().take(limit).toList();

  TripStats getStats() {
    final List<TripRecord> all = getAll();
    return TripStats(
      totalTrips: all.length,
      completedTrips:
          all.where((TripRecord t) => t.outcome == TripOutcome.completed).length,
      cancelledTrips:
          all.where((TripRecord t) => t.outcome == TripOutcome.cancelled).length,
      totalDuration: all.fold(
        Duration.zero,
        (Duration sum, TripRecord t) => sum + (t.duration ?? Duration.zero),
      ),
    );
  }

  /// Remove trips older than [days] and keep only most recent [maxRecords].
  Future<void> cleanup({int days = 180, int maxRecords = 100}) async {
    final DateTime cutoff =
        DateTime.now().subtract(Duration(days: days));
    final List<TripRecord> all = getAll();

    for (final TripRecord t in all) {
      if (t.startTime.isBefore(cutoff)) {
        await _box.delete(t.id);
      }
    }

    final List<TripRecord> remaining = getAll();
    if (remaining.length > maxRecords) {
      final List<TripRecord> toDelete =
          remaining.skip(maxRecords).toList();
      for (final TripRecord t in toDelete) {
        await _box.delete(t.id);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class SavedDestinationsRepository {
  static const String _boxName = 'saved_destinations_v1';

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  Box<String> get _box => Hive.box<String>(_boxName);

  Future<void> save(SavedDestination dest) async {
    await _box.put(dest.id, jsonEncode(dest.toJson()));
  }

  Future<void> delete(String id) async => _box.delete(id);
  Future<void> clearAll() async => _box.clear();

  List<SavedDestination> getAll() {
    return _box.values
        .map<SavedDestination?>((String raw) {
          try {
            return SavedDestination.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedDestination>()
        .toList()
      ..sort((SavedDestination a, SavedDestination b) =>
          b.useCount.compareTo(a.useCount));
  }

  bool isSaved(double lat, double lng, {double thresholdMeters = 100}) {
    for (final SavedDestination d in getAll()) {
      final double dist = _haversine(lat, lng, d.latitude, d.longitude);
      if (dist < thresholdMeters) return true;
    }
    return false;
  }

  Future<void> incrementUseCount(String id) async {
    final String? raw = _box.get(id);
    if (raw == null) return;
    final SavedDestination dest = SavedDestination.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    await save(dest.copyWith(
      useCount: dest.useCount + 1,
      lastUsedAt: DateTime.now(),
    ));
  }

  static double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371000;
    final double phi1 = lat1 * 3.14159265358979 / 180;
    final double phi2 = lat2 * 3.14159265358979 / 180;
    final double dPhi = (lat2 - lat1) * 3.14159265358979 / 180;
    final double dLam = (lng2 - lng1) * 3.14159265358979 / 180;
    final double a = (dPhi / 2) * (dPhi / 2) +
        phi1.abs() * phi2.abs() * (dLam / 2) * (dLam / 2);
    return r * 2 * (a < 1 ? a : 1 - a);
  }
}
