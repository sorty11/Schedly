import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedly/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SchedlyVisualTheme Enum Tests', () {
    test('fromId correctly parses all themes', () {
      expect(SchedlyVisualTheme.fromId('default'), SchedlyVisualTheme.defaultTheme);
      expect(SchedlyVisualTheme.fromId('space'), SchedlyVisualTheme.space);
      expect(SchedlyVisualTheme.fromId('cats'), SchedlyVisualTheme.cats);
      expect(SchedlyVisualTheme.fromId('cyber_robo'), SchedlyVisualTheme.cyberRobo);
      expect(SchedlyVisualTheme.fromId('arcade'), SchedlyVisualTheme.arcade);
    });

    test('fromId falls back to defaultTheme on null or unknown id', () {
      expect(SchedlyVisualTheme.fromId(null), SchedlyVisualTheme.defaultTheme);
      expect(SchedlyVisualTheme.fromId(''), SchedlyVisualTheme.defaultTheme);
      expect(SchedlyVisualTheme.fromId('nonexistent_theme'), SchedlyVisualTheme.defaultTheme);
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
        'visual_theme_preference': 'space',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      expect(controller.visualTheme, SchedlyVisualTheme.space);
    });

    test('setVisualTheme updates state, notifies listeners, and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.setVisualTheme(SchedlyVisualTheme.cats);

      expect(controller.visualTheme, SchedlyVisualTheme.cats);
      expect(notified, true);
      expect(prefs.getString('visual_theme_preference'), 'cats');

      // Changing back to defaultTheme
      notified = false;
      await controller.setVisualTheme(SchedlyVisualTheme.defaultTheme);
      expect(controller.visualTheme, SchedlyVisualTheme.defaultTheme);
      expect(notified, true);
      expect(prefs.getString('visual_theme_preference'), 'default');
    });
  });

  group('AppTheme transparentScaffold Tests', () {
    test('Default theme retains original solid scaffold backgrounds', () {
      final light = AppTheme.buildTheme(isDark: false, transparentScaffold: false);
      final dark = AppTheme.buildTheme(isDark: true, transparentScaffold: false);

      expect(light.scaffoldBackgroundColor, isNot(Colors.transparent));
      expect(dark.scaffoldBackgroundColor, isNot(Colors.transparent));
      expect(light.scaffoldBackgroundColor, AppColors.background);
      expect(dark.scaffoldBackgroundColor, AppColors.backgroundDark);
    });

    test('Custom theme provides transparent scaffold and app bar backgrounds', () {
      final light = AppTheme.buildTheme(isDark: false, transparentScaffold: true);
      final dark = AppTheme.buildTheme(isDark: true, transparentScaffold: true);

      expect(light.scaffoldBackgroundColor, Colors.transparent);
      expect(dark.scaffoldBackgroundColor, Colors.transparent);
      expect(light.appBarTheme.backgroundColor, Colors.transparent);
      expect(dark.appBarTheme.backgroundColor, Colors.transparent);
    });
  });

  group('AnimatedThemeBackground Widget Tests', () {
    testWidgets('defaultTheme renders child without any background stack', (tester) async {
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

    testWidgets('space theme renders AnimatedThemeCanvas behind child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedThemeBackground(
            theme: SchedlyVisualTheme.space,
            child: Text('Foreground Content'),
          ),
        ),
      );

      expect(find.text('Foreground Content'), findsOneWidget);
      expect(find.byType(AnimatedThemeCanvas), findsOneWidget);
    });
  });
}
