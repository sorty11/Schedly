import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/models/timetable_entry.dart';
import 'package:schedly/models/event_category.dart';
import 'package:schedly/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisualSkin Architecture & Recipe Tests', () {
    test('VisualSkin.fromTheme returns correct subclass for all 4 themes', () {
      final defaultSkin = VisualSkin.fromTheme(
        SchedlyVisualTheme.defaultTheme,
        isDark: true,
      );
      final heritageSkin = VisualSkin.fromTheme(
        SchedlyVisualTheme.heritage,
        isDark: true,
      );
      final futureSkin = VisualSkin.fromTheme(
        SchedlyVisualTheme.future,
        isDark: true,
      );
      final bloomSkin = VisualSkin.fromTheme(
        SchedlyVisualTheme.bloom,
        isDark: true,
      );

      expect(defaultSkin, isA<DefaultSkin>());
      expect(heritageSkin, isA<HeritageSkin>());
      expect(futureSkin, isA<FutureSkin>());
      expect(bloomSkin, isA<BloomSkin>());
    });

    test('Each skin provides distinct card border radii', () {
      final defaultSkin = DefaultSkin(isDark: true);
      final heritageSkin = HeritageSkin(isDark: true);
      final futureSkin = FutureSkin(isDark: true);
      final bloomSkin = BloomSkin(isDark: true);

      expect(
        defaultSkin.cardRecipe.borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(
        heritageSkin.cardRecipe.borderRadius,
        const BorderRadius.all(Radius.circular(14)),
      );
      expect(
        futureSkin.cardRecipe.borderRadius,
        const BorderRadius.all(Radius.circular(10)),
      );
      expect(
        bloomSkin.cardRecipe.borderRadius,
        const BorderRadius.all(Radius.circular(22)),
      );
    });

    test('Each skin provides distinct typography and subject icons', () {
      final heritageSkin = HeritageSkin(isDark: true);
      final futureSkin = FutureSkin(isDark: true);
      final bloomSkin = BloomSkin(isDark: true);
      final defaultSkin = DefaultSkin(isDark: true);

      // Icons should resolve appropriately per theme personality
      expect(heritageSkin.getSubjectIcon('math'), Icons.science_outlined);
      expect(futureSkin.getSubjectIcon('dsa'), Icons.psychology_rounded);
      expect(bloomSkin.getSubjectIcon('dcca'), Icons.widgets_rounded);
      expect(defaultSkin.getSubjectIcon('math'), Icons.calculate_rounded);
    });
  });

  group('ThemedDaySelector Widget Tests', () {
    testWidgets('renders all 6 days and triggers onDaySelected when tapped', (
      tester,
    ) async {
      int selectedIndex = 0;
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(
            isDark: true,
            visualTheme: SchedlyVisualTheme.heritage,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ThemedDaySelector(
                  days: days,
                  selectedIndex: selectedIndex,
                  todayIndex: 1,
                  onDaySelected: (idx) {
                    setState(() {
                      selectedIndex = idx;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Should render Mon, Tue, Wed, Thu, Fri, Sat
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);

      // Tap on Wednesday (index 2)
      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 2);
    });
  });

  group('ThemedLectureCard Widget Tests', () {
    final testEntry = TimetableEntry(
      id: 'entry_1',
      subject: 'Data Structures',
      category: EventCategory.academic,
      room: 'Lab 3',
      component: 'Lab',
      batch: 'B1',
      startTime: 540,
      endTime: 660,
      durationMinutes: 120,
      facultyId: 'Prof. Turing',
      status: 'active',
    );

    for (final theme in SchedlyVisualTheme.values) {
      testWidgets('ThemedLectureCard renders correctly in ${theme.name}', (
        tester,
      ) async {
        bool editTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(isDark: true, visualTheme: theme),
            home: Scaffold(
              body: ThemedLectureCard(
                entries: [testEntry],
                isEditMode: true,
                canEditEntry: (e) => true,
                onTap: () {
                  editTapped = true;
                },
              ),
            ),
          ),
        );

        // Subject name and room details should appear
        expect(find.textContaining('Data Structures'), findsOneWidget);
        expect(find.text('9:00 AM - 11:00 AM'), findsOneWidget);

        // Tap card to trigger edit
        await tester.tap(find.textContaining('Data Structures'));
        await tester.pumpAndSettle();

        expect(editTapped, isTrue);
      });
    }

    testWidgets('ThemedLectureCard displays CANCELLED badge when inactive', (
      tester,
    ) async {
      final cancelledEntry = TimetableEntry(
        id: 'entry_2',
        subject: 'Data Structures',
        category: EventCategory.academic,
        room: 'Lab 3',
        component: 'Lab',
        batch: 'B1',
        startTime: 540,
        endTime: 660,
        durationMinutes: 120,
        facultyId: 'Prof. Turing',
        status: 'cancelled',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(
            isDark: true,
            visualTheme: SchedlyVisualTheme.bloom,
          ),
          home: Scaffold(body: ThemedLectureCard(entries: [cancelledEntry])),
        ),
      );

      expect(find.textContaining('Data Structures'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
    });
  });
}
