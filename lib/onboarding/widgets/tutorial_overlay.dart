import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/theme.dart';
import '../models/tutorial_step.dart';
import '../services/tutorial_controller.dart';
import 'tutorial_target.dart';
import 'tutorial_tooltip.dart';

class TutorialOverlayManager {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => const _TutorialOverlayWidget(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final Rect hole;
  final SpotlightShape shape;
  final double radius;

  _HoleClipper({
    required this.hole,
    required this.shape,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (shape == SpotlightShape.circle) {
      path.addOval(hole);
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(hole, Radius.circular(radius)),
      );
    }
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) =>
      hole != oldClipper.hole ||
      shape != oldClipper.shape ||
      radius != oldClipper.radius;
}

class _TutorialOverlayWidget extends StatefulWidget {
  const _TutorialOverlayWidget();

  @override
  State<_TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<_TutorialOverlayWidget>
    with SingleTickerProviderStateMixin {
  final TutorialController _controller = TutorialController.instance;

  Rect? _currentTargetBounds;
  Rect? _previousTargetBounds;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_controller.isVisible) return;

    final step = _controller.currentStep;
    if (step != null) {
      final bounds = TargetRegistry.instance.getBounds(step.targetId);
      if (bounds != null && bounds != _currentTargetBounds) {
        if (mounted) {
          setState(() {
            _previousTargetBounds = _currentTargetBounds ?? bounds;
            _currentTargetBounds = bounds;
          });
        }
      }
    }
  }

  void _onControllerUpdate() {
    if (!_controller.isVisible) {
      TutorialOverlayManager.hide();
      return;
    }

    final step = _controller.currentStep;
    if (step != null) {
      final bounds = TargetRegistry.instance.getBounds(step.targetId);
      if (bounds != null && bounds != _currentTargetBounds) {
        if (mounted) {
          setState(() {
            _previousTargetBounds = _currentTargetBounds ?? bounds;
            _currentTargetBounds = bounds;
          });
        }
      } else {
        if (mounted) setState(() {});
      }
    } else {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state == TutorialState.idle || state == TutorialState.preparing) {
      return const SizedBox.shrink();
    }

    final boundsToUse = _currentTargetBounds ?? _previousTargetBounds;
    if (boundsToUse == null) {
      return const SizedBox.shrink();
    }

    final step = _controller.currentStep;
    final padding = step?.targetPadding ?? const EdgeInsets.all(8.0);
    final shape = step?.shape ?? SpotlightShape.roundedRectangle;

    final rect = boundsToUse;
    final highlightRect = Rect.fromLTRB(
      rect.left - padding.left,
      rect.top - padding.top,
      rect.right + padding.right,
      rect.bottom + padding.bottom,
    );

    final prevRect = _previousTargetBounds ?? highlightRect;
    final prevHighlightRect = Rect.fromLTRB(
      prevRect.left - padding.left,
      prevRect.top - padding.top,
      prevRect.right + padding.right,
      prevRect.bottom + padding.bottom,
    );

    final bool showTooltip =
        state == TutorialState.highlighting ||
        state == TutorialState.waitingForInteraction ||
        state == TutorialState.interactionCompleted ||
        state == TutorialState.celebration;

    final skin = VisualSkin.of(context);
    final isHeritage = skin.visualTheme == SchedlyVisualTheme.heritage;
    final isFuture = skin.visualTheme == SchedlyVisualTheme.future;
    final isBloom = skin.visualTheme == SchedlyVisualTheme.bloom;

    final double cornerRadius = shape == SpotlightShape.circle
        ? highlightRect.width / 2
        : (isBloom ? AppRadius.x2l : (isFuture ? AppRadius.md : AppRadius.lg));

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(begin: prevHighlightRect, end: highlightRect),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              builder: (context, currentRect, _) {
                if (currentRect == null) return const SizedBox.shrink();
                return Stack(
                  children: [
                    // Backdrop with cutout hole
                    ClipPath(
                      clipper: _HoleClipper(
                        hole: currentRect,
                        shape: shape,
                        radius: cornerRadius,
                      ),
                      child: Stack(
                        children: [
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // If user taps backdrop, allow safe skip or ignore
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: isFuture ? 0.75 : (isHeritage ? 0.70 : 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spotlight Border & Skin Highlights
                    Positioned.fromRect(
                      rect: currentRect,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: shape == SpotlightShape.circle
                                ? BoxShape.circle
                                : BoxShape.rectangle,
                            borderRadius: shape == SpotlightShape.circle
                                ? null
                                : BorderRadius.circular(cornerRadius),
                            border: Border.all(
                              color: isHeritage
                                  ? const Color(0xFFC07040)
                                  : (isFuture
                                      ? const Color(0xFF00E5FF)
                                      : skin.primaryAccent.withValues(alpha: 0.8)),
                              width: isHeritage ? 2.5 : (isFuture ? 1.8 : 2.0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isHeritage
                                    ? const Color(0xFFC86432).withValues(alpha: 0.35)
                                    : (isFuture
                                        ? const Color(0xFF00E5FF).withValues(alpha: 0.45)
                                        : skin.primaryAccent.withValues(alpha: 0.3)),
                                blurRadius: isFuture ? 20 : 16,
                                spreadRadius: isFuture ? 2 : 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Tooltip Layer
          Positioned.fill(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(begin: prevHighlightRect, end: highlightRect),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              builder: (context, currentRect, _) {
                if (currentRect == null) return const SizedBox.shrink();
                return Stack(
                  children: [
                    TutorialTooltip(
                      targetBounds: currentRect,
                      opacity: showTooltip ? 1.0 : 0.0,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

