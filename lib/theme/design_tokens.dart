import 'package:flutter/material.dart';

// ─── Spacing ─────────────────────────────────────────────────────────────────
// Phoenix utilizes a strict 4px/8px modular grid.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12; // Used for tight component internal padding
  static const double lg = 16;
  static const double xl = 24; // Replaced 20 with 24 for strict 8px rhythm
  static const double x2l = 32;
  static const double x3l = 48; // Shifted up
  static const double x4l = 64;
  static const double x5l = 96;
  static const double x6l = 128;

  // Workspace Margins
  static const double workspacePadding =
      32; // Outer padding for workspace content
  static const double sidebarGap = 24; // Gap between sidebar and workspace
}

// ─── Corner Radii ─────────────────────────────────────────────────────────────
// Schedly V11 Cohesive Radius Scale:
// - Small controls, chips, input inner: 10–12px (md)
// - Standard cards, list items: 16px (lg)
// - Elevated cards, hero surfaces: 20px (xl)
// - Large sheets, dialogs, modals: 28px (x2l)
class AppRadius {
  AppRadius._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12; // Standard for inputs, small controls, chips
  static const double lg = 16; // Standard for cards, list items
  static const double xl = 20; // Elevated cards, hero modules
  static const double x2l = 28; // Bottom sheets, dialogs, large panels
  static const double full = 999;
}

// ─── Animation Durations ──────────────────────────────────────────────────────
// Schedly motion is instantaneous, snappy, and physics-based. Long fades are banned.
class AppDuration {
  AppDuration._();
  static const Duration micro = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration standard = Duration(milliseconds: 150);
  static const Duration smooth = Duration(milliseconds: 200);
  static const Duration spring = Duration(milliseconds: 250);
  static const Duration enter = Duration(milliseconds: 150);
  static const Duration exit = Duration(milliseconds: 100);
  static const Duration stagger = Duration(milliseconds: 30);
}

// ─── Motion Curves ────────────────────────────────────────────────────────────
class AppCurves {
  AppCurves._();
  static const Curve standard = Curves.easeOut; // Crisp deceleration
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeIn;
  static const Curve spring = Curves.easeOutQuad;
  static const Curve bounce = Curves.easeOutQuart;
}

// ─── Elevation / Shadows ──────────────────────────────────────────────────────
// Shadows in Schedly are soft, calm, and diffused. Depth comes from subtle borders
// complemented by gentle ambient occlusion.
class AppShadow {
  AppShadow._();

  static List<BoxShadow> level1(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.25)
          : Colors.black.withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> level2(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> level3(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.45)
          : Colors.black.withValues(alpha: 0.07),
      blurRadius: 26,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> level4(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.10),
      blurRadius: 40,
      offset: const Offset(0, 16),
      spreadRadius: -4,
    ),
  ];
}

// ─── Breakpoints ──────────────────────────────────────────────────────────────
class AppBreakpoints {
  AppBreakpoints._();
  static const double mobile = 700;
  static const double tablet = 1100;
  static const double desktop = 1600;
}

// ─── Touch Targets ────────────────────────────────────────────────────────────
class AppTouchTarget {
  AppTouchTarget._();
  static const double min = 44;
  static const double comfortable = 48;
}

// ─── Icon Sizes ───────────────────────────────────────────────────────────────
class AppIconSize {
  AppIconSize._();
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

// ─── Neumorphism (DEPRECATED FOR PHOENIX) ─────────────────────────────────────
// Kept to prevent breaking existing screens during phased migration.
// They return empty or extremely subtle minimal shadows now.
class AppNeumorphism {
  AppNeumorphism._();

  static List<BoxShadow> elevated({bool isDark = false}) =>
      AppShadow.level1(Colors.transparent, isDark: isDark);
  static List<BoxShadow> inset({bool isDark = false}) => [];
  static List<BoxShadow> hero({bool isDark = false}) =>
      AppShadow.level2(Colors.transparent, isDark: isDark);
}
