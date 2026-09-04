import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'cc_character.dart';

class WelcomeCard extends StatefulWidget {
  final String roleMessage;
  final VoidCallback onStartTour;
  final VoidCallback onSkip;

  const WelcomeCard({
    super.key,
    required this.roleMessage,
    required this.onStartTour,
    required this.onSkip,
  });

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = VisualSkin.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeritage = skin.visualTheme == SchedlyVisualTheme.heritage;
    final isFuture = skin.visualTheme == SchedlyVisualTheme.future;
    final isBloom = skin.visualTheme == SchedlyVisualTheme.bloom;

    final disableMotion = MediaQuery.of(context).disableAnimations;

    final cardBgColor = isHeritage
        ? (isDark
            ? const Color(0xFF241B16).withValues(alpha: 0.95)
            : const Color(0xFFFAF5EE).withValues(alpha: 0.96))
        : (isFuture
            ? (isDark
                ? const Color(0xFF0B1017).withValues(alpha: 0.96)
                : const Color(0xFFF3F7FA).withValues(alpha: 0.96))
            : (isBloom
                ? (isDark
                    ? const Color(0xFF1E1728).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.96))
                : (isDark
                    ? Colors.black.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90))));

    final cardBorderColor = isHeritage
        ? const Color(0xFFC07040).withValues(alpha: 0.5)
        : (isFuture
            ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
            : (isBloom
                ? skin.primaryAccent.withValues(alpha: 0.35)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08))));

    final double cardRadius = isBloom ? AppRadius.x2l : (isFuture ? AppRadius.md : AppRadius.xl);

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
          padding: const EdgeInsets.all(AppSpacing.x2l),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: cardBorderColor, width: isFuture ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: isFuture
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CCCharacter(
                size: 90,
                expression: CCExpression.happy,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Welcome to Schedly 👋',
                style: TextStyle(
                  fontFamily: isFuture ? 'JetBrainsMono' : 'Outfit',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isFuture
                      ? const Color(0xFF00E5FF)
                      : Theme.of(context).colorScheme.onSurface,
                  letterSpacing: isFuture ? -0.5 : 0.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.roleMessage,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x2l),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: widget.onStartTour,
                    style: FilledButton.styleFrom(
                      backgroundColor: skin.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2l,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cardRadius / 2),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Start 1-Min Tour',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: isFuture ? 0.85 : 0.75),
      body: Center(
        child: disableMotion
            ? content
            : ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(
                  opacity: _controller,
                  child: content,
                ),
              ),
      ),
    );
  }
}
