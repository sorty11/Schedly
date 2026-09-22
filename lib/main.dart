import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/local_notification_service.dart';
import 'services/ad_service.dart';

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
import 'widgets/animations/skeleton_components.dart';
import 'services/deep_link_router.dart';
import 'nmims_structure.dart';

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
    persistenceEnabled:
        !kIsWeb, // Disabled on Web to prevent BloomFilter crashes
    cacheSizeBytes: 104857600, // 100 MB
  );

  // We no longer automatically sign in anonymously.
  // The user must go through the LoginPage.

  final prefs = await SharedPreferences.getInstance();
  themeController = ThemeController(prefs);

  // Synchronous, zero-await initialization from memory/prefs
  AppSettings.loadFromPrefs(prefs);

  // Render UI as early as safely possible
  runApp(const SchedlyApp());

  // Non-critical background services & migrations initialized asynchronously without blocking startup
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Background migration if needed
    MigrationService.migrateFacultyIds();

    // Background AdMob initialization
    AdService.initialize();

    // Background notification services
    NotificationService.initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    LocalNotificationService.initialize();
  });
}

class SchedlyApp extends StatelessWidget {
  const SchedlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isCustomTheme =
            themeController.visualTheme != SchedlyVisualTheme.defaultTheme;

        return MaterialApp(
          navigatorKey: DeepLinkRouter.navigatorKey,
          title: 'Schedly',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SchedlyScrollBehavior(),
          themeMode: themeController.themeMode,
          theme: AppTheme.buildTheme(
            isDark: false,
            visualTheme: themeController.visualTheme,
            transparentScaffold: isCustomTheme,
          ),
          darkTheme: AppTheme.buildTheme(
            isDark: true,
            visualTheme: themeController.visualTheme,
            transparentScaffold: isCustomTheme,
          ),
          builder: (context, child) {
            // Pass-through: no global width constraint.
            // Each screen is responsible for its own responsive layout.
            return AnimatedTheme(
              data: Theme.of(context),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedThemeBackground(
                theme: themeController.visualTheme,
                child: child!,
              ),
            );
          },
          home: const StartupRouter(),
        );
      },
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      );
      return;
    }

    if (user.isAnonymous) {
      final legacyDivision = prefs.getString('selected_division');
      if (AppSettings.sectionId != null ||
          AppSettings.facultyName != null ||
          legacyDivision != null) {
        // Needs migration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AccountMigrationPage()),
        );
      } else {
        // Empty anonymous user
        await user.delete();
        await prefs.remove('has_logged_in');
        await AppSettings.resetRole();
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingFlow()),
          );
      }
      return;
    }

    // Fast path: if user is verified and has cached session, navigate immediately
    // without blocking the first frame on network user.reload()
    if (user.emailVerified &&
        (AppSettings.studentName != null || AppSettings.facultyName != null)) {
      final role = AppSettings.facultyName != null ? 'Faculty' : 'Student';

      if (role == 'Faculty') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FacultyHomePage()),
        );
      } else {
        final div = AppSettings.sectionId ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(division: div)),
        );
      }

      // Sync session in the background without blocking first usable frame
      _syncSessionInBackground(user);
      return;
    }

    // Only reload over network if not emailVerified to check if user verified in browser
    if (!user.emailVerified) {
      try {
        await user.reload();
      } catch (e) {
        debugPrint('Failed to reload user, proceeding with cached session: $e');
      }
    }
    final updatedUser = FirebaseAuth.instance.currentUser;

    if (updatedUser != null && !updatedUser.emailVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
      );
      return;
    }

    if (AppSettings.studentName != null || AppSettings.facultyName != null) {
      // Fast path: use cached session (after email verification)
      final role = AppSettings.facultyName != null ? 'Faculty' : 'Student';

      if (role == 'Faculty') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FacultyHomePage()),
        );
      } else {
        final div = AppSettings.sectionId ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(division: div)),
        );
      }

      // Update missing session info in the background without blocking navigation
      _syncSessionInBackground(updatedUser);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser!.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final role = (data['role'] ?? data['userType']) as String?;
        final divisionVal = data['division'] as String?;
        final isExistingUser = data['onboardingCompleted'] == true ||
            data['profileCompleted'] == true ||
            role != null ||
            (divisionVal != null && divisionVal.isNotEmpty);

        if (isExistingUser) {
          if (role == 'Faculty') {
            await AppSettings.saveRole(UserRole.faculty);
            final facId = data['facultyProfileId'] ?? updatedUser.uid;
            final facDoc = await FirebaseFirestore.instance
                .collection('faculty_profiles')
                .doc(facId)
                .get();
            if (facDoc.exists) {
              final fData = facDoc.data()!;
              await AppSettings.saveFacultyDetails(
                name: fData['name'] ?? '',
                email: fData['email'] ?? '',
                department: fData['department'] ?? '',
                designation: fData['designation'] ?? '',
                cabin: fData['cabin'] ?? '',
                assignedDivisions: List<String>.from(
                  fData['assignedDivisions'] ?? [],
                ),
                id: facDoc.id,
              );
              if (fData['setupComplete'] == true) {
                await AppSettings.completeFacultySetup();
              }
            } else {
              await AppSettings.saveFacultyDetails(
                name: data['name'] ?? 'Faculty',
                email: data['email'] ?? updatedUser.email ?? '',
                department: data['department'] ?? '',
                designation: data['designation'] ?? '',
                cabin: data['cabin'] ?? '',
                id: facId,
              );
            }

            await prefs.setBool('has_logged_in', true);

            if (data['onboardingCompleted'] != true ||
                data['profileCompleted'] != true) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(updatedUser.uid)
                  .set({
                'onboardingCompleted': true,
                'profileCompleted': true,
              }, SetOptions(merge: true)).catchError((e) {
                debugPrint('Failed to update onboarding completed: $e');
              });
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FacultyHomePage()),
            );
          } else {
            // Student / CR / SR
            final div = (data['sectionId'] ??
                    AppSettings.sectionId ??
                    divisionVal ??
                    '')
                .toString();
            final parts = NMIMSStructure.parseSectionId(div);

            await AppSettings.saveStudentDetails(
              name: data['name'] ?? AppSettings.studentName ?? 'Student',
              rollNo: data['rollNo'] ?? AppSettings.studentRollNo ?? 'Unknown',
              batch: data['studentBatch'] ?? data['batch'] ?? AppSettings.studentBatch,
              acYear: data['academicYear'] ?? parts['year'] ?? '',
              br: data['branch'] ?? data['program'] ?? parts['branch'] ?? '',
              div: data['divisionName'] ?? parts['division'] ?? div,
              secId: data['sectionId'] ?? div,
              schoolName: data['school'] ?? parts['school'] ?? 'STME',
              programName: data['program'] ?? parts['branch'],
              sem: data['semester'] ?? parts['semester'],
            );

            final roleStr = role;
            if (roleStr == 'CR') {
              await AppSettings.saveRole(UserRole.cr);
            } else if (roleStr == 'SR') {
              await AppSettings.saveRole(UserRole.sr);
            } else {
              await AppSettings.saveRole(UserRole.student);
            }

            await prefs.setBool('has_logged_in', true);

            if (data['onboardingCompleted'] != true ||
                data['profileCompleted'] != true) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(updatedUser.uid)
                  .set({
                'onboardingCompleted': true,
                'profileCompleted': true,
              }, SetOptions(merge: true)).catchError((e) {
                debugPrint('Failed to update onboarding completed: $e');
              });
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage(division: div)),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error reading user document in StartupRouter: $e');
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingWizardPage()),
    );
  }

  Future<void> _syncSessionInBackground(User? user) async {
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        bool needsUpdate = false;
        final updates = <String, dynamic>{};

        if (data.containsKey('userType') && !data.containsKey('role')) {
          updates['role'] = data['userType'];
          updates['userType'] = FieldValue.delete();
          needsUpdate = true;
        } else if (data.containsKey('userType')) {
          updates['userType'] = FieldValue.delete();
          needsUpdate = true;
        }

        if (data.containsKey('draftProfile')) {
          final dp = data['draftProfile'] as Map<String, dynamic>;
          if (dp.containsKey('name') && !data.containsKey('name'))
            updates['name'] = dp['name'];
          if (dp.containsKey('rollNo') && !data.containsKey('rollNo'))
            updates['rollNo'] = dp['rollNo'];
          updates['draftProfile'] = FieldValue.delete();
          needsUpdate = true;
        }

        if (needsUpdate) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update(updates);
          debugPrint('Normalized user document for schema consistency.');
        }

        final roleToUse = updates.containsKey('role')
            ? updates['role']
            : data['role'];
        final div = data['division'] as String?;
        final secId = data['sectionId'] ?? div ?? '';

        if (roleToUse == 'Faculty') {
          await AppSettings.saveRole(UserRole.faculty);
          if (data.containsKey('facultyProfileId')) {
            final facDoc = await FirebaseFirestore.instance
                .collection('faculty_profiles')
                .doc(data['facultyProfileId'])
                .get();
            if (facDoc.exists) {
              final fData = facDoc.data()!;
              await AppSettings.saveFacultyDetails(
                name: fData['name'] ?? '',
                email: fData['email'] ?? '',
                department: fData['department'] ?? '',
                designation: fData['designation'] ?? '',
                cabin: fData['cabin'] ?? '',
                id: facDoc.id,
              );
            }
          }
        } else {
          final roleStr = roleToUse as String?;
          if (roleStr == 'CR') {
            await AppSettings.saveRole(UserRole.cr);
          } else if (roleStr == 'SR') {
            await AppSettings.saveRole(UserRole.sr);
          } else {
            await AppSettings.saveRole(UserRole.student);
          }

          if (div != null && div.isNotEmpty) {
            final parts = NMIMSStructure.parseSectionId(secId.isNotEmpty ? secId : div);
            await AppSettings.saveStudentDetails(
              name: data['name'] ?? AppSettings.studentName ?? 'Student',
              rollNo: data['rollNo'] ?? AppSettings.studentRollNo ?? 'Unknown',
              batch: data['studentBatch'] ?? data['batch'] ?? AppSettings.studentBatch,
              acYear: data['academicYear'] ?? parts['year'] ?? AppSettings.academicYear ?? '',
              br: data['branch'] ?? data['program'] ?? parts['branch'] ?? AppSettings.branch ?? '',
              div: data['divisionName'] ?? parts['division'] ?? AppSettings.division ?? div,
              secId: secId.isNotEmpty ? secId : div,
              schoolName: data['school'] ?? parts['school'] ?? AppSettings.school ?? 'STME',
              programName: data['program'] ?? parts['branch'] ?? AppSettings.program,
              sem: data['semester'] ?? parts['semester'] ?? AppSettings.semester,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in background sync: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: DashboardSkeleton());
  }
}
