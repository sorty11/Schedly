import 'package:flutter/material.dart';
import 'dart:math' as math;

enum CCExpression { normal, happy, thinking, surprising, pointing, celebrating }

class CCCharacter extends StatefulWidget {
  final CCExpression expression;
  final double size;

  const CCCharacter({
    super.key,
    this.expression = CCExpression.normal,
    this.size = 60,
  });

  @override
  State<CCCharacter> createState() => _CCCharacterState();
}

class _CCCharacterState extends State<CCCharacter> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _blinkController;
  
  bool _isBlinking = false;
  
  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    _scheduleBlink();
  }
  
  void _scheduleBlink() {
    if (!mounted) return;
    Future.delayed(Duration(milliseconds: 2000 + math.Random().nextInt(4000)), () {
      if (!mounted) return;
      _blink();
    });
  }
  
  void _blink() async {
    if (!mounted) return;
    setState(() => _isBlinking = true);
    await _blinkController.forward();
    if (!mounted) return;
    await _blinkController.reverse();
    if (!mounted) return;
    setState(() => _isBlinking = false);
    _scheduleBlink();
  }
  
  @override
  void dispose() {
    _floatController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floatAnim = Tween<Offset>(begin: const Offset(0, -0.05), end: const Offset(0, 0.05))
        .animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine));

    return SlideTransition(
      position: floatAnim,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _CCPainter(
            expression: widget.expression,
            isBlinking: _isBlinking,
            colorScheme: Theme.of(context).colorScheme,
          ),
        ),
      ),
    );
  }
}

class _CCPainter extends CustomPainter {
  final CCExpression expression;
  final bool isBlinking;
  final ColorScheme colorScheme;

  _CCPainter({
    required this.expression,
    required this.isBlinking,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Body (glassy or solid primary)
    paint.color = colorScheme.primary;
    final bodyRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 + size.height * 0.05),
      width: size.width * 0.75,
      height: size.height * 0.65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.3)),
      paint,
    );
    
    // Face screen
    paint.color = colorScheme.surface;
    final faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 + size.height * 0.05),
      width: size.width * 0.6,
      height: size.height * 0.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, Radius.circular(size.width * 0.15)),
      paint,
    );

    // Eyes
    paint.color = colorScheme.primary;
    final eyeY = faceRect.center.dy - size.height * 0.05;
    final eyeW = size.width * 0.08;
    final eyeH = isBlinking ? size.height * 0.02 : size.height * 0.12;
    
    // Left eye
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(faceRect.center.dx - size.width * 0.15, eyeY), width: eyeW, height: eyeH),
        Radius.circular(eyeW / 2),
      ),
      paint,
    );
    
    // Right eye
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(faceRect.center.dx + size.width * 0.15, eyeY), width: eyeW, height: eyeH),
        Radius.circular(eyeW / 2),
      ),
      paint,
    );

    // Expression specific
    if (expression == CCExpression.happy || expression == CCExpression.celebrating) {
      // Draw a smile
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = size.width * 0.04;
      paint.strokeCap = StrokeCap.round;
      final smileHeight = expression == CCExpression.celebrating ? 0.18 : 0.15;
      final smilePath = Path()
        ..moveTo(faceRect.center.dx - size.width * 0.1, faceRect.center.dy + size.height * 0.1)
        ..quadraticBezierTo(
          faceRect.center.dx, faceRect.center.dy + size.height * smileHeight,
          faceRect.center.dx + size.width * 0.1, faceRect.center.dy + size.height * 0.1,
        );
      canvas.drawPath(smilePath, paint);
    } else if (expression == CCExpression.thinking) {
      // Draw a straight line for mouth
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = size.width * 0.04;
      paint.strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(faceRect.center.dx - size.width * 0.05, faceRect.center.dy + size.height * 0.12),
        Offset(faceRect.center.dx + size.width * 0.05, faceRect.center.dy + size.height * 0.12),
        paint,
      );
    }
    
    // Antenna line
    paint.style = PaintingStyle.fill;
    paint.color = colorScheme.primary;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, bodyRect.top - size.height * 0.05),
        width: size.width * 0.06,
        height: size.height * 0.1,
      ),
      paint,
    );
    // Antenna bulb
    paint.color = colorScheme.secondary; // glow color
    canvas.drawCircle(
      Offset(size.width / 2, bodyRect.top - size.height * 0.1),
      size.width * 0.08,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CCPainter oldDelegate) {
    return oldDelegate.expression != expression || 
           oldDelegate.isBlinking != isBlinking ||
           oldDelegate.colorScheme != colorScheme;
  }
}
