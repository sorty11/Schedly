import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  static Future<void> addLecture({
    required String division,
    required String day,
    required String subject,
    required String time,
    required String room,
  }) async {
    final existing =
        await db
            .collection('timetables')
            .doc(division)
            .collection(day)
            .where(
              'time',
              isEqualTo: time,
            )
            .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'This time slot is already occupied.',
      );
    }

    await db
        .collection('timetables')
        .doc(division)
        .collection(day)
        .add({
      'subject': subject,
      'time': time,
      'room': room,
      'cancelled': false,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }

  static Future<List<String>>
      getSubjects(
    String division,
  ) async {
    try {
      final doc =
          await db
              .collection('sections')
              .doc(division)
              .get();

      if (!doc.exists) {
        return [];
      }

      final data = doc.data();

      if (data == null ||
          data['subjects'] == null) {
        return [];
      }

      return List<String>.from(
        data['subjects'],
      );
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveSubjects({
    required String division,
    required List<String> subjects,
  }) async {
    await db
        .collection('sections')
        .doc(division)
        .set(
      {
        'subjects': subjects,
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}
