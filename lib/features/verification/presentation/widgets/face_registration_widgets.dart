import 'dart:math';
import 'package:flutter/material.dart';

/// Circular face frame overlay with animated progress ring
class CircularFaceFrame extends StatelessWidget {
  final double size;
  final Color frameColor;
  final double strokeWidth;
  final double progress; // 0.0 to 1.0
  final bool showProgress;

  const CircularFaceFrame({
    super.key,
    this.size = 280,
    this.frameColor = Colors.white,
    this.strokeWidth = 4,
    this.progress = 0.0,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircularFramePainter(
          frameColor: frameColor,
          strokeWidth: strokeWidth,
          progress: progress,
          showProgress: showProgress,
        ),
      ),
    );
  }
}

class _CircularFramePainter extends CustomPainter {
  final Color frameColor;
  final double strokeWidth;
  final double progress;
  final bool showProgress;

  _CircularFramePainter({
    required this.frameColor,
    required this.strokeWidth,
    required this.progress,
    required this.showProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Draw base circle (frame)
    final framePaint = Paint()
      ..color = frameColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, framePaint);

    // Draw progress arc if enabled
    if (showProgress && progress > 0) {
      final progressPaint = Paint()
        ..color = frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -pi / 2; // Start from top
      final sweepAngle = 2 * pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularFramePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.frameColor != frameColor ||
        oldDelegate.showProgress != showProgress;
  }
}

/// Animated pose guidance widget showing head rotation
class PoseGuidanceWidget extends StatefulWidget {
  final String instruction;
  final String? secondaryInstruction;
  final IconData icon;
  final bool animate;

  const PoseGuidanceWidget({
    super.key,
    required this.instruction,
    this.secondaryInstruction,
    required this.icon,
    this.animate = false,
  });

  @override
  State<PoseGuidanceWidget> createState() => _PoseGuidanceWidgetState();
}

class _PoseGuidanceWidgetState extends State<PoseGuidanceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PoseGuidanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: widget.animate ? (_animation.value - 0.5) * 0.3 : 0,
                child: Icon(widget.icon, color: Colors.white, size: 48),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            widget.instruction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.secondaryInstruction != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.secondaryInstruction!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Real-time quality indicator showing feedback
class QualityIndicator extends StatelessWidget {
  final String message;
  final bool isValid;
  final IconData? icon;

  const QualityIndicator({
    super.key,
    required this.message,
    required this.isValid,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isValid
            ? Colors.green.withOpacity(0.9)
            : Colors.orange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? (isValid ? Icons.check_circle : Icons.warning),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Success dialog with animation
class RegistrationSuccessDialog extends StatefulWidget {
  final String message;
  final VoidCallback onComplete;

  const RegistrationSuccessDialog({
    super.key,
    required this.message,
    required this.onComplete,
  });

  @override
  State<RegistrationSuccessDialog> createState() =>
      _RegistrationSuccessDialogState();
}

class _RegistrationSuccessDialogState extends State<RegistrationSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You can now use face verification',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Step indicator showing progress through registration
class RegistrationStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const RegistrationStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: isCurrent ? 32 : 24,
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted || isCurrent
                  ? Colors.blue
                  : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
