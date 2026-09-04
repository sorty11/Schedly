import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/app_settings.dart';
import 'package:schedly/theme/app_theme.dart';
import 'package:schedly/widgets/profile_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget({required String initial, String? photoUrl}) {
    AppSettings.profilePhotoUrl = photoUrl;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(child: ProfileAvatar(initial: initial, size: 80)),
      ),
    );
  }

  group('ProfileAvatar Widget Tests', () {
    testWidgets(
      '1. Renders minimal circular avatar with initial when no photo exists',
      (tester) async {
        await tester.pumpWidget(createTestWidget(initial: 'A', photoUrl: null));
        await tester.pumpAndSettle();

        // Expect to find the initial 'A'
        expect(find.text('A'), findsOneWidget);

        // Expect to find the edit camera badge icon
        expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      },
    );

    testWidgets('2. Tapping avatar opens Change Profile Photo bottom sheet', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(initial: 'S', photoUrl: null));
      await tester.pumpAndSettle();

      // Tap on the avatar
      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and options
      expect(find.text('Change Profile Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // When no photo exists, 'Remove Photo' should NOT be present
      expect(find.text('Remove Photo'), findsNothing);
    });

    testWidgets('3. Displays Remove Photo option when a photo URL is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          initial: 'M',
          photoUrl: 'https://example.com/avatar.jpg',
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the avatar
      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();

      // Verify bottom sheet contains Remove Photo
      expect(find.text('Change Profile Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Remove Photo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Change Profile Photo'), findsNothing);
    });
  });
}
