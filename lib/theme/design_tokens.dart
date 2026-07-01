
import 'package:flutter/material.dart';
import 'package:schedly/theme/theme.dart';

// ─── Spacing ─────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2l = 24;
  static const double x3l = 32;
  static const double x4l = 40;
  static const double x5l = 48;
  static const double x6l = 64;
}

// ─── Corner Radii ─────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double x2l = 32;
  static const double full = 999;
}

// ─── Animation Durations ──────────────────────────────────────────────────────
class AppDuration {
  AppDuration._();
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration smooth = Duration(milliseconds: 350);
  static const Duration spring = Duration(milliseconds: 500);
  static const Duration enter = Duration(milliseconds: 300);
  static const Duration exit = Duration(milliseconds: 200);
  static const Duration stagger = Duration(milliseconds: 60);
}

// ─── Motion Curves ────────────────────────────────────────────────────────────
class AppCurves {
  AppCurves._();
  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutExpo;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
}

// ─── Elevation / Shadows ──────────────────────────────────────────────────────
class AppShadow {
  AppShadow._();

  static List<BoxShadow> level1(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : primary.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> level2(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.4)
          : primary.withValues(alpha: 0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> level3(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.5)
          : primary.withValues(alpha: 0.15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> level4(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.6)
          : primary.withValues(alpha: 0.20),
      blurRadius: 48,
      offset: const Offset(0, 16),
      spreadRadius: -4,
    ),
  ];
}
