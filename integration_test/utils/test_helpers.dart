import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestHelpers {
  static Future<void> startApp(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
  }

  static Future<void> login(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    // Wait for the login/onboarding screen
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Sign out if already logged in (cleanup from previous test)
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Try finding the login button (Onboarding Flow -> 'Already have an account? Login')
    final loginSwitchBtn = find.textContaining('Login');
    if (loginSwitchBtn.evaluate().isNotEmpty) {
      await tester.tap(loginSwitchBtn.first);
      await tester.pumpAndSettle();
    }

    final emailField = find.bySemanticsLabel(
      RegExp(r'Email', caseSensitive: false),
    );
    final passwordField = find.bySemanticsLabel(
      RegExp(r'Password', caseSensitive: false),
    );
    final loginBtn = find
        .text('Login')
        .last; // Assuming the actual submit button is also named Login

    // It's possible we are already on a login page, let's just find the text fields.
    // If we can't find them by semantics, let's find by type.
    if (emailField.evaluate().isEmpty) {
      // Find TextField by hint text or icon if semantic label isn't used
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        await tester.enterText(textFields.at(0), email);
        await tester.enterText(textFields.at(1), password);
      }
    } else {
      await tester.enterText(emailField, email);
      await tester.enterText(passwordField, password);
    }

    // Close keyboard
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(loginBtn);
    await tester.pumpAndSettle(
      const Duration(seconds: 5),
    ); // Wait for auth & navigation
  }

  static Future<void> logout(WidgetTester tester) async {
    // Navigate to profile tab
    final profileTab = find.byIcon(Icons.person_rounded);
    if (profileTab.evaluate().isNotEmpty) {
      await tester.tap(profileTab);
      await tester.pumpAndSettle();
    }

    // Find logout button
    final logoutBtn = find.textContaining('Logout');
    if (logoutBtn.evaluate().isNotEmpty) {
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirm dialog if it exists
      final confirmBtn = find.text('Logout').last;
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  static void verifyNoRenderFlexErrors(WidgetTester tester) {
    // Flutter test framework automatically fails on RenderFlex overflow
    // unless we catch it. We want it to fail, so standard behavior is fine,
    // but we can add explicit checks if needed.
    expect(tester.takeException(), isNull);
  }

  static Future<void> cleanupSmokeTestDivision(String division) async {
    // WARNING: This directly modifies Firestore. Ensure it only targets the TEST division.
    if (!division.toLowerCase().contains('smoke')) {
      throw Exception(
        'SAFETY ABORT: Attempted to clean a non-smoke test division: $division',
      );
    }

    // Cleanup timetables collection for the test division
    final db = FirebaseFirestore.instance;
    final timetablesRef = db.collection('timetables').doc(division);

    // We can't easily delete subcollections from the client SDK,
    // but for tests, we could delete specific known documents created by the test.
    // E.g., 'Monday' -> 'dummy_lecture_id'
  }
}
