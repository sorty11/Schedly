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
}