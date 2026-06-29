import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:schedly/firebase_options.dart';
import 'package:schedly/services/pdf_timetable_import_service.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('Test PDF Import splitting', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Check what is currently in Firestore
    final snapshot = await FirebaseFirestore.instance.collection('timetables').get();
    print('Divisions: ${snapshot.docs.map((d) => d.id)}');
    
    if (snapshot.docs.isNotEmpty) {
      final div = snapshot.docs.first.id;
      final mon = await FirebaseFirestore.instance.collection('timetables').doc(div).collection('Monday').get();
      print('Monday entries for $div:');
      for (var doc in mon.docs) {
        print('${doc.id}: ${doc.data()}');
      }
    }
  });
}
