import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../user_roles.dart';
import '../models/whats_new_item.dart';

class WhatsNewDialog extends StatelessWidget {
  final WhatsNewRelease release;
  final List<WhatsNewFeature> features;
  final UserRole role;
  final VoidCallback onDismiss;

  const WhatsNewDialog({
    super.key,
    required this.release,
    required this.features,
    required this.role,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final skin = VisualSkin.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeritage = skin.visualTheme == SchedlyVisualTheme.heritage;
    final isFuture = skin.visualTheme == SchedlyVisualTheme.future;
    final isBloom = skin.visualTheme == SchedlyVisualTheme.bloom;

    final cardBgColor = isHeritage
        ? (isDark
            ? const Color(0xFF241B16).withValues(alpha: 0.96)
            : const Color(0xFFFAF5EE).withValues(alpha: 0.98))
        : (isFuture
            ? (isDark
                ? const Color(0xFF0C1018).withValues(alpha: 0.96)
                : const Color(0xFFF3F7FA).withValues(alpha: 0.98))
            : (isBloom
                ? (isDark
                    ? const Color(0xFF1E1728).withValues(alpha: 0.96)
                    : Colors.white.withValues(alpha: 0.98))
                : (isDark
                    ? const Color(0xFF14141E).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.96))));

    final cardBorderColor = isHeritage
        ? const Color(0xFFC07040).withValues(alpha: 0.5)
        : (isFuture
            ? const Color(0xFF00E5FF).withValues(alpha: 0.55)
            : (isBloom
                ? skin.primaryAccent.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08))));

    final double cardRadius = isBloom ? AppRadius.x2l : (isFuture ? AppRadius.md : AppRadius.xl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: cardBorderColor, width: isFuture ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: isFuture
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Header ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFuture
                                    ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                                    : skin.primaryAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                border: Border.all(
                                  color: isFuture
                                      ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                                      : skin.primaryAccent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'RELEASE V${release.versionName}',
                                style: TextStyle(
                                  fontFamily: isFuture ? 'JetBrainsMono' : 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isFuture ? const Color(0xFF00E5FF) : skin.primaryAccent,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: onDismiss,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          release.heroTitle,
                          style: TextStyle(
                            fontFamily: isFuture ? 'JetBrainsMono' : 'Outfit',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: isFuture ? -0.5 : 0.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          release.heroSubtitle,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Feature List ─────────────────────────────────────────
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shrinkWrap: true,
                      itemCount: features.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final feature = features[index];
                        return _buildFeatureItem(context, feature, skin, isFuture);
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Footer CTA ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: onDismiss,
                            style: FilledButton.styleFrom(
                              backgroundColor: skin.primaryAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(cardRadius / 2),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Explore Schedly V11',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    WhatsNewFeature feature,
    VisualSkin skin,
    bool isFuture,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: skin.primaryAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: skin.primaryAccent.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            feature.icon,
            size: 20,
            color: isFuture ? const Color(0xFF00E5FF) : skin.primaryAccent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      feature.title,
                      style: TextStyle(
                        fontFamily: isFuture ? 'JetBrainsMono' : 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (feature.tag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: skin.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        feature.tag!,
                        style: TextStyle(
                          fontFamily: isFuture ? 'JetBrainsMono' : 'Inter',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isFuture ? const Color(0xFF00E5FF) : skin.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                feature.description,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

