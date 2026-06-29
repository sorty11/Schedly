import 'package:flutter/widgets.dart';

enum TooltipPosition { top, bottom, left, right, auto }

class TutorialStep {
  final String targetId;
  final String title;
  final String description;
  final String ccMessage; // What Campus Companion (CC) says
  final IconData? icon;
  final bool requireInteraction; // If true, "Next" button is hidden. App handles progression via API.
  final TooltipPosition preferredPosition;

  const TutorialStep({
    required this.targetId,
    required this.title,
    required this.description,
    this.ccMessage = "Here's a tip!",
    this.icon,
    this.requireInteraction = false,
    this.preferredPosition = TooltipPosition.auto,
  });
}
