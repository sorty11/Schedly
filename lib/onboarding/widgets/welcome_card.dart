import 'package:flutter/material.dart';
import 'dart:ui';
import 'cc_character.dart';
import '../../theme/theme.dart';

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

class _WelcomeCardState extends State<WelcomeCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
          child: FadeTransition(
            opacity: _controller,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.x2l),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  margin: EdgeInsets.all(AppSpacing.x3l),
                  padding: EdgeInsets.all(AppSpacing.x3l),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppRadius.x2l),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CCCharacter(size: 100, expression: CCExpression.happy),
                  const SizedBox(height: AppSpacing.x2l),
                  Text(
                    'Welcome to Schedly 👋',
                    style: TextStyle(fontFamily: 'Outfit', 
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.roleMessage,
                    style: TextStyle(fontFamily: 'Inter', 
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.x3l),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: widget.onSkip,
                        child: Text(
                          'Skip',
                          style: TextStyle(fontFamily: 'Inter', 
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      FilledButton(
                        onPressed: widget.onStartTour,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2l,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        child: Text(
                          'Start Tour',
                          style: TextStyle(fontFamily: 'Inter', 
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
