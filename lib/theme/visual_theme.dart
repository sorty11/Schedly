import 'package:flutter/material.dart';

enum SchedlyVisualTheme {
  defaultTheme(
    'default',
    'Default',
    'Standard clean Schedly look',
    Icons.brightness_auto_rounded,
  ),
  space(
    'space',
    'Space 🌌',
    'Dark cosmic nebula with drifting starfield',
    Icons.auto_awesome_rounded,
  ),
  cats(
    'cats',
    'Cats 🐱',
    'Cozy ambient cats & gentle floating paws',
    Icons.pets_rounded,
  ),
  cyberRobo(
    'cyber_robo',
    'Cyber Robo 🤖',
    'Futuristic circuit traces & glowing grid',
    Icons.smart_toy_rounded,
  ),
  arcade(
    'arcade',
    'Arcade 🎮',
    'Retro synthwave grid & 8-bit shimmer',
    Icons.sports_esports_rounded,
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
    if (id == null) return SchedlyVisualTheme.defaultTheme;
    for (final theme in SchedlyVisualTheme.values) {
      if (theme.id == id) return theme;
    }
    return SchedlyVisualTheme.defaultTheme;
  }
}
