import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HudSpeedometer extends StatelessWidget {
  final double speedKmh;
  final double maxSpeed;

  const HudSpeedometer({
    super.key,
    required this.speedKmh,
    this.maxSpeed = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    final double displaySpeed = max(0.0, speedKmh);
    final double normalized = (displaySpeed / maxSpeed).clamp(0.0, 1.0);
    final accent = context.appAccent;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: context.appCard.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: context.appBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.4 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _SpeedRingPainter(
          progress: normalized,
          ringColor: accent,
          backgroundColor: context.appBorder,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displaySpeed.toInt().toString(),
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'km/h',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color backgroundColor;

  _SpeedRingPainter({
    required this.progress,
    required this.ringColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    // Track arc
    final trackPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Active speed arc
    final activePaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Start angle at 135 deg, sweep 270 deg (standard automotive gauge)
    const startAngle = 135.0 * (pi / 180.0);
    const totalSweep = 270.0 * (pi / 180.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalSweep * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
