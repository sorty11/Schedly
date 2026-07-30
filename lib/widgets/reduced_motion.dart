import 'package:flutter/material.dart';

/// Utility to check if the user prefers reduced motion.
/// Use this to gate animations throughout the app.
class ReducedMotion {
  ReducedMotion._();

  /// Check if animations should be disabled.
  static bool isEnabled(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Returns Duration.zero if reduced motion is enabled, otherwise returns the provided duration.
  static Duration duration(BuildContext context, Duration normal) {
    return isEnabled(context) ? Duration.zero : normal;
  }

  /// Returns Curves.linear if reduced motion is enabled (instant), otherwise returns the provided curve.
  static Curve curve(BuildContext context, Curve normal) {
    return isEnabled(context) ? Curves.linear : normal;
  }
}
