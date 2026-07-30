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
    this.slideOffset = const Offset(0, 0.04), // Kept the same semantic slide definition
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    // Determine translation values (flutter_animate takes translation in pixels/percent,
    // since we used an offset before, we will use small pixel offsets for subtlety)
    final double dx = axis == Axis.horizontal ? 20.0 : 0.0;
    final double dy = axis == Axis.vertical ? 20.0 : 0.0;

    return child
        .animate(delay: (index * delayMs).ms)
        .fade(duration: 220.ms, curve: Curves.easeOut)
        .slide(
          begin: Offset(slideOffset.dx * 10, slideOffset.dy * 10), // Scale offset for precise flutter_animate pixel/fraction handling
          end: Offset.zero,
          duration: 300.ms,
          curve: Curves.easeOutCubic, // Elegant physics feel
        );
  }
}
