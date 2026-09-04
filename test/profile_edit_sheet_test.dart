import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/services/profile_service.dart';
import 'package:schedly/theme/theme.dart';
import 'package:schedly/widgets/profile_edit_sheet.dart';

void main() {
  group('ProfileService Validation Tests', () {
    test('validateName correctly rejects null, empty and short names', () {
      expect(ProfileService.validateName(null), 'Name cannot be empty');
      expect(ProfileService.validateName(''), 'Name cannot be empty');
      expect(ProfileService.validateName('   '), 'Name cannot be empty');
      expect(ProfileService.validateName('A'), 'Name must be at least 2 characters');
      expect(ProfileService.validateName('John Doe'), isNull);
      expect(ProfileService.validateName('  Jane Smith  '), isNull);
    });

    test('validateSapId correctly validates SAP ID formats', () {
      expect(ProfileService.validateSapId(null), 'SAP ID / Roll Number cannot be empty');
      expect(ProfileService.validateSapId(''), 'SAP ID / Roll Number cannot be empty');
      expect(ProfileService.validateSapId('   '), 'SAP ID / Roll Number cannot be empty');
      expect(ProfileService.validateSapId('X'), 'Must be at least 2 characters');
      expect(
        ProfileService.validateSapId('Invalid SAP!'),
        'Must be alphanumeric (letters, numbers, hyphen or underscore)',
      );
      expect(
        ProfileService.validateSapId('A 137'),
        'Must be alphanumeric (letters, numbers, hyphen or underscore)',
      );

      // Valid IDs
      expect(ProfileService.validateSapId('A137'), isNull);
      expect(ProfileService.validateSapId('70022500123'), isNull);
      expect(ProfileService.validateSapId('FAC-01'), isNull);
      expect(ProfileService.validateSapId('CS_2024'), isNull);
    });
  });

  group('ProfileEditSheet Widget Tests', () {
    Widget buildTestWidget({
      required String currentName,
      required String currentSapId,
      required bool isFaculty,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProfileEditSheet(
            currentName: currentName,
            currentSapId: currentSapId,
            isFaculty: isFaculty,
          ),
        ),
      );
    }

    testWidgets('Pre-fills existing Name and SAP ID for Student', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        currentName: 'Aarav Patel',
        currentSapId: 'A137',
        isFaculty: false,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('A137'), findsOneWidget);
      expect(find.text('SAP ID / Roll Number'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Pre-fills existing Name and Faculty ID for Faculty', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        currentName: 'Dr. Sharma',
        currentSapId: 'FAC701',
        isFaculty: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sharma'), findsOneWidget);
      expect(find.text('FAC701'), findsOneWidget);
      expect(find.text('Faculty SAP ID / Employee ID'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Shows validation errors on empty submission', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        currentName: 'Aarav Patel',
        currentSapId: 'A137',
        isFaculty: false,
      ));
      await tester.pumpAndSettle();

      // Clear the text fields
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Name cannot be empty'), findsOneWidget);
      expect(find.text('SAP ID / Roll Number cannot be empty'), findsOneWidget);
    });

    testWidgets('Whitespace trimming and valid input acceptance', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        currentName: 'Aarav Patel',
        currentSapId: 'A137',
        isFaculty: false,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '   Rohan Varma   ');
      await tester.enterText(find.byType(TextFormField).last, '   b042   ');
      await tester.pumpAndSettle();

      expect(ProfileService.validateName('   Rohan Varma   '), isNull);
      expect(ProfileService.validateSapId('   b042   '), isNull);
    });

    testWidgets('No-op detection when fields are unchanged', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ProfileEditSheet.show(
                  context,
                  currentName: 'Aarav Patel',
                  currentSapId: 'A137',
                  isFaculty: false,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Save Changes without modifying anything
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Sheet should dismiss with false (no unnecessary write)
      expect(result, isFalse);
    });
  });
}
