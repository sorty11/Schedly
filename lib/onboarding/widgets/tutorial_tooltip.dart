import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../models/tutorial_step.dart';
import '../services/tutorial_controller.dart';
import 'cc_character.dart';

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

    final mediaQuery = MediaQuery.of(context);
    final screenW = mediaQuery.size.width;
    final screenH = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    // Tooltip Width Constraints
    final double maxTooltipWidth = 400.0;
    final double availableWidth = screenW - 32;
    final double tooltipWidth = availableWidth > maxTooltipWidth
        ? maxTooltipWidth
        : availableWidth;

    // Determine Y Position (Above or Below)
    bool placeBelow = true;
    if (step.preferredPosition == TooltipPosition.top) {
      placeBelow = false;
    } else if (step.preferredPosition == TooltipPosition.bottom) {
      placeBelow = true;
    } else {
      // Auto: prefer below unless close to bottom
      placeBelow = targetBounds.bottom + 230 < (screenH - bottomPadding);
      if (!placeBelow && targetBounds.top - 230 < (topPadding + 20)) {
        placeBelow = (screenH - targetBounds.bottom) > targetBounds.top;
      }
    }

    final double beakSpacing = 12.0;
    double top = placeBelow
        ? targetBounds.bottom + beakSpacing
        : targetBounds.top - 215;

    // Ensure within screen bounds
    final minTop = topPadding + 12;
    final maxTop = screenH - bottomPadding - 220;
    if (top < minTop) top = minTop;
    if (top > maxTop) top = maxTop > minTop ? maxTop : minTop;

    // Determine X Position (Centered over target, bounded by screen)
    double left = targetBounds.center.dx - (tooltipWidth / 2);
    if (left < 16) left = 16;
    if (left + tooltipWidth > screenW - 16) left = screenW - 16 - tooltipWidth;

    // Beak position
    double beakLeft = targetBounds.center.dx - left - 16;
    if (beakLeft < 16) beakLeft = 16;
    if (beakLeft > tooltipWidth - 48) beakLeft = tooltipWidth - 48;

    final state = controller.state;
    final bool isCelebration =
        state == TutorialState.celebration ||
        state == TutorialState.interactionCompleted;
    final bool isWaiting = state == TutorialState.waitingForInteraction;

    CCExpression expression = CCExpression.happy;
    if (isCelebration) expression = CCExpression.celebrating;
    if (isWaiting) expression = CCExpression.thinking;

    final skin = VisualSkin.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeritage = skin.visualTheme == SchedlyVisualTheme.heritage;
    final isFuture = skin.visualTheme == SchedlyVisualTheme.future;
    final isBloom = skin.visualTheme == SchedlyVisualTheme.bloom;

    final cardBgColor = isHeritage
        ? (isDark
            ? const Color(0xFF241B16).withValues(alpha: 0.94)
            : const Color(0xFFFAF5EE).withValues(alpha: 0.95))
        : (isFuture
            ? (isDark
                ? const Color(0xFF0B1017).withValues(alpha: 0.95)
                : const Color(0xFFF3F7FA).withValues(alpha: 0.95))
            : (isBloom
                ? (isDark
                    ? const Color(0xFF1E1728).withValues(alpha: 0.94)
                    : Colors.white.withValues(alpha: 0.95))
                : (isDark
                    ? Colors.black.withValues(alpha: 0.80)
                    : Colors.white.withValues(alpha: 0.90))));

    final cardBorderColor = isHeritage
        ? const Color(0xFFC07040).withValues(alpha: 0.45)
        : (isFuture
            ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
            : (isBloom
                ? skin.primaryAccent.withValues(alpha: 0.3)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08))));

    final double cardRadius = isBloom ? AppRadius.x2l : (isFuture ? AppRadius.md : AppRadius.xl);

    return Positioned(
      top: top,
      left: left,
      width: tooltipWidth,
      child: Semantics(
        label: 'Tutorial step ${controller.currentStepIndex + 1} of ${controller.activeTour?.steps.length ?? 1}: ${step.title}',
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
                  child: Icon(
                    Icons.arrow_drop_up_rounded,
                    color: cardBorderColor,
                    size: 32,
                  ),
                ),

              ClipRRect(
                borderRadius: BorderRadius.circular(cardRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(color: cardBorderColor, width: isFuture ? 1.5 : 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: isFuture
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CCCharacter(size: 56, expression: expression),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCelebration ? "Awesome!" : step.title,
                                    style: TextStyle(
                                      fontFamily: isFuture ? 'JetBrainsMono' : 'Outfit',
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isFuture && !isCelebration
                                          ? const Color(0xFF00E5FF)
                                          : Theme.of(context).colorScheme.onSurface,
                                      letterSpacing: isFuture ? -0.3 : 0.0,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    isCelebration
                                        ? "You're all set with this step!"
                                        : (isWaiting ? step.ccMessage : step.description),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.8),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Step progress
                            Text(
                              '${controller.currentStepIndex + 1} / ${controller.activeTour?.steps.length ?? 1}',
                              style: TextStyle(
                                fontFamily: isFuture ? 'JetBrainsMono' : 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isFuture
                                    ? const Color(0xFF00E5FF)
                                    : skin.primaryAccent,
                              ),
                            ),

                            // Action buttons
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (controller.currentStepIndex > 0)
                                  TextButton(
                                    onPressed: () => controller.previousStep(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    child: const Text('Back', style: TextStyle(fontSize: 12)),
                                  ),
                                TextButton(
                                  onPressed: () => controller.skipTour(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: const Text('Skip', style: TextStyle(fontSize: 12)),
                                ),
                                if (!step.requireInteraction && !isCelebration)
                                  FilledButton(
                                    onPressed: () => controller.advanceStep(),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: skin.primaryAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      minimumSize: const Size(0, 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(cardRadius / 2),
                                      ),
                                    ),
                                    child: Text(
                                      step.actionLabel ??
                                          (controller.currentStepIndex ==
                                                  (controller.activeTour?.steps.length ?? 1) - 1
                                              ? 'Finish'
                                              : 'Next'),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (step.requireInteraction && !isCelebration)
                                  FilledButton.tonal(
                                    onPressed: () {
                                      // Controlled progression: user can tap the button to continue
                                      controller.completeStep();
                                    },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      minimumSize: const Size(0, 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(cardRadius / 2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.touch_app_rounded, size: 14),
                                        SizedBox(width: 4),
                                        Text('Continue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
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
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: cardBorderColor,
                    size: 32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

