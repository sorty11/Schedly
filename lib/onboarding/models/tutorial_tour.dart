import '../../user_roles.dart';
import 'tutorial_step.dart';

enum TutorialCategory {
  gettingStarted,
  timetable,
  attendance,
  management,
  themes,
  featureDiscovery,
}

class TutorialTour {
  final String tourId;
  final String name;
  final String description;
  final List<TutorialStep> steps;
  final UserRole? targetRole; // null if universal
  final TutorialCategory category;
  final int minAppBuild;

  const TutorialTour({
    required this.tourId,
    required this.name,
    this.description = '',
    required this.steps,
    this.targetRole,
    this.category = TutorialCategory.gettingStarted,
    this.minAppBuild = 11,
  });
}

