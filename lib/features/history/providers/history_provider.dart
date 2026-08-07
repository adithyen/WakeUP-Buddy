import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_database.dart';

// ── Repositories ──────────────────────────────────────────────────────────────

final tripHistoryRepositoryProvider = Provider<TripHistoryRepository>(
  (_) => TripHistoryRepository(),
);

final savedDestinationsRepositoryProvider =
    Provider<SavedDestinationsRepository>(
  (_) => SavedDestinationsRepository(),
);

// ── Trip history list ─────────────────────────────────────────────────────────

final tripHistoryProvider =
    StateNotifierProvider<TripHistoryNotifier, List<TripRecord>>(
  (Ref ref) => TripHistoryNotifier(ref.read(tripHistoryRepositoryProvider)),
);

class TripHistoryNotifier extends StateNotifier<List<TripRecord>> {
  final TripHistoryRepository _repo;

  TripHistoryNotifier(this._repo) : super(_repo.getAll());

  Future<void> addTrip(TripRecord record) async {
    await _repo.save(record);
    state = _repo.getAll();
  }

  Future<void> deleteTrip(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    state = <TripRecord>[];
  }

  TripStats get stats => _repo.getStats();
}

// ── Saved destinations ────────────────────────────────────────────────────────

final savedDestinationsProvider =
    StateNotifierProvider<SavedDestinationsNotifier, List<SavedDestination>>(
  (Ref ref) =>
      SavedDestinationsNotifier(ref.read(savedDestinationsRepositoryProvider)),
);

class SavedDestinationsNotifier extends StateNotifier<List<SavedDestination>> {
  final SavedDestinationsRepository _repo;

  SavedDestinationsNotifier(this._repo) : super(_repo.getAll());

  Future<void> save(SavedDestination dest) async {
    await _repo.save(dest);
    state = _repo.getAll();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    state = <SavedDestination>[];
  }
}
