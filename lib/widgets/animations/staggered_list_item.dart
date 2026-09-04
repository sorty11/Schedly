import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final int delayMs;
  final Offset slideOffset;
  final Axis axis;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delayMs = 60,
    this.slideOffset = const Offset(
      0,
      0.04,
    ), // Kept the same semantic slide definition
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    // Stagger only the first 4 items upon initial screen entrance (max ~100ms cascade).
    // Items at index 4 and beyond, or items constructed during fast scrolling, appear
    // immediately with 0ms delay, eliminating blank/delayed card rendering during scrolls.
    final effectiveIndex = index.clamp(0, 3);
    final effectiveDelayMs = (effectiveIndex * (delayMs.clamp(0, 35)));

    return child
        .animate(delay: effectiveDelayMs.ms)
        .fade(duration: 180.ms, curve: Curves.easeOut)
        .slide(
          begin: Offset(slideOffset.dx * 8, slideOffset.dy * 8),
          end: Offset.zero,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
