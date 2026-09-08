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

    // outbox check
  }, skip: 'Manual proof script requiring live Firebase connection');
}
