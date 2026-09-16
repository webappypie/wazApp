// test/widget_test.dart
//
// Trivial smoke test — verifies the app boots without errors.
// Phase 0 verification item: confirm flutter_test works.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wapptidy/app.dart';

void main() {
  testWidgets('App boots and renders navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: WappTidyApp()),
    );
    // App renders without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
    // Bottom nav is present (5 destinations).
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}
