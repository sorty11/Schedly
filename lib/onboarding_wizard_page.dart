import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/schedly_card.dart';
import 'widgets/schedly_text_field.dart';
import 'widgets/app_dialogs.dart';
import 'services/division_membership_service.dart';
import 'services/faculty_auth_service.dart';
import 'nmims_structure.dart';
import 'main.dart';
import 'home_page.dart';
import 'faculty/faculty_home_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';

class OnboardingWizardPage extends StatefulWidget {
  const OnboardingWizardPage({super.key});

  @override
  State<OnboardingWizardPage> createState() => _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends State<OnboardingWizardPage> {
  final PageController _pageController = PageController();
  final _firestore = FirebaseFirestore.instance;
  User? get user => FirebaseAuth.instance.currentUser;
  
  bool _loading = true;
  int _currentStep = 0;
  
  String? _selectedRole; // 'Student' or 'Faculty'
  
  // Student & Faculty Shared
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  
  // Student specific
  final _rollNoController = TextEditingController();
  
  // Faculty specific
  final _facultyIdController = TextEditingController();
  final _masterPasswordController = TextEditingController();
  
  // Section Selection (Student)
  String? _selectedYear;
  String? _selectedDivision;
  
  final _profileFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _rollNoController.dispose();
    _facultyIdController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    if (user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['onboardingCompleted'] == true) {
          _routeToDashboard(data['userType']);
          return;
        }
        
        setState(() {
          _selectedRole = data['userType'];
          _currentStep = data['onboardingStep'] ?? 0;
          
          if (data['draftProfile'] != null) {
            _nameController.text = data['draftProfile']['name'] ?? '';
            _departmentController.text = data['draftProfile']['department'] ?? '';
            _rollNoController.text = data['draftProfile']['rollNo'] ?? '';
            _facultyIdController.text = data['draftProfile']['facultyId'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Draft load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      if (_currentStep > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(_currentStep);
        });
      }
    }
  }

  Future<void> _saveDraftAndProceed(int nextStep) async {
    if (user == null) return;
    setState(() => _loading = true);
    
    try {
      await _firestore.collection('users').doc(user!.uid).set({
        'userType': _selectedRole,
        'onboardingStep': nextStep,
        'draftProfile': {
          'name': _nameController.text.trim(),
          'department': _departmentController.text.trim(),
          'rollNo': _rollNoController.text.trim().toUpperCase(),
          'facultyId': _facultyIdController.text.trim(),
        },
      }, SetOptions(merge: true));
      
      setState(() => _currentStep = nextStep);
      _pageController.animateToPage(
        nextStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      AppDialogs.showError(context: context, title: 'Error', message: 'Could not save progress.');
    } finally {
      setState(() => _loading = false);
    }
  }
  
  void _routeToDashboard(String? role) {
    if (role == 'Faculty') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FacultyHomePage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(division: AppSettings.sectionId ?? '')));
    }
  }

  Future<void> _completeStudentOnboarding() async {
    if (_selectedYear == null || _selectedDivision == null) {
      AppDialogs.showError(context: context, title: 'Missing Info', message: 'Please select a section.');
      return;
    }
    
    setState(() => _loading = true);
    try {
      final branch = NMIMSStructure.getBranchForDivision(_selectedDivision!);
      final sectionId = '${_selectedYear!.replaceAll(' ', '')}_${branch?.replaceAll(' ', '')}_$_selectedDivision';
      
      await DivisionMembershipService.joinDivision(
        uid: user!.uid,
        sectionId: sectionId,
        role: 'Student',
        name: _nameController.text.trim(),
        rollNo: _rollNoController.text.trim().toUpperCase(),
      );

      await AppSettings.saveRole(UserRole.student);
      await AppSettings.saveStudentDetails(
        name: _nameController.text.trim(),
        rollNo: _rollNoController.text.trim().toUpperCase(),
        acYear: _selectedYear!,
        br: branch ?? '',
        div: _selectedDivision!,
        secId: sectionId,
      );
      
      await _firestore.collection('users').doc(user!.uid).set({
        'onboardingCompleted': true,
        'profileCompleted': true,
        'profileVersion': 1,
        'division': sectionId,
      }, SetOptions(merge: true));
      
      _routeToDashboard('Student');
    } catch (e) {
      AppDialogs.showError(context: context, title: 'Error', message: e.toString());
      setState(() => _loading = false);
    }
  }

  Future<void> _completeFacultyOnboarding() async {
    if (!_verifyFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Reuse existing robust faculty verification logic
      await FacultyAuthService.elevateToFaculty(
        name: _nameController.text.trim(),
        masterPassword: _masterPasswordController.text.trim(),
      );

      await _firestore.collection('users').doc(user!.uid).set({
        'onboardingCompleted': true,
        'profileCompleted': true,
        'profileVersion': 1,
      }, SetOptions(merge: true));

      _routeToDashboard('Faculty');
    } catch (e) {
      AppDialogs.showError(context: context, title: 'Verification Failed', message: e.toString().replaceAll('Exception: ', ''));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _currentStep == 0 && _selectedRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Setup'),
        automaticallyImplyLeading: false,
        leading: _currentStep > 0 && !_loading ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            setState(() => _currentStep--);
            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          },
        ) : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_currentStep + 1) / 3),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildRoleSelectionPage(),
                  _buildProfileSetupPage(),
                  _selectedRole == 'Student' ? _buildStudentSectionPage() : _buildFacultyVerificationPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectionPage() {
    return _WizardPageContainer(
      title: 'Who are you?',
      subtitle: 'Select your role to personalize your experience.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            title: 'Student',
            description: 'Join your class section and view your timetable.',
            icon: Icons.school_rounded,
            isSelected: _selectedRole == 'Student',
            onTap: () => setState(() => _selectedRole = 'Student'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RoleCard(
            title: 'Faculty',
            description: 'Manage lectures, announcements, and schedules.',
            icon: Icons.admin_panel_settings_rounded,
            isSelected: _selectedRole == 'Faculty',
            onTap: () => setState(() => _selectedRole = 'Faculty'),
          ),
          const SizedBox(height: AppSpacing.x3l),
          AnimatedButton(
            onPressed: _selectedRole == null ? null : () => _saveDraftAndProceed(1),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupPage() {
    final isStudent = _selectedRole == 'Student';
    return _WizardPageContainer(
      title: 'Complete Profile',
      subtitle: 'Tell us a bit about yourself.',
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchedlyTextField(
              controller: _nameController,
              labelText: 'Full Name',
              prefixIcon: Icons.person,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isStudent)
              SchedlyTextField(
                controller: _rollNoController,
                labelText: 'Roll Number (e.g. A137)',
                prefixIcon: Icons.badge,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            if (!isStudent)
              SchedlyTextField(
                controller: _facultyIdController,
                labelText: 'Faculty ID (Optional)',
                prefixIcon: Icons.badge,
              ),
            const SizedBox(height: AppSpacing.lg),
            SchedlyTextField(
              controller: _departmentController,
              labelText: 'Department (Optional)',
              prefixIcon: Icons.business,
            ),
            const SizedBox(height: AppSpacing.x3l),
            AnimatedButton(
              onPressed: () {
                if (_profileFormKey.currentState!.validate()) {
                  _saveDraftAndProceed(2);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSectionPage() {
    return _WizardPageContainer(
      title: 'Join Section',
      subtitle: 'Select your academic year and division.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sections').where('active', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('No active sections available. Ask your CR to create one.');
          }

          final docs = snapshot.data!.docs;
          final activeYears = docs.map((d) => d['academicYear'] as String).toSet().toList()..sort();

          if (_selectedYear != null && !activeYears.contains(_selectedYear)) {
            _selectedYear = null;
            _selectedDivision = null;
          }

          List<String> activeDivisions = [];
          if (_selectedYear != null) {
            activeDivisions = docs.where((d) => d['academicYear'] == _selectedYear).map((d) => d['division'] as String).toSet().toList()..sort();
            if (_selectedDivision != null && !activeDivisions.contains(_selectedDivision)) _selectedDivision = null;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedYear,
                decoration: const InputDecoration(labelText: 'Academic Year', border: OutlineInputBorder()),
                items: activeYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (val) => setState(() { _selectedYear = val; _selectedDivision = null; }),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                value: _selectedDivision,
                decoration: const InputDecoration(labelText: 'Division', border: OutlineInputBorder()),
                items: activeDivisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _selectedDivision = val),
              ),
              const SizedBox(height: AppSpacing.x3l),
              AnimatedButton(
                onPressed: _loading ? null : _completeStudentOnboarding,
                isLoading: _loading,
                child: const Text('Complete Setup'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFacultyVerificationPage() {
    return _WizardPageContainer(
      title: 'Faculty Verification',
      subtitle: 'Enter the master password provided by administration to activate your faculty account.',
      child: Form(
        key: _verifyFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchedlyTextField(
              controller: _masterPasswordController,
              obscureText: true,
              labelText: 'Master Password',
              prefixIcon: Icons.lock,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.x3l),
            AnimatedButton(
              onPressed: _loading ? null : _completeFacultyOnboarding,
              isLoading: _loading,
              child: const Text('Verify & Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardPageContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _WizardPageContainer({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.x3l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: AppSpacing.x3l),
              SchedlyCard(
                variant: SchedlyCardVariant.elevated,
                padding: EdgeInsets.all(AppSpacing.x2l),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({required this.title, required this.description, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(AppSpacing.x2l),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
          border: Border.all(color: isSelected ? colorScheme.primary : Theme.of(context).dividerColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: isSelected ? colorScheme.primary : Colors.grey),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
