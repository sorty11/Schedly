import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class StudentRosterPage extends StatelessWidget {
  final String division;

  const StudentRosterPage({super.key, required this.division});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Roster'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sections')
            .doc(division)
            .collection('students')
            .orderBy('rollNo')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No students registered yet.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final students = snapshot.data!.docs;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  'Total Students: ${students.length}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = students[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown Name';
                    final rollNo = data['rollNo'] ?? 'No Roll No';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          rollNo.isNotEmpty ? rollNo[0].toUpperCase() : '?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      subtitle: Text('Roll No: $rollNo'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
