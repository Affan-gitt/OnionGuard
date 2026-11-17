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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppConstants.mutedGreenGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Animated Circular Arc
          SizedBox(
            width: 110,
            height: 110,
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
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                value > -100 ? animatedVal.toStringAsFixed(1) : '--',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppConstants.cream,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
          const SizedBox(height: 10),

          // Conforming status badge based on text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: activeColor.withValues(alpha: 0.40), width: 0.9),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
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
    final radius = (size.width / 2) - 8;
    const strokeWidth = 9.0;
    const startAngle = 0.75 * math.pi;
    const sweepAngle = 1.5 * math.pi;

    // 1. Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 2. Active Progress Arc
    if (fraction > 0) {
      final activePaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * fraction,
        false,
        activePaint,
      );
    }

    // 3. Threshold Limit Tick Marker
    final thresholdAngle = startAngle + (sweepAngle * thresholdFraction);
    final tickInner = center + Offset(math.cos(thresholdAngle) * (radius - 5), math.sin(thresholdAngle) * (radius - 5));
    final tickOuter = center + Offset(math.cos(thresholdAngle) * (radius + 5), math.sin(thresholdAngle) * (radius + 5));

    final tickPaint = Paint()
      ..color = thresholdColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tickInner, tickOuter, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.thresholdFraction != thresholdFraction ||
        oldDelegate.arcColor != arcColor;
  }
}
