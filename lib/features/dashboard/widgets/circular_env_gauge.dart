import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class CircularEnvGauge extends StatelessWidget {
  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final double thresholdValue;
  final String unit;
  final Color activeColor;
  final Color glowColor;
  final IconData icon;
  final String statusText;
  final double size;

  const CircularEnvGauge({
    super.key,
    required this.label,
    required this.value,
    this.minValue = 0,
    this.maxValue = 100,
    required this.thresholdValue,
    required this.unit,
    this.activeColor = AppConstants.emerald,
    this.glowColor = AppConstants.glowEmerald,
    required this.icon,
    required this.statusText,
    this.size = 145,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp fraction between 0.0 and 1.0
    final range = maxValue - minValue;
    final clampedValue = value.clamp(minValue, maxValue);
    final targetFraction = range > 0 ? (clampedValue - minValue) / range : 0.0;
    final thresholdFraction = range > 0 ? ((thresholdValue - minValue) / range).clamp(0.0, 1.0) : 0.7;

    return Container(
      width: size,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppConstants.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppConstants.borderEmerald, width: 1),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Label with Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: activeColor),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppConstants.mutedGreenGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Animated Circular Arc
          SizedBox(
            width: size - 30,
            height: size - 30,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: targetFraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animatedFraction, child) {
                return CustomPaint(
                  painter: _GaugeArcPainter(
                    fraction: animatedFraction,
                    thresholdFraction: thresholdFraction,
                    arcColor: activeColor,
                    trackColor: const Color(0xFF071D13),
                    thresholdColor: AppConstants.warmGold,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Smooth animated value counter
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: value, end: value),
                          duration: const Duration(milliseconds: 600),
                          builder: (context, animatedVal, child) {
                            return Text(
                              value > -100 ? animatedVal.toStringAsFixed(1) : '--',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.cream,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Status Badge / Threshold Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: activeColor.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: activeColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  final double fraction;
  final double thresholdFraction;
  final Color arcColor;
  final Color trackColor;
  final Color thresholdColor;

  _GaugeArcPainter({
    required this.fraction,
    required this.thresholdFraction,
    required this.arcColor,
    required this.trackColor,
    required this.thresholdColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const startAngle = 0.75 * math.pi; // 135 degrees
    const totalSweep = 1.5 * math.pi;  // 270 degrees sweep

    // 1. Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // 2. Active arc with subtle glow
    final activePaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + totalSweep,
        colors: [
          arcColor.withValues(alpha: 0.7),
          arcColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweep = (totalSweep * fraction).clamp(0.001, totalSweep);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      activePaint,
    );

    // 3. Threshold marker line
    final threshAngle = startAngle + (totalSweep * thresholdFraction);
    final markerPaint = Paint()
      ..color = thresholdColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final p1 = Offset(
      center.dx + (radius - 5) * math.cos(threshAngle),
      center.dy + (radius - 5) * math.sin(threshAngle),
    );
    final p2 = Offset(
      center.dx + (radius + 5) * math.cos(threshAngle),
      center.dy + (radius + 5) * math.sin(threshAngle),
    );
    canvas.drawLine(p1, p2, markerPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.thresholdFraction != thresholdFraction;
  }
}
