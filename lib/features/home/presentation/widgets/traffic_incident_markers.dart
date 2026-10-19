import 'package:flutter/material.dart';
import '../../../tracking/data/models/traffic_incident_model.dart';

/// Interactive UI markers matching TomTom Map Styles v2
/// (2/incidents_light & 2/incidents_dark)
class TrafficIncidentMarkerWidget extends StatelessWidget {
  final TrafficIncident incident;
  final VoidCallback? onTap;

  const TrafficIncidentMarkerWidget({
    super.key,
    required this.incident,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (incident.isRoadClosed) {
      child = _DiamondBarricadeSign();
    } else if (incident.isJam && incident.delayBadge != null) {
      final int min = (incident.delaySeconds / 60).round();
      final Color bgColor = min >= 5
          ? const Color(0xFFD32F2F) // Deep Red for >=5'
          : min >= 3
              ? const Color(0xFFE53935) // Red for 3'
              : const Color(0xFFFF9800); // Orange for 2'
      child = _DelayBadge(text: incident.delayBadge!, color: bgColor);
    } else if (incident.isRoadWorks) {
      child = _RoadWorksBadge();
    } else if (incident.isAccident) {
      child = _AccidentBadge();
    } else {
      child = _GeneralHazardBadge();
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// Diamond Barricade Sign representing Road Closure
/// Matches TomTom Map Styles v2 road closed symbol
class _DiamondBarricadeSign extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Diamond Sign
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFC62828), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _BarricadePatternPainter(),
          ),
        ),
        // Barricade legs
        CustomPaint(
          size: const Size(18, 7),
          painter: _BarricadeLegsPainter(),
        ),
      ],
    );
  }
}

/// Painter for the diagonal hazard stripes and barrier icon on diamond sign
class _BarricadePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 8, size.width - 6, size.height - 16),
      const Radius.circular(2),
    );

    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawPaint(paintWhite);

    // Draw diagonal red stripes
    final stripePaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (double i = -10; i < size.width + 10; i += 6) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + 12, size.height),
        stripePaint,
      );
    }

    // Border around barrier
    final borderPaint = Paint()
      ..color = const Color(0xFF424242)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rect, borderPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarricadeLegsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final legPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Left leg
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(0, size.height),
      legPaint,
    );
    // Right leg
    canvas.drawLine(
      Offset(size.width * 0.75, 0),
      Offset(size.width, size.height),
      legPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Delay Badge (e.g. orange 2', red 3', dark red 5')
/// Matches TomTom Map Styles v2 delay badge
class _DelayBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _DelayBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
          height: 1.1,
        ),
      ),
    );
  }
}

/// Road works icon badge
class _RoadWorksBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.construction_rounded,
        color: Colors.black87,
        size: 16,
      ),
    );
  }
}

/// Accident warning badge
class _AccidentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.car_crash_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

/// General Hazard badge
class _GeneralHazardBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFFB8C00),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

/// Show bottom sheet with incident details when tapped
void showTrafficIncidentDetailsModal(
  BuildContext context,
  TrafficIncident incident,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  if (incident.isRoadClosed)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: Color(0xFFD32F2F),
                        size: 26,
                      ),
                    )
                  else if (incident.isJam)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.traffic_rounded,
                        color: Color(0xFFFF9800),
                        size: 26,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Color(0xFFFFB300),
                        size: 26,
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.isRoadClosed
                              ? 'Road Closed'
                              : incident.isJam
                                  ? 'Traffic Delay'
                                  : incident.isAccident
                                      ? 'Accident'
                                      : 'Road Works',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (incident.delayBadge != null)
                          Text(
                            '+${incident.delayBadge} delay reported by TomTom',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE53935),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A32) : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.description,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (incident.roadName != null && incident.roadName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.signpost_rounded,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            incident.roadName!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
