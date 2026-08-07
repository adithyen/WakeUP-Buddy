import 'package:flutter/material.dart';

import '../constants/app_dimensions.dart';

class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;

  const AppBottomSheet({
    super.key,
    this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.xl,
        AppDimensions.sm,
        AppDimensions.xl,
        AppDimensions.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: AppDimensions.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title!,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],
          child,
        ],
      ),
    );
  }
}