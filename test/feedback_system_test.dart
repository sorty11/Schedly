import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/widgets/support/bug_report_sheet.dart';
import 'package:schedly/widgets/support/feature_request_sheet.dart';
import 'package:schedly/widgets/support/other_feedback_sheet.dart';
import 'package:schedly/theme/theme.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Feedback Sheets UI & Validation Tests', () {
    testWidgets('BugReportSheet renders title, categories, and inputs', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const BugReportSheet()));
      await tester.pumpAndSettle();

      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });

    testWidgets('FeatureRequestSheet renders title, categories, and inputs', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const FeatureRequestSheet()));
      await tester.pumpAndSettle();

      expect(find.text('Suggest a Feature'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Submit Suggestion'), findsOneWidget);
    });

    testWidgets('OtherFeedbackSheet renders title, categories, and inputs', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const OtherFeedbackSheet()));
      await tester.pumpAndSettle();

      expect(find.text('General Feedback'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Topic / Title'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Send Feedback'), findsOneWidget);
    });

    testWidgets('BugReportSheet displays validation errors on empty submit', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const BugReportSheet()));
      await tester.pumpAndSettle();

      final submitBtn = find.text('Submit Report');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a title'), findsOneWidget);
      expect(find.text('Please enter a description'), findsOneWidget);
    });

    testWidgets(
      'OtherFeedbackSheet displays validation errors on empty submit',
      (tester) async {
        await tester.pumpWidget(createTestWidget(const OtherFeedbackSheet()));
        await tester.pumpAndSettle();

        final submitBtn = find.text('Send Feedback');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a title'), findsOneWidget);
        expect(find.text('Please enter your feedback'), findsOneWidget);
      },
    );
  });
}
