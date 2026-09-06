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
                    Colors.transparent,
                    (isDark ? Colors.black : Colors.white).withValues(
                      alpha: isDark ? 0.25 : 0.40,
                    ),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ),
        ),
        RepaintBoundary(child: child),
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
        color: widget.isDark
            ? const Color(0xFF000000)
            : const Color(0xFFF9F9F9),
      );
    }

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animation = disableAnimations ? null : _controller;
    final staticProgress = disableAnimations ? 0.0 : null;

    CustomPainter painter;
    switch (widget.theme) {
      case SchedlyVisualTheme.heritage:
        painter = HeritageThemePainter(
          animation: animation,
          progress: staticProgress,
          isDark: widget.isDark,
          isPreview: widget.isPreview,
        );
        break;
      case SchedlyVisualTheme.future:
        painter = FutureThemePainter(
          animation: animation,
          progress: staticProgress,
          isDark: widget.isDark,
          isPreview: widget.isPreview,
        );
        break;
      case SchedlyVisualTheme.bloom:
        painter = BloomThemePainter(
          animation: animation,
          progress: staticProgress,
          isDark: widget.isDark,
          isPreview: widget.isPreview,
        );
        break;
      case SchedlyVisualTheme.champion:
        painter = ChampionThemePainter(
          animation: animation,
          progress: staticProgress,
          isDark: widget.isDark,
          isPreview: widget.isPreview,
        );
        break;
      case SchedlyVisualTheme.defaultTheme:
        return const SizedBox.shrink();
    }

    return CustomPaint(painter: painter, size: Size.infinite);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HERITAGE THEME PAINTER (Old School Rust / Academic Editorial Texture)
// ─────────────────────────────────────────────────────────────────────────────
class HeritageThemePainter extends CustomPainter {
  final Animation<double>? animation;
  final double? _staticProgress;
  final bool isDark;
  final bool isPreview;

  HeritageThemePainter({
    this.animation,
    double? progress,
    required this.isDark,
    required this.isPreview,
  })  : _staticProgress = progress,
        super(repaint: animation);

  double get progress => animation?.value ?? _staticProgress ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final baseColor = isDark
        ? const Color(0xFF141210)
        : const Color(0xFFF7F4EE);
    final deepColor = isDark
        ? const Color(0xFF191613)
        : const Color(0xFFEFE8DD);

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [baseColor, deepColor],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // Warm antique dust motes drifting gently
    final motePaint = Paint()..style = PaintingStyle.fill;
    final moteCount = isPreview ? 10 : 22;

    for (int i = 0; i < moteCount; i++) {
      final seed = i * 47.123;
      final speed = 0.3 + (i % 5) * 0.15;
      final t = (progress * speed + (i / moteCount)) % 1.0;

      final x = (math.sin(seed + t * math.pi * 2) * 0.35 + 0.5) * size.width;
      final y = (1.0 - t) * size.height;

      final radius = 1.0 + (i % 3) * 0.8;
      final alpha = (math.sin(t * math.pi) * (isDark ? 0.22 : 0.15)).clamp(
        0.0,
        1.0,
      );

      motePaint.color =
          (isDark ? const Color(0xFFD48827) : const Color(0xFFA34820))
              .withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), radius, motePaint);
    }
  }

  @override
  bool shouldRepaint(covariant HeritageThemePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate._staticProgress != _staticProgress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. FUTURE THEME PAINTER (Neo Future / High-Tech Precision Grid & Pulses)
// ─────────────────────────────────────────────────────────────────────────────
class FutureThemePainter extends CustomPainter {
  final Animation<double>? animation;
  final double? _staticProgress;
  final bool isDark;
  final bool isPreview;

  FutureThemePainter({
    this.animation,
    double? progress,
    required this.isDark,
    required this.isPreview,
  })  : _staticProgress = progress,
        super(repaint: animation);

  double get progress => animation?.value ?? _staticProgress ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final baseColor = isDark
        ? const Color(0xFF060A12)
        : const Color(0xFFF0F4F8);
    final deepColor = isDark
        ? const Color(0xFF0A101D)
        : const Color(0xFFE4EDF5);

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [baseColor, deepColor],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // Subtle luminous cybernetic grid lines
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..color = (isDark ? const Color(0xFF00D8FF) : const Color(0xFF0284C7))
          .withValues(alpha: isDark ? 0.05 : 0.04);

    final step = isPreview ? 28.0 : 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // High-tech luminous data particles drifting vertically
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final count = isPreview ? 8 : 18;

    for (int i = 0; i < count; i++) {
      final seed = i * 29.53;
      final speed = 0.4 + (i % 4) * 0.2;
      final t = (progress * speed + (i / count)) % 1.0;

      final x = ((seed * 11) % size.width);
      final y = t * size.height;
      final radius = 1.2 + (i % 2) * 0.8;

      final pulseAlpha = (math.sin(t * math.pi) * (isDark ? 0.35 : 0.20)).clamp(
        0.0,
        1.0,
      );
      particlePaint.color =
          (isDark ? const Color(0xFF00D8FF) : const Color(0xFF0284C7))
              .withValues(alpha: pulseAlpha);

      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FutureThemePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate._staticProgress != _staticProgress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. BLOOM THEME PAINTER (Vibrant / Soft Modern Botanical Warmth)
// ─────────────────────────────────────────────────────────────────────────────
class BloomThemePainter extends CustomPainter {
  final Animation<double>? animation;
  final double? _staticProgress;
  final bool isDark;
  final bool isPreview;

  BloomThemePainter({
    this.animation,
    double? progress,
    required this.isDark,
    required this.isPreview,
  })  : _staticProgress = progress,
        super(repaint: animation);

  double get progress => animation?.value ?? _staticProgress ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final baseColor = isDark
        ? const Color(0xFF120C17)
        : const Color(0xFFFDF6F8);
    final deepColor = isDark
        ? const Color(0xFF1A1121)
        : const Color(0xFFF7ECF3);

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [baseColor, deepColor],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // Soft floating pastel bokeh orbs
    final orbCount = isPreview ? 4 : 8;

    for (int i = 0; i < orbCount; i++) {
      final angle =
          (progress * math.pi * 2 * 0.2) + (i * (math.pi * 2 / orbCount));
      final radius = (isPreview ? 25.0 : 60.0) + (i % 3) * 15.0;

      final cx = size.width * (0.2 + 0.6 * ((math.sin(angle + i) + 1) / 2));
      final cy =
          size.height * (0.15 + 0.7 * ((math.cos(angle * 0.7 + i) + 1) / 2));

      Color orbColor;
      if (i % 3 == 0) {
        orbColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFF43F5E);
      } else if (i % 3 == 1) {
        orbColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA);
      } else {
        orbColor = isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488);
      }

      final orbPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            orbColor.withValues(alpha: isDark ? 0.12 : 0.08),
            orbColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

      canvas.drawCircle(Offset(cx, cy), radius, orbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BloomThemePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate._staticProgress != _staticProgress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CHAMPION THEME PAINTER (Royal Obsidian & Luminous Gold Achievement Aura)
// ─────────────────────────────────────────────────────────────────────────────
// 5. CHAMPION THEME PAINTER — LUXURY OBSIDIAN & LIQUID METALLIC GOLD
// ─────────────────────────────────────────────────────────────────────────────
class ChampionThemePainter extends CustomPainter {
  final Animation<double>? animation;
  final double? _staticProgress;
  final bool isDark;
  final bool isPreview;

  ChampionThemePainter({
    this.animation,
    double? progress,
    required this.isDark,
    required this.isPreview,
  })  : _staticProgress = progress,
        super(repaint: animation);

  double get progress => animation?.value ?? _staticProgress ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── 1. Deep Imperial Obsidian Base ──────────────────────────────────────
    final baseColor = isDark
        ? const Color(0xFF070608)
        : const Color(0xFFFAF7F2);
    final coreGlowColor = isDark
        ? const Color(0xFF19130A)
        : const Color(0xFFF3EBDE);

    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 1.2,
        colors: [coreGlowColor, baseColor],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // ── 2. Flowing Metallic Gold Energy Streams ──────────────────────────────
    _paintEnergyStreams(canvas, size);

    // ── 3. Sacred Royal Crest & Laurel Watermark ─────────────────────────────
    _paintRoyalCrestWatermark(canvas, size);

    // ── 4. Elegant Diagonal Light Sweep ─────────────────────────────────────
    _paintLightSweep(canvas, size);

    // ── 5. Floating Gold Micro-Embers & Glints ───────────────────────────────
    _paintEmbers(canvas, size);
  }

  void _paintEnergyStreams(Canvas canvas, Size size) {
    final streamCount = isPreview ? 2 : 3;
    final goldColor = isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706);

    for (int i = 0; i < streamCount; i++) {
      final phase = progress * 2 * math.pi + (i * 2.1);
      final yBase = size.height * (0.24 + i * 0.28);
      final amp = isPreview ? 18.0 : 40.0;

      final path = Path();
      path.moveTo(0, yBase + math.sin(phase) * amp);

      for (double x = 0; x <= size.width; x += (isPreview ? 25.0 : 15.0)) {
        final wave = math.sin((x / size.width * 2 * math.pi) + phase + (i * 0.7));
        final y = yBase + wave * amp;
        path.lineTo(x, y);
      }

      // Soft ambient energy glow ribbon
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPreview ? 14.0 : 32.0
        ..color = goldColor.withValues(alpha: isDark ? 0.055 : 0.035)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0);
      canvas.drawPath(path, glowPaint);

      // Fine metallic filament
      final filamentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = goldColor.withValues(alpha: isDark ? 0.12 : 0.08);
      canvas.drawPath(path, filamentPaint);
    }
  }

  void _paintRoyalCrestWatermark(Canvas canvas, Size size) {
    final crestPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = (isDark ? const Color(0xFFFFD700) : const Color(0xFFB4831B))
          .withValues(alpha: isDark ? 0.11 : 0.08);

    final centerX = size.width * 0.5;
    final centerY = size.height * (isPreview ? 0.45 : 0.32);
    final scale = isPreview ? 0.50 : 1.05;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.scale(scale);

    // Crown Motif with 5 peaks and diamond finials
    final crownPath = Path();
    crownPath.moveTo(-60, 25);
    crownPath.lineTo(-70, -20); // Left outer peak
    crownPath.lineTo(-35, 5);
    crownPath.lineTo(0, -45);  // Center high peak
    crownPath.lineTo(35, 5);
    crownPath.lineTo(70, -20);  // Right outer peak
    crownPath.lineTo(60, 25);
    crownPath.close();
    canvas.drawPath(crownPath, crestPaint);

    // Diamond finial on center peak
    final diamondPath = Path();
    diamondPath.moveTo(0, -56);
    diamondPath.lineTo(6, -48);
    diamondPath.lineTo(0, -40);
    diamondPath.lineTo(-6, -48);
    diamondPath.close();
    canvas.drawPath(diamondPath, crestPaint);

    // Chevron rank bars below the crown base
    final chevronPath = Path();
    chevronPath.moveTo(-45, 36);
    chevronPath.lineTo(0, 50);
    chevronPath.lineTo(45, 36);
    canvas.drawPath(chevronPath, crestPaint);

    final chevronPath2 = Path();
    chevronPath2.moveTo(-32, 46);
    chevronPath2.lineTo(0, 58);
    chevronPath2.lineTo(32, 46);
    canvas.drawPath(chevronPath2, crestPaint);

    // Concentric ceremonial halo rings
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = (isDark ? const Color(0xFFFFD700) : const Color(0xFFB4831B))
          .withValues(alpha: isDark ? 0.06 : 0.04);
    canvas.drawCircle(Offset.zero, 95, haloPaint);
    canvas.drawCircle(Offset.zero, 115, haloPaint);

    // Laurel leaf accents (left & right arcs)
    for (int side = -1; side <= 1; side += 2) {
      for (int leaf = 0; leaf < 6; leaf++) {
        final angle = -math.pi * 0.45 + (leaf * 0.20);
        final lx = side * (90 * math.cos(angle));
        final ly = 90 * math.sin(angle);
        final leafPath = Path();
        leafPath.moveTo(lx, ly);
        leafPath.quadraticBezierTo(
          lx + side * 14,
          ly - 7,
          lx + side * 20,
          ly + 2,
        );
        leafPath.quadraticBezierTo(lx + side * 12, ly + 9, lx, ly);
        canvas.drawPath(leafPath, crestPaint);
      }
    }

    canvas.restore();
  }

  void _paintLightSweep(Canvas canvas, Size size) {
    // Subtle 45-degree specular light sweep passing across the canvas
    final sweepProgress = (progress * 1.5) % 2.0;
    if (sweepProgress > 1.2) return; // Dormant gap between sweeps for elegance

    final t = sweepProgress / 1.2;
    final sweepX = size.width * (-0.3 + t * 1.6);
    final rect = Rect.fromLTWH(sweepX - 80, 0, 160, size.height);

    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          (isDark ? const Color(0xFFFFD700) : const Color(0xFFFDE68A))
              .withValues(alpha: isDark ? 0.065 : 0.045),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);
  }

  void _paintEmbers(Canvas canvas, Size size) {
    final count = isPreview ? 12 : 28;
    final goldColor = isDark ? const Color(0xFFFFE066) : const Color(0xFFD97706);
    final emberPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final seed = i * 61.27;
      final speed = 0.25 + (i % 4) * 0.12;
      final t = (progress * speed + (i / count)) % 1.0;

      final sway = math.sin(t * math.pi * 3 + seed) * (isPreview ? 8.0 : 22.0);
      final x = ((seed * 23.7) % size.width) + sway;
      final y = (1.0 - t) * size.height;
      final radius = 0.8 + (i % 3) * 0.9;

      // Shimmer intensity peaks at mid-height
      final shimmer = math.sin(t * math.pi);
      final alpha = (shimmer * (isDark ? 0.55 : 0.35)).clamp(0.0, 1.0);

      emberPaint.color = goldColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, emberPaint);

      // Micro-glint cross sparkle on bright embers
      if (i % 4 == 0 && alpha > 0.25 && !isPreview) {
        final glintPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = (isDark ? Colors.white : const Color(0xFFFFD700))
              .withValues(alpha: alpha * 0.85);
        final glintSize = radius * 4.0;
        canvas.drawLine(
          Offset(x - glintSize, y),
          Offset(x + glintSize, y),
          glintPaint,
        );
        canvas.drawLine(
          Offset(x, y - glintSize),
          Offset(x, y + glintSize),
          glintPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChampionThemePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate._staticProgress != _staticProgress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}

