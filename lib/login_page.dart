import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'cr_auth_bottom_sheet.dart';
import 'nmims_structure.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/app_dialogs.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNoController = TextEditingController();

  String? _selectedYear;
  String? _selectedDivision;
  bool _loading = false;

  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _heroController.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedYear == null || _selectedDivision == null) {
      AppDialogs.showError(
        context: context,
        title: 'Missing Details',
        message: 'Please select Academic Year and Division to continue.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final rollNo = _rollNoController.text.trim().toUpperCase();

      final branch = NMIMSStructure.getBranchForDivision(_selectedDivision!);
      if (branch == null) {
        throw Exception(
            'Could not determine branch for Division $_selectedDivision');
      }

      final sectionId =
          '${_selectedYear!.replaceAll(' ', '')}_${branch.replaceAll(' ', '')}_$_selectedDivision';

      final docRef =
          FirebaseFirestore.instance.collection('sections').doc(sectionId);
      final docSnap = await docRef.get();
      if (!docSnap.exists || docSnap.data()?['active'] != true) {
        throw Exception('This section has not been set up by your CR yet.');
      }

      await docRef.collection('students').doc(rollNo).set({
        'name': name,
        'rollNo': rollNo,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_logged_in', true);
      await prefs.setString('selected_division', sectionId); await NotificationService.updateDivisionSubscription(sectionId);
      HapticFeedback.mediumImpact();

      await AppSettings.saveRole(UserRole.student);
      await AppSettings.saveStudentDetails(
        name: name,
        rollNo: rollNo,
        acYear: _selectedYear!,
        br: branch,
        div: _selectedDivision!,
        secId: sectionId,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(division: sectionId)),
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Login Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _heroFade,
          child: SlideTransition(
            position: _heroSlide,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero Header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x2l,
                      AppSpacing.x4l,
                      AppSpacing.x2l,
                      AppSpacing.x3l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo mark
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'S',
                              style: GoogleFonts.outfit(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.x2l),

                        Text(
                          'Welcome to\nSchedly',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(height: 1.15),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        Text(
                          'Enter your details to access your division\'s timetable, analytics, and more.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Form Card ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.x2l,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? sem.surfaceElevated : colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: isDark
                              ? sem.borderSubtle
                              : const Color(0xFFE8E8F0),
                          width: 1,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.x2l),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Your Details',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // Name field
                              StaggeredListItem(
                                index: 0,
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(
                                      Icons.person_rounded,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                      size: 20,
                                    ),
                                    fillColor: isDark
                                        ? sem.surfaceElevated2
                                        : const Color(0xFFF8F8FC),
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                  validator: (value) => value == null ||
                                          value.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.md),

                              // Roll No field
                              StaggeredListItem(
                                index: 1,
                                child: TextFormField(
                                  controller: _rollNoController,
                                  decoration: InputDecoration(
                                    labelText: 'Roll Number (e.g. A137)',
                                    prefixIcon: Icon(
                                      Icons.badge_rounded,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                      size: 20,
                                    ),
                                    fillColor: isDark
                                        ? sem.surfaceElevated2
                                        : const Color(0xFFF8F8FC),
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  validator: (value) => value == null ||
                                          value.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.x2l),

                              // Division selector from Firestore
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('sections')
                                    .where('active', isEqualTo: true)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      !snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return Text(
                                      'No active sections available.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      textAlign: TextAlign.center,
                                    );
                                  }

                                  final docs = snapshot.data!.docs;
                                  final activeYears = docs
                                      .map((d) =>
                                          d['academicYear'] as String)
                                      .toSet()
                                      .toList()
                                    ..sort();

                                  if (_selectedYear != null &&
                                      !activeYears.contains(_selectedYear)) {
                                    _selectedYear = null;
                                    _selectedDivision = null;
                                  }

                                  List<String> activeDivisions = [];
                                  if (_selectedYear != null) {
                                    activeDivisions = docs
                                        .where((d) =>
                                            d['academicYear'] == _selectedYear)
                                        .map((d) => d['division'] as String)
                                        .toSet()
                                        .toList()
                                      ..sort();
                                    if (_selectedDivision != null &&
                                        !activeDivisions
                                            .contains(_selectedDivision)) {
                                      _selectedDivision = null;
                                    }
                                  }

                                  return StaggeredListItem(
                                    index: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Academic Year',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: sem.onSurfaceMuted,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Wrap(
                                          spacing: AppSpacing.sm,
                                          runSpacing: AppSpacing.sm,
                                          children: activeYears.map((year) {
                                            final isSelected =
                                                _selectedYear == year;
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedYear = year;
                                                  _selectedDivision = null;
                                                });
                                              },
                                              child: AnimatedContainer(
                                                duration: AppDuration.standard,
                                                curve: AppCurves.standard,
                                                padding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: AppSpacing.lg,
                                                  vertical: AppSpacing.sm + 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? colorScheme.primary
                                                      : isDark
                                                          ? sem.surfaceElevated2
                                                          : const Color(
                                                              0xFFF5F5F7),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppRadius.full),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? colorScheme.primary
                                                        : sem.borderSubtle,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  year,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),

                                        if (_selectedYear != null) ...[
                                          const SizedBox(height: AppSpacing.xl),
                                          Text(
                                            'Division',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                              color: sem.onSurfaceMuted,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Wrap(
                                            spacing: AppSpacing.sm,
                                            runSpacing: AppSpacing.sm,
                                            children:
                                                activeDivisions.map((div) {
                                              final isSelected =
                                                  _selectedDivision == div;
                                              final br = NMIMSStructure
                                                      .getBranchForDivision(
                                                          div) ??
                                                  '';
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(
                                                    () => _selectedDivision =
                                                        div,
                                                  );
                                                },
                                                child: AnimatedContainer(
                                                  duration: AppDuration.standard,
                                                  curve: AppCurves.standard,
                                                  padding:
                                                      EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.lg,
                                                    vertical: AppSpacing.sm + 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? colorScheme.primary
                                                        : isDark
                                                            ? sem.surfaceElevated2
                                                            : const Color(
                                                                0xFFF5F5F7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppRadius.full),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? colorScheme.primary
                                                          : sem.borderSubtle,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Div $div',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isSelected
                                                              ? Colors.white
                                                              : colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      if (br.isNotEmpty)
                                                        Text(
                                                          br,
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 10,
                                                            color: isSelected
                                                                ? Colors.white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.75)
                                                                : sem
                                                                    .onSurfaceMuted,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: AppSpacing.x3l),

                              // Continue button
                              StaggeredListItem(
                                index: 3,
                                child: AnimatedButton(
                                  onPressed: _loading ? null : _registerStudent,
                                  isLoading: _loading,
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  child: const Text(
                                    'Continue to Dashboard',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── CR Portal card ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x2l,
                      AppSpacing.lg,
                      AppSpacing.x2l,
                      AppSpacing.x4l,
                    ),
                    child: StaggeredListItem(
                      index: 4,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CRAuthBottomSheet(
                              initialYear: _selectedYear,
                              initialDivision: _selectedDivision,
                            ),
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(
                                color: colorScheme.secondary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.secondary.withValues(alpha: 0.06),
                                  colorScheme.primary.withValues(alpha: 0.03),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.secondary,
                                        colorScheme.primary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.secondary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Class Representative Portal',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Manage timetables, announce updates & more',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: sem.onSurfaceMuted,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: colorScheme.secondary.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}