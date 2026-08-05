import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/theme.dart';
import '../widgets/schedly_text_field.dart';
import '../widgets/animations/animated_button.dart';

class FacultyManagementPage extends StatefulWidget {
  const FacultyManagementPage({super.key});

  @override
  State<FacultyManagementPage> createState() => _FacultyManagementPageState();
}

class _FacultyManagementPageState extends State<FacultyManagementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Faculty Management', style: TextStyle(fontFamily: 'Outfit')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SchedlyTextField(
              hintText: 'Search Faculty...',
              prefixIcon: Icons.search_rounded,
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('faculty_profiles').snapshots(),
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
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final legacyId = doc.id.toLowerCase();
                  return name.contains(_searchQuery) || legacyId.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No faculty profiles found.',
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
                    
                    return ListTile(
                      title: Text(data['name'] ?? 'Unknown Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ID: ${doc.id}'),
                      trailing: Icon(Icons.edit_rounded, color: semanticColors.accent),
                      onTap: () => _editFaculty(doc.id, data),
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

  void _editFaculty(String uid, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _EditFacultySheet(uid: uid, data: data),
    );
  }
}

class _EditFacultySheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;

  const _EditFacultySheet({required this.uid, required this.data});

  @override
  State<_EditFacultySheet> createState() => _EditFacultySheetState();
}

class _EditFacultySheetState extends State<_EditFacultySheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _divisionsCtrl;
  late TextEditingController _subjectsCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data['name'] ?? '');
    
    // Convert arrays to comma-separated strings for easy editing
    final divs = (widget.data['divisions'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? '';
    final subs = (widget.data['subjects'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? '';
    
    _divisionsCtrl = TextEditingController(text: divs);
    _subjectsCtrl = TextEditingController(text: subs);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _divisionsCtrl.dispose();
    _subjectsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final divisionsList = _divisionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final subjectsList = _subjectsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await FirebaseFirestore.instance.collection('faculty_profiles').doc(widget.uid).set({
        'name': _nameCtrl.text.trim(),
        'divisions': divisionsList,
        'subjects': subjectsList,
      }, SetOptions(merge: true));
      
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
        title: const Text('Delete Faculty?'),
        content: const Text('This will delete their Firestore document.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('faculty_profiles').doc(widget.uid).delete();
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
            Text('Edit Faculty Document', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: AppSpacing.md),
            
            SchedlyTextField(controller: _nameCtrl, labelText: 'Name'),
            const SizedBox(height: AppSpacing.sm),
            SchedlyTextField(controller: _divisionsCtrl, labelText: 'Divisions (comma separated)', hintText: '2023-24_B.Tech_A, 2023-24_B.Tech_B'),
            const SizedBox(height: AppSpacing.sm),
            SchedlyTextField(controller: _subjectsCtrl, labelText: 'Subjects (comma separated)'),
            
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
