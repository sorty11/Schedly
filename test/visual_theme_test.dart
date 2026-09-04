import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('SchedlyVisualTheme Enum Tests', () {
    test('fromId correctly parses all 4 themes', () {
      expect(
        SchedlyVisualTheme.fromId('default'),
        SchedlyVisualTheme.defaultTheme,
      );
      expect(
        SchedlyVisualTheme.fromId('heritage'),
        SchedlyVisualTheme.heritage,
      );
      expect(SchedlyVisualTheme.fromId('future'), SchedlyVisualTheme.future);
      expect(SchedlyVisualTheme.fromId('bloom'), SchedlyVisualTheme.bloom);
    });

    test('fromId correctly migrates legacy theme IDs', () {
      expect(SchedlyVisualTheme.fromId('space'), SchedlyVisualTheme.future);
      expect(
        SchedlyVisualTheme.fromId('cyber_robo'),
        SchedlyVisualTheme.future,
      );
      expect(SchedlyVisualTheme.fromId('arcade'), SchedlyVisualTheme.future);
      expect(SchedlyVisualTheme.fromId('cats'), SchedlyVisualTheme.bloom);
    });

    test('fromId falls back to defaultTheme on null or unknown id', () {
      expect(SchedlyVisualTheme.fromId(null), SchedlyVisualTheme.defaultTheme);
      expect(SchedlyVisualTheme.fromId(''), SchedlyVisualTheme.defaultTheme);
      expect(
        SchedlyVisualTheme.fromId('nonexistent_theme'),
        SchedlyVisualTheme.defaultTheme,
      );
    });

    test('Each theme has valid title, description, and icon', () {
      for (final theme in SchedlyVisualTheme.values) {
        expect(theme.id.isNotEmpty, true);
        expect(theme.displayName.isNotEmpty, true);
        expect(theme.description.isNotEmpty, true);
        expect(theme.icon, isNotNull);
      }
    });
  });

  group('ThemeController Visual Theme Tests', () {
    test('Loads defaultTheme when no preference saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      expect(controller.visualTheme, SchedlyVisualTheme.defaultTheme);
    });

    test('Loads saved theme preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'visual_theme_preference': 'heritage',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      expect(controller.visualTheme, SchedlyVisualTheme.heritage);
    });

    test('Migrates legacy saved theme preference on load', () async {
      SharedPreferences.setMockInitialValues({
        'visual_theme_preference': 'space',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      expect(controller.visualTheme, SchedlyVisualTheme.future);
    });

    test(
      'setVisualTheme updates state, notifies listeners, and persists to SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final controller = ThemeController(prefs);

        bool notified = false;
        controller.addListener(() {
          notified = true;
        });

        await controller.setVisualTheme(SchedlyVisualTheme.bloom);

        expect(controller.visualTheme, SchedlyVisualTheme.bloom);
        expect(notified, true);
        expect(prefs.getString('visual_theme_preference'), 'bloom');

        // Changing to heritage
        notified = false;
        await controller.setVisualTheme(SchedlyVisualTheme.heritage);
        expect(controller.visualTheme, SchedlyVisualTheme.heritage);
        expect(notified, true);
        expect(prefs.getString('visual_theme_preference'), 'heritage');

        // Changing back to defaultTheme
        notified = false;
        await controller.setVisualTheme(SchedlyVisualTheme.defaultTheme);
        expect(controller.visualTheme, SchedlyVisualTheme.defaultTheme);
        expect(notified, true);
        expect(prefs.getString('visual_theme_preference'), 'default');
      },
    );
  });

  group('AppTheme transparentScaffold Tests', () {
    test('Default theme retains original solid scaffold backgrounds', () {
      final light = AppTheme.buildTheme(
        isDark: false,
        visualTheme: SchedlyVisualTheme.defaultTheme,
        transparentScaffold: false,
      );
      final dark = AppTheme.buildTheme(
        isDark: true,
        visualTheme: SchedlyVisualTheme.defaultTheme,
        transparentScaffold: false,
      );

      expect(light.scaffoldBackgroundColor, isNot(Colors.transparent));
      expect(dark.scaffoldBackgroundColor, isNot(Colors.transparent));
      expect(light.scaffoldBackgroundColor, AppColors.background);
      expect(dark.scaffoldBackgroundColor, AppColors.backgroundDark);
    });

    test(
      'Custom theme provides transparent scaffold and app bar backgrounds',
      () {
        final light = AppTheme.buildTheme(
          isDark: false,
          visualTheme: SchedlyVisualTheme.future,
          transparentScaffold: true,
        );
        final dark = AppTheme.buildTheme(
          isDark: true,
          visualTheme: SchedlyVisualTheme.future,
          transparentScaffold: true,
        );

        expect(light.scaffoldBackgroundColor, Colors.transparent);
        expect(dark.scaffoldBackgroundColor, Colors.transparent);
        expect(light.appBarTheme.backgroundColor, Colors.transparent);
        expect(dark.appBarTheme.backgroundColor, Colors.transparent);
      },
    );
  });

  group('AnimatedThemeBackground Widget Tests', () {
    testWidgets('defaultTheme renders child without any background stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedThemeBackground(
            theme: SchedlyVisualTheme.defaultTheme,
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(AnimatedThemeCanvas), findsNothing);
    });

    testWidgets('future theme renders AnimatedThemeCanvas behind child', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedThemeBackground(
            theme: SchedlyVisualTheme.future,
            child: Text('Foreground Content'),
          ),
        ),
      );

      expect(find.text('Foreground Content'), findsOneWidget);
      expect(find.byType(AnimatedThemeCanvas), findsOneWidget);
    });

    testWidgets('heritage theme renders AnimatedThemeCanvas behind child', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedThemeBackground(
            theme: SchedlyVisualTheme.heritage,
            child: Text('Heritage Content'),
          ),
        ),
      );

      expect(find.text('Heritage Content'), findsOneWidget);
      expect(find.byType(AnimatedThemeCanvas), findsOneWidget);
    });

    testWidgets('bloom theme renders AnimatedThemeCanvas behind child', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedThemeBackground(
            theme: SchedlyVisualTheme.bloom,
            child: Text('Bloom Content'),
          ),
        ),
      );

      expect(find.text('Bloom Content'), findsOneWidget);
      expect(find.byType(AnimatedThemeCanvas), findsOneWidget);
    });
  });
}
