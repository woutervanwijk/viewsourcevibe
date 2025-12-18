import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/widgets/url_input.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  group('URL Input Clearing Tests', () {
    
    late HtmlService htmlService;
    
    setUp(() {
      htmlService = HtmlService();
    });

    testWidgets('URL input shows URL when web content is loaded', (WidgetTester tester) async {
      // Build the URL input widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<HtmlService>(
              create: (_) => htmlService,
              child: const UrlInput(),
            ),
          ),
        ),
      );

      // Verify initial state
      final urlField = find.byType(TextField);
      expect(urlField, findsOneWidget);

      // Load a web URL
      final webFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com/test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
      );

      htmlService.loadFile(webFile);
      await tester.pumpAndSettle();

      // Verify URL is shown
      final textField = tester.widget<TextField>(urlField);
      expect(textField.controller?.text, 'https://example.com/test.html');
    });

    testWidgets('URL input clears when local file is loaded', (WidgetTester tester) async {
      // Build the URL input widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<HtmlService>(
              create: (_) => htmlService,
              child: const UrlInput(),
            ),
          ),
        ),
      );

      // First, set some text in the URL field
      await tester.enterText(find.byType(TextField), 'https://example.com');
      await tester.pump();

      // Verify text is set
      final urlField = find.byType(TextField);
      final textField = tester.widget<TextField>(urlField);
      expect(textField.controller?.text, 'https://example.com');

      // Load a local file
      final localFile = HtmlFile(
        name: 'local.html',
        path: '/path/to/local.html',
        content: '<html><body>Local</body></html>',
        lastModified: DateTime.now(),
        size: 30,
      );

      htmlService.loadFile(localFile);
      await tester.pumpAndSettle();

      // Verify URL is cleared
      final updatedTextField = tester.widget<TextField>(urlField);
      expect(updatedTextField.controller?.text, '');
    });

    testWidgets('URL input clears when switching from web to local file', (WidgetTester tester) async {
      // Build the URL input widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<HtmlService>(
              create: (_) => htmlService,
              child: const UrlInput(),
            ),
          ),
        ),
      );

      // Load a web URL first
      final webFile = HtmlFile(
        name: 'test.html',
        path: 'https://example.com/test.html',
        content: '<html><body>Test</body></html>',
        lastModified: DateTime.now(),
        size: 32,
      );

      htmlService.loadFile(webFile);
      await tester.pumpAndSettle();

      // Verify URL is shown
      final urlField = find.byType(TextField);
      final textField = tester.widget<TextField>(urlField);
      expect(textField.controller?.text, 'https://example.com/test.html');

      // Now load a local file
      final localFile = HtmlFile(
        name: 'local.html',
        path: '/path/to/local.html',
        content: '<html><body>Local</body></html>',
        lastModified: DateTime.now(),
        size: 30,
      );

      htmlService.loadFile(localFile);
      await tester.pumpAndSettle();

      // Verify URL is cleared
      final updatedTextField = tester.widget<TextField>(urlField);
      expect(updatedTextField.controller?.text, '');
    });
  });

  group('URL Input Edge Cases', () {
    
    testWidgets('URL input handles file path edge cases', (WidgetTester tester) async {
      final htmlService = HtmlService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<HtmlService>(
              create: (_) => htmlService,
              child: const UrlInput(),
            ),
          ),
        ),
      );

      // Test various file path formats
      final testCases = [
        HtmlFile(name: 'file.html', path: 'file:///path/to/file.html', content: '', lastModified: DateTime.now(), size: 0),
        HtmlFile(name: 'file.html', path: '/absolute/path/file.html', content: '', lastModified: DateTime.now(), size: 0),
        HtmlFile(name: 'file.html', path: 'relative/path/file.html', content: '', lastModified: DateTime.now(), size: 0),
        HtmlFile(name: 'file.html', path: 'assets/sample.html', content: '', lastModified: DateTime.now(), size: 0),
      ];

      for (final file in testCases) {
        htmlService.loadFile(file);
        await tester.pumpAndSettle();

        final urlField = find.byType(TextField);
        final textField = tester.widget<TextField>(urlField);
        expect(textField.controller?.text, '', reason: 'URL should be cleared for path: ${file.path}');
      }
    });

    testWidgets('URL input handles URL edge cases', (WidgetTester tester) async {
      final htmlService = HtmlService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<HtmlService>(
              create: (_) => htmlService,
              child: const UrlInput(),
            ),
          ),
        ),
      );

      // Test various URL formats
      final testCases = [
        'http://example.com',
        'https://example.com',
        'https://www.example.com/path',
        'http://sub.example.com:8080/path?query=value',
      ];

      for (final url in testCases) {
        final file = HtmlFile(name: 'test.html', path: url, content: '', lastModified: DateTime.now(), size: 0);
        htmlService.loadFile(file);
        await tester.pumpAndSettle();

        final urlField = find.byType(TextField);
        final textField = tester.widget<TextField>(urlField);
        expect(textField.controller?.text, url, reason: 'URL should be shown for URL: $url');
      }
    });
  });
}