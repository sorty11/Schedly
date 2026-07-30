import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedAuthBackground extends StatefulWidget {
  final Widget child;
  final bool isCenteredLogo;

  const AnimatedAuthBackground({super.key, required this.child, this.isCenteredLogo = false});

  @override
  State<AnimatedAuthBackground> createState() => _AnimatedAuthBackgroundState();
}

class _AnimatedAuthBackgroundState extends State<AnimatedAuthBackground> with TickerProviderStateMixin {
  late AnimationController _auroraController;
  late AnimationController _waveController;
  late AnimationController _starsController;

  @override
  void initState() {
    super.initState();

    // 40-second breathing aurora
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat(reverse: true);

    // 18-second loop for waves
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // 10-second star twinkle (slow opacity animation)
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _waveController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The animated background should fill the screen
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dark navy gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF030712),
                Color(0xFF071321),
                Color(0xFF0B1D33),
              ],
            ),
          ),
        ),

        // 2. Slow animated aurora blobs
        AnimatedBuilder(
          animation: _auroraController,
          builder: (context, _) {
            return CustomPaint(
              painter: _AuroraPainter(progress: _auroraController.value),
            );
          },
        ),

        // 4. Sparse star particles
        AnimatedBuilder(
          animation: _starsController,
          builder: (context, _) {
            return CustomPaint(
              painter: _StarsPainter(progress: _starsController.value),
            );
          },
        ),

        // 3. Animated Bezier wave at the bottom
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            return CustomPaint(
              painter: _WavePainter(progress: _waveController.value),
            );
          },
        ),

        // 5. Soft glow behind the logo area
        widget.isCenteredLogo
            ? Align(
                alignment: Alignment.center,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
                        blurRadius: 150,
                        spreadRadius: 60,
                      ),
                    ],
                  ),
                ),
              )
            : Positioned(
                top: MediaQuery.of(context).size.height * 0.12,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
                          blurRadius: 100,
                          spreadRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

        // 6. Child (Static Form)
        SafeArea(child: widget.child),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;

  _AuroraPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);

    // Primary electric blue blob
    final cx1 = size.width * (0.3 + 0.4 * math.sin(progress * math.pi));
    final cy1 = size.height * (0.4 + 0.3 * math.cos(progress * math.pi));
    
    paint.color = const Color(0xFF00E5FF).withValues(alpha: 0.12);
    canvas.drawCircle(Offset(cx1, cy1), size.width * 0.45, paint);

    // Secondary electric blue blob (slightly darker tone of blue)
    final cx2 = size.width * (0.7 - 0.4 * math.cos(progress * math.pi));
    final cy2 = size.height * (0.6 - 0.2 * math.sin(progress * math.pi));
    
    paint.color = const Color(0xFF00A2FF).withValues(alpha: 0.10);
    canvas.drawCircle(Offset(cx2, cy2), size.width * 0.4, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.progress != progress;
}

class _WavePainter extends CustomPainter {
  final double progress;

  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = const Color(0xFF00E5FF);
    final waveCount = 3;

    // Draw waves near the bottom 25% of the screen
    final heightOffset = size.height * 0.85;

    for (int i = 0; i < waveCount; i++) {
      final path = Path();
      
      // Phase shifts smoothly over the 18 seconds
      final phase = progress * 2 * math.pi + (i * math.pi / waveCount);
      final amplitude = 25.0 + (i * 12.0);

      path.moveTo(0, heightOffset);

      for (double x = 0; x <= size.width; x += 10) {
        final normalizedX = x / size.width;
        // A single frequency across width, adjusted slightly per wave for depth
        final y = heightOffset + math.sin(normalizedX * math.pi * 1.5 + phase) * amplitude;
        path.lineTo(x, y);
      }

      // Draw the core glowing line
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = baseColor.withValues(alpha: 0.2 - (i * 0.05));
      
      canvas.drawPath(path, paint);

      // Draw the outer blurred glow for each line
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = baseColor.withValues(alpha: 0.06 - (i * 0.01))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        
      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.progress != progress;
}

class _StarsPainter extends CustomPainter {
  final double progress;

  _StarsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Seeded for static positions
    final paint = Paint();
    final starCount = 35; // Sparse

    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sizeStar = random.nextDouble() * 1.5 + 0.5;
      
      final phaseOffset = random.nextDouble() * math.pi * 2;
      // Sine wave for smooth fading, never completely disappearing
      final opacity = 0.1 + 0.4 * (0.5 * (1 + math.sin(progress * math.pi * 2 + phaseOffset)));
      
      // mostly white, some tinted blue
      final isBlueTint = random.nextBool();
      final starColor = isBlueTint ? const Color(0xFFD4FBFF) : Colors.white;

      paint.color = starColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), sizeStar, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => oldDelegate.progress != progress;
}
