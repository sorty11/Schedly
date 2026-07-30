import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import '../widgets/app_dialogs.dart';
import 'package:cloud_functions/cloud_functions.dart';
class CRFacultyViewPage extends StatelessWidget {
  final String division;

  const CRFacultyViewPage({super.key, required this.division});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Roster', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('faculty_profiles')
            .where('assignedDivisions', arrayContains: division)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 64, color: colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('No Faculty Assigned', style: TextStyle(color: sem.onSurfaceMuted, fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('No faculty members have set up their profiles for Div $division.', style: TextStyle(color: sem.onSurfaceMuted), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _FacultyCard(
                data: data,
                division: division,
                facultyId: docs[index].id,
              );
            },
          );
        },
      ),
    );
  }
}

class _FacultyCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String division;
  final String facultyId;

  const _FacultyCard({
    required this.data,
    required this.division,
    required this.facultyId,
  });

  @override
  State<_FacultyCard> createState() => _FacultyCardState();
}

class _FacultyCardState extends State<_FacultyCard> {
  bool _isLoading = false;

  Future<void> _removeFaculty() async {
    final name = widget.data['name'] ?? 'Unknown Faculty';
    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: 'Remove Faculty',
      message: 'Are you sure you want to remove $name from this section?\n\nThis will only remove their assignment from this class. Their faculty account will remain active.',
      confirmText: 'Remove',
      isDestructive: true,
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFunctions.instance.httpsCallable('removeFaculty').call({
        'targetUid': widget.facultyId,
        'sectionId': widget.division,
      });

      if (mounted) {
        AppDialogs.showSnackBar(
          context: context,
          message: 'Faculty removed successfully.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        AppDialogs.showError(
          context: context,
          title: 'Remove Failed',
          message: e.message ?? 'An unknown error occurred.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(
          context: context,
          title: 'Remove Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    
    final name = widget.data['name'] ?? 'Unknown Faculty';
    final designation = widget.data['designation'] ?? 'Designation';
    final department = widget.data['department'] ?? 'Department';
    final email = widget.data['email'] ?? '';
    final subjectsMap = widget.data['subjects'] as Map<String, dynamic>? ?? {};
    final divisionSubjects = List<String>.from(subjectsMap[widget.division] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'F',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('$designation, $department', style: TextStyle(color: sem.onSurfaceMuted, fontSize: 13)),
                      if (email.isNotEmpty)
                        Text(email, style: TextStyle(color: sem.onSurfaceMuted, fontSize: 12)),
                      
                      const SizedBox(height: AppSpacing.md),
                      Text('Subjects Taught in Div ${widget.division}:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: divisionSubjects.isEmpty 
                            ? [Text('None', style: TextStyle(color: sem.onSurfaceMuted, fontStyle: FontStyle.italic, fontSize: 12))]
                            : divisionSubjects.map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
                                ),
                                child: Text(s, style: TextStyle(fontSize: 11, color: colorScheme.secondary, fontWeight: FontWeight.w600)),
                              )).toList(),
                      )
                    ],
                  ),
                ),
              ],
            ),
            if (AppSettings.currentRole == UserRole.cr) ...[
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading
                    ? const SizedBox(
                        height: 36,
                        width: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _removeFaculty,
                        icon: const Icon(Icons.person_remove_rounded, size: 16),
                        label: const Text('Remove Faculty'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: sem.error,
                          side: BorderSide(color: sem.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
