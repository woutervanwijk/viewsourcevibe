import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/widgets/metadata_view.dart';
import 'package:view_source_vibe/widgets/services_view.dart';
import 'package:view_source_vibe/widgets/media_view.dart';
import 'package:provider/provider.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tab functionality tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    // loadFile extracts metadata in an isolate, which only runs on the real
    // event loop, so load outside the fake-async test zone and wait for it.
    Future<void> load(WidgetTester tester, HtmlFile file) =>
        tester.runAsync(() async {
          await htmlService.loadFile(file);
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while ((htmlService.isExtractingMetadata ||
                  htmlService.pageMetadata == null) &&
              DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 20));
          }
        });

    testWidgets('MetadataView shows loading then content',
        (WidgetTester tester) async {
      // Load a test file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content:
            '<html><head><title>Test Page</title></head><body><h1>Hello World</h1></body></html>',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: true,
      );

      await load(tester, testFile);

      // Build the MetadataView widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<HtmlService>.value(value: htmlService),
              ChangeNotifierProvider(create: (_) => AppSettings()),
            ],
            child: const Scaffold(
              body: MetadataView(),
            ),
          ),
        ),
      );

      // Wait for any animations or async operations
      await tester.pumpAndSettle();

      // Verify that metadata is available
      expect(htmlService.pageMetadata, isNotNull);
      expect(htmlService.pageMetadata!['title'], 'Test Page');

      // The view should not show a loading indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The view should show the title (header and previews)
      expect(find.text('Test Page'), findsWidgets);
    });

    testWidgets('ServicesView handles empty services gracefully',
        (WidgetTester tester) async {
      // Load a test file with no services
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content:
            '<html><head><title>Test</title></head><body><p>Simple page</p></body></html>',
        lastModified: DateTime.now(),
        size: 50,
        isUrl: true,
      );

      await load(tester, testFile);

      // Build the ServicesView widget
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HtmlService>.value(
            value: htmlService,
            child: const Scaffold(
              body: ServicesView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash and should show "No Services Detected" message
      expect(find.text('No Services Detected'), findsOneWidget);
    });

    testWidgets('MediaView handles empty media gracefully',
        (WidgetTester tester) async {
      // Load a test file with no media
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content:
            '<html><head><title>Test</title></head><body><p>No media here</p></body></html>',
        lastModified: DateTime.now(),
        size: 50,
        isUrl: true,
      );

      await load(tester, testFile);

      // Build the MediaView widget
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HtmlService>.value(
            value: htmlService,
            child: const Scaffold(
              body: MediaView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash and should show the empty-media message
      expect(find.text('No Images or Videos found'), findsOneWidget);
    });
  });
}
