import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_config.dart';
import '../utils/test_helpers.dart';

Future<void> runFacultySmokeTest(WidgetTester tester) async {
  print('--- Starting Faculty Smoke Test ---');

  // 1. Login
  print('Faculty Login...');
  await TestHelpers.login(
    tester,
    email: TestConfig.facultyEmail,
    password: TestConfig.facultyPassword,
  );

  // Verify Faculty Home loads
  expect(
    find.text('Faculty'),
    findsWidgets,
    reason: 'Should identify as Faculty in UI',
  );

  // 2. Timetable
  print('Faculty Timetable...');
  final timetableTab = find.byIcon(Icons.calendar_month_rounded);
  await tester.tap(timetableTab);
  await tester.pumpAndSettle();

  // 3. Faculty Requests (if they exist)
  print('Faculty Requests...');
  final requestsBtn = find.textContaining('Requests');
  if (requestsBtn.evaluate().isNotEmpty) {
    await tester.tap(requestsBtn.first);
    await tester.pumpAndSettle();
  }

  // 4. Notifications
  print('Faculty Notifications...');
  final bellIcon = find.byIcon(Icons.notifications_rounded);
  if (bellIcon.evaluate().isNotEmpty) {
    await tester.tap(bellIcon);
    await tester.pumpAndSettle();
  }

  // 5. Logout
  print('Faculty Logout...');
  await TestHelpers.logout(tester);

  TestHelpers.verifyNoRenderFlexErrors(tester);
  print('--- Faculty Smoke Test PASS ---');
}
