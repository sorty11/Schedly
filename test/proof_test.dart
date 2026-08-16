import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:schedly/firebase_options.dart';

void main() {
  test('Fetch Mismatch Proof', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCvHene63scD_yzJiR0HHWHBKTad-n-sSI',
        appId: '1:1044389536762:web:8b8c7ec25645328411ba43',
        messagingSenderId: '1044389536762',
        projectId: 'schedly-production',
        authDomain: 'schedly-production.firebaseapp.com',
        storageBucket: 'schedly-production.firebasestorage.app',
        measurementId: 'G-RKCNHWHVX9',
      ),
    );

    print('--- PROVING FACULTY REMINDER ROLE MISMATCH ---');

    // 4. outbox
    final oRes = await FirebaseFirestore.instance
        .collection('notification_outbox')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    for (final doc in oRes.docs) {
      final data = doc.data();
      final type = data['type'];
      final role = data['role'];
      if (role == 'faculty' ||
          type == 'faculty_reminder' ||
          type == 'lecture_added' ||
          type == 'add' ||
          type == 'edit') {
        print(
          '4. Outbox (${doc.id}) -> division: ${data['division']}, role: ${data['role']}, uid: ${data['uid']}, title: ${data['title']}, processed: ${data['processed']}',
        );
      }
    }
  });
}
