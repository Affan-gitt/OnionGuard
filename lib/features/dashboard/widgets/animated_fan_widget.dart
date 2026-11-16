import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class AnimatedFanWidget extends StatefulWidget {
  final bool isRunning;
  final double size;

  const AnimatedFanWidget({
    super.key,
    required this.isRunning,
    this.size = 38,
  });

  @override
  State<AnimatedFanWidget> createState() => _AnimatedFanWidgetState();
}

class _AnimatedFanWidgetState extends State<AnimatedFanWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isRunning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedFanWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRunning && _controller.isAnimating) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isRunning
                  ? AppConstants.emerald.withValues(alpha: 0.15)
                  : AppConstants.darkCardSurface,
              border: Border.all(
                color: widget.isRunning
                    ? AppConstants.emerald.withValues(alpha: 0.8)
                    : AppConstants.mutedGreenGrey.withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: widget.isRunning
                  ? [
                      BoxShadow(
                        color: AppConstants.emerald.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.mode_fan_off,
              size: widget.size * 0.58,
              color: widget.isRunning ? AppConstants.emerald : AppConstants.mutedGreenGrey,
            ),
          ),
        );
      },
    );
  }
}
