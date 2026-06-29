import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nmims_structure.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'home_page.dart';
import 'models/section_config.dart';
import 'models/period_config.dart';
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
  int _currentStep = 0;
  bool _loading = false;

  // Step 1: Section Details
  final _sectionFormKey = GlobalKey<FormState>();
  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedDivision;
  final _crPasswordController = TextEditingController();
  final _srPasswordController = TextEditingController();

  // Step 2: Schedule Foundation
  final List<String> _availableDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  List<String> _workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  
  final _batchController = TextEditingController();
  List<String> _batches = ['Whole Class', 'Batch 1', 'Batch 2'];

  // Step 3: Master Timetable (Periods)
  List<PeriodConfig> _periods = [];

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
    _batchController.dispose();
    super.dispose();
  }

  void _loadTemplate(String template) {
    setState(() {
      if (template == 'NMIMS') {
        _workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        _periods = [
          PeriodConfig(id: 'p1', name: 'Period 1', startTime: 555, endTime: 615), // 9:15 - 10:15
          PeriodConfig(id: 'p2', name: 'Period 2', startTime: 615, endTime: 675), // 10:15 - 11:15
          PeriodConfig(id: 'b1', name: 'Break', startTime: 675, endTime: 690, isBreak: true), // 11:15 - 11:30
          PeriodConfig(id: 'p3', name: 'Period 3', startTime: 690, endTime: 750), // 11:30 - 12:30
          PeriodConfig(id: 'p4', name: 'Period 4', startTime: 750, endTime: 810), // 12:30 - 13:30
          PeriodConfig(id: 'p5', name: 'Period 5', startTime: 810, endTime: 870), // 13:30 - 14:30
          PeriodConfig(id: 'p6', name: 'Period 6', startTime: 870, endTime: 930), // 14:30 - 15:30
        ];
      } else {
        _periods = [];
      }
    });
  }

  Future<void> _completeSetup() async {
    if (_selectedYear == null || _selectedBranch == null || _selectedDivision == null) return;
    
    setState(() => _loading = true);

    try {
      final sectionId = '${_selectedYear!.replaceAll(' ', '')}_${_selectedBranch!.replaceAll(' ', '')}_$_selectedDivision';
      final db = FirebaseFirestore.instance;
      
      final config = SectionConfig(
        id: sectionId,
        academicYear: _selectedYear!,
        branch: _selectedBranch!,
        division: _selectedDivision!,
        workingDays: _workingDays,
        batches: _batches,
        periods: _periods,
        active: true,
      );

      // Save to sections collection
      await db.collection('sections').doc(sectionId).set({
        ...config.toJson(),
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
        const SnackBar(content: Text('Semester Setup Complete!')),
      );
      
      // Navigate straight to home (Import Center will be accessible from CR Panel)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(division: _selectedDivision!)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStep1() {
    List<String> validDivisions = [];
    if (_selectedBranch != null) {
      validDivisions = NMIMSStructure.getDivisionsForBranch(_selectedBranch!);
      if (!validDivisions.contains(_selectedDivision)) _selectedDivision = null;
    }
    
    return Form(
      key: _sectionFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(labelText: 'Academic Year', border: OutlineInputBorder()),
            items: NMIMSStructure.academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
            onChanged: (val) => setState(() => _selectedYear = val),
            validator: (val) => val == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedBranch,
            decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
            items: NMIMSStructure.branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (val) => setState(() {
              _selectedBranch = val;
              _selectedDivision = null;
            }),
            validator: (val) => val == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedDivision,
            decoration: const InputDecoration(labelText: 'Division', border: OutlineInputBorder()),
            items: validDivisions.map((d) => DropdownMenuItem(value: d, child: Text('Division $d'))).toList(),
            onChanged: _selectedBranch == null ? null : (val) => setState(() => _selectedDivision = val),
            validator: (val) => val == null ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _crPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'CR Password', border: OutlineInputBorder()),
            validator: (val) => (val == null || val.length < 4) ? 'Minimum 4 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _srPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'SR Password', border: OutlineInputBorder()),
            validator: (val) => (val == null || val.length < 4) ? 'Minimum 4 characters' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Working Days', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableDays.map((day) {
            final isSelected = _workingDays.contains(day);
            return FilterChip(
              label: Text(day.substring(0, 3)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _workingDays.add(day);
                  } else {
                    _workingDays.remove(day);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('Class Batches', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _batches.map((b) {
            return Chip(
              label: Text(b),
              onDeleted: b == 'Whole Class' ? null : () {
                setState(() => _batches.remove(b));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _batchController,
                decoration: const InputDecoration(
                  hintText: 'Add batch (e.g., D1, Lab A)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty && !_batches.contains(val.trim())) {
                    setState(() {
                      _batches.add(val.trim());
                      _batchController.clear();
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () {
                if (_batchController.text.trim().isNotEmpty && !_batches.contains(_batchController.text.trim())) {
                  setState(() {
                    _batches.add(_batchController.text.trim());
                    _batchController.clear();
                  });
                }
              },
            )
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Master Timetable', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('NMIMS Template'),
              onPressed: () => _loadTemplate('NMIMS'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_periods.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No periods defined. Load a template or add them manually.', textAlign: TextAlign.center),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _periods.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = _periods.removeAt(oldIndex);
                _periods.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final p = _periods[index];
              final startH = (p.startTime ~/ 60).toString().padLeft(2, '0');
              final startM = (p.startTime % 60).toString().padLeft(2, '0');
              final endH = (p.endTime ~/ 60).toString().padLeft(2, '0');
              final endM = (p.endTime % 60).toString().padLeft(2, '0');
              
              return ListTile(
                key: ValueKey(p.id),
                leading: Icon(p.isBreak ? Icons.coffee_rounded : Icons.schedule_rounded),
                title: Text(p.name, style: TextStyle(fontWeight: p.isBreak ? FontWeight.w400 : FontWeight.bold)),
                subtitle: Text('$startH:$startM - $endH:$endM'),
                trailing: const Icon(Icons.drag_handle_rounded),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Semester Setup')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (_sectionFormKey.currentState?.validate() ?? false) {
              setState(() => _currentStep += 1);
            }
          } else if (_currentStep == 1) {
            if (_workingDays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one working day')));
              return;
            }
            setState(() => _currentStep += 1);
          } else if (_currentStep == 2) {
            _completeSetup();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep -= 1);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedButton(
                    onPressed: _loading ? null : details.onStepContinue,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: _loading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_currentStep == 2 ? 'Complete Setup' : 'Continue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_currentStep > 0) const SizedBox(width: 12),
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Section & Security'),
            content: _buildStep1(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Working Days & Batches'),
            content: _buildStep2(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Lecture Timing Builder'),
            content: _buildStep3(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }
}
