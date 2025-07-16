// File: lib/animations/animated_feedback.dart
import 'package:flutter/material.dart';

class AnimatedFeedback {
  /// Shows an animated success (green tick) or error (red cross) feedback
  /// [context] - BuildContext for overlay
  /// [isSuccess] - true for green tick, false for red cross
  /// [message] - Optional message (currently not displayed but can be extended)
  static void show(BuildContext context, bool isSuccess, {String? message}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedFeedbackWidget(
        isSuccess: isSuccess,
        message: message,
        onComplete: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  /// Convenience method for showing success feedback
  static void showSuccess(BuildContext context, {String? message}) {
    show(context, true, message: message);
  }

  /// Convenience method for showing error feedback
  static void showError(BuildContext context, {String? message}) {
    show(context, false, message: message);
  }
}

class _AnimatedFeedbackWidget extends StatefulWidget {
  final bool isSuccess;
  final String? message;
  final VoidCallback onComplete;

  const _AnimatedFeedbackWidget({
    Key? key,
    required this.isSuccess,
    this.message,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_AnimatedFeedbackWidget> createState() => _AnimatedFeedbackWidgetState();
}

class _AnimatedFeedbackWidgetState extends State<_AnimatedFeedbackWidget>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _checkController;
  late AnimationController _fadeController;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _circleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _circleController,
      curve: Curves.easeOut,
    ));

    _checkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    // First animate the circle drawing in
    await _circleController.forward();

    // Small delay then animate the check/cross drawing in
    await Future.delayed(const Duration(milliseconds: 100));
    await _checkController.forward();

    // Stay visible for 1.2 seconds
    await Future.delayed(const Duration(milliseconds: 1200));

    // Fade out
    await _fadeController.forward();

    // Complete and remove overlay
    widget.onComplete();
  }

  @override
  void dispose() {
    _circleController.dispose();
    _checkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 100, // Position near bottom of screen
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_circleAnimation, _checkAnimation, _fadeAnimation]),
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: SizedBox(
                width: 60, // Smaller size like Apple Pay
                height: 60,
                child: CustomPaint(
                  painter: _ApplePayStylePainter(
                    circleProgress: _circleAnimation.value,
                    checkProgress: _checkAnimation.value,
                    isSuccess: widget.isSuccess,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApplePayStylePainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final bool isSuccess;

  _ApplePayStylePainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw the animated circle
    final circlePaint = Paint()
      ..color = isSuccess ? Colors.green : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Draw circle progress (like Apple Pay)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // Start from top (-90 degrees in radians)
      2 * 3.14159 * circleProgress, // Full circle based on progress
      false,
      circlePaint,
    );

    // Draw the check or cross inside
    if (checkProgress > 0) {
      final iconPaint = Paint()
        ..color = isSuccess ? Colors.green : Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      if (isSuccess) {
        _drawAnimatedCheck(canvas, center, iconPaint, checkProgress);
      } else {
        _drawAnimatedCross(canvas, center, iconPaint, checkProgress);
      }
    }
  }

  void _drawAnimatedCheck(Canvas canvas, Offset center, Paint paint, double progress) {
    // Check mark path
    final path = Path();

    // First stroke of check (short line going down-right)
    final start1 = Offset(center.dx - 8, center.dy);
    final mid = Offset(center.dx - 2, center.dy + 6);
    final end1 = Offset(center.dx + 8, center.dy - 6);

    if (progress <= 0.5) {
      // First half: draw the first stroke
      final currentProgress = progress * 2;
      final currentEnd = Offset.lerp(start1, mid, currentProgress)!;
      path.moveTo(start1.dx, start1.dy);
      path.lineTo(currentEnd.dx, currentEnd.dy);
    } else {
      // Second half: complete first stroke and draw second
      final currentProgress = (progress - 0.5) * 2;
      final currentEnd = Offset.lerp(mid, end1, currentProgress)!;
      path.moveTo(start1.dx, start1.dy);
      path.lineTo(mid.dx, mid.dy);
      path.lineTo(currentEnd.dx, currentEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawAnimatedCross(Canvas canvas, Offset center, Paint paint, double progress) {
    // Draw X mark
    final size = 8.0;

    if (progress <= 0.5) {
      // First diagonal
      final currentProgress = progress * 2;
      final start = Offset(center.dx - size, center.dy - size);
      final end = Offset(center.dx + size, center.dy + size);
      final currentEnd = Offset.lerp(start, end, currentProgress)!;
      canvas.drawLine(start, currentEnd, paint);
    } else {
      // Both diagonals
      final currentProgress = (progress - 0.5) * 2;
      // First diagonal (complete)
      canvas.drawLine(
        Offset(center.dx - size, center.dy - size),
        Offset(center.dx + size, center.dy + size),
        paint,
      );
      // Second diagonal (animating)
      final start2 = Offset(center.dx + size, center.dy - size);
      final end2 = Offset(center.dx - size, center.dy + size);
      final currentEnd2 = Offset.lerp(start2, end2, currentProgress)!;
      canvas.drawLine(start2, currentEnd2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


// Usage Examples:
//
// Import in your scheduling_tab.dart:
// import 'package:bmsapp/animations/animated_feedback.dart';
//
// Then use anywhere in your app:
//
// For success:
// AnimatedFeedback.showSuccess(context);
//
// For error:
// AnimatedFeedback.showError(context);
//
// Or with the general method:
// AnimatedFeedback.show(context, true);  // success
// AnimatedFeedback.show(context, false); // error