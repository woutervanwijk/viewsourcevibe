import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/widgets/source_viewer.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:provider/provider.dart';

void main() {
  final sampleFile = HtmlFile(
    name: 'test.html',
    path: 'test.html',
    content: '<html><body>Test Content</body></html>',
    lastModified: DateTime.now(),
    size: 32,
    isUrl: false,
  );

  // Loads the file (real async work) and shows it in a SourceViewer.
  // Uses fixed pumps: the editor's blinking cursor never settles.
  Future<HtmlService> pumpViewer(WidgetTester tester) async {
    final htmlService = HtmlService();
    await tester.runAsync(() => htmlService.loadFile(sampleFile));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HtmlService>.value(value: htmlService),
          ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          home: Scaffold(body: SourceViewer(file: htmlService.currentFile!)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return htmlService;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('HTML')); // header shows the detected type
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // The type list is longer than the test screen: scroll an item into view.
  Future<Finder> menuItem(WidgetTester tester, String label) async {
    final item = find.text(label);
    await tester.scrollUntilVisible(
      item,
      100,
      scrollable: find
          .descendant(
              of: find.byType(BottomSheet), matching: find.byType(Scrollable))
          .first,
    );
    return item;
  }

  testWidgets('header shows the detected type and opens the type menu',
      (tester) async {
    await pumpViewer(tester);
    expect(find.text('HTML'), findsOneWidget);

    await openMenu(tester);

    expect(find.text('Select Content Type'), findsOneWidget);
    expect(await menuItem(tester, 'CSS'), findsOneWidget);
    expect(await menuItem(tester, 'JavaScript'), findsOneWidget);
  });

  testWidgets('choosing a type changes highlighting, not the file name',
      (tester) async {
    final htmlService = await pumpViewer(tester);
    await openMenu(tester);

    await tester.tap(await menuItem(tester, 'JavaScript'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(htmlService.selectedContentType, 'javascript');
    expect(htmlService.currentFile?.name, 'test.html');
    expect(find.text('Select Content Type'), findsNothing);

    // Let the debounced auto-save timer (1.5s) fire before teardown.
    await tester.pump(const Duration(seconds: 2));
  });
}
