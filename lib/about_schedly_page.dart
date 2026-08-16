import 'package:flutter/material.dart';
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

class _AboutSchedlyPageState extends State<AboutSchedlyPage>
    with SingleTickerProviderStateMixin {
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
      padding: EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.md,
        top: AppSpacing.x2l,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
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
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: semanticColors.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
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

  Widget _buildLegalTile(String title, IconData icon, VoidCallback onTap) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    return AnimatedListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
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

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LegalDocumentSheet(
        title: 'Privacy Policy',
        content: '''
What Information Schedly Stores
We store minimal personal data to make the app function properly, including your basic profile information (name, roll number, division) and academic choices (selected subjects and batches).

Why It Is Stored
This information is stored to provide you with a personalized timetable, accurate attendance analytics, and role-based permissions based on your section.

Firebase Authentication & Firestore
We use Firebase Authentication to securely verify your identity. Your data is stored in Cloud Firestore. We do not store passwords locally; session tokens are handled securely by Firebase.

Notification Tokens
We collect device notification tokens via Firebase Cloud Messaging to send you real-time alerts about cancelled or rescheduled lectures.

Role Information
Your assigned role (Student, Class Representative, Subject Representative, or Faculty) is stored to manage app permissions and capabilities.

Data Privacy & Deletion
We do not share your data with third parties. You can request deletion of your account and associated personal data at any time from the app settings.
''',
      ),
    );
  }

  void _showTerms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LegalDocumentSheet(
        title: 'Terms & Conditions',
        content: '''
Educational Use Only
Schedly is strictly an educational tool designed to assist with timetable management. It is not an official university record.

Responsibilities of Students
Students are responsible for maintaining their personal attendance accuracy and respecting the privacy of their peers.

Responsibilities of Class Representatives (CR)
CRs are entrusted with editing the timetable and sending announcements responsibly. Any misuse of this power may lead to role revocation.

Responsibilities of Subject Representatives (SR)
SRs must accurately track lecture conduct and coordinate with faculty.

Responsibilities of Faculty
Faculty members are responsible for reviewing requests and ensuring their schedules are accurately reflected.

Proper Use of Features
Timetable editing and conduct tracking features must be used with integrity. Deliberate falsification of academic records is prohibited.

Account Misuse Policy
Any account found abusing the system, exploiting vulnerabilities, or harassing other users will be terminated immediately.
''',
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
        padding: EdgeInsets.symmetric(
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
                        child: Icon(
                          Icons.school_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                  Text(
                    _appName,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Smart Academic Companion',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
                    style: TextStyle(
                      fontFamily: 'Inter',
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
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Version $_version',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Build $_buildNumber',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: semanticColors.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
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
                  padding: EdgeInsets.all(AppSpacing.x2l),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: semanticColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _buildCheckItem('Smart Timetable'),
                      _buildCheckItem('Offline Support'),
                      _buildCheckItem('Attendance Analytics'),
                      _buildCheckItem('SR Conduct Tracker'),
                      _buildCheckItem('CR Management'),
                      _buildCheckItem('Faculty Portal'),
                      _buildCheckItem('Lecture Replacement'),
                      _buildCheckItem('PDF Timetable Import'),
                      _buildCheckItem('Announcements'),
                      _buildCheckItem('Push Notifications'),
                      _buildCheckItem('Secure Role-Based Access'),
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
                  padding: EdgeInsets.all(AppSpacing.x2l),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'Schedly is built specifically for colleges to modernize timetable management, lecture tracking, communication, and analytics. It provides an intuitive experience for Students, Subject Representatives, and Class Representatives while remaining fast, reliable, and offline-capable.',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
                    _buildLegalTile(
                      'Privacy Policy',
                      Icons.privacy_tip_outlined,
                      _showPrivacyPolicy,
                    ),
                    Divider(
                      height: 1,
                      color: semanticColors.borderSubtle,
                      indent: 64,
                    ),
                    _buildLegalTile(
                      'Terms & Conditions',
                      Icons.gavel_rounded,
                      _showTerms,
                    ),
                    Divider(
                      height: 1,
                      color: semanticColors.borderSubtle,
                      indent: 64,
                    ),
                    _buildLegalTile(
                      'Open Source Licenses',
                      Icons.code_rounded,
                      () {
                        showLicensePage(
                          context: context,
                          applicationName: _appName,
                          applicationVersion: _version,
                          applicationLegalese: '© 2026 $_appName',
                        );
                      },
                    ),
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
                      Text(
                        'Made with ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: semanticColors.onSurfaceMuted,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(Icons.favorite, color: Colors.red, size: 16),
                      Text(
                        ' for Students',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: semanticColors.onSurfaceMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '© 2026 $_appName',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: semanticColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Designed & Developed by Ayaan Patel',
                    style: TextStyle(
                      fontFamily: 'Inter',
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

class _LegalDocumentSheet extends StatelessWidget {
  final String title;
  final String content;

  const _LegalDocumentSheet({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final paragraphs = content.trim().split('\n\n');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x2l,
        AppSpacing.lg,
        AppSpacing.x2l,
        AppSpacing.x4l,
      ),
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.x2l),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sem.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: sem.onSurfaceMuted),
                  style: IconButton.styleFrom(
                    backgroundColor: sem.surfaceElevated,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: sem.borderSubtle),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: paragraphs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final lines = paragraphs[index].trim().split('\n');
                  if (lines.isEmpty) return const SizedBox();

                  final sectionTitle = lines.first;
                  final sectionBody = lines.length > 1
                      ? lines.sublist(1).join('\n')
                      : '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionTitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (sectionBody.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          sectionBody,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
