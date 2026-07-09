import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme.dart';

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
              final name = data['name'] ?? 'Unknown Faculty';
              final designation = data['designation'] ?? 'Designation';
              final department = data['department'] ?? 'Department';
              final email = data['email'] ?? '';
              final subjectsMap = data['subjects'] as Map<String, dynamic>? ?? {};
              final divisionSubjects = List<String>.from(subjectsMap[division] ?? []);

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
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
                            Text('Subjects Taught in Div $division:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
