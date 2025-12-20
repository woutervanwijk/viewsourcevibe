import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/screens/home_screen.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  group('Title Navigation Test', () {
    testWidgets('Title should navigate to AboutScreen when tapped', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      final htmlService = HtmlService();
      final settings = AppSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => htmlService),
            ChangeNotifierProvider(create: (_) => settings),
          ],
          child: MaterialApp(
            home: HomeScreen(),
            routes: {
              '/about': (context) => AboutScreen(),
            },
          ),
        ),
      );

      // Wait for the widget to build completely
      await tester.pumpAndSettle();

      // Find the AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Find the title text "View\nSource\nVibe"
      final titleText = find.text('View\nSource\nVibe');
      expect(titleText, findsOneWidget);

      // Tap the title text directly (the GestureDetector should handle the tap)
      await tester.tap(titleText, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify that AboutScreen is pushed onto the navigation stack
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    testWidgets('Title should contain icon and text', (WidgetTester tester) async {
      final htmlService = HtmlService();
      final settings = AppSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => htmlService),
            ChangeNotifierProvider(create: (_) => settings),
          ],
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Find the title text "View\nSource\nVibe"
      final titleText = find.text('View\nSource\nVibe');
      expect(titleText, findsOneWidget);

      // Find the Row that contains this text
      final titleRow = find.ancestor(
        of: titleText,
        matching: find.byType(Row),
      );
      expect(titleRow, findsOneWidget);

      // Find the Image (icon) inside the Row
      final iconImage = find.descendant(
        of: titleRow,
        matching: find.byType(Image),
      );
      expect(iconImage, findsOneWidget);
    });
  });
}