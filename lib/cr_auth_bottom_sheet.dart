import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:schedly/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nmims_structure.dart';
import 'cr_setup_wizard.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'dart:ui';
import 'home_page.dart';
import 'widgets/animations/staggered_list_item.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/animated_icon_button.dart';
import 'widgets/app_dialogs.dart';

class CRAuthBottomSheet extends StatefulWidget {
  final String? initialYear;
  final String? initialDivision;

  const CRAuthBottomSheet({
    super.key,
    this.initialYear,
    this.initialDivision,
  });

  @override
  State<CRAuthBottomSheet> createState() => _CRAuthBottomSheetState();
}

class _CRAuthBottomSheetState extends State<CRAuthBottomSheet> {
  bool _showAuth = false;
  
  String? _selectedYear;
  String? _selectedDivision;
  final _passwordController = TextEditingController();
  
  bool _loading = false;
  bool _checkingSection = false;
  bool _sectionExists = false;
  String? _sectionId;
  String? _branch;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedDivision = widget.initialDivision;
    
    if (_selectedYear != null && _selectedDivision != null) {
      _checkSectionStatus();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkSectionStatus() async {
    if (_selectedYear == null || _selectedDivision == null) return;
    
    setState(() => _checkingSection = true);
    
    try {
      _branch = NMIMSStructure.getBranchForDivision(_selectedDivision!);
      if (_branch == null) throw Exception('Invalid division mapped');
      
      _sectionId = '${_selectedYear!.replaceAll(' ', '')}_${_branch!.replaceAll(' ', '')}_$_selectedDivision';
      
      final docSnap = await FirebaseFirestore.instance.collection('sections').doc(_sectionId).get();
      
      setState(() {
        _sectionExists = docSnap.exists;
      });
    } catch (e) {
      // Ignored for UI simplicity
    } finally {
      if (mounted) {
        setState(() => _checkingSection = false);
      }
    }
  }
  
  InputDecoration _modernDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    );
  }

  Future<void> _authenticate() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      AppDialogs.showError(
        context: context,
        title: 'Missing Password',
        message: 'Please enter a password to continue.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_sectionExists) {
        // Authenticate against existing section's CR password
        final docSnap = await FirebaseFirestore.instance.collection('sections').doc(_sectionId).get();
        final storedPassword = docSnap.data()?['crPassword'] as String?;
        
        if (storedPassword != pwd) {
          throw Exception('Incorrect CR Password for this section');
        }
        
        if (!mounted) return;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_logged_in', true);
        await prefs.setString('selected_division', _sectionId!); await NotificationService.updateDivisionSubscription(_sectionId!);
        HapticFeedback.mediumImpact();
        
        await AppSettings.saveRole(UserRole.cr);
        await AppSettings.saveStudentDetails(
          name: 'Class Representative', 
          rollNo: 'ADMIN',
          acYear: _selectedYear!,
          br: _branch!,
          div: _selectedDivision!,
          secId: _sectionId!,
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(division: _sectionId!),
          ),
          (_) => false,
        );
      } else {
        // Master password to create a new section
        if (pwd != 'ADMIN123') {
          throw Exception('Incorrect Master Password. You are not authorized to create new sections.');
        }
        
        if (!mounted) return;
        Navigator.pop(context); // Close bottom sheet
        
        // Pass off to CR Setup Wizard
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CRSetupWizard(
              initialYear: _selectedYear,
              initialBranch: _branch,
              initialDivision: _selectedDivision,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Authentication Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroPage() {
    return SingleChildScrollView(
      key: const ValueKey('intro'),
      padding: EdgeInsets.only(
        left: AppSpacing.x2l,
        right: AppSpacing.x2l,
        top: AppSpacing.x2l,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Representative Portal',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Setup and manage your academic section',
            style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          StaggeredListItem(index: 1, child: _buildFeatureRow(Icons.add_business_rounded, 'Create Academic Section', 'Initialize your class space')),
          StaggeredListItem(index: 2, child: _buildFeatureRow(Icons.picture_as_pdf_rounded, 'Upload Official Timetable', 'Auto-parse college PDF')),
          StaggeredListItem(index: 3, child: _buildFeatureRow(Icons.edit_calendar_rounded, 'Manage Timetable', 'Reschedule or cancel lectures')),
          StaggeredListItem(index: 4, child: _buildFeatureRow(Icons.campaign_rounded, 'Publish Announcements', 'Broadcast updates instantly')),
          StaggeredListItem(index: 5, child: _buildFeatureRow(Icons.analytics_rounded, 'View Analytics', 'Monitor lecture conduct stats')),
          
          const SizedBox(height: 24),
          StaggeredListItem(
            index: 6,
            child: AnimatedButton(
              onPressed: () {
                setState(() => _showAuth = true);
              },
              child: const Text('Continue to Authentication'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPage() {
    List<String> allDivisions = [];
    if (_selectedYear != null) {
      for (var b in NMIMSStructure.branches) {
        allDivisions.addAll(NMIMSStructure.getDivisionsForBranch(b));
      }
      allDivisions.sort();
      
      if (_selectedDivision != null && !allDivisions.contains(_selectedDivision)) {
        _selectedDivision = null;
      }
    }

    return SingleChildScrollView(
      key: const ValueKey('auth'),
      padding: EdgeInsets.only(
        left: AppSpacing.x2l,
        right: AppSpacing.x2l,
        top: AppSpacing.x2l,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              AnimatedIconButton(
                onPressed: () => setState(() => _showAuth = false),
                icon: const Icon(Icons.arrow_back_rounded),
                padding: 0,
              ),
              const SizedBox(width: 16),
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.admin_panel_settings_rounded, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Representative',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Authentication Required',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          StaggeredListItem(
            index: 1,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedYear,
              decoration: _modernDecoration('Academic Year', Icons.school_rounded),
              items: NMIMSStructure.academicYears
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedYear = val;
                  _selectedDivision = null;
                  _sectionExists = false;
                  _passwordController.clear();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          
          StaggeredListItem(
            index: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedDivision,
              decoration: _modernDecoration('Division', Icons.class_rounded),
              items: allDivisions
                  .map((d) {
                    final br = NMIMSStructure.getBranchForDivision(d) ?? '';
                    return DropdownMenuItem(
                      value: d, 
                      child: Text('Division $d ($br)'),
                    );
                  })
                  .toList(),
              onChanged: _selectedYear == null ? null : (val) {
                setState(() {
                  _selectedDivision = val;
                  _passwordController.clear();
                });
                _checkSectionStatus();
              },
            ),
          ),
          const SizedBox(height: 16),
          
          if (_checkingSection)
            const Center(child: CircularProgressIndicator())
          else if (_selectedYear != null && _selectedDivision != null) ...[
            StaggeredListItem(
              index: 3,
              child: Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: _sectionExists 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sectionExists ? Icons.check_circle_rounded : Icons.add_circle_rounded,
                      color: _sectionExists ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _sectionExists 
                          ? 'Section found. Enter CR Password to access dashboard.' 
                          : 'Section not initialized. Enter Master Password to create.',
                        style: TextStyle(
                          color: _sectionExists ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            StaggeredListItem(
              index: 4,
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _modernDecoration(
                  _sectionExists ? 'CR Password' : 'Master Password', 
                  Icons.lock_rounded
                ),
              ),
            ),
            const SizedBox(height: 24),
            StaggeredListItem(
              index: 5,
              child: AnimatedButton(
                onPressed: _loading ? null : _authenticate,
                isLoading: _loading,
                child: Text(_sectionExists ? 'Login to CR Panel' : 'Proceed to Setup Wizard'),
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showAuth ? _buildAuthPage() : _buildIntroPage(),
          ),
        ),
      ),
    );
  }
}
