import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';

import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/animated_list_tile.dart';

class AboutSchedlyPage extends StatefulWidget {
  const AboutSchedlyPage({super.key});

  @override
  State<AboutSchedlyPage> createState() => _AboutSchedlyPageState();
}

class _AboutSchedlyPageState extends State<AboutSchedlyPage> with SingleTickerProviderStateMixin {
  String _version = 'Loading...';
  String _buildNumber = '';
  String _appName = 'Schedly';

  late final AnimationController _logoController;
  late final Animation<double> _logoFloatAnimation;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _logoFloatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
        _appName = info.appName.isNotEmpty ? info.appName : 'Schedly';
      });
    }
  }

  Widget _sectionHeader(String title) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.md,
        top: AppSpacing.x2l,
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: semanticColors.onSurfaceMuted,
        ),
      ),
    );
  }



  Widget _buildCheckItem(String text) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: semanticColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile(String title, IconData icon) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return AnimatedListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      onTap: () {}, // Placeholder
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: semanticColors.onSurfaceMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
        ).copyWith(bottom: AppSpacing.x4l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Header ──────────────────────────────────────────────
            StaggeredListItem(
              index: 0,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _logoFloatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _logoFloatAnimation.value),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.school_rounded, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                  Text(
                    _appName,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Smart Academic Companion',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Designed to simplify academic life by helping students, Subject Representatives (SRs), and Class Representatives (CRs) manage timetables, lectures, analytics, announcements, replacements, and academic workflows through a beautiful offline-first experience.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: semanticColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Version Information ──────────────────────────────────────
            StaggeredListItem(
              index: 1,
              child: AnimatedCard(
                borderRadius: AppRadius.xl,
                backgroundColor: semanticColors.surfaceElevated,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: semanticColors.borderSubtle),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Version $_version',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Build $_buildNumber',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: semanticColors.onSurfaceMuted,
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

            // ── Features ─────────────────────────────────────────────────
            _sectionHeader('Feature Highlights'),
            StaggeredListItem(
              index: 2,
              child: AnimatedCard(
                borderRadius: AppRadius.xl,
                backgroundColor: semanticColors.surfaceElevated,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.x2l),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: semanticColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _buildCheckItem('Smart Timetable'),
                      _buildCheckItem('Offline Support'),
                      _buildCheckItem('Analytics Dashboard'),
                      _buildCheckItem('SR Conduct Tracker'),
                      _buildCheckItem('CR Management'),
                      _buildCheckItem('Lecture Replacement System'),
                      _buildCheckItem('PDF Timetable Import'),
                      _buildCheckItem('Announcements'),
                      _buildCheckItem('Interactive Tutorials'),
                      _buildCheckItem('Campus Companion (CC)'),
                      _buildCheckItem('Premium Animations'),
                    ],
                  ),
                ),
              ),
            ),

            // ── Why Schedly? ─────────────────────────────────────────────
            _sectionHeader('Why Schedly?'),
            StaggeredListItem(
              index: 3,
              child: AnimatedCard(
                borderRadius: AppRadius.xl,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.x2l),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Schedly is built specifically for colleges to modernize timetable management, lecture tracking, communication, and analytics. It provides an intuitive experience for Students, Subject Representatives, and Class Representatives while remaining fast, reliable, and offline-capable.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),

            // ── Legal Section ────────────────────────────────────────────
            _sectionHeader('Legal'),
            StaggeredListItem(
              index: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: semanticColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: semanticColors.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildLegalTile('Privacy Policy', Icons.privacy_tip_outlined),
                    Divider(height: 1, color: semanticColors.borderSubtle, indent: 64),
                    _buildLegalTile('Terms & Conditions', Icons.gavel_rounded),
                    Divider(height: 1, color: semanticColors.borderSubtle, indent: 64),
                    _buildLegalTile('Open Source Licenses', Icons.code_rounded),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.x4l),

            // ── Footer ───────────────────────────────────────────────────
            StaggeredListItem(
              index: 5,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Made with ', style: GoogleFonts.inter(color: semanticColors.onSurfaceMuted, fontSize: 13)),
                      const Icon(Icons.favorite, color: Colors.red, size: 16),
                      Text(' for Students', style: GoogleFonts.inter(color: semanticColors.onSurfaceMuted, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '© 2026 $_appName',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: semanticColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Designed & Developed by Ayaan Patel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: semanticColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
