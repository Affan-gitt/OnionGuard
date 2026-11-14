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
    final bgPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), bgPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    final range = (maxY - minY) > 0 ? (maxY - minY) : 1.0;

    // Threshold line if specified
    if (thresholdLine != null && thresholdLine! >= minY && thresholdLine! <= maxY) {
      final tY = size.height - ((thresholdLine! - minY) / range) * size.height;
      final tPaint = Paint()
        ..color = thresholdColor ?? AppConstants.statusAmber
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Dashed line
      const double dashWidth = 5, dashSpace = 4;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(Offset(startX, tY), Offset(startX + dashWidth, tY), tPaint);
        startX += dashWidth + dashSpace;
      }
    }

    // Line Path
    final path = Path();
    final stepX = dataPoints.length > 1 ? size.width / (dataPoints.length - 1) : size.width;

    for (int i = 0; i < dataPoints.length; i++) {
      final val = dataPoints[i].clamp(minY, maxY);
      final x = i * stepX;
      final y = size.height - ((val - minY) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Gradient fill under line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    // Latest point dot
    final lastVal = dataPoints.last.clamp(minY, maxY);
    final lastX = size.width;
    final lastY = size.height - ((lastVal - minY) / range) * size.height;

    final dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant LiveChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints || oldDelegate.thresholdLine != thresholdLine;
  }
}
