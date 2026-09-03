import 'package:cloud_firestore/cloud_firestore.dart';

class FacultySrConnectionService {
  /// Fetches the assigned SR identities for a given division and subject.
  static Future<List<String>> getAssignedSRs({
    required String division,
    required String subject,
  }) async {
    try {
      final assignmentId = subject.toLowerCase().replaceAll(' ', '_');
      final doc = await FirebaseFirestore.instance
          .collection('sections')
          .doc(division)
          .collection('sr_assignments')
          .doc(assignmentId)
          .get();

      if (doc.exists && doc.data()?['srs'] is List) {
        return List<String>.from(doc.data()!['srs']);
      }
    } catch (_) {}
    return [];
  }

  /// Fetches the faculty assigned to teach a subject in a division.
  static Future<List<Map<String, dynamic>>> getAssignedFaculty({
    required String division,
    required String subject,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('faculty_profiles')
          .where('assignedDivisions', arrayContains: division)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final subjectsMap = (data['subjects'] as Map<String, dynamic>?) ?? {};
        final divSubjects = List<String>.from(subjectsMap[division] ?? []);
        final match = divSubjects.any(
          (s) =>
              s.toLowerCase() == subject.toLowerCase() ||
              s.toLowerCase().contains(subject.toLowerCase()) ||
              subject.toLowerCase().contains(s.toLowerCase()),
        );
        if (match) {
          results.add({'id': doc.id, ...data});
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
