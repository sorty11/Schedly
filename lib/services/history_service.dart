import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryService {
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static Future<void> logOperation({
    required String division,
    required String operation,
    required String details,
    required String role,
  }) async {
    await db.collection('sections').doc(division).collection('history').add({
      'operation': operation,
      'details': details,
      'role': role,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
