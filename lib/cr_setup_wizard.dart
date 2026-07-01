import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nmims_structure.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'home_page.dart';
import 'models/section_config.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/app_dialogs.dart';
import 'theme/theme.dart';

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

  final _formKey = GlobalKey<FormState>();
  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedDivision;
  
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
    _crPasswordController.dispose();
    _srPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() => _loading = true);

    try {
      final sectionId = '${_selectedYear!.replaceAll(' ', '')}_${_selectedBranch!.replaceAll(' ', '')}_$_selectedDivision';
      final db = FirebaseFirestore.instance;
      
      final config = SectionConfig(
        id: sectionId,
        academicYear: _selectedYear!,
        branch: _selectedBranch!,
        division: _selectedDivision!,
        workingDays: [], // Managed in Manual Timetable Studio
        batches: [], // Managed in Manual Timetable Studio
        periods: [], // Managed in Manual Timetable Studio
        active: true,
      );

      await db.collection('sections').doc(sectionId).set({
        ...config.toJson(),
        'crPassword': _crPasswordController.text,
        'srPassword': _srPasswordController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'timetablePublished': false,
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

    List<String> validDivisions = [];
    if (_selectedBranch != null) {
      validDivisions = NMIMSStructure.getDivisionsForBranch(_selectedBranch!);
      if (!validDivisions.contains(_selectedDivision)) _selectedDivision = null;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text('Setup Class Section', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('Section Details', sem),
                    const SizedBox(height: 16),
                    _buildDropdown('Academic Year', _selectedYear, NMIMSStructure.academicYears, (val) => setState(() => _selectedYear = val)),
                    const SizedBox(height: 16),
                    _buildDropdown('Branch', _selectedBranch, NMIMSStructure.branches, (val) => setState(() {
                      _selectedBranch = val;
                      _selectedDivision = null;
                    })),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedDivision,
                      decoration: _inputDecoration('Division', sem),
                      items: validDivisions.map((d) => DropdownMenuItem(value: d, child: Text('Division $d'))).toList(),
                      onChanged: _selectedBranch == null ? null : (val) => setState(() => _selectedDivision = val),
                      validator: (val) => val == null ? 'Required' : null,
                      dropdownColor: isDark ? sem.surfaceElevated2 : cs.surface,
                    ),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Security', sem),
                    const SizedBox(height: 8),
                    Text('Create passwords for CRs and SRs to manage this section.', style: GoogleFonts.inter(fontSize: 13, color: sem.onSurfaceMuted)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _crPasswordController,
                      obscureText: true,
                      decoration: _inputDecoration('CR Password', sem),
                      validator: (val) => (val == null || val.length < 4) ? 'Minimum 4 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _srPasswordController,
                      obscureText: true,
                      decoration: _inputDecoration('SR Password', sem),
                      validator: (val) => (val == null || val.length < 4) ? 'Minimum 4 characters' : null,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
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
                child: FilledButton(
                  onPressed: _loading ? null : _completeSetup,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  child: _loading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Section & Proceed', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppSemanticColors sem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
        Divider(color: sem.borderSubtle, thickness: 1, height: 24),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, AppSemanticColors sem) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: sem.borderSubtle)),
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label, sem),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Required' : null,
      dropdownColor: isDark ? sem.surfaceElevated2 : cs.surface,
    );
  }
}
