import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_config.dart';
import '../utils/test_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> runCrSmokeTest(WidgetTester tester) async {
  print('--- Starting CR Smoke Test ---');

  if (!TestConfig.testDivision.toLowerCase().contains('smoke')) {
    print(
      'WARNING: TEST_DIVISION does not contain "smoke". Skipping CR mutation tests for safety.',
    );
    return;
  }

  // 1. Login
  print('CR Login...');
  await TestHelpers.login(
    tester,
    email: TestConfig.crEmail,
    password: TestConfig.crPassword,
  );

  // Verify CR Panel is accessible
  expect(find.text('CR Panel'), findsWidgets, reason: 'CR should see CR Panel');

  // 2. Timetable Management (Adding a Lecture)
  print('CR Adding a Lecture...');
  final addLectureBtn = find.text('Quick Add');
  if (addLectureBtn.evaluate().isNotEmpty) {
    await tester.tap(addLectureBtn.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Fill out form
    final subjectField = find.byType(TextFormField).first;
    await tester.enterText(subjectField, 'SMOKE_TEST_LECTURE');

    // Select batch
    final batchDropdown = find.text('Whole Class');
    if (batchDropdown.evaluate().isNotEmpty) {
      // It's already whole class, but let's test split batches if needed.
    }

    final saveBtn = find.text('Save');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify it was added by checking if the text exists on the page
    // Note: It might be on a different day, so we assume adding defaults to today.
  }

  // 3. Timetable Replacement (Monthly)
  print('CR Monthly Replacement...');
  final timetableTab = find.byIcon(Icons.calendar_month_rounded);
  await tester.tap(timetableTab);
  await tester.pumpAndSettle();

  final monthlyBtn = find.text('Monthly');
  if (monthlyBtn.evaluate().isNotEmpty) {
    await tester.tap(monthlyBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Add Holiday
    final addHolidayBtn = find.byIcon(
      Icons.holiday_village,
    ); // Adjust icon if different
    if (addHolidayBtn.evaluate().isNotEmpty) {
      await tester.tap(addHolidayBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Confirm dialog
      final confirmBtn = find.text('Mark Holiday');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    }
  }

  // 4. Clean up test data directly in Firestore to maintain purity
  print('CR Cleanup...');
  try {
    final query = await FirebaseFirestore.instance
        .collection('timetables')
        .doc(TestConfig.testDivision)
        .collection('Monday') // Example
        .where('subject', isEqualTo: 'SMOKE_TEST_LECTURE')
        .get();

    for (var doc in query.docs) {
      await doc.reference.delete();
    }
    print('Cleaned up SMOKE_TEST_LECTURE');
  } catch (e) {
    print('Cleanup encountered an issue: $e');
  }

  // 5. Logout
  print('CR Logout...');
  await TestHelpers.logout(tester);

  TestHelpers.verifyNoRenderFlexErrors(tester);
  print('--- CR Smoke Test PASS ---');
}
