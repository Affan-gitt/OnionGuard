import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Canvas painter for the iconic Tor-inspired Onion Guard logo
class OnionLogoPainter extends CustomPainter {
  final Color primaryEmerald;
  final Color sproutLime;
  final Color ringCream;
  final Color badgeBg;
  final bool showGlow;
  final double pulseValue;

  OnionLogoPainter({
    this.primaryEmerald = AppConstants.emerald,
    this.sproutLime = AppConstants.lime,
    this.ringCream = AppConstants.cream,
    this.badgeBg = AppConstants.deepForest,
    this.showGlow = true,
    this.pulseValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.50;
    final cy = s * 0.53;
    final r = s * 0.35;
    final lineW = math.max(1.5, s * 0.045);

    // 1. Neon glowing halo
    if (showGlow) {
      final glowPaint = Paint()
        ..color = primaryEmerald.withValues(alpha: 0.18 * pulseValue)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08);
      canvas.drawCircle(Offset(cx, cy), r * 1.25, glowPaint);
    }

    // 2. Circular background badge
    final bgPaint = Paint()
      ..color = badgeBg
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 1.18, bgPaint);

    final borderPaint = Paint()
      ..color = primaryEmerald.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, s * 0.025);
    canvas.drawCircle(Offset(cx, cy), r * 1.18, borderPaint);

    // 3. Right half outer contour (smooth outer onion bulb)
    final rightContourPaint = Paint()
      ..color = primaryEmerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      math.pi,
      false,
      rightContourPaint,
    );

    // 4. Left concentric onion rings (layers)
    final List<Color> layerColors = [
      ringCream,
      primaryEmerald,
      sproutLime,
      primaryEmerald,
    ];
    final int numLayers = 4;
    for (int i = 1; i <= numLayers; i++) {
      final curR = r * (i / numLayers);
      final layerPaint = Paint()
        ..color = layerColors[(i - 1) % layerColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineW
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: curR),
        math.pi / 2,
        math.pi,
        false,
        layerPaint,
      );
    }

    // 5. Vertical axis separator line
    final axisPaint = Paint()
      ..color = ringCream.withValues(alpha: 0.90)
      ..strokeWidth = lineW * 0.70;
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), axisPaint);

    // 6. Onion nucleus (center bulb core)
    final coreR = r * 0.20;
    final corePaint = Paint()
      ..color = ringCream
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), coreR, corePaint);

    final innerDotPaint = Paint()
      ..color = primaryEmerald
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), coreR * 0.50, innerDotPaint);

    // 7. Sprout / Shoot at top
    final sproutBaseY = cy - r;
    final stemTopX = cx + s * 0.025;
    final stemTopY = cy - r - s * 0.16;

    final sproutPath = Path()
      ..moveTo(cx - s * 0.035, sproutBaseY)
      ..lineTo(cx + s * 0.035, sproutBaseY)
      ..lineTo(stemTopX + s * 0.025, stemTopY)
      ..lineTo(stemTopX - s * 0.025, stemTopY)
      ..close();

    final sproutPaint = Paint()
      ..color = sproutLime
      ..style = PaintingStyle.fill;
    canvas.drawPath(sproutPath, sproutPaint);

    // Secondary leaf angling right
    final leafPath = Path()
      ..moveTo(cx + s * 0.015, sproutBaseY - s * 0.03)
      ..lineTo(cx + s * 0.095, sproutBaseY - s * 0.12)
      ..lineTo(cx + s * 0.035, sproutBaseY - s * 0.08)
      ..close();

    final leafPaint = Paint()
      ..color = primaryEmerald
      ..style = PaintingStyle.fill;
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant OnionLogoPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.primaryEmerald != primaryEmerald;
  }
}

/// Dynamic animated Onion Guard logo with orbital tech rings and tap gesture handler
class AnimatedOnionLogo extends StatefulWidget {
  final double size;
  final bool animateRings;
  final bool showOrbitalRings;
  final VoidCallback? onTap;

  const AnimatedOnionLogo({
    super.key,
    this.size = 64,
    this.animateRings = true,
    this.showOrbitalRings = false,
    this.onTap,
  });

  @override
  State<AnimatedOnionLogo> createState() => _AnimatedOnionLogoState();
}

class _AnimatedOnionLogoState extends State<AnimatedOnionLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.animateRings) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedOnionLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateRings && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animateRings && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = 0.85 + (math.sin(_controller.value * 2 * math.pi) * 0.15);
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Optional rotating orbital tech rings (for splash / large badges)
                if (widget.showOrbitalRings) ...[
                  Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size(widget.size * 1.35, widget.size * 1.35),
                      painter: _OrbitalRingPainter(
                        color: AppConstants.emerald.withValues(alpha: 0.35),
                        dashCount: 16,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -_controller.value * 2 * math.pi * 0.7,
                    child: CustomPaint(
                      size: Size(widget.size * 1.55, widget.size * 1.55),
                      painter: _OrbitalRingPainter(
                        color: AppConstants.lime.withValues(alpha: 0.20),
                        dashCount: 24,
                      ),
                    ),
                  ),
                ],

                // Core onion logo
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: OnionLogoPainter(
                    pulseValue: pulse,
                    showGlow: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrbitalRingPainter extends CustomPainter {
  final Color color;
  final int dashCount;

  _OrbitalRingPainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final sweep = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r - 2),
          i * sweep,
          sweep * 0.55,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingPainter oldDelegate) => false;
}
