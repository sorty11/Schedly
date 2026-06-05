import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/local_notification_service.dart';
import 'division_selection_page.dart';
import 'home_page.dart';
import 'splash_screen.dart';
import 'app_settings.dart';
import 'services/announcement_listener.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initialize();
  await LocalNotificationService.initialize();
  AnnouncementListener.start();

  await AppSettings.loadRole();
  await AppSettings.loadSRDetails();

  runApp(const SchedlyApp());
}

class SchedlyApp extends StatelessWidget {
  const SchedlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
      home: const SplashScreen(),
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

  await prefs.clear(); // TEMPORARY

  final hasLoggedIn =
      prefs.getBool(
            'has_logged_in',
          ) ??
          false;
  final division =
      prefs.getString(
    'selected_division',
  );

  if (!mounted) return;

  if (!hasLoggedIn) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
    );
    return;
  }

  if (division == null) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DivisionSelectionPage(
            role: 'Student',
          ),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          division: division,
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