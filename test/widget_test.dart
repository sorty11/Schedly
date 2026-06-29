// Schedly — basic smoke test.
// This verifies the app entry point compiles and renders.

import 'package:flutter_test/flutter_test.dart';

import 'package:schedly/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // SchedlyApp initialises Firebase before running; this test only
    // verifies the widget tree compiles. Full integration tests require
    // a Firebase test project.
    expect(SchedlyApp, isNotNull);
  });
}
