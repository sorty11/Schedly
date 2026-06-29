import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';
import 'tutorial_storage_service.dart';
import '../widgets/cc_character.dart';

class FeatureDiscoveryService {
  static const int currentAppFeatureVersion = 1;

  static Future<void> checkNewFeatures(BuildContext context) async {
    final lastSeen = await TutorialStorageService.getLastSeenFeatureVersion();
    if (currentAppFeatureVersion > lastSeen) {
      if (!context.mounted) return;
      _showFeatureDiscovery(context);
    }
  }

  static void _showFeatureDiscovery(BuildContext context) {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => _FeatureCard(
        onDismiss: () async {
          entry?.remove();
          await TutorialStorageService.setLastSeenFeatureVersion(currentAppFeatureVersion);
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }
}

class _FeatureCard extends StatelessWidget {
  final VoidCallback onDismiss;
  
  const _FeatureCard({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.x3l),
          padding: const EdgeInsets.all(AppSpacing.x3l),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.x2l),
            boxShadow: AppShadow.level4(Theme.of(context).colorScheme.primary),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CCCharacter(size: 80, expression: CCExpression.surprising),
              const SizedBox(height: AppSpacing.x2l),
              Text(
                '✨ NEW FEATURE',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).extension<AppSemanticColors>()?.conducted ?? Colors.green,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Flagship Onboarding',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Meet CC, your new Campus Companion! Experience the redesigned interactive tutorials.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.x3l),
              FilledButton(
                onPressed: onDismiss,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text('Awesome!', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
