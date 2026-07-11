import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/local_notification_service.dart';


import 'package:flutter/foundation.dart';

import 'home_page.dart';
import 'splash_screen.dart';
import 'app_settings.dart';
import 'services/migration_service.dart';
import 'login_page.dart';
import 'theme/theme.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'faculty/faculty_home_page.dart';
import 'user_roles.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Since Android displays notification payloads automatically, we only need to handle data-only
  // messages if we want to show a custom local notification. If it's a notification payload, 
  // the OS handles it in the background!
  
  // Wait, our backend sends both data and notification payloads so Android OS will automatically 
  // display the banner in the background. We don't strictly need to call LocalNotificationService.show() here
  // unless we want to override the default behavior or if it's data-only.
}


late final ThemeController themeController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
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
  } else {
    await Firebase.initializeApp();
  }

  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !kIsWeb, // Disabled on Web to prevent BloomFilter crashes
    cacheSizeBytes: 104857600, // 100 MB
  );

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Auth error: $e');
    }
  }

  await AppSettings.loadRole();
  await AppSettings.loadSRDetails();
  await AppSettings.loadStudentDetails();
  await AppSettings.loadFacultyDetails();
  
  await MigrationService.migrateFacultyIds();

  // Fire and forget to prevent blocking the UI thread (fixes black screen bug)
  NotificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await LocalNotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  
  themeController = ThemeController(prefs);

  // Trigger the proof
  _proveMismatch();

  runApp(const SchedlyApp());
}

Future<void> _proveMismatch() async {
  try {
    debugPrint('--- PROVING MISMATCH ---');
    
    // 1. AppSettings.facultyId
    debugPrint('1. AppSettings.facultyId: \${AppSettings.facultyId}');
    
    // 2. faculty_profiles document ID
    final profiles = await FirebaseFirestore.instance.collection('faculty_profiles').get();
    for (final doc in profiles.docs) {
      final data = doc.data();
      debugPrint('2. faculty_profiles ID: ${doc.id} (Name: ${data['name']})');
    }
    
    // 3. facultyId stored inside the timetable document
    final timetables = await FirebaseFirestore.instance.collectionGroup('Monday').get();
    for (final doc in timetables.docs) {
      final data = doc.data();
      if (data.containsKey('facultyId')) {
        debugPrint('3. Timetable Entry (${doc.id}) -> facultyId: ${data['facultyId']}');
      }
    }
    
    // 4. division written into notification_outbox
    final outbox = await FirebaseFirestore.instance.collection('notification_outbox').orderBy('createdAt', descending: true).limit(5).get();
    for (final doc in outbox.docs) {
      final data = doc.data();
      if (data['role'] == 'faculty' || data['type'] == 'faculty_reminder') {
        debugPrint('4. Outbox (${doc.id}) -> division: ${data['division']}, type: ${data['type']}');
      }
    }
    
    // 5. topic subscribed by TopicSubscriptionService (fcm_tokens)
    final tokens = await FirebaseFirestore.instance.collectionGroup('fcm_tokens').get();
    for (final doc in tokens.docs) {
      final data = doc.data();
      if (data['role'] == 'faculty') {
        debugPrint('5. fcm_tokens (${doc.id}) -> division (Topic): ${data['division']}');
      }
    }
    
    // 6. Firestore users/{uid}.role
    final users = await FirebaseFirestore.instance.collection('users').get();
    for (final doc in users.docs) {
      final data = doc.data();
      final role = data['role'];
      if (role == 'faculty' || role == 'FACULTY') {
        debugPrint('6. users (${doc.id}) -> role: $role');
      }
    }
    
    debugPrint('--- END OF PROOF ---');
  } catch (e) {
    debugPrint('Proof error: \$e');
  }
}

class SchedlyApp extends StatelessWidget {
  const SchedlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Schedly',
          debugShowCheckedModeBanner: false,
          themeMode: themeController.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(),
        );
      }
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() =>
      _StartupRouterState();
}

class _StartupRouterState
    extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    _checkDivision();
  }

  Future<void> _checkDivision() async {
  final prefs =
      await SharedPreferences.getInstance();

  final hasLoggedIn = prefs.getBool('has_logged_in') ?? false;
  final legacyDivision = prefs.getString('selected_division');
  
  if (!mounted) return;

  if (AppSettings.currentRole == UserRole.faculty) {
    if (!hasLoggedIn || AppSettings.facultyName == null) {
      await prefs.remove('has_logged_in');
      await AppSettings.resetRole();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FacultyHomePage()));
    }
    return;
  }

  // Migration Check: If legacy division exists but no sectionId, force re-login
  if (legacyDivision != null && AppSettings.sectionId == null) {
    await prefs.remove('has_logged_in');
    await prefs.remove('selected_division');
    await AppSettings.resetRole();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return;
  }

  if (!hasLoggedIn || AppSettings.sectionId == null) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          division: AppSettings.sectionId!,
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(),
      ),
    );
  }
}
