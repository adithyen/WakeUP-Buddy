import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../providers/tracking_provider.dart';

/// Confirmation dialog shown when the user tries to cancel an active trip.
///
/// Returns `true` if the user confirmed cancellation, `false` otherwise.
Future<bool> showCancelTripDialog(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => const _CancelTripDialog(),
  );
  return confirmed ?? false;
}

class _CancelTripDialog extends ConsumerWidget {
  const _CancelTripDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 28,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'Cancel This Trip?',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Your destination alert will be cancelled and location tracking will stop.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.xxl),
            AppButton(
              label: 'Yes, Cancel Trip',
              variant: AppButtonVariant.danger,
              onPressed: () async {
                await ref.read(trackingProvider.notifier).stopTrip();
                if (context.mounted) Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: AppDimensions.sm),
            AppButton(
              label: 'Keep Tracking',
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
