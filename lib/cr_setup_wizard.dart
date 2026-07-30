import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nmims_structure.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'home_page.dart';
import 'models/section_config.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';
import 'theme/theme.dart';
import 'package:schedly/exceptions.dart';
import 'widgets/schedly_card.dart';
import 'widgets/schedly_text_field.dart';

class CRSetupWizard extends StatefulWidget {
  final String? initialYear;
  final String? initialBranch;
  final String? initialDivision;

  const CRSetupWizard({
    super.key,
    this.initialYear,
    this.initialBranch,
    this.initialDivision,
  });

  @override
  State<CRSetupWizard> createState() => _CRSetupWizardState();
}

class _CRSetupWizardState extends State<CRSetupWizard> {
  bool _loading = false;
  int _currentStep = 0;
  final PageController _pageController = PageController();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedDivision;
  
  final _masterPasswordController = TextEditingController();
  final _crPasswordController = TextEditingController();
  final _srPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedBranch = widget.initialBranch;
    _selectedDivision = widget.initialDivision;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _masterPasswordController.dispose();
    _crPasswordController.dispose();
    _srPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!(_formKey1.currentState?.validate() ?? false)) return;
      setState(() => _currentStep = 1);
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 0);
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _completeSetup() async {
    if (!(_formKey2.currentState?.validate() ?? false)) return;
    
    setState(() => _loading = true);

    try {
      final sectionId = '${_selectedYear!.replaceAll(' ', '')}_${_selectedBranch!.replaceAll(' ', '')}_$_selectedDivision';
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AppException('You must be authenticated to create a section');
      
      final token = await user.getIdToken();
      if (token == null) throw AppException('Failed to retrieve authentication token');

      final config = SectionConfig(
        id: sectionId,
        academicYear: _selectedYear!,
        branch: _selectedBranch!,
        division: _selectedDivision!,
        workingDays: [],
        batches: [],
        periods: [],
        active: true,
      );

      final callable = FirebaseFunctions.instance.httpsCallable('createSection');
      await callable.call({
        'masterPassword': _masterPasswordController.text,
        'sectionId': sectionId,
        'config': config.toJson(),
        'crPassword': _crPasswordController.text,
        'srPassword': _srPasswordController.text,
        'creatorName': 'Class Representative'
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_logged_in', true);
      
      await AppSettings.saveRole(UserRole.cr);
      await AppSettings.saveStudentDetails(
        name: 'Class Representative', 
        rollNo: 'ADMIN',
        acYear: _selectedYear!,
        br: _selectedBranch!,
        div: _selectedDivision!,
        secId: sectionId,
      );

      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(division: _selectedDivision!)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Setup Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('Setup Section', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _currentStep == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _previousStep,
              )
            : const BackButton(),
      ),
      body: Column(
        children: [
          // Custom Progress Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.md),
            child: Row(
              children: [
                _buildStepIndicator('1', 'Details', 0, cs, sem),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep >= 1 ? cs.primary : sem.borderSubtle,
                  ),
                ),
                _buildStepIndicator('2', 'Security', 1, cs, sem),
              ],
            ),
          ),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(sem, cs, isDark),
                _buildStep2(sem, cs, isDark),
              ],
            ),
          ),
          
          // Bottom Action
          Container(
            padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.lg, AppSpacing.x2l, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: isDark ? sem.surfaceElevated : cs.surface,
              border: Border(top: BorderSide(color: sem.borderSubtle)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
              ],
            ),
            child: SafeArea(
              top: false,
              child: AnimatedButton(
                onPressed: _loading ? null : _nextStep,
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Center(
                    child: _loading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _currentStep == 0 ? 'Continue' : 'Create Section & Proceed', 
                            style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String number, String title, int step, ColorScheme cs, AppSemanticColors sem) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? cs.primary : sem.surfaceElevated2,
            border: Border.all(color: isActive ? cs.primary : sem.borderSubtle, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(fontFamily: 'Outfit', 
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : sem.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(fontFamily: 'Inter', 
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? cs.onSurface : sem.onSurfaceMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1(AppSemanticColors sem, ColorScheme cs, bool isDark) {
    List<String> validDivisions = [];
    if (_selectedBranch != null) {
      validDivisions = NMIMSStructure.getDivisionsForBranch(_selectedBranch!);
      if (!validDivisions.contains(_selectedDivision)) _selectedDivision = null;
    }

    return Form(
      key: _formKey1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Section Details', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Select your program to initialize the workspace.', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted)),
            const SizedBox(height: AppSpacing.x2l),
            
            SchedlyCard(
              variant: SchedlyCardVariant.elevated,
              padding: const EdgeInsets.all(AppSpacing.x2l),
              child: Column(
                children: [
                  _buildDropdown('Academic Year', _selectedYear, NMIMSStructure.academicYears, (val) => setState(() => _selectedYear = val), Icons.calendar_today_rounded),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDropdown('Branch', _selectedBranch, NMIMSStructure.branches, (val) => setState(() {
                    _selectedBranch = val;
                    _selectedDivision = null;
                  }), Icons.account_tree_rounded),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDropdown(
                    'Division', 
                    _selectedDivision, 
                    validDivisions, 
                    _selectedBranch == null ? null : (val) => setState(() => _selectedDivision = val), 
                    Icons.class_rounded,
                    prefix: 'Division '
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(AppSemanticColors sem, ColorScheme cs, bool isDark) {
    return Form(
      key: _formKey2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Security', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Enter the deployment master password and create secure access keys.', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted)),
            const SizedBox(height: AppSpacing.x2l),
            
            SchedlyCard(
              variant: SchedlyCardVariant.elevated,
              padding: const EdgeInsets.all(AppSpacing.x2l),
              child: Column(
                children: [
                  SchedlyTextField(
                    controller: _masterPasswordController,
                    labelText: 'Master Setup Password',
                    prefixIcon: Icons.admin_panel_settings_rounded,
                    obscureText: true,
                    validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SchedlyTextField(
                    controller: _crPasswordController,
                    labelText: 'CR Password',
                    prefixIcon: Icons.shield_rounded,
                    obscureText: true,
                    validator: (val) => (val == null || val.length < 4) ? 'Minimum 4 chars' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SchedlyTextField(
                    controller: _srPasswordController,
                    labelText: 'SR Password',
                    prefixIcon: Icons.security_rounded,
                    obscureText: true,
                    validator: (val) => (val == null || val.length < 4) ? 'Minimum 4 chars' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?>? onChanged, IconData icon, {String prefix = ''}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: sem.onSurfaceMuted, size: 20),
        fillColor: isDark ? sem.surfaceElevated2 : cs.surface,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: sem.borderFocus, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
      icon: Icon(Icons.expand_more_rounded, color: sem.onSurfaceMuted),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text('$prefix$e'))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Required' : null,
      dropdownColor: isDark ? sem.surfaceElevated : cs.surface,
    );
  }
}
