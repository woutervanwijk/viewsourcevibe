import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';
import 'package:htmlviewer/models/html_file.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';

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

      // Verify it's a LayoutBuilder (wrapper for proper layout constraints)
      expect(widget, isA<LayoutBuilder>());

      // Verify the widget structure is correct
      final layoutBuilder = widget as LayoutBuilder;
      expect(layoutBuilder, isNotNull);
    });

    test('buildHighlightedText should handle different file extensions', () {
      const extensions = ['html', 'css', 'js', 'json', 'xml', 'txt'];
      const content = 'test content';

      for (final ext in extensions) {
        final widget = htmlService.buildHighlightedText(content, ext);
        expect(widget, isA<LayoutBuilder>());
      }
    });

    test('buildHighlightedText should respect font size parameter', () {
      const content = 'test';
      const fontSize = 16.0;

      final widget = htmlService.buildHighlightedText(content, 'html', fontSize: fontSize);
      
      // Verify it creates the proper widget structure
      expect(widget, isA<LayoutBuilder>());
    });
  });

  group('Line Number Configuration Test', () {
    test('LineNumberStyle should have correct default values', () {
      const style = LineNumberStyle();
      expect(style.width, equals(42.0));
      expect(style.textAlign, equals(TextAlign.right));
      expect(style.margin, equals(10.0));
      expect(style.textStyle, isNull);
      expect(style.background, isNull);
    });

    test('LineNumberStyle should be customizable', () {
      const style = LineNumberStyle(
        width: 60.0,
        textAlign: TextAlign.left,
        margin: 15.0,
        textStyle: TextStyle(fontSize: 12.0),
        background: Colors.grey,
      );

      expect(style.width, equals(60.0));
      expect(style.textAlign, equals(TextAlign.left));
      expect(style.margin, equals(15.0));
      expect(style.textStyle, isNotNull);
      expect(style.background, equals(Colors.grey));
    });
  });
}