import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/destination.dart';
import '../../providers/destination_provider.dart';

class DestinationSummaryCard extends ConsumerWidget {
  const DestinationSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Destination? destination = ref.watch(selectedDestinationProvider);

    if (destination == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Destination selected', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppDimensions.sm),
          Text(destination.name, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            destination.description ?? 'Pinned location on the map',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lat: ${destination.latitude.toStringAsFixed(5)}',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              Expanded(
                child: Text(
                  'Lng: ${destination.longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}