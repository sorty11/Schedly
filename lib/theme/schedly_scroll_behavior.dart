import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Centralized scroll behavior providing consistent, platform-adaptive, high-velocity
/// scrolling physics with responsive momentum and natural settling across all devices.
class SchedlyScrollBehavior extends MaterialScrollBehavior {
  const SchedlyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = getPlatform(context);
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // Cupertino bouncing physics with fast deceleration (0.99) to prevent lingering float
        return const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        // Material clamping physics tuned for immediate flick momentum and fast settling
        return const SchedlyAndroidScrollPhysics();
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Uses platform-native overscroll indicators (e.g. Android 12+ stretch or glow)
    return super.buildOverscrollIndicator(context, child, details);
  }
}

/// Custom Android / Material scroll physics tuned for high-velocity flick response
/// and prompt settling (eliminating sluggish lingering float without abrupt stops).
class SchedlyAndroidScrollPhysics extends ClampingScrollPhysics {
  const SchedlyAndroidScrollPhysics({super.parent});

  /// Tuned kinetic friction coefficient.
  /// Flutter default is 0.015 (floats for 2.5+ seconds).
  /// 0.022 provides a responsive initial surge that settles in ~600-800ms.
  static const double tunedFriction = 0.022;

  /// Kinetic friction coefficient getter
  double get friction => tunedFriction;

  @override
  SchedlyAndroidScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SchedlyAndroidScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }
      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }
      assert(end != null);
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        end!,
        math.min(0.0, velocity),
        tolerance: tolerance,
      );
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: tunedFriction,
      tolerance: tolerance,
    );
  }
}
