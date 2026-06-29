import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nmims_structure.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'upload_timetable_pdf_page.dart';

import 'widgets/animations/animated_button.dart';

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
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedDivision;
  
  final _crPasswordController = TextEditingController();
  final _srPasswordController = TextEditingController();

  bool _loading = false;
  
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

  Future<void> _createSection() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedYear == null || _selectedBranch == null || _selectedDivision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select year, branch, and division')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final sectionId = '${_selectedYear!.replaceAll(' ', '')}_${_selectedBranch!.replaceAll(' ', '')}_$_selectedDivision';
      
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('sections').doc(sectionId);
      
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        throw Exception('This academic section already exists.');
      }
      
      await docRef.set({
        'academicYear': _selectedYear,
        'branch': _selectedBranch,
        'division': _selectedDivision,
        'active': true,
        'crPassword': _crPasswordController.text,
        'srPassword': _srPasswordController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Save locally
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section created successfully!')),
      );
      
      // Route to PDF upload page directly
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const UploadTimetablePdfPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> validDivisions = [];
    if (_selectedBranch != null) {
      validDivisions = NMIMSStructure.getDivisionsForBranch(_selectedBranch!);
      if (!validDivisions.contains(_selectedDivision)) {
        _selectedDivision = null; // reset if invalid for new branch
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('CR Setup Wizard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create New Academic Section',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up a new section for your class. This will initialize the timetable, announcements, and conduct tracking.',
              ),
              const SizedBox(height: 24),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  border: OutlineInputBorder(),
                ),
                items: NMIMSStructure.academicYears
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedYear = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedBranch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  border: OutlineInputBorder(),
                ),
                items: NMIMSStructure.branches
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedBranch = val;
                  _selectedDivision = null;
                }),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedDivision,
                decoration: const InputDecoration(
                  labelText: 'Division',
                  border: OutlineInputBorder(),
                ),
                items: validDivisions
                    .map((d) => DropdownMenuItem(value: d, child: Text('Division $d')))
                    .toList(),
                onChanged: _selectedBranch == null ? null : (val) => setState(() => _selectedDivision = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _crPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Set CR Password',
                  border: OutlineInputBorder(),
                  helperText: 'You will use this to access the CR Panel.',
                ),
                validator: (val) => (val == null || val.length < 4) ? 'Must be at least 4 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _srPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Set SR Password',
                  border: OutlineInputBorder(),
                  helperText: 'Subject Representatives will use this to verify lectures.',
                ),
                validator: (val) => (val == null || val.length < 4) ? 'Must be at least 4 characters' : null,
              ),
              const SizedBox(height: 32),
              
              AnimatedButton(
                onPressed: _loading ? null : _createSection,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Section & Upload Timetable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
