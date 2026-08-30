import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/test_config.dart';
import 'utils/test_helpers.dart';
import 'flows/student_flow.dart';
import 'flows/cr_flow.dart';
import 'flows/sr_flow.dart';
import 'flows/faculty_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Schedly Production E2E Smoke Tests', () {
    setUpAll(() {
      print('==================================================');
      print('STARTING END-TO-END SUITE');
      print('==================================================');
      if (!TestConfig.hasCredentials) {
        print('WARNING: Missing one or more credentials via --dart-define.');
        print('Tests may fail if proper credentials are not provided.');
      }
      print('Target Division: ${TestConfig.testDivision}');
    });

    testWidgets('Student Flow - Timetable, Monthly, Notifications, Profile', (
      tester,
    ) async {
      if (TestConfig.studentEmail.isEmpty) {
        print('SKIPPING: TEST_STUDENT_EMAIL not provided.');
        return;
      }
      await TestHelpers.startApp(tester);
      await runStudentSmokeTest(tester);
    });

    testWidgets('CR Flow - Panel, Setup, Add/Edit/Delete, Holidays', (
      tester,
    ) async {
      if (TestConfig.crEmail.isEmpty) {
        print('SKIPPING: TEST_CR_EMAIL not provided.');
        return;
      }
      await TestHelpers.startApp(tester);
      await runCrSmokeTest(tester);
    });

    testWidgets('SR Flow - Conduct, Monthly, Lecture Edit Rules', (
      tester,
    ) async {
      if (TestConfig.srEmail.isEmpty) {
        print('SKIPPING: TEST_SR_EMAIL not provided.');
        return;
      }
      await TestHelpers.startApp(tester);
      await runSrSmokeTest(tester);
    });

    testWidgets('Faculty Flow - Requests, Timetable, Notifications', (
      tester,
    ) async {
      if (TestConfig.facultyEmail.isEmpty) {
        print('SKIPPING: TEST_FACULTY_EMAIL not provided.');
        return;
      }
      await TestHelpers.startApp(tester);
      await runFacultySmokeTest(tester);
    });
  });
}
