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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squall/app.dart';
import 'package:squall/core/settings/settings_provider.dart';

void main() {
  testWidgets('Squall app shows branding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: const SquallApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Squall'), findsWidgets);
  });
}