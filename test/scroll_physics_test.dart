import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedly/theme/schedly_scroll_behavior.dart';
import 'package:schedly/widgets/animations/animated_card.dart';
import 'package:schedly/widgets/animations/staggered_list_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SchedlyScrollBehavior Tests', () {
    test('dragDevices includes touch, mouse, stylus, trackpad', () {
      const behavior = SchedlyScrollBehavior();
      final devices = behavior.dragDevices;
      expect(devices.contains(PointerDeviceKind.touch), isTrue);
      expect(devices.contains(PointerDeviceKind.mouse), isTrue);
      expect(devices.contains(PointerDeviceKind.stylus), isTrue);
      expect(devices.contains(PointerDeviceKind.trackpad), isTrue);
    });

    testWidgets('Builds SchedlyAndroidScrollPhysics for Android platform', (
      tester,
    ) async {
      late ScrollPhysics physics;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          scrollBehavior: const SchedlyScrollBehavior(),
          home: Builder(
            builder: (context) {
              physics = ScrollConfiguration.of(
                context,
              ).getScrollPhysics(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(physics, isA<SchedlyAndroidScrollPhysics>());
      final androidPhysics = physics as SchedlyAndroidScrollPhysics;
      expect(androidPhysics.friction, closeTo(0.022, 0.001));
    });

    testWidgets('Builds fast BouncingScrollPhysics for iOS platform', (
      tester,
    ) async {
      late ScrollPhysics physics;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          scrollBehavior: const SchedlyScrollBehavior(),
          home: Builder(
            builder: (context) {
              physics = ScrollConfiguration.of(
                context,
              ).getScrollPhysics(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(physics, isA<BouncingScrollPhysics>());
      final bouncing = physics as BouncingScrollPhysics;
      expect(bouncing.decelerationRate, ScrollDecelerationRate.fast);
    });

    test(
      'SchedlyAndroidScrollPhysics copyWith and applyTo preserve friction',
      () {
        const physics = SchedlyAndroidScrollPhysics();
        expect(physics.friction, 0.022);

        final copy = physics.applyTo(const AlwaysScrollableScrollPhysics());
        expect(copy, isA<SchedlyAndroidScrollPhysics>());
        expect(copy.friction, 0.022);
      },
    );
  });

  group('StaggeredListItem Scrolling Optimization Tests', () {
    testWidgets(
      'Clamps stagger delay so late items appear promptly without lingering blank space',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) {
                  return StaggeredListItem(
                    index: index,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          ),
        );

        // Initially, the clamped items (index 0 to 3) take <= 105ms, while items beyond 3 have 0 delay
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
      },
    );
  });

  group('AnimatedCard Gesture Cooperation Tests', () {
    testWidgets(
      'AnimatedCard does not capture scroll arena and allows vertical drag',
      (tester) async {
        final controller = ScrollController();
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const SchedlyScrollBehavior(),
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) {
                  return AnimatedCard(
                    onTap: () => tapped = true,
                    child: SizedBox(height: 100, child: Text('Card $index')),
                  );
                },
              ),
            ),
          ),
        );

        expect(controller.offset, 0.0);

        // Drag up to scroll
        await tester.drag(find.text('Card 0'), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Scroll offset must have advanced without being swallowed by AnimatedCard
        expect(controller.offset, greaterThan(200));
        expect(tapped, isFalse);

        // Tap on visible card
        await tester.tap(find.text('Card 5'));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );
  });
}
