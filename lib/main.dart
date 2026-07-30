import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/local_notification_service.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'home_page.dart';
import 'onboarding_flow.dart';
import 'app_settings.dart';
import 'services/migration_service.dart';
import 'theme/theme.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'faculty/faculty_home_page.dart';
import 'user_roles.dart';
import 'email_verification_page.dart';
import 'account_migration_page.dart';
import 'onboarding_wizard_page.dart';

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
final Stopwatch appStartupTimer = Stopwatch();

Future<void> main() async {
  appStartupTimer.start();
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !kIsWeb, // Disabled on Web to prevent BloomFilter crashes
    cacheSizeBytes: 104857600, // 100 MB
  );

  // We no longer automatically sign in anonymously.
  // The user must go through the LoginPage.

  final prefs = await SharedPreferences.getInstance();
  themeController = ThemeController(prefs);
  
  // Run these concurrently to speed up initialization
  await Future.wait([
    AppSettings.loadRole(),
    AppSettings.loadSRDetails(),
    AppSettings.loadStudentDetails(),
    AppSettings.loadFacultyDetails(),
    MigrationService.migrateFacultyIds(),
  ]);

  // Fire and forget non-critical initializations
  NotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  LocalNotificationService.initialize();
  
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
          home: const StartupRouter(),
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingFlow()));
      return;
    }

    if (user.isAnonymous) {
      final legacyDivision = prefs.getString('selected_division');
      if (AppSettings.sectionId != null || AppSettings.facultyName != null || legacyDivision != null) {
        // Needs migration
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AccountMigrationPage()));
      } else {
        // Empty anonymous user
        await user.delete();
        await prefs.remove('has_logged_in');
        await AppSettings.resetRole();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingFlow()));
      }
      return;
    }

    // Force reload to get the latest emailVerified status
    await user.reload();
    final updatedUser = FirebaseAuth.instance.currentUser;

    if (updatedUser != null && !updatedUser.emailVerified) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmailVerificationPage()));
      return;
    }

    if (AppSettings.studentName != null || AppSettings.facultyName != null) {
      // Fast path: use cached session
      final userType = AppSettings.facultyName != null ? 'Faculty' : 'Student';
      
      if (userType == 'Faculty') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FacultyHomePage()));
      } else {
        final div = AppSettings.sectionId ?? '';
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(division: div)));
      }
      
      // Update missing session info in the background without blocking navigation
      _syncSessionInBackground(updatedUser);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(updatedUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data['onboardingCompleted'] == true) {
          final userType = data['userType'];
          if (userType == 'Faculty') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FacultyHomePage()));
          } else {
            // Student
            final div = AppSettings.sectionId ?? data['division'] ?? '';
            
            // Re-populate AppSettings from Firestore on re-login
            if (AppSettings.studentName == null) {
              await AppSettings.saveStudentDetails(
                name: data['name'] ?? 'Student',
                rollNo: data['rollNo'] ?? 'Unknown',
                acYear: '', // Handled elsewhere or not needed for core function
                br: '',
                div: '',
                secId: div,
              );
              
              final roleStr = data['role'] as String?;
              if (roleStr == 'CR') {
                await AppSettings.saveRole(UserRole.cr);
              } else if (roleStr == 'SR') {
                await AppSettings.saveRole(UserRole.sr);
              } else {
                await AppSettings.saveRole(UserRole.student);
              }
            }
            
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(division: div)));
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading user document in StartupRouter: $e');
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingWizardPage()));
  }

  Future<void> _syncSessionInBackground(User? user) async {
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data['userType'] != 'Faculty') {
           final roleStr = data['role'] as String?;
           if (roleStr == 'CR') {
             await AppSettings.saveRole(UserRole.cr);
           } else if (roleStr == 'SR') {
             await AppSettings.saveRole(UserRole.sr);
           } else {
             await AppSettings.saveRole(UserRole.student);
           }
        }
      }
    } catch (e) {
      debugPrint('Error in background sync: $e');
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
