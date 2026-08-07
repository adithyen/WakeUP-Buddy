import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Non-blocking banner that slides in at the top of the active trip screen
/// to communicate GPS signal loss or recovery.
class GpsStatusBanner extends StatefulWidget {
  final bool isVisible;
  final String message;
  final bool isError;

  const GpsStatusBanner({
    super.key,
    required this.isVisible,
    required this.message,
    this.isError = true,
  });

  @override
  State<GpsStatusBanner> createState() => _GpsStatusBannerState();
}

class _GpsStatusBannerState extends State<GpsStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void didUpdateWidget(GpsStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _anim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: AppDimensions.sm,
        ),
        color: widget.isError
            ? AppColors.error.withAlpha(220)
            : AppColors.success.withAlpha(220),
        child: Row(
          children: <Widget>[
            Icon(
              widget.isError
                  ? Icons.gps_off_rounded
                  : Icons.gps_fixed_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (widget.isError)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown when overshoot is confirmed (user passed their stop).
class OvershootWarningBanner extends StatelessWidget {
  final double extraDistanceM;
  final VoidCallback onDismiss;
  final VoidCallback onAlertAgain;

  const OvershootWarningBanner({
    super.key,
    required this.extraDistanceM,
    required this.onDismiss,
    required this.onAlertAgain,
  });

  @override
  Widget build(BuildContext context) {
    final String dist = extraDistanceM >= 1000
        ? '${(extraDistanceM / 1000).toStringAsFixed(1)} km'
        : '${extraDistanceM.round()} m';

    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        color: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 22),
                SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    'You may have passed your stop!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'You are now $dist past your destination.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: const Text('I got off'),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAlertAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.warning,
                    ),
                    child: const Text('Alert me again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
