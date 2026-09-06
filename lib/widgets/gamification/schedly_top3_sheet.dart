import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/theme.dart';
import '../../models/gamification_profile.dart';
import '../../services/gamification_service.dart';

class SchedlyTop3Sheet extends StatefulWidget {
  final LeaderboardPopupData data;

  const SchedlyTop3Sheet({super.key, required this.data});

  static Future<void> show(BuildContext context, {required LeaderboardPopupData data}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => SchedlyTop3Sheet(data: data),
    );
  }

  @override
  State<SchedlyTop3Sheet> createState() => _SchedlyTop3SheetState();
}

class _SchedlyTop3SheetState extends State<SchedlyTop3Sheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _autoCloseTimer;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..forward();

    // 6-second timer starts exactly when popup is mounted and visible
    _autoCloseTimer = Timer(const Duration(seconds: 6), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _autoCloseTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sem = theme.extension<AppSemanticColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    final skin = VisualSkin.of(context);
    final isChampionTheme = skin.visualTheme == SchedlyVisualTheme.champion;

    final sheetBg = isChampionTheme
        ? (isDark ? const Color(0xFF0C0A10) : const Color(0xFFFAF7F2))
        : (isDark ? sem.surfaceElevated : colorScheme.surface);
    final top3 = widget.data.top3;
    final bestCR = widget.data.bestCR;
    final bestSR = widget.data.bestSR;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.x2l),
        ),
        border: Border.all(
          color: isChampionTheme
              ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFB4831B))
                  .withValues(alpha: 0.40)
              : sem.borderSubtle,
          width: isChampionTheme ? 1.2 : 1.0,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Auto-close progress bar (subtle & premium)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.x2l),
              ),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  return LinearProgressIndicator(
                    value: 1.0 - _progressController.value,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isChampionTheme
                          ? const Color(0xFFFFD700)
                          : colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isChampionTheme
                      ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                      : colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: (isChampionTheme
                              ? const Color(0xFFFFD700)
                              : const Color(0xFFE5A93C))
                          .withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: isChampionTheme
                          ? Border.all(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.5),
                              width: 1,
                            )
                          : null,
                    ),
                    child: isChampionTheme
                        ? const Icon(
                            Icons.workspace_premium_rounded,
                            size: 20,
                            color: Color(0xFFFFD700),
                          )
                        : const Text('🏆', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCHEDLY LEADERS',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isChampionTheme
                                ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706))
                                : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Global Top 3 & Leadership',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: sem.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      'CONTINUE',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section title
                    Text(
                      'GLOBAL TOP 3',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: sem.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Top 3 cards
                    if (top3.isEmpty)
                      _buildEmptyState(sem)
                    else
                      for (int i = 0; i < top3.length; i++) ...[
                        _buildTop3Card(
                          rank: i + 1,
                          profile: top3[i],
                          colorScheme: colorScheme,
                          sem: sem,
                        ),
                        if (i < top3.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],

                    const SizedBox(height: AppSpacing.lg),

                    // Leadership recognition row
                    Text(
                      'LEADERSHIP RECOGNITION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: sem.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Row(
                      children: [
                        Expanded(
                          child: _buildLeadershipCard(
                            title: 'BEST CR',
                            icon: Icons.admin_panel_settings_rounded,
                            profile: bestCR,
                            accentColor: const Color(0xFF3B82F6),
                            colorScheme: colorScheme,
                            sem: sem,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildLeadershipCard(
                            title: 'BEST SR',
                            icon: Icons.school_rounded,
                            profile: bestSR,
                            accentColor: const Color(0xFF10B981),
                            colorScheme: colorScheme,
                            sem: sem,
                          ),
                        ),
                      ],
                    ),

                    if (widget.data.champion != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildChampionCard(
                        profile: widget.data.champion!,
                        colorScheme: colorScheme,
                        sem: sem,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppSemanticColors sem) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: sem.surfaceElevated2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: sem.borderSubtle),
      ),
      child: Center(
        child: Text(
          'No leaderboard rankings recorded yet.\nBe the first to earn EXP today!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: sem.onSurfaceMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildChampionCard({
    required GamificationProfile profile,
    required ColorScheme colorScheme,
    required AppSemanticColors sem,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFFFD700);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1728), const Color(0xFF110D17)]
              : [const Color(0xFFFAF2E4), const Color(0xFFF3E7D0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: goldColor.withValues(alpha: isDark ? 0.75 : 0.65),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFE57F).withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
          BoxShadow(
            color: goldColor.withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: goldColor, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: _buildAvatar(profile, colorScheme),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0C0A10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: goldColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('🔥 ', style: TextStyle(fontSize: 11)),
                    Text(
                      'REIGNING CHAMPION',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: goldColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E170A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF2E2412), Color(0xFF1B150A)]
                    : const [Color(0xFFFDF6E2), Color(0xFFF5E8C8)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: goldColor.withValues(alpha: isDark ? 0.65 : 0.50),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '${profile.weeklyExp} Weekly XP',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: goldColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTop3Card({
    required int rank,
    required GamificationProfile profile,
    required ColorScheme colorScheme,
    required AppSemanticColors sem,
  }) {
    final isFirst = rank == 1;
    final medalEmoji = isFirst ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final medalColor = isFirst
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: isFirst ? AppSpacing.md + 2 : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isFirst
            ? medalColor.withValues(alpha: 0.08)
            : sem.surfaceElevated2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isFirst
              ? medalColor.withValues(alpha: 0.45)
              : sem.borderSubtle,
          width: isFirst ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Medal
          Text(medalEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.md),

          // Prominent Profile Picture
          _buildAvatar(profile, colorScheme),
          const SizedBox(width: AppSpacing.md),

          // Name and context
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: GoogleFonts.inter(
                    fontSize: isFirst ? 15 : 14,
                    fontWeight: isFirst ? FontWeight.w800 : FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.academicContext.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.academicContext,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: sem.onSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Total XP
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isFirst
                  ? medalColor.withValues(alpha: 0.18)
                  : colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '${profile.exp} XP',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFirst ? const Color(0xFFB8860B) : colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(GamificationProfile profile, ColorScheme colorScheme) {
    const double size = 38;

    if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Image.network(
          profile.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(profile, colorScheme, size),
        ),
      );
    }

    return _buildFallbackAvatar(profile, colorScheme, size);
  }

  Widget _buildFallbackAvatar(
    GamificationProfile profile,
    ColorScheme colorScheme,
    double size,
  ) {
    final initials = profile.displayName.isNotEmpty
        ? profile.displayName.substring(0, 1).toUpperCase()
        : 'S';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildLeadershipCard({
    required String title,
    required IconData icon,
    required GamificationProfile? profile,
    required Color accentColor,
    required ColorScheme colorScheme,
    required AppSemanticColors sem,
  }) {
    final points = title == 'BEST CR'
        ? (profile?.crPoints ?? 0)
        : (profile?.srPoints ?? 0);
    final hasLeader = profile != null && points > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: sem.surfaceElevated2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: hasLeader ? accentColor.withValues(alpha: 0.3) : sem.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasLeader ? profile.displayName : 'No leader yet',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            hasLeader ? '$points activity pts' : 'Qualifying edits needed',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: sem.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
