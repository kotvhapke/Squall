// @TestOn("browser")
//
// Web-only test suite.
// Run with: flutter test --platform chrome
//
// The app uses dart:html (file picker, localStorage)
// which is only available on the web platform.
// On Dart VM (flutter test) this test is skipped.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:squall/app.dart';
import 'package:squall/core/settings/settings_provider.dart';
import 'package:squall/core/settings/persistence.dart';

void main() {
  testWidgets('Squall app shows branding', (WidgetTester tester) async {
    final store = MemoryPersistence();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(store: store),
        child: const SquallApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Squall'), findsWidgets);
  });
}