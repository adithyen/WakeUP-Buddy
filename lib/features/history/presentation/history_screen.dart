import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_card.dart';
import '../data/local_database.dart';
import '../providers/history_provider.dart';

/// Trip history screen grouped by date, with a stats banner at the top.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TripRecord> trips = ref.watch(tripHistoryProvider);
    final TripHistoryNotifier notifier =
        ref.read(tripHistoryProvider.notifier);
    final ThemeData theme = Theme.of(context);

    final Map<String, List<TripRecord>> grouped = _groupByDate(trips);
    final TripStats stats = notifier.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        actions: <Widget>[
          if (trips.isNotEmpty)
            IconButton(
              onPressed: () => _confirmClearAll(context, ref),
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear all history',
            ),
        ],
      ),
      body: trips.isEmpty
          ? _EmptyState()
          : CustomScrollView(
              slivers: <Widget>[
                // ── Stats banner ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    child: _StatsBanner(stats: stats),
                  ),
                ),

                // ── Trip groups ─────────────────────────────────────────────
                for (final MapEntry<String, List<TripRecord>> entry
                    in grouped.entries) ...<Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.lg,
                        vertical: AppDimensions.xs,
                      ),
                      child: Text(
                        entry.key,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext ctx, int i) {
                        final TripRecord trip = entry.value[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.lg,
                            vertical: AppDimensions.xs,
                          ),
                          child: _TripCard(
                            trip: trip,
                            onDelete: () => ref
                                .read(tripHistoryProvider.notifier)
                                .deleteTrip(trip.id),
                          ),
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.xxxl),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'All trip records will be permanently deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(tripHistoryProvider.notifier).clearAll();
    }
  }

  static Map<String, List<TripRecord>> _groupByDate(List<TripRecord> trips) {
    final Map<String, List<TripRecord>> grouped =
        <String, List<TripRecord>>{};
    for (final TripRecord trip in trips) {
      final String key = _dateLabel(trip.startTime);
      grouped.putIfAbsent(key, () => <TripRecord>[]).add(trip);
    }
    return grouped;
  }

  static String _dateLabel(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tripDay = DateTime(date.year, date.month, date.day);
    if (tripDay == today) return 'Today';
    if (tripDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_monthAbbr(date.month)} ${date.day}';
  }

  static String _monthAbbr(int m) => const <String>[
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final TripStats stats;
  const _StatsBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _Stat(
            icon: Icons.route_rounded,
            label: 'Total',
            value: '${stats.totalTrips}',
            color: theme.colorScheme.primary,
          ),
          _Stat(
            icon: Icons.check_circle_rounded,
            label: 'Done',
            value: '${stats.completedTrips}',
            color: AppColors.success,
          ),
          _Stat(
            icon: Icons.cancel_rounded,
            label: 'Cancelled',
            value: '${stats.cancelledTrips}',
            color: AppColors.error,
          ),
          _Stat(
            icon: Icons.timer_rounded,
            label: 'Total time',
            value: _fmtDuration(stats.totalDuration),
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripRecord trip;
  final VoidCallback onDelete;

  const _TripCard({required this.trip, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool completed = trip.outcome == TripOutcome.completed;
    final Color statusColor =
        completed ? AppColors.success : AppColors.error;
    final IconData statusIcon =
        completed ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final String statusLabel = completed ? 'Completed' : 'Cancelled';

    final String duration = trip.duration != null
        ? _fmtDuration(trip.duration!)
        : '--';

    final String time =
        '${trip.startTime.hour.toString().padLeft(2, '0')}:'
        '${trip.startTime.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: ValueKey<String>(trip.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimensions.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: AppCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    trip.destinationName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusLabel · $duration · $time',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds}s';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.history_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'No trips yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Your completed and cancelled trips\nwill appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
