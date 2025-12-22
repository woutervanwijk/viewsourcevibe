import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/widgets/file_viewer.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('FileViewer shows content type menu when tapped', (WidgetTester tester) async {
    // Create a sample file
    final sampleFile = HtmlFile(
      name: 'test.html',
      path: 'test.html',
      content: '<html><body>Test Content</body></html>',
      lastModified: DateTime.now(),
      size: 32,
      isUrl: false,
    );

    // Create services
    final htmlService = HtmlService();
    final settings = AppSettings();

    // Load the file
    await htmlService.loadFile(sampleFile);

    // Build the widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HtmlService>.value(value: htmlService),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FileViewer(file: sampleFile),
          ),
        ),
      ),
    );

    // Verify the file viewer is displayed
    expect(find.text('test.html'), findsOneWidget);
    expect(find.text('Test Content'), findsOneWidget);

    // Tap the filename area to show content type menu
    final filenameArea = find.text('test.html');
    await tester.tap(filenameArea);
    await tester.pumpAndSettle();

    // Verify the content type menu is shown
    expect(find.text('Select Content Type'), findsOneWidget);
    expect(find.text('JavaScript'), findsOneWidget);
    expect(find.text('CSS'), findsOneWidget);
    expect(find.text('HTML'), findsOneWidget);
  });

  testWidgets('FileViewer updates content type when selected', (WidgetTester tester) async {
    // Create a sample file
    final sampleFile = HtmlFile(
      name: 'test.html',
      path: 'test.html',
      content: '<html><body>Test Content</body></html>',
      lastModified: DateTime.now(),
      size: 32,
      isUrl: false,
    );

    // Create services
    final htmlService = HtmlService();
    final settings = AppSettings();

    // Load the file
    await htmlService.loadFile(sampleFile);

    // Build the widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HtmlService>.value(value: htmlService),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FileViewer(file: sampleFile),
          ),
        ),
      ),
    );

    // Tap the filename area to show content type menu
    final filenameArea = find.text('test.html');
    await tester.tap(filenameArea);
    await tester.pumpAndSettle();

    // Find and tap the JavaScript option
    final javascriptOption = find.text('JavaScript').first;
    await tester.tap(javascriptOption);
    await tester.pumpAndSettle();

    // Verify the filename has changed to reflect the new content type
    expect(find.text('test.js'), findsOneWidget);
    expect(find.text('test.html'), findsNothing);
  });
}