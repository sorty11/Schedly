import 'package:flutter/material.dart';

enum SchedlyVisualTheme {
  defaultTheme(
    'default',
    'Classic Schedly',
    'Standard clean Schedly look',
    Icons.brightness_auto_rounded,
  ),
  heritage(
    'heritage',
    'Old School Rust',
    'Aged copper, rust, antique brass & academic elegance',
    Icons.auto_stories_rounded,
  ),
  future(
    'future',
    'Neo Future',
    'Deep graphite, glowing cyan & precision tech',
    Icons.terminal_rounded,
  ),
  bloom(
    'bloom',
    'Vibrant',
    'Soft berry, coral, lavender, mint & rounded warmth',
    Icons.palette_rounded,
  );

  final String id;
  final String displayName;
  final String description;
  final IconData icon;

  const SchedlyVisualTheme(
    this.id,
    this.displayName,
    this.description,
    this.icon,
  );

  static SchedlyVisualTheme fromId(String? id) {
    if (id == null || id.isEmpty) return SchedlyVisualTheme.defaultTheme;
    for (final theme in SchedlyVisualTheme.values) {
      if (theme.id == id) return theme;
    }
    // Legacy theme migration as per requirement 12:
    // space, cyber_robo, arcade -> future; cats -> bloom
    if (id == 'space' || id == 'cyber_robo' || id == 'arcade') {
      return SchedlyVisualTheme.future;
    }
    if (id == 'cats') {
      return SchedlyVisualTheme.bloom;
    }
    return SchedlyVisualTheme.defaultTheme;
  }
}
