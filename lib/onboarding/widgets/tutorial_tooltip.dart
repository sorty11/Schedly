import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final double tooltipWidth = availableWidth > maxTooltipWidth ? maxTooltipWidth : availableWidth;

    // Determine Y Position (Above or Below)
    bool placeBelow = targetBounds.bottom + 250 < screenH;
    if (!placeBelow && targetBounds.top - 250 < 0) {
      placeBelow = (screenH - targetBounds.bottom) > targetBounds.top;
    }

    // Give some breathing room to the beak
    final double beakSpacing = 16.0;
    double top = placeBelow ? targetBounds.bottom + beakSpacing : targetBounds.top - 220;

    // Determine X Position (Centered over target, bounded by screen)
    double left = targetBounds.center.dx - (tooltipWidth / 2);
    if (left < 16) left = 16;
    if (left + tooltipWidth > screenW - 16) left = screenW - 16 - tooltipWidth;

    // Beak position
    double beakLeft = targetBounds.center.dx - left - 20; // 20 is half beak width
    // Constrain beak to stay within the tooltip box
    if (beakLeft < 16) beakLeft = 16;
    if (beakLeft > tooltipWidth - 40 - 16) beakLeft = tooltipWidth - 40 - 16;

    final state = controller.state;
    final bool isCelebration = state == TutorialState.celebration || state == TutorialState.interactionCompleted;
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
                child: const Icon(Icons.arrow_drop_up_rounded, color: Colors.white, size: 40),
              ),
            
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadow.level4(Theme.of(context).colorScheme.primary),
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
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              isCelebration 
                                ? "You got it right!" 
                                : (isWaiting ? step.ccMessage : step.description),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _buildProgressBar(controller.currentStepIndex + 1, controller.activeTour?.steps.length ?? 1),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 2.0,
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
                            TextButton(
                              onPressed: () => controller.skipTour(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text('Skip', style: GoogleFonts.inter(fontSize: 13)),
                            ),
                            if (!step.requireInteraction && !isCelebration)
                              FilledButton(
                                onPressed: () => controller.advanceStep(),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                ),
                                child: Text(
                                  controller.currentStepIndex == (controller.activeTour?.steps.length ?? 1) - 1 ? 'Finish' : 'Next',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            if (step.requireInteraction && !isCelebration)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, 
                                      size: 16, 
                                      color: Theme.of(context).colorScheme.onPrimaryContainer
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Try it',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
  
            if (!placeBelow)
              Padding(
                padding: EdgeInsets.only(left: beakLeft),
                child: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 40),
              ),
          ],
        ),
      ),
    );
  }

  String _buildProgressBar(int current, int total) {
    if (total <= 0) return '';
    final progress = current / total;
    final filledBars = (progress * 4).round().clamp(0, 4);
    final emptyBars = 4 - filledBars;
    final filledStr = '█' * filledBars;
    final emptyStr = '░' * emptyBars;
    return '$filledStr$emptyStr';
  }
}
