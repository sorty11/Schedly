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
// Phoenix demands sharp, architectural borders. Huge bubbly radii are removed.
class AppRadius {
  AppRadius._();
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8; // Standard for inputs, small cards
  static const double lg = 12; // Maximum for large panels/dialogs
  static const double xl = 16;
  static const double x2l = 24;
  static const double full = 999;
}

// ─── Animation Durations ──────────────────────────────────────────────────────
// Phoenix motion is instantaneous, snappy, and physics-based. Long fades are banned.
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
// Shadows in Phoenix are almost non-existent. Depth comes from 1px borders.
// When shadows are used (e.g. modals), they are highly dispersed.
class AppShadow {
  AppShadow._();

  static List<BoxShadow> level1(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.8)
          : Colors.black.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> level2(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 1.0)
          : Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> level3(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 1.0)
          : Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> level4(Color primary, {bool isDark = false}) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 1.0)
          : Colors.black.withValues(alpha: 0.12),
      blurRadius: 48,
      offset: const Offset(0, 24),
      spreadRadius: -8,
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
