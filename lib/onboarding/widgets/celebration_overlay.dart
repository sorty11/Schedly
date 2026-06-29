import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'cc_character.dart';
import '../../theme/theme.dart';

class CelebrationOverlayManager {
  static OverlayEntry? _overlayEntry;

  static void showCelebration(BuildContext context, {required VoidCallback onComplete}) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _CelebrationWidget(
        onComplete: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          onComplete();
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }
}

class _CelebrationWidget extends StatefulWidget {
  final VoidCallback onComplete;
  
  const _CelebrationWidget({required this.onComplete});

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget> with TickerProviderStateMixin {
  late AnimationController _appearController;
  late List<_Particle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(40, (index) => _Particle.create(_random));
    
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // Total celebration time
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background fade
          FadeTransition(
            opacity: Tween(begin: 0.0, end: 0.6).animate(
              CurvedAnimation(parent: _appearController, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
            ),
            child: Container(color: Colors.black),
          ),
          
          // Confetti Particle System
          AnimatedBuilder(
            animation: _appearController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_particles, _appearController.value),
              );
            },
          ),
          
          // CC Character and Message
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _appearController,
              curve: const Interval(0.1, 0.5, curve: Curves.elasticOut),
            ),
            child: FadeTransition(
              opacity: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: _appearController, curve: const Interval(0.1, 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CCCharacter(size: 100, expression: CCExpression.happy),
                  const SizedBox(height: AppSpacing.x2l),
                  Text(
                    "🎉 You're Ready!",
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "Welcome to Schedly.",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  final Offset start;
  final Offset control1;
  final Offset control2;
  final Offset end;
  final Color color;
  final double size;
  final double startT; // when it appears
  final double duration; // how long it lasts

  _Particle({
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    required this.color,
    required this.size,
    required this.startT,
    required this.duration,
  });

  static _Particle create(math.Random random) {
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.purple, Colors.orange
    ];
    
    // Start from center
    final angle = random.nextDouble() * 2 * math.pi;
    final distance = random.nextDouble() * 400 + 100;
    final endX = math.cos(angle) * distance;
    final endY = math.sin(angle) * distance + 200; // gravity effect
    
    return _Particle(
      start: Offset.zero,
      control1: Offset(math.cos(angle) * distance * 0.5, math.sin(angle) * distance * 0.5 - 100),
      control2: Offset(math.cos(angle) * distance * 0.8, math.sin(angle) * distance * 0.8),
      end: Offset(endX, endY),
      color: colors[random.nextInt(colors.length)],
      size: random.nextDouble() * 8 + 4,
      startT: random.nextDouble() * 0.2,
      duration: 0.5 + random.nextDouble() * 0.3,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      if (progress < p.startT) continue;
      
      double localProgress = (progress - p.startT) / p.duration;
      if (localProgress > 1.0) continue; // particle faded out

      // Bezier curve interpolation
      final t = localProgress;
      final t1 = 1 - t;
      
      final currentX = t1*t1*t1*p.start.dx + 3*t1*t1*t*p.control1.dx + 3*t1*t*t*p.control2.dx + t*t*t*p.end.dx;
      final currentY = t1*t1*t1*p.start.dy + 3*t1*t1*t*p.control1.dy + 3*t1*t*t*p.control2.dy + t*t*t*p.end.dy;
      
      paint.color = p.color.withValues(alpha: 1.0 - localProgress);
      
      // Draw spinning rectangles or circles
      canvas.save();
      canvas.translate(center.dx + currentX, center.dy + currentY);
      canvas.rotate(t * math.pi * 4); // spin
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
