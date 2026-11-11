import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/screens/home_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/reader_service.dart';

import 'fixtures/inspection/full_page.dart';
import 'fixtures/inspection/pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tab overview (dots) menu', () {
    testWidgets('dots button opens a dialog listing all tabs; tapping one switches',
        (WidgetTester tester) async {
      // Seeded HTML page; browser tab last so the WebView never builds.
      final service = makeService(seedStore(InspectionStore(), fullPage()));
      addTearDown(service.dispose);
      final settings = AppSettings()..useBrowserByDefault = false;
      service.setAppSettings(settings);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HtmlService>.value(value: service),
            ChangeNotifierProvider<ReaderService>.value(
                value: ReaderService(service)),
            ChangeNotifierProvider<AppSettings>.value(value: settings),
          ],
          child: MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The dots button sits at the right of the tab strip.
      final dots = find.byIcon(Icons.more_vert);
      expect(dots, findsOneWidget);

      final tabCount = tester.widgetList(find.byType(Tab)).length;
      expect(tabCount, greaterThan(2));

      await tester.tap(dots);
      await tester.pumpAndSettle();

      // The dialog lists every tab at once (one tile per tab).
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byType(Icon)),
        findsNWidgets(tabCount),
      );
      expect(find.descendant(of: dialog, matching: find.text('Source')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('Reader')),
          findsOneWidget);

      // Tapping a tab in the dialog closes it and switches the tab.
      final before = service.activeTabIndex;
      expect(before, 0);
      await tester.tap(
          find.descendant(of: dialog, matching: find.text('Media')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(service.activeTabIndex, isNot(before));
    });
  });
}
