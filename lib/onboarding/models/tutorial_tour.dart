import 'tutorial_step.dart';

class TutorialTour {
  final String tourId;
  final String name;
  final List<TutorialStep> steps;

  const TutorialTour({
    required this.tourId,
    required this.name,
    required this.steps,
  });
}
