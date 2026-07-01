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
import 'login_page.dart';
import 'theme/theme.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
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

  await NotificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await LocalNotificationService.initialize();

  await AppSettings.loadRole();
  await AppSettings.loadSRDetails();
  await AppSettings.loadStudentDetails();

  final prefs = await SharedPreferences.getInstance();
  themeController = ThemeController(prefs);

  runApp(const SchedlyApp());
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
