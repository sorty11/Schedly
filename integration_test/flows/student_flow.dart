import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_config.dart';
import '../utils/test_helpers.dart';
import 'package:schedly/widgets/schedly_card.dart'; // Example specific imports if needed

Future<void> runStudentSmokeTest(WidgetTester tester) async {
  print('--- Starting STUDENT Smoke Test ---');

  // 1. Login Flow (Success & Failure)
  print('Testing Login...');
  // We can test invalid login first
  await TestHelpers.login(
    tester,
    email: 'invalid@student.com',
    password: 'wrongpassword',
  );
  expect(
    find.textContaining('invalid-credential'),
    findsOneWidget,
    reason: 'Should show error for invalid login',
  );

  // Close the error dialog/snackbar if present
  final dismissBtn = find.text('OK');
  if (dismissBtn.evaluate().isNotEmpty) {
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();
  }

  // Real login
  await TestHelpers.login(
    tester,
    email: TestConfig.studentEmail,
    password: TestConfig.studentPassword,
  );

  // Verify Home page loads
  print('Testing Home/Dashboard...');
  expect(
    find.textContaining('Good'),
    findsWidgets,
    reason: 'Should see Good Morning/Afternoon/Evening',
  );

  // 2. Timetable Flow
  print('Testing Timetable...');
  final timetableTab = find.byIcon(Icons.calendar_month_rounded);
  await tester.tap(timetableTab);
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Verify weekly view loaded
  expect(
    find.text('Mon'),
    findsWidgets,
    reason: 'Should show weekday headers in weekly view',
  );

  // Switch to Monthly
  print('Testing Monthly Timetable...');
  final monthlyBtn = find.text('Monthly');
  if (monthlyBtn.evaluate().isNotEmpty) {
    await tester.tap(monthlyBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      find.byType(CalendarDatePicker),
      findsWidgets,
      reason: 'Should see the calendar widget',
    );
  }

  // 3. Notifications/Updates
  print('Testing Notifications...');
  final updatesTab = find.byIcon(Icons.notifications_rounded);
  await tester.tap(updatesTab);
  await tester.pumpAndSettle();

  // 4. Profile & Logout
  print('Testing Profile & Logout...');
  await TestHelpers.logout(tester);

  TestHelpers.verifyNoRenderFlexErrors(tester);
  print('--- STUDENT Smoke Test PASS ---');
}
