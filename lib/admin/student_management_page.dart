import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/theme.dart';
import '../widgets/schedly_text_field.dart';
import '../widgets/animations/animated_button.dart';

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Student Management', style: TextStyle(fontFamily: 'Outfit')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SchedlyTextField(
              hintText: 'Search by Name or Roll No...',
              prefixIcon: Icons.search_rounded,
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').where('role', whereIn: ['Student', 'CR', 'SR']).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['draftProfile']?['name'] ?? '').toString().toLowerCase();
                  final rollNo = (data['draftProfile']?['rollNo'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || rollNo.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found.',
                      style: TextStyle(color: semanticColors.onSurfaceMuted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.only(bottom: AppSpacing.x4l),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final profile = data['draftProfile'] ?? {};
                    
                    return ListTile(
                      title: Text(profile['name'] ?? 'Unknown Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${profile['rollNo'] ?? 'No Roll No'} • Div: ${data['division'] ?? 'Unknown'} • Role: ${data['role']}'),
                      trailing: Icon(Icons.edit_rounded, color: semanticColors.accent),
                      onTap: () => _editStudent(doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _editStudent(String uid, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _EditStudentSheet(uid: uid, data: data),
    );
  }
}

class _EditStudentSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;

  const _EditStudentSheet({required this.uid, required this.data});

  @override
  State<_EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<_EditStudentSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _rollNoCtrl;
  late TextEditingController _divCtrl;
  late TextEditingController _roleCtrl;
  late bool _onboardingCompleted;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.data['draftProfile'] ?? {};
    _nameCtrl = TextEditingController(text: profile['name'] ?? '');
    _rollNoCtrl = TextEditingController(text: profile['rollNo'] ?? '');
    _divCtrl = TextEditingController(text: widget.data['division'] ?? '');
    _roleCtrl = TextEditingController(text: widget.data['role'] ?? 'Student');
    _onboardingCompleted = widget.data['onboardingCompleted'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollNoCtrl.dispose();
    _divCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'role': _roleCtrl.text.trim(),
        'division': _divCtrl.text.trim(),
        'onboardingCompleted': _onboardingCompleted,
        'draftProfile.name': _nameCtrl.text.trim(),
        'draftProfile.rollNo': _rollNoCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Student?'),
        content: const Text('This will delete their Firestore document. They will have to onboard again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit User Document', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: AppSpacing.md),
            
            SchedlyTextField(controller: _nameCtrl, labelText: 'Name'),
            const SizedBox(height: AppSpacing.sm),
            SchedlyTextField(controller: _rollNoCtrl, labelText: 'Roll No'),
            const SizedBox(height: AppSpacing.sm),
            SchedlyTextField(controller: _divCtrl, labelText: 'Division ID (e.g. 2023-24_B.Tech_A)'),
            const SizedBox(height: AppSpacing.sm),
            SchedlyTextField(controller: _roleCtrl, labelText: 'Role (Student, CR, SR)'),
            const SizedBox(height: AppSpacing.sm),
            
            SwitchListTile(
              title: const Text('Onboarding Completed'),
              value: _onboardingCompleted,
              onChanged: (v) => setState(() => _onboardingCompleted = v),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            
            const SizedBox(height: AppSpacing.xl),
            AnimatedButton(
              onPressed: _loading ? null : _save,
              isLoading: _loading,
              child: const Text('Save Changes'),
            ),
            TextButton(
              onPressed: _loading ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Document'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
