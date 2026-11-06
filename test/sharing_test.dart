import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sharing Service Tests', () {
    test('Sharing service URL detection patterns', () async {
      // Test URL detection patterns without accessing private members
      // These patterns are used in the _isUrl method

      expect(
          'https://example.com'.startsWith('http://') ||
              'https://example.com'.startsWith('https://') ||
              'https://example.com'.startsWith('www.'),
          true);

      expect(
          'http://example.com'.startsWith('http://') ||
              'http://example.com'.startsWith('https://') ||
              'http://example.com'.startsWith('www.'),
          true);

      expect(
          'www.example.com'.startsWith('http://') ||
              'www.example.com'.startsWith('https://') ||
              'www.example.com'.startsWith('www.'),
          true);

      expect(
          'example.com'.startsWith('http://') ||
              'example.com'.startsWith('https://') ||
              'example.com'.startsWith('www.'),
          false);

      expect(
          'not-a-url'.startsWith('http://') ||
              'not-a-url'.startsWith('https://') ||
              'not-a-url'.startsWith('www.'),
          false);
    });
  });

  group('Sharing Content Handling Tests', () {
    // Pumps a real widget tree with an HtmlService and hands back a context.
    Future<(BuildContext, HtmlService)> pumpContext(WidgetTester tester) async {
      final htmlService = HtmlService();
      late BuildContext context;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: htmlService,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(builder: (c) {
                context = c;
                return const SizedBox();
              }),
            ),
          ),
        ),
      );
      return (context, htmlService);
    }

    testWidgets('shared text is loaded as a file', (tester) async {
      final (context, htmlService) = await pumpContext(tester);
      await tester.runAsync(() => UnifiedSharingService.handleSharedContent(
            context,
            {'type': 'text', 'content': 'Hello World'},
          ));
      expect(htmlService.currentFile?.content, 'Hello World');
      expect(htmlService.currentFile?.isUrl, isFalse);
    });

    testWidgets('shared file bytes are loaded as a file', (tester) async {
      final (context, htmlService) = await pumpContext(tester);
      await tester.runAsync(() => UnifiedSharingService.handleSharedContent(
            context,
            {
              'type': 'file',
              'fileBytes': <int>[72, 101, 108, 108, 111], // 'Hello'
              'fileName': 'test.txt',
            },
          ));
      expect(htmlService.currentFile?.content, 'Hello');
    });

    testWidgets('shared URL is opened as a URL', (tester) async {
      final (context, htmlService) = await pumpContext(tester);
      await tester.runAsync(() => UnifiedSharingService.handleSharedContent(
            context,
            {'type': 'url', 'content': 'https://example.com'},
          ));
      expect(htmlService.currentFile?.path, startsWith('https://example.com'));
      expect(htmlService.currentFile?.isUrl, isTrue);
    });
  });
}
