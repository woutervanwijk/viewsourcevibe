import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
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

    testWidgets('MetadataView shows loading then content', (WidgetTester tester) async {
      // Load a test file
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test Page</title></head><body><h1>Hello World</h1></body></html>',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: true,
      );

      await htmlService.loadFile(testFile);

      // Wait for metadata extraction to complete
      await tester.pumpAndSettle();

      // Build the MetadataView widget
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HtmlService>.
            value(
              value: htmlService,
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

      // The view should show the title
      expect(find.text('Test Page'), findsOneWidget);
    });

    testWidgets('ServicesView handles empty services gracefully', (WidgetTester tester) async {
      // Load a test file with no services
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test</title></head><body><p>Simple page</p></body></html>',
        lastModified: DateTime.now(),
        size: 50,
        isUrl: true,
      );

      await htmlService.loadFile(testFile);
      await tester.pumpAndSettle();

      // Build the ServicesView widget
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HtmlService>.
            value(
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

    testWidgets('MediaView handles empty media gracefully', (WidgetTester tester) async {
      // Load a test file with no media
      final testFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com',
        content: '<html><head><title>Test</title></head><body><p>No media here</p></body></html>',
        lastModified: DateTime.now(),
        size: 50,
        isUrl: true,
      );

      await htmlService.loadFile(testFile);
      await tester.pumpAndSettle();

      // Build the MediaView widget
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HtmlService>.
            value(
              value: htmlService,
              child: const Scaffold(
                body: MediaView(),
              ),
            ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash and should show "No Media Detected" message
      expect(find.text('No Media Detected'), findsOneWidget);
    });
  });
}
