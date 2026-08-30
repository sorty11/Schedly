import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_config.dart';
import '../utils/test_helpers.dart';

Future<void> runSrSmokeTest(WidgetTester tester) async {
  print('--- Starting SR Smoke Test ---');

  if (!TestConfig.testDivision.toLowerCase().contains('smoke')) {
    print(
      'WARNING: TEST_DIVISION does not contain "smoke". Skipping SR tests for safety.',
    );
    return;
  }

  // 1. Login
  print('SR Login...');
  await TestHelpers.login(
    tester,
    email: TestConfig.srEmail,
    password: TestConfig.srPassword,
  );

  // Verify SR Dashboard is accessible
  expect(
    find.text('SR Dashboard'),
    findsWidgets,
    reason: 'SR should see SR Dashboard',
  );

  // 2. Timetable Edit Attempt
  print('SR Timetable Edit...');
  final quickAddBtn = find.text('Quick Add');
  if (quickAddBtn.evaluate().isNotEmpty) {
    await tester.tap(quickAddBtn.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Fill out form
    final subjectField = find.byType(TextFormField).first;
    await tester.enterText(subjectField, 'SR_SMOKE_TEST');

    final saveBtn = find.text('Save');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // We expect this to either succeed (if SR is authorized for the division)
    // or we can verify the notification is queued.
    // The main test is that it doesn't crash the app with an unhandled exception.
  }

  // 3. Check Conduct
  print('SR Conduct...');
  final conductTab = find.text('Conduct');
  if (conductTab.evaluate().isNotEmpty) {
    await tester.tap(conductTab.first);
    await tester.pumpAndSettle();
  }

  // 4. Logout
  print('SR Logout...');
  await TestHelpers.logout(tester);

  TestHelpers.verifyNoRenderFlexErrors(tester);
  print('--- SR Smoke Test PASS ---');
}
