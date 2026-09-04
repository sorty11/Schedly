import 'package:flutter/widgets.dart';

enum TooltipPosition { top, bottom, left, right, auto }
enum SpotlightShape { roundedRectangle, circle }

class TutorialStep {
  final String targetId;
  final String title;
  final String description;
  final String ccMessage; // What Campus Companion (CC) says
  final IconData? icon;
  final bool requireInteraction; // If true, Next button is hidden or shows Try It Out
  final TooltipPosition preferredPosition;
  final SpotlightShape shape;
  final EdgeInsets targetPadding;
  final String? actionLabel;

  const TutorialStep({
    required this.targetId,
    required this.title,
    required this.description,
    this.ccMessage = "Here's a tip!",
    this.icon,
    this.requireInteraction = false,
    this.preferredPosition = TooltipPosition.auto,
    this.shape = SpotlightShape.roundedRectangle,
    this.targetPadding = const EdgeInsets.all(8.0),
    this.actionLabel,
  });
}

