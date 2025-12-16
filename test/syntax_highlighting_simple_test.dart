import 'package:flutter_test/flutter_test.dart';
import 'package:htmlviewer/services/html_service.dart';

void main() {
  group('Syntax Highlighting Simple Tests', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('getLanguageForExtension should return correct language names', () {
      expect(htmlService.getLanguageForExtension('html'), equals('vbscript-html'));
      expect(htmlService.getLanguageForExtension('htm'), equals('vbscript-html'));
      expect(htmlService.getLanguageForExtension('css'), equals('css'));
      expect(htmlService.getLanguageForExtension('js'), equals('javascript'));
      expect(htmlService.getLanguageForExtension('json'), equals('json'));
      expect(htmlService.getLanguageForExtension('xml'), equals('xml'));
      expect(htmlService.getLanguageForExtension('txt'), equals('plaintext'));
      expect(htmlService.getLanguageForExtension('unknown'), equals('plaintext'));
    });

    test('buildHighlightedText should create widget for HTML', () {
      const htmlContent = '<html><body><h1>Hello World</h1></body></html>';
      
      final widget = htmlService.buildHighlightedText(htmlContent, 'html');
      
      // Verify it creates a widget (the specific type doesn't matter for this test)
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should create widget for CSS', () {
      const cssContent = 'body { color: red; background: blue; }';
      
      final widget = htmlService.buildHighlightedText(cssContent, 'css');
      
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should create widget for JavaScript', () {
      const jsContent = 'function hello() { console.log("Hello World"); }';
      
      final widget = htmlService.buildHighlightedText(jsContent, 'js');
      
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should create widget for JSON', () {
      const jsonContent = '{"name": "test", "value": 123}';
      
      final widget = htmlService.buildHighlightedText(jsonContent, 'json');
      
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should create widget for XML', () {
      const xmlContent = '<?xml version="1.0"?><root><item>test</item></root>';
      
      final widget = htmlService.buildHighlightedText(xmlContent, 'xml');
      
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should create widget for unknown extensions', () {
      const unknownContent = 'some random content';
      
      final widget = htmlService.buildHighlightedText(unknownContent, 'unknown');
      
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should handle empty content', () {
      const emptyContent = '';
      
      final widget = htmlService.buildHighlightedText(emptyContent, 'html');
      
      expect(widget, isNotNull);
    });

    test('buildHighlightedText should handle different font sizes', () {
      const content = 'test';
      
      // Test different font sizes
      final widget1 = htmlService.buildHighlightedText(content, 'html', fontSize: 12.0);
      final widget2 = htmlService.buildHighlightedText(content, 'html', fontSize: 16.0);
      final widget3 = htmlService.buildHighlightedText(content, 'html', fontSize: 18.0);
      
      expect(widget1, isNotNull);
      expect(widget2, isNotNull);
      expect(widget3, isNotNull);
    });
  });
}