import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/theme_provider.dart';

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeOption selected = ref.watch(themeProvider);
    final ThemeNotifier notifier = ref.read(themeProvider.notifier);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    Widget optionButton({
      required ThemeOption option,
      required IconData icon,
      required String label,
    }) {
      final bool isSelected = selected == option;
      final Color activeTextColor = isSelected
          ? (ThemeData.estimateBrightnessForColor(colorScheme.primary) == Brightness.light
              ? Colors.black
              : Colors.white)
          : colorScheme.onSurfaceVariant;

      return Expanded(
        child: AnimatedContainer(
          duration: AppDimensions.animFast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            onTap: () => notifier.setTheme(option),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: activeTextColor,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: activeTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          optionButton(option: ThemeOption.light, icon: Icons.light_mode_rounded, label: 'Light'),
          const SizedBox(width: AppDimensions.xs),
          optionButton(option: ThemeOption.dark, icon: Icons.dark_mode_rounded, label: 'Dark'),
          const SizedBox(width: AppDimensions.xs),
          optionButton(option: ThemeOption.system, icon: Icons.auto_awesome_rounded, label: 'System'),
        ],
      ),
    );
  }
}