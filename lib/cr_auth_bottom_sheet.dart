import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:schedly/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/security_utils.dart';
import 'nmims_structure.dart';
import 'cr_setup_wizard.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'dart:ui';
import 'utils/responsive_utils.dart';
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
  String? _selectedBranch;
  String? _selectedDivision;
  String? _sectionId;
  
  bool _sectionExists = false;
  bool _isLoading = false;
  bool _checkingSection = false;
  
  List<DocumentSnapshot> _activeSections = [];
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }
  
  Future<void> _fetchSections() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('sections').where('active', isEqualTo: true).get();
      if (mounted) {
        setState(() {
          _activeSections = snap.docs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections: $e');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _checkSectionStatus() {
    if (_selectedYear == null || _selectedBranch == null || _selectedDivision == null) return;
    
    _sectionId = '${_selectedYear!.replaceAll(' ', '')}_${_selectedBranch!.replaceAll(' ', '')}_$_selectedDivision';
    
    setState(() {
      _sectionExists = _activeSections.any((doc) => doc.id == _sectionId);
    });
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
          final batch = FirebaseFirestore.instance.batch();
          
          final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          batch.set(userRef, {
            'role': 'CR',
            'division': _sectionId,
          }, SetOptions(merge: true));

          final actionRef = FirebaseFirestore.instance.collection('admin_actions').doc('${user.uid}_$_sectionId');
          batch.set(actionRef, {
            'masterHash': SecurityUtils.masterHash,
            'action': 'claimCR',
            'timestamp': FieldValue.serverTimestamp(),
          });

          final membershipRef = FirebaseFirestore.instance.collection('section_memberships').doc('${_sectionId}_${user.uid}');
          batch.set(membershipRef, {
            'userId': user.uid,
            'sectionId': _sectionId,
            'role': 'CR',
            'status': 'active',
            'joinedAt': FieldValue.serverTimestamp(),
          });

          await batch.commit();
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
          br: _selectedBranch!,
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
          MaterialPageRoute(builder: (_) => CRSetupWizard(initialYear: _selectedYear, initialBranch: _selectedBranch, initialDivision: _selectedDivision)),
        );
      }
    } catch (e) {
      debugPrint('CR_VERIFY ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Incorrect') ? 'Incorrect CR password' : 'Unable to contact server'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('CR_VERIFY ERROR: $e');
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
    final activeYears = _activeSections.map((d) => d['academicYear'] as String).toSet().toList()..sort();
    if (_selectedYear != null && !activeYears.contains(_selectedYear)) {
      _selectedYear = null;
      _selectedBranch = null;
      _selectedDivision = null;
    }

    List<String> activeBranches = [];
    if (_selectedYear != null) {
      activeBranches = _activeSections.where((d) => d['academicYear'] == _selectedYear).map((d) => d['branch'] as String).toSet().toList()..sort();
      if (_selectedBranch != null && !activeBranches.contains(_selectedBranch)) {
        _selectedBranch = null;
        _selectedDivision = null;
      }
    }

    List<String> activeDivisions = [];
    if (_selectedYear != null && _selectedBranch != null) {
      activeDivisions = _activeSections.where((d) => d['academicYear'] == _selectedYear && d['branch'] == _selectedBranch)
                            .map((d) => d['division'] as String).toSet().toList()..sort();
      if (_selectedDivision != null && !activeDivisions.contains(_selectedDivision)) {
        _selectedDivision = null;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: ResponsiveUtils.constrainedFormBox(
            context,
            maxWidth: 500,
            child: Container(
              margin: ResponsiveUtils.getBottomSheetMargin(context),
              padding: EdgeInsets.all(ResponsiveUtils.getCardPadding(context)),
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
                  items: activeYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedYear = val;
                      _selectedBranch = null;
                      _selectedDivision = null;
                      _sectionExists = false;
                      _passwordController.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedYear != null) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedBranch,
                    decoration: _compactDecoration('Branch', Icons.account_tree_rounded),
                    items: activeBranches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBranch = val;
                        _selectedDivision = null;
                        _sectionExists = false;
                        _passwordController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_selectedBranch != null) ...[
                  if (activeDivisions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No sections available.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedDivision,
                      decoration: _compactDecoration('Division', Icons.class_rounded),
                      items: activeDivisions.map((d) {
                        return DropdownMenuItem(value: d, child: Text('Division $d'));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDivision = val;
                          _passwordController.clear();
                        });
                        _checkSectionStatus();
                      },
                    ),
                  const SizedBox(height: 12),
                ],
                if (_checkingSection)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                else if (_selectedYear != null && _selectedBranch != null && _selectedDivision != null) ...[
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
      ),
    );
  }
}
