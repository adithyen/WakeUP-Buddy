import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// A horizontal slide-to-dismiss widget.
///
/// The user must drag the thumb > 80 % of the track width to trigger
/// [onDismissed]. If released early the thumb animates back to the start.
/// Haptic feedback fires once at the threshold.
class DismissSlider extends StatefulWidget {
  final VoidCallback onDismissed;
  final String label;

  const DismissSlider({
    super.key,
    required this.onDismissed,
    this.label = 'Slide to Dismiss',
  });

  @override
  State<DismissSlider> createState() => _DismissSliderState();
}

class _DismissSliderState extends State<DismissSlider>
    with SingleTickerProviderStateMixin {
  static const double _thumbSize = 56.0;
  static const double _trackHeight = 64.0;
  static const double _dismissThreshold = 0.80;

  double _dragOffset = 0.0;
  bool _hapticFired = false;
  bool _dismissed = false;

  late final AnimationController _springController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late Animation<double> _springAnimation;

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _springController.stop();
    _hapticFired = false;
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (_dismissed) return;
    final double maxOffset = trackWidth - _thumbSize - AppDimensions.sm * 2;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, maxOffset);
    });

    final double ratio = _dragOffset / maxOffset;
    if (ratio >= _dismissThreshold && !_hapticFired) {
      _hapticFired = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _onDragEnd(DragEndDetails details, double trackWidth) {
    if (_dismissed) return;
    final double maxOffset = trackWidth - _thumbSize - AppDimensions.sm * 2;
    final double ratio = _dragOffset / maxOffset;

    if (ratio >= _dismissThreshold) {
      // Animate thumb to the end, then call callback
      setState(() {
        _dismissed = true;
        _dragOffset = maxOffset;
      });
      Future<void>.delayed(const Duration(milliseconds: 200), widget.onDismissed);
    } else {
      // Spring back to start
      _springAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
      )..addListener(() {
          setState(() => _dragOffset = _springAnimation.value);
        });
      _springController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double trackWidth = constraints.maxWidth;
        final double maxOffset = trackWidth - _thumbSize - AppDimensions.sm * 2;
        final double progress = maxOffset > 0 ? (_dragOffset / maxOffset).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              _onDragUpdate(d, trackWidth),
          onHorizontalDragEnd: (DragEndDetails d) =>
              _onDragEnd(d, trackWidth),
          child: Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              border: Border.all(
                color: Colors.white.withAlpha(77),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                // Filled progress behind the thumb
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_trackHeight / 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        width: _thumbSize + AppDimensions.sm + _dragOffset,
                        decoration: const BoxDecoration(
                          gradient: AppColors.alertGradient,
                        ),
                      ),
                    ),
                  ),
                ),

                // Label text (fades out as user drags)
                Positioned.fill(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: (1 - progress * 2).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 50),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.chevron_right,
                              color: Colors.white70, size: 20),
                          const Icon(Icons.chevron_right,
                              color: Colors.white54, size: 20),
                          const SizedBox(width: AppDimensions.xs),
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          const Icon(Icons.chevron_right,
                              color: Colors.white54, size: 20),
                          const Icon(Icons.chevron_right,
                              color: Colors.white70, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Draggable thumb
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 0),
                  left: _dragOffset + AppDimensions.sm,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withAlpha(77),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _dismissed ? Icons.check : Icons.arrow_forward_ios_rounded,
                      color: AppColors.accentDanger,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
