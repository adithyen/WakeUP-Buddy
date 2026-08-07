import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(AppDimensions.radiusLg);

    final Widget child = AnimatedScale(
      scale: _pressed && enabled ? 0.98 : 1,
      duration: AppDimensions.animFast,
      child: Container(
        height: AppDimensions.buttonHeight,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isFullWidth ? AppDimensions.xl : AppDimensions.xxxl,
        ),
        decoration: BoxDecoration(
          gradient: widget.variant == AppButtonVariant.primary ? AppColors.primaryGradient : null,
          color: widget.variant == AppButtonVariant.danger
              ? AppColors.accentDanger
              : widget.variant == AppButtonVariant.secondary
                  ? colorScheme.surfaceContainerHighest
                  : widget.variant == AppButtonVariant.ghost
                      ? Colors.transparent
                      : null,
          borderRadius: borderRadius,
          border: widget.variant == AppButtonVariant.secondary || widget.variant == AppButtonVariant.ghost
              ? Border.all(color: widget.variant == AppButtonVariant.ghost ? Colors.transparent : colorScheme.primary)
              : null,
          boxShadow: widget.variant == AppButtonVariant.primary
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withAlpha(51),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedOpacity(
            opacity: widget.isLoading ? 0.75 : 1,
            duration: AppDimensions.animFast,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_foregroundColor(colorScheme)),
                    ),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, size: AppDimensions.iconSizeMd),
                if (widget.icon != null || widget.isLoading) const SizedBox(width: AppDimensions.sm),
                Text(widget.label),
              ],
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.isFullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: enabled ? widget.onPressed : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          child: child,
        ),
      ),
    );
  }

  Color _foregroundColor(ColorScheme colorScheme) {
    return switch (widget.variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => colorScheme.primary,
      AppButtonVariant.danger => Colors.white,
      AppButtonVariant.ghost => colorScheme.primary,
    };
  }
}