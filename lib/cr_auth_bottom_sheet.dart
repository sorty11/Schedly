import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:schedly/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'nmims_structure.dart';
import 'cr_setup_wizard.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'dart:ui';
import 'home_page.dart';

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
  String? _selectedYear;
  String? _selectedDivision;
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
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
      if (_branch == null) return;
      
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

  Future<void> _authenticate() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a password'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('CR_VERIFY: Button pressed');
      
      if (_sectionExists) {
        debugPrint('CR_VERIFY: Attempting local verification...');
        final docSnap = await FirebaseFirestore.instance.collection('sections').doc(_sectionId).get();
        final savedPassword = docSnap.data()?['crPassword'];
        if (pwd != savedPassword) {
          throw Exception('Incorrect password');
        }
        
        debugPrint('CR_VERIFY: Password verified locally. Updating Firestore role...');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'role': 'CR',
            'division': _sectionId,
          }, SetOptions(merge: true));
        }
        
        debugPrint('CR_VERIFY: Role updated successfully.');
        
        if (!mounted) return;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_logged_in', true);
        await prefs.setString('selected_division', _sectionId!); 
        
        // DO NOT AWAIT notification setup
        debugPrint('CR_VERIFY: Starting FCM subscription asynchronously');
        NotificationService.updateDivisionSubscription(_sectionId!).catchError((e) {
          debugPrint('CR_VERIFY: Notification error (ignored): $e');
        });
        
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
        
        debugPrint('CR_VERIFY: Role updated locally');
        
        if (!mounted) return;
        debugPrint('CR_VERIFY: Navigation');
        
        // Close immediately on success!
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomePage(division: _sectionId!)),
          (_) => false,
        );
      } else {
        if (pwd != 'schedly11') {
          throw Exception('Incorrect Master Password');
        }
        if (!mounted) return;
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CRSetupWizard(initialYear: _selectedYear, initialBranch: _branch, initialDivision: _selectedDivision)),
        );
      }
    } on FirebaseFunctionsException catch (e, s) {
      debugPrint('CR_VERIFY ERROR: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.code == 'not-found' || e.code == 'unauthenticated' || e.message?.contains('Incorrect') == true ? 'Incorrect CR password' : 'Unable to contact server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, s) {
      debugPrint('CR_VERIFY ERROR: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Incorrect') ? 'Incorrect CR password' : 'Unable to contact server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      debugPrint('CR_VERIFY: Loading reset');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _compactDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: const TextStyle(fontSize: 14),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CR Verification',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Authenticate to manage your section',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedYear,
                  decoration: _compactDecoration('Academic Year', Icons.school_rounded),
                  items: NMIMSStructure.academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedYear = val;
                      _selectedDivision = null;
                      _sectionExists = false;
                      _passwordController.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedDivision,
                  decoration: _compactDecoration('Division', Icons.class_rounded),
                  items: allDivisions.map((d) {
                    final br = NMIMSStructure.getBranchForDivision(d) ?? '';
                    return DropdownMenuItem(value: d, child: Text('Division $d ($br)'));
                  }).toList(),
                  onChanged: _selectedYear == null ? null : (val) {
                    setState(() {
                      _selectedDivision = val;
                      _passwordController.clear();
                    });
                    _checkSectionStatus();
                  },
                ),
                const SizedBox(height: 12),
                if (_checkingSection)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                else if (_selectedYear != null && _selectedDivision != null) ...[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _compactDecoration(
                      _sectionExists ? 'CR Password' : 'Master Password', 
                      Icons.lock_rounded
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _authenticate,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_sectionExists ? 'Verify & Continue' : 'Start Setup', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
