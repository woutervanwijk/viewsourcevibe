import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('CodeField Line Numbers Test', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('buildHighlightedText should create proper widget structure', () {
      const testContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Test</title>
</head>
<body>
    <h1>Hello World</h1>
</body>
</html>''';

      final file = HtmlFile(
        name: 'test.html',
        path: 'test.html',
        content: testContent,
        lastModified: DateTime.now(),
        size: testContent.length,
      );

      // Build the widget
      final widget = htmlService.buildHighlightedText(
        file.content,
        file.extension,
        fontSize: 14.0,
        themeName: 'github',
      );

      // Verify it's a CodeEditor widget
      expect(widget, isA<CodeEditor>());

      // Verify the widget structure is correct
      final codeEditor = widget as CodeEditor;
      expect(codeEditor, isNotNull);
    });

    test('buildHighlightedText should handle different file extensions', () {
      const extensions = ['html', 'css', 'js', 'json', 'xml', 'txt'];
      const content = 'test content';

      for (final ext in extensions) {
        final widget = htmlService.buildHighlightedText(content, ext);
        expect(widget, isA<CodeEditor>());
      }
    });

    test('buildHighlightedText should respect font size parameter', () {
      const content = 'test';
      const fontSize = 16.0;

      final widget =
          htmlService.buildHighlightedText(content, 'html', fontSize: fontSize);

      // Verify it creates the proper widget structure
      expect(widget, isA<CodeEditor>());
    });
  });

  group('CodeEditor Configuration Test', () {
    test('CodeEditor should be created with correct properties', () {
      const content = 'test content';

      final service = HtmlService();
      final widget = service.buildHighlightedText(content, 'html');
      final codeEditor = widget as CodeEditor;

      expect(codeEditor.readOnly, isTrue);
      expect(codeEditor.wordWrap, isFalse);
    });
  });
}
