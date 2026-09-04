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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = disableAnimations ? 0.0 : _controller.value;
        CustomPainter painter;
        switch (widget.theme) {
          case SchedlyVisualTheme.heritage:
            painter = HeritageThemePainter(
              progress: progress,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.future:
            painter = FutureThemePainter(
              progress: progress,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.bloom:
            painter = BloomThemePainter(
              progress: progress,
              isDark: widget.isDark,
              isPreview: widget.isPreview,
            );
            break;
          case SchedlyVisualTheme.defaultTheme:
            return const SizedBox.shrink();
        }

        return CustomPaint(painter: painter, size: Size.infinite);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HERITAGE THEME PAINTER (Old School Rust / Academic Editorial Texture)
// ─────────────────────────────────────────────────────────────────────────────
class HeritageThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  HeritageThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

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
      oldDelegate.progress != progress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. FUTURE THEME PAINTER (Neo Future / High-Tech Precision Grid & Pulses)
// ─────────────────────────────────────────────────────────────────────────────
class FutureThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  FutureThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

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
      oldDelegate.progress != progress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. BLOOM THEME PAINTER (Vibrant / Soft Modern Botanical Warmth)
// ─────────────────────────────────────────────────────────────────────────────
class BloomThemePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isPreview;

  BloomThemePainter({
    required this.progress,
    required this.isDark,
    required this.isPreview,
  });

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
      oldDelegate.progress != progress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isPreview != isPreview;
}
