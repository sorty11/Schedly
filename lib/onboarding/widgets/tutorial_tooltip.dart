import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/tutorial_controller.dart';
import 'cc_character.dart';
import '../../theme/theme.dart';

class TutorialTooltip extends StatelessWidget {
  final Rect targetBounds;
  final double opacity;

  const TutorialTooltip({
    super.key,
    required this.targetBounds,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TutorialController.instance;
    final step = controller.currentStep;
    if (step == null) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Tooltip Width Constraints
    final double maxTooltipWidth = 380.0;
    final double availableWidth = screenW - 32; // 16 padding each side
    final double tooltipWidth = availableWidth > maxTooltipWidth
        ? maxTooltipWidth
        : availableWidth;

    // Determine Y Position (Above or Below)
    bool placeBelow = targetBounds.bottom + 250 < screenH;
    if (!placeBelow && targetBounds.top - 250 < 0) {
      placeBelow = (screenH - targetBounds.bottom) > targetBounds.top;
    }

    // Give some breathing room to the beak
    final double beakSpacing = 16.0;
    double top = placeBelow
        ? targetBounds.bottom + beakSpacing
        : targetBounds.top - 220;

    // Determine X Position (Centered over target, bounded by screen)
    double left = targetBounds.center.dx - (tooltipWidth / 2);
    if (left < 16) left = 16;
    if (left + tooltipWidth > screenW - 16) left = screenW - 16 - tooltipWidth;

    // Beak position
    double beakLeft =
        targetBounds.center.dx - left - 20; // 20 is half beak width
    // Constrain beak to stay within the tooltip box
    if (beakLeft < 16) beakLeft = 16;
    if (beakLeft > tooltipWidth - 40 - 16) beakLeft = tooltipWidth - 40 - 16;

    final state = controller.state;
    final bool isCelebration =
        state == TutorialState.celebration ||
        state == TutorialState.interactionCompleted;
    final bool isWaiting = state == TutorialState.waitingForInteraction;

    CCExpression expression = CCExpression.happy;
    if (isCelebration) expression = CCExpression.celebrating;
    if (isWaiting) expression = CCExpression.thinking;

    return Positioned(
      top: top,
      left: left,
      width: tooltipWidth,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (placeBelow)
              Padding(
                padding: EdgeInsets.only(left: beakLeft),
                child: const Icon(
                  Icons.arrow_drop_up_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),

            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CCCharacter(size: 60, expression: expression),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCelebration ? "Awesome!" : step.title,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  isCelebration
                                      ? "You got it right!"
                                      : (isWaiting
                                            ? step.ccMessage
                                            : step.description),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Actions Row using Wrap for absolute safety against overflow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Progress Indicator
                          Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(
                              'Step ${controller.currentStepIndex + 1} of ${controller.activeTour?.steps.length ?? 1}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          // Actions (Wrap safely drops to next line if squeezed)
                          Expanded(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (controller.currentStepIndex > 0)
                                  TextButton(
                                    onPressed: () => controller.previousStep(),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                    ),
                                    child: Text(
                                      'Previous',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () => controller.skipTour(),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                    ),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (!step.requireInteraction && !isCelebration)
                                  FilledButton(
                                    onPressed: () => controller.advanceStep(),
                                    style: FilledButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                    ),
                                    child: Text(
                                      controller.currentStepIndex ==
                                              (controller
                                                          .activeTour
                                                          ?.steps
                                                          .length ??
                                                      1) -
                                                  1
                                          ? 'Finish'
                                          : 'Next',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (step.requireInteraction && !isCelebration)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.full,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.touch_app_rounded,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Try it',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!placeBelow)
              Padding(
                padding: EdgeInsets.only(left: beakLeft),
                child: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
