import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schedly/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Theme Tokens & Extension Tests', () {
    for (final visualTheme in SchedlyVisualTheme.values) {
      test(
        'Theme "${visualTheme.displayName}" builds Light and Dark themes correctly',
        () {
          final lightTheme = AppTheme.buildTheme(
            isDark: false,
            visualTheme: visualTheme,
          );
          final darkTheme = AppTheme.buildTheme(
            isDark: true,
            visualTheme: visualTheme,
          );

          expect(lightTheme.brightness, Brightness.light);
          expect(darkTheme.brightness, Brightness.dark);

          // Extensions must exist on both light and dark
          final lightSem = lightTheme.extension<AppSemanticColors>();
          final darkSem = darkTheme.extension<AppSemanticColors>();
          expect(lightSem, isNotNull);
          expect(darkSem, isNotNull);

          final lightLecture = lightTheme.extension<SchedlyLectureTypeColors>();
          final darkLecture = darkTheme.extension<SchedlyLectureTypeColors>();
          expect(lightLecture, isNotNull);
          expect(darkLecture, isNotNull);

          // CardTheme check
          expect(lightTheme.cardTheme.shape, isNotNull);
          expect(darkTheme.cardTheme.shape, isNotNull);
        },
      );

      test(
        'Theme "${visualTheme.displayName}" resolves curated lecture colors',
        () {
          final lightTheme = AppTheme.buildTheme(
            isDark: false,
            visualTheme: visualTheme,
          );
          final lectureColors = lightTheme
              .extension<SchedlyLectureTypeColors>()!;

          final theoryColor = lectureColors.resolve(component: 'Theory');
          final labColor = lectureColors.resolve(component: 'Lab');
          final tutorialColor = lectureColors.resolve(component: 'Tutorial');
          final practicalColor = lectureColors.resolve(component: 'Practical');
          final projectColor = lectureColors.resolve(component: 'Project');
          final seminarColor = lectureColors.resolve(component: 'Seminar');
          final vivaColor = lectureColors.resolve(component: 'Viva');
          final eventColor = lectureColors.resolve(component: 'Event');
          final lunchColor = lectureColors.resolve(subject: 'Lunch Break');

          expect(theoryColor, isNotNull);
          expect(labColor, isNotNull);
          expect(tutorialColor, isNotNull);
          expect(practicalColor, isNotNull);
          expect(projectColor, isNotNull);
          expect(seminarColor, isNotNull);
          expect(vivaColor, isNotNull);
          expect(eventColor, isNotNull);
          expect(lunchColor, isNotNull);
        },
      );
    }

    testWidgets(
      'AppTheme.lectureTypeColor helper works within widget context for all themes',
      (tester) async {
        for (final visualTheme in SchedlyVisualTheme.values) {
          Color? resolvedColor;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.buildTheme(
                isDark: false,
                visualTheme: visualTheme,
              ),
              home: Builder(
                builder: (context) {
                  resolvedColor = AppTheme.lectureTypeColor(
                    context,
                    component: 'Lab',
                    subject: 'Web Development',
                  );
                  return const Scaffold(body: SizedBox());
                },
              ),
            ),
          );

          expect(resolvedColor, isNotNull);
        }
      },
    );
  });
}
