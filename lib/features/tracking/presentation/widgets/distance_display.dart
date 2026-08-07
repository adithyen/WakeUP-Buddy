import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../data/models/trip_state.dart';

/// Animated hero distance counter that smoothly transitions between values.
///
/// - Number tweens from old → new in [_tweenDuration]
/// - Color shifts based on proximity: primary → amber → red
/// - Displays formatted value + unit ("4.2" + "km" or "820" + "m")
class DistanceDisplay extends StatefulWidget {
  final double? distanceMeters;
  final TripStatus status;
  final double alertRadiusMeters;

  const DistanceDisplay({
    super.key,
    required this.distanceMeters,
    required this.status,
    required this.alertRadiusMeters,
  });

  @override
  State<DistanceDisplay> createState() => _DistanceDisplayState();
}

class _DistanceDisplayState extends State<DistanceDisplay>
    with TickerProviderStateMixin {
  static const Duration _tweenDuration = Duration(milliseconds: 600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _tweenDuration,
  );
  late Animation<double> _tween;

  double _fromValue = 0;
  double _toValue = 0;

  // Pulse animation for approaching / alerting states
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
      .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _fromValue = widget.distanceMeters ?? 0;
    _toValue = _fromValue;
    _tween = Tween<double>(begin: _fromValue, end: _toValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _maybeUpdatePulse();
  }

  @override
  void didUpdateWidget(DistanceDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.distanceMeters != widget.distanceMeters &&
        widget.distanceMeters != null) {
      _fromValue = _tween.value;
      _toValue = widget.distanceMeters!;
      _tween = Tween<double>(begin: _fromValue, end: _toValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }

    if (oldWidget.status != widget.status) {
      _maybeUpdatePulse();
    }
  }

  void _maybeUpdatePulse() {
    final bool shouldPulse = widget.status == TripStatus.approaching ||
        widget.status == TripStatus.alerting;
    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldPulse) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _distanceColor(BuildContext context) {
    return switch (widget.status) {
      TripStatus.alerting => AppColors.error,
      TripStatus.approaching => AppColors.warning,
      _ => Theme.of(context).colorScheme.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _distanceColor(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_tween, _pulseAnim]),
      builder: (BuildContext context, Widget? _) {
        final double value = _tween.value;
        final ({String number, String unit}) formatted = _formatDistance(value);

        return ScaleTransition(
          scale: _pulseAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatted.number,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      formatted.unit,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: color.withAlpha(178),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'remaining',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color.withAlpha(153),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static ({String number, String unit}) _formatDistance(double meters) {
    if (meters >= 1000) {
      return (number: (meters / 1000).toStringAsFixed(1), unit: 'km');
    }
    return (number: meters.round().toString(), unit: 'm');
  }
}
