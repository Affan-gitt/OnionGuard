import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class LiveChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final double? thresholdLine;
  final Color? thresholdColor;
  final double minY;
  final double maxY;
  final String unit;

  LiveChartPainter({
    required this.dataPoints,
    required this.lineColor,
    this.thresholdLine,
    this.thresholdColor,
    required this.minY,
    required this.maxY,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark translucent card background
    final bgPaint = Paint()..color = AppConstants.darkCardSurface.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      bgPaint,
    );

    // 2. Subtle tech grid lines
    final gridPaint = Paint()
      ..color = AppConstants.borderEmerald.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    final range = (maxY - minY) > 0 ? (maxY - minY) : 1.0;

    // 3. Threshold marker reference line
    if (thresholdLine != null && thresholdLine! >= minY && thresholdLine! <= maxY) {
      final tY = size.height - ((thresholdLine! - minY) / range) * size.height;
      final tPaint = Paint()
        ..color = thresholdColor ?? AppConstants.warmGold
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Dashed reference line
      const double dashWidth = 6, dashSpace = 4;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(Offset(startX, tY), Offset(startX + dashWidth, tY), tPaint);
        startX += dashWidth + dashSpace;
      }
    }

    // 4. Smooth cubic curve path
    final path = Path();
    final stepX = dataPoints.length > 1 ? size.width / (dataPoints.length - 1) : size.width;

    for (int i = 0; i < dataPoints.length; i++) {
      final val = dataPoints[i].clamp(minY, maxY);
      final x = i * stepX;
      final y = size.height - ((val - minY) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevVal = dataPoints[i - 1].clamp(minY, maxY);
        final prevX = (i - 1) * stepX;
        final prevY = size.height - ((prevVal - minY) / range) * size.height;
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    // 5. Gradient fill underneath the glowing curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.30),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    // 6. Glowing line stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // 7. Latest data point glowing dot
    final lastVal = dataPoints.last.clamp(minY, maxY);
    final lastX = size.width;
    final lastY = size.height - ((lastVal - minY) / range) * size.height;

    final dotGlow = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(lastX, lastY), 5.5, dotGlow);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(lastX, lastY), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant LiveChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.thresholdLine != thresholdLine;
  }
}
