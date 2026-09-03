import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'visual_theme.dart';

/// Reusable animated background widget that displays the selected [SchedlyVisualTheme]
/// behind any child widget with zero widget-tree re-evaluation on animation ticks.
class AnimatedThemeBackground extends StatelessWidget {
  final SchedlyVisualTheme theme;
  final Widget child;

  const AnimatedThemeBackground({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (theme == SchedlyVisualTheme.defaultTheme) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedThemeCanvas(theme: theme, isDark: isDark),
        ),
        // Readability scrim: subtle vignette layer guaranteeing high contrast for foreground UI
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 1.25,
                  colors: [
                    (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.25 : 0.65),
                    (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.65 : 0.85),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Standalone animated canvas that renders the visual theme's animation loop.
/// Can be used as a full background or inside miniature preview cards.
class AnimatedThemeCanvas extends StatefulWidget {
  final SchedlyVisualTheme theme;
  final bool isDark;
  final bool isPreview;

  const AnimatedThemeCanvas({
    super.key,
    required this.theme,
    this.isDark = true,
    this.isPreview = false,
  });

  @override
  State<AnimatedThemeCanvas> createState() => _AnimatedThemeCanvasState();
}

class _AnimatedThemeCanvasState extends State<AnimatedThemeCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (widget.theme != SchedlyVisualTheme.defaultTheme) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedThemeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      if (widget.theme == SchedlyVisualTheme.defaultTheme) {
        _controller.stop();
      } else if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.theme == SchedlyVisualTheme.defaultTheme) {
      return Container(
        color: widget.isDark ? const Color(0xFF000000) : const Color(0xFFF9F9F9),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        CustomPainter painter;
        switch (widget.theme) {
          case SchedlyVisualTheme.space:
            painter = SpaceThemePainter(
              progress: _controller.value,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.cats:
            painter = CatsThemePainter(
              progress: _controller.value,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.cyberRobo:
            painter = CyberRoboThemePainter(
              progress: _controller.value,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.arcade:
            painter = ArcadeThemePainter(
              progress: _controller.value,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.defaultTheme:
            return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: painter,
          size: Size.infinite,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SPACE THEME PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class SpaceThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  SpaceThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

  static final List<_Star> _stars = List.generate(65, (i) {
    final rand = math.Random(i * 101 + 7);
    return _Star(
      x: rand.nextDouble(),
      y: rand.nextDouble(),
      size: 0.8 + rand.nextDouble() * 1.8,
      speed: 0.05 + rand.nextDouble() * 0.15,
      blinkOffset: rand.nextDouble() * math.pi * 2,
      isCyan: rand.nextDouble() > 0.65,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep space gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF030612),
          Color(0xFF070B1E),
          Color(0xFF02040B),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Subtle breathing nebula
    final nebulaRadius = math.min(size.width, size.height) * 0.75;
    final nebulaPulse = math.sin(progress * math.pi * 2) * 0.08 + 0.92;
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF381559).withValues(alpha: 0.35 * nebulaPulse),
          const Color(0xFF0D2354).withValues(alpha: 0.25 * nebulaPulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.65, size.height * 0.35),
          radius: nebulaRadius,
        ),
      );
    canvas.drawRect(rect, nebulaPaint);

    // Drifting twinkling starfield
    final starPaint = Paint()..style = PaintingStyle.fill;

    final starCount = isPreview ? 25 : _stars.length;
    for (int i = 0; i < starCount; i++) {
      final s = _stars[i];
      final currentY = (s.y + progress * s.speed) % 1.0 * size.height;
      final currentX = s.x * size.width;
      final blink = (math.sin(progress * math.pi * 6 + s.blinkOffset) + 1.0) / 2.0;
      final opacity = (0.35 + 0.65 * blink).clamp(0.0, 1.0);

      starPaint.color = s.isCyan
          ? const Color(0xFF8AE8FF).withValues(alpha: opacity)
          : Colors.white.withValues(alpha: opacity);

      canvas.drawCircle(Offset(currentX, currentY), s.size, starPaint);

      // Star halo for larger stars
      if (s.size > 1.8) {
        final haloPaint = Paint()
          ..color = (s.isCyan ? const Color(0xFF42C5FF) : Colors.white)
              .withValues(alpha: opacity * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawCircle(Offset(currentX, currentY), s.size * 2.2, haloPaint);
      }
    }

    // Occasional subtle shooting star
    final shootT = (progress * 3.0) % 1.0;
    if (shootT < 0.22) {
      final t = shootT / 0.22;
      final startX = size.width * 0.15 + t * size.width * 0.7;
      final startY = size.height * 0.08 + t * size.height * 0.25;
      final tailLength = size.width * 0.12;
      final shootPaint = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: (1.0 - t) * 0.8),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromPoints(
            Offset(startX, startY),
            Offset(startX - tailLength, startY - tailLength * 0.35),
          ),
        );
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX - tailLength, startY - tailLength * 0.35),
        shootPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpaceThemePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double blinkOffset;
  final bool isCyan;

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.blinkOffset,
    required this.isCyan,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. CATS THEME PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class CatsThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  CatsThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

  static final List<_CatItem> _items = List.generate(14, (i) {
    final rand = math.Random(i * 97 + 13);
    return _CatItem(
      x: 0.08 + (i / 14.0) * 0.84 + (rand.nextDouble() * 0.08 - 0.04),
      initialY: rand.nextDouble(),
      speed: 0.04 + rand.nextDouble() * 0.06,
      scale: 0.75 + rand.nextDouble() * 0.5,
      type: rand.nextInt(3), // 0: sleeping cat head, 1: paw print, 2: star sparkle
      swayOffset: rand.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Cozy twilight warm base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF13101C),
          Color(0xFF181324),
          Color(0xFF0F0E16),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Warm pastel radial ambient glows
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4C2A4C).withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.3, size.height * 0.4),
          radius: size.width * 0.6,
        ),
      );
    canvas.drawRect(rect, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    final itemCount = isPreview ? 6 : _items.length;
    for (int i = 0; i < itemCount; i++) {
      final item = _items[i];
      final y = (item.initialY - progress * item.speed) % 1.0 * size.height;
      final sway = math.sin(progress * math.pi * 4 + item.swayOffset) * 12.0;
      final x = (item.x * size.width + sway).clamp(16.0, size.width - 16.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.scale(item.scale);

      if (item.type == 0) {
        // Minimalist Sleeping Cat Silhouette (head + pointed ears + closed smiling eyes)
        final catColor = const Color(0xFFE4C3DE).withValues(alpha: 0.32);
        linePaint.color = catColor;
        fillPaint.color = const Color(0xFF9E6896).withValues(alpha: 0.12);

        // Head shape
        const headRadius = 14.0;
        canvas.drawCircle(Offset.zero, headRadius, fillPaint);
        canvas.drawCircle(Offset.zero, headRadius, linePaint);

        // Left ear
        final leftEar = Path()
          ..moveTo(-11, -8)
          ..lineTo(-14, -20)
          ..lineTo(-3, -13);
        canvas.drawPath(leftEar, linePaint);

        // Right ear
        final rightEar = Path()
          ..moveTo(3, -13)
          ..lineTo(14, -20)
          ..lineTo(11, -8);
        canvas.drawPath(rightEar, linePaint);

        // Sleeping eyes: ^ . ^
        final eyePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFF3DAEC).withValues(alpha: 0.4);

        // Left sleeping eye curve
        final leftEye = Path()
          ..moveTo(-7, -1)
          ..quadraticBezierTo(-4, -4, -1, -1);
        canvas.drawPath(leftEye, eyePaint);

        // Right sleeping eye curve
        final rightEye = Path()
          ..moveTo(1, -1)
          ..quadraticBezierTo(4, -4, 7, -1);
        canvas.drawPath(rightEye, eyePaint);
      } else if (item.type == 1) {
        // Floating Cute Paw Print
        fillPaint.color = const Color(0xFFFFB6C1).withValues(alpha: 0.24);

        // Main palm pad
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 3), width: 14, height: 11),
          fillPaint,
        );

        // 4 cute toe beans
        canvas.drawCircle(const Offset(-6, -6), 2.8, fillPaint);
        canvas.drawCircle(const Offset(-2, -9), 3.0, fillPaint);
        canvas.drawCircle(const Offset(3, -9), 3.0, fillPaint);
        canvas.drawCircle(const Offset(7, -6), 2.8, fillPaint);
      } else {
        // Ambient Star / Sparkle
        fillPaint.color = const Color(0xFFFFD4A3).withValues(alpha: 0.35);
        final spark = Path()
          ..moveTo(0, -6)
          ..quadraticBezierTo(0, 0, 6, 0)
          ..quadraticBezierTo(0, 0, 0, 6)
          ..quadraticBezierTo(0, 0, -6, 0)
          ..quadraticBezierTo(0, 0, 0, -6);
        canvas.drawPath(spark, fillPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CatsThemePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CatItem {
  final double x;
  final double initialY;
  final double speed;
  final double scale;
  final int type;
  final double swayOffset;

  const _CatItem({
    required this.x,
    required this.initialY,
    required this.speed,
    required this.scale,
    required this.type,
    required this.swayOffset,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CYBER ROBO THEME PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class CyberRoboThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  CyberRoboThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Dark cyber carbon base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF040A12),
          Color(0xFF06101D),
          Color(0xFF03070E),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Cyan glowing ambient radial glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00B4D8).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.7),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawRect(rect, glowPaint);

    // Grid Perspective in bottom third
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    final horizonY = size.height * 0.65;
    const linesCount = 8;
    for (int i = 0; i < linesCount; i++) {
      final t = (i + (progress * 2) % 1.0) / linesCount;
      final y = horizonY + math.pow(t, 2.2) * (size.height - horizonY);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Perspective diagonals
    for (double xRatio = -0.5; xRatio <= 1.5; xRatio += 0.25) {
      canvas.drawLine(
        Offset(size.width * 0.5, horizonY),
        Offset(size.width * xRatio, size.height),
        gridPaint,
      );
    }

    // Circuit trace lines flowing with subtle pulses
    final tracePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final packetPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00FFC2).withValues(alpha: 0.85);

    final glowPacketPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00FFC2).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    // 4 fixed procedural circuit routes
    final routes = [
      [
        Offset(size.width * 0.15, size.height * 0.05),
        Offset(size.width * 0.15, size.height * 0.28),
        Offset(size.width * 0.35, size.height * 0.42),
        Offset(size.width * 0.35, size.height * 0.60),
      ],
      [
        Offset(size.width * 0.85, size.height * 0.08),
        Offset(size.width * 0.85, size.height * 0.32),
        Offset(size.width * 0.65, size.height * 0.48),
        Offset(size.width * 0.65, size.height * 0.62),
      ],
      [
        Offset(size.width * 0.50, size.height * 0.02),
        Offset(size.width * 0.50, size.height * 0.22),
        Offset(size.width * 0.72, size.height * 0.34),
        Offset(size.width * 0.72, size.height * 0.52),
      ],
    ];

    for (int r = 0; r < routes.length; r++) {
      final pts = routes[r];
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, tracePaint);

      // Terminal circuit nodes
      for (final p in pts) {
        canvas.drawCircle(p, 2.2, tracePaint);
      }

      // Traveling glowing data pulse along the circuit
      final pulseT = (progress * 1.8 + r * 0.33) % 1.0;
      final targetIdx = (pulseT * (pts.length - 1)).floor();
      final nextIdx = (targetIdx + 1).clamp(0, pts.length - 1);
      final segmentT = (pulseT * (pts.length - 1)) - targetIdx;

      final pCurrent = Offset.lerp(pts[targetIdx], pts[nextIdx], segmentT)!;
      canvas.drawCircle(pCurrent, 4.5, glowPacketPaint);
      canvas.drawCircle(pCurrent, 2.2, packetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberRoboThemePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. ARCADE THEME PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class ArcadeThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  ArcadeThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

  static final List<_PixelParticle> _pixels = List.generate(28, (i) {
    final rand = math.Random(i * 131 + 47);
    return _PixelParticle(
      x: rand.nextDouble(),
      initialY: rand.nextDouble(),
      size: 2.0 + rand.nextDouble() * 3.5,
      speed: 0.05 + rand.nextDouble() * 0.08,
      isMagenta: rand.nextDouble() > 0.45,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Retro synthwave dark violet backdrop
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF090412),
          Color(0xFF140824),
          Color(0xFF080310),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Neon horizon sun arc
    final horizonY = size.height * 0.58;
    final sunRadius = math.min(size.width * 0.35, 120.0);
    final sunPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF007F).withValues(alpha: 0.35),
          const Color(0xFFFF8C00).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(size.width * 0.5, horizonY), radius: sunRadius),
      );
    canvas.drawCircle(Offset(size.width * 0.5, horizonY), sunRadius, sunPaint);

    // Retro horizon grid
    final gridPaint = Paint()
      ..color = const Color(0xFFFF007F).withValues(alpha: 0.14)
      ..strokeWidth = 1.0;

    const gridLines = 8;
    for (int i = 0; i < gridLines; i++) {
      final t = (i + (progress * 2.5) % 1.0) / gridLines;
      final y = horizonY + math.pow(t, 2.0) * (size.height - horizonY);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Grid vertical converging lines
    for (double r = -0.4; r <= 1.4; r += 0.2) {
      canvas.drawLine(
        Offset(size.width * 0.5, horizonY),
        Offset(size.width * r, size.height),
        gridPaint,
      );
    }

    // Floating retro 8-bit square pixels
    final pixelPaint = Paint()..style = PaintingStyle.fill;

    for (final p in _pixels) {
      final y = (p.initialY - progress * p.speed) % 1.0 * size.height;
      final x = p.x * size.width;

      final color = p.isMagenta ? const Color(0xFFFF007F) : const Color(0xFF00F0FF);
      pixelPaint.color = color.withValues(alpha: 0.35);

      // Pixel diamond or square
      final pRect = Rect.fromCenter(center: Offset(x, y), width: p.size, height: p.size);
      canvas.drawRect(pRect, pixelPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ArcadeThemePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PixelParticle {
  final double x;
  final double initialY;
  final double size;
  final double speed;
  final bool isMagenta;

  const _PixelParticle({
    required this.x,
    required this.initialY,
    required this.size,
    required this.speed,
    required this.isMagenta,
  });
}
