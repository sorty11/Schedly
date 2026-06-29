import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:schedly/firebase_options.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('Fetch firestore data', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final snapshot = await FirebaseFirestore.instance.collection('timetables').get();
      print('DIVISIONS: ${snapshot.docs.map((e) => e.id).toList()}');
      
      if (snapshot.docs.isNotEmpty) {
        final div = snapshot.docs.first.id;
        final mon = await FirebaseFirestore.instance.collection('timetables').doc(div).collection('Monday').get();
        for (var doc in mon.docs) {
          print('DOC ID: ${doc.id}');
          print('DOC DATA: ${doc.data()}');
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }
  });
}
