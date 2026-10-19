import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

import '../../../../core/services/sensor_speed_service.dart';

class HudSpeedometer extends StatelessWidget {
  final double speedKmh;
  final double maxSpeed;
  final MotionPhase motionPhase;

  const HudSpeedometer({
    super.key,
    required this.speedKmh,
    this.maxSpeed = 120.0,
    this.motionPhase = MotionPhase.stationary,
  });

  @override
  Widget build(BuildContext context) {
    final double displaySpeed = max(0.0, speedKmh);
    final double normalized = (displaySpeed / maxSpeed).clamp(0.0, 1.0);
    final accent = context.appAccent;

    final IconData phaseIcon;
    final String phaseText;
    final Color phaseColor;

    switch (motionPhase) {
      case MotionPhase.walking:
        phaseIcon = Icons.navigation_rounded;
        phaseText = 'Moving';
        phaseColor = accent;
        break;
      case MotionPhase.slowTraffic:
        phaseIcon = Icons.traffic_rounded;
        phaseText = 'Traffic';
        phaseColor = const Color(0xFFF59E0B); // Amber orange
        break;
      case MotionPhase.transit:
        phaseIcon = Icons.directions_car_rounded;
        phaseText = 'Transit';
        phaseColor = accent;
        break;
      case MotionPhase.stationary:
        phaseIcon = Icons.pause_circle_outline_rounded;
        phaseText = 'Stopped';
        phaseColor = context.appTextSecondary;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: context.appCard.withValues(alpha: 0.92),
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
              ringColor: phaseColor,
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
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.appCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: phaseColor.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: phaseColor.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(phaseIcon, size: 12, color: phaseColor),
              const SizedBox(width: 4),
              Text(
                phaseText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: phaseColor,
                ),
              ),
            ],
          ),
        ),
      ],
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
