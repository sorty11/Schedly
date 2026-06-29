import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/tutorial_controller.dart';
import 'tutorial_target.dart';
import 'tutorial_tooltip.dart';
import '../../theme/theme.dart';

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
  _HoleClipper(this.hole);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(AppRadius.lg)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) => hole != oldClipper.hole;
}

class _TutorialOverlayWidget extends StatefulWidget {
  const _TutorialOverlayWidget();

  @override
  State<_TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<_TutorialOverlayWidget> {
  final TutorialController _controller = TutorialController.instance;
  
  Rect? _currentTargetBounds;
  Rect? _previousTargetBounds;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
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
        setState(() {
          _previousTargetBounds = _currentTargetBounds ?? bounds;
          _currentTargetBounds = bounds;
        });
      } else if (bounds == null) {
        // Target is missing, state is likely waitingForTarget.
        // We do NOT clear _currentTargetBounds. We keep the previous bounds 
        // to prevent the overlay from unmounting or jumping to an error state.
        setState(() {});
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    
    if (state == TutorialState.idle || state == TutorialState.preparing) {
      return const SizedBox.shrink();
    }

    if (state == TutorialState.recovery) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Waiting for next step...',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please navigate to the required screen or try recovering.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _controller.skipTour(),
                    child: const Text('Skip Tutorial', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => _controller.retryCurrentStep(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final boundsToUse = _currentTargetBounds ?? _previousTargetBounds;
    if (boundsToUse == null) {
      return const SizedBox.shrink();
    }

    final rect = boundsToUse;
    final highlightRect = Rect.fromLTRB(
      rect.left - 8,
      rect.top - 8,
      rect.right + 8,
      rect.bottom + 8,
    );
    
    final prevRect = _previousTargetBounds ?? highlightRect;
    final prevHighlightRect = Rect.fromLTRB(
      prevRect.left - 8,
      prevRect.top - 8,
      prevRect.right + 8,
      prevRect.bottom + 8,
    );

    // Fade out tooltip during transition, paused, or celebration
    final bool showTooltip = state == TutorialState.highlighting || 
                             state == TutorialState.waitingForInteraction || 
                             state == TutorialState.interactionCompleted ||
                             state == TutorialState.celebration;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(begin: prevHighlightRect, end: highlightRect),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              builder: (context, currentRect, _) {
                if (currentRect == null) return const SizedBox.shrink();
                return Stack(
                  children: [
                    ClipPath(
                      clipper: _HoleClipper(currentRect),
                      child: Stack(
                        children: [
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                            child: Container(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          GestureDetector(
                            onTap: () {}, // Block all taps outside the hole
                            behavior: HitTestBehavior.opaque,
                            child: Container(color: Colors.black.withValues(alpha: 0.6)),
                          ),
                        ],
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
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              builder: (context, currentRect, _) {
                if (currentRect == null) return const SizedBox.shrink();
                // We wrap TutorialTooltip in a Stack so its Positioned widget has a proper parent.
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
