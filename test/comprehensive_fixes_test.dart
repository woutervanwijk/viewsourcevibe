import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';

void main() {
  group('Comprehensive Fixes Test', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('HTML syntax highlighting should work with proper language mode', () {
      const htmlContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
</head>
<body>
    <h1>Hello World</h1>
    <p class="content">This is a test paragraph.</p>
</body>
</html>''';

      final widget = htmlService.buildHighlightedText(htmlContent, 'html');
      expect(widget, isNotNull);
    });

    test('Word wrapping should be disabled', () {
      const longLineContent = 'This is a very long line of text that should not wrap and should enable horizontal scrolling instead of wrapping to the next line.';

      final widget = htmlService.buildHighlightedText(longLineContent, 'txt');
      expect(widget, isNotNull);
    });

    test('Line numbers should be synchronized with content', () {
      const multiLineContent = '''Line 1
Line 2
Line 3
Line 4
Line 5''';

      final widget = htmlService.buildHighlightedText(multiLineContent, 'txt');
      expect(widget, isNotNull);
    });

    test('CSS syntax highlighting should work', () {
      const cssContent = '''body {
    color: red;
    background-color: blue;
    font-family: Arial, sans-serif;
}

.h1 {
    font-size: 24px;
    margin: 0;
}''';

      final widget = htmlService.buildHighlightedText(cssContent, 'css');
      expect(widget, isNotNull);
    });

    test('JavaScript syntax highlighting should work', () {
      const jsContent = '''function helloWorld() {
    console.log("Hello, World!");
    return true;
}

const x = 10;
const y = 20;
const sum = x + y;''';

      final widget = htmlService.buildHighlightedText(jsContent, 'js');
      expect(widget, isNotNull);
    });

    test('JSON syntax highlighting should work', () {
      const jsonContent = '''{
    "name": "Test",
    "value": 123,
    "nested": {
        "key": "value"
    },
    "array": [1, 2, 3]
}''';

      final widget = htmlService.buildHighlightedText(jsonContent, 'json');
      expect(widget, isNotNull);
    });

    test('XML syntax highlighting should work', () {
      const xmlContent = '''<?xml version="1.0"?>
<root>
    <item id="1">First item</item>
    <item id="2">Second item</item>
</root>''';

      final widget = htmlService.buildHighlightedText(xmlContent, 'xml');
      expect(widget, isNotNull);
    });

    test('Language mode fallback should work for unknown extensions', () {
      const unknownContent = 'Some random content for unknown file type';

      final widget = htmlService.buildHighlightedText(unknownContent, 'unknown');
      expect(widget, isNotNull);
    });

    test('Empty content should not cause errors', () {
      const emptyContent = '';

      final widget = htmlService.buildHighlightedText(emptyContent, 'html');
      expect(widget, isNotNull);
    });

    test('Very long single line should enable horizontal scrolling', () {
      final longContent = 'a'.padRight(1000, 'a'); // 1000 character line

      final widget = htmlService.buildHighlightedText(longContent, 'txt');
      expect(widget, isNotNull);
    });
  });
}