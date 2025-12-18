import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('XML Detection and Filename Handling', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('Detects XML content and assigns .xml extension', () {
      const xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<root>
  <element>Value</element>
</root>''';

      final result = htmlService.ensureHtmlExtension('test', xmlContent);
      expect(result, 'file.xml');
    });

    test('Detects XML without declaration but with namespace', () {
      const xmlContent = '''<root xmlns="http://example.com">
  <element>Value</element>
</root>''';

      final result = htmlService.ensureHtmlExtension('data', xmlContent);
      expect(result, 'file.xml');
    });

    test('Detects RSS feed as XML', () {
      const rssContent = '''<rss version="2.0">
  <channel>
    <title>Test Feed</title>
  </channel>
</rss>''';

      final result = htmlService.ensureHtmlExtension('feed', rssContent);
      expect(result, 'file.xml');
    });

    test('Detects SVG as XML', () {
      const svgContent = '''<svg width="100" height="100">
  <circle cx="50" cy="50" r="40" fill="red" />
</svg>''';

      final result = htmlService.ensureHtmlExtension('image', svgContent);
      expect(result, 'file.xml');
    });

    test('Handles empty filename', () {
      const xmlContent = '<root><item>test</item></root>';

      final result = htmlService.ensureHtmlExtension('', xmlContent);
      expect(result, 'file.xml');
    });

    test('Handles unclear filename (just "/")', () {
      const xmlContent = '<data>content</data>';

      final result = htmlService.ensureHtmlExtension('/', xmlContent);
      expect(result, 'file.xml');
    });

    test('Handles unclear filename (just "index")', () {
      const xmlContent = '<config>settings</config>';

      final result = htmlService.ensureHtmlExtension('index', xmlContent);
      expect(result, 'file.xml');
    });

    test('Preserves existing extensions', () {
      const xmlContent = '<root>data</root>';

      final result = htmlService.ensureHtmlExtension('file.xml', xmlContent);
      expect(result, 'file.xml');
    });

    test('Detects HTML vs XML correctly', () {
      const htmlContent = '''<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body><p>Hello</p></body>
</html>''';

      final result = htmlService.ensureHtmlExtension('page', htmlContent);
      expect(result, 'file.html');
    });

    test('Falls back to .txt for non-XML text', () {
      const textContent = 'This is plain text content without any XML tags.';

      final result = htmlService.ensureHtmlExtension('text', textContent);
      expect(result, 'file.txt');
    });

    test('XML detection with self-closing tags', () {
      const xmlContent = '''<config>
  <setting name="test" value="value" />
  <option enabled="true" />
</config>''';

      final result = htmlService.ensureHtmlExtension('config', xmlContent);
      expect(result, 'file.xml');
    });

    test('XML detection with comments', () {
      const xmlContent = '''<!-- XML Configuration -->
<root>
  <!-- Item comment -->
  <item>value</item>
</root>''';

      final result = htmlService.ensureHtmlExtension('config', xmlContent);
      expect(result, 'file.xml');
    });

    test('Handles filenames without path separators', () {
      const xmlContent = '<data>test</data>';

      final result = htmlService.ensureHtmlExtension('unknown', xmlContent);
      expect(result, 'file.xml');
    });
  });

  group('XML Parsing Helper Methods', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    test('tryParseAsXml returns true for valid XML', () {
      const validXml = '''<?xml version="1.0"?>
<catalog>
  <book id="1">
    <title>Test Book</title>
  </book>
</catalog>''';

      expect(htmlService.tryParseAsXml(validXml), true);
    });

    test('tryParseAsXml returns false for non-XML content', () {
      const nonXml = 'This is not XML content';
      expect(htmlService.tryParseAsXml(nonXml), false);
    });

    test('tryParseAsXml returns false for HTML content', () {
      const html = '''<!DOCTYPE html>
<html>
<body>Hello World</body>
</html>''';
      expect(htmlService.tryParseAsXml(html), false);
    });

    test('tryParseAsXml detects SOAP messages', () {
      const soap = '''<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    <GetPrice>
      <Item>Apples</Item>
    </GetPrice>
  </soap:Body>
</soap:Envelope>''';

      expect(htmlService.tryParseAsXml(soap), true);
    });

    test('tryParseAsXml detects WSDL', () {
      const wsdl = '''<definitions name="HelloService"
  targetNamespace="http://www.examples.com/wsdl/HelloService.wsdl"
  xmlns="http://schemas.xmlsoap.org/wsdl/">
  <message name="SayHelloRequest"/>
</definitions>''';

      expect(htmlService.tryParseAsXml(wsdl), true);
    });

    test('hasBalancedTags returns true for balanced tags', () {
      const balanced = '<root><child></child></root>';
      expect(htmlService.hasBalancedTags(balanced), true);
    });

    test('hasBalancedTags returns false for unbalanced tags', () {
      const unbalanced = '<root><child></root>';
      expect(htmlService.hasBalancedTags(unbalanced), false);
    });

    test('hasBalancedTags handles self-closing tags', () {
      const selfClosing = '<root><item/><item/></root>';
      expect(htmlService.hasBalancedTags(selfClosing), true);
    });
  });

  group('Integration Tests', () {
    test('XML content gets XML syntax highlighting', () {
      const xmlContent = '''<?xml version="1.0"?>
<books>
  <book>
    <title>Flutter Guide</title>
    <author>John Doe</author>
  </book>
</books>''';

      final htmlService = HtmlService();
      final filename = htmlService.ensureHtmlExtension('data', xmlContent);
      final language = htmlService.getLanguageForExtension('xml');

      expect(filename, 'file.xml');
      expect(language, 'xml');
    });

    test('Plain text without XML structure gets text extension', () {
      const textContent = '''Some text that looks like it might be XML but isn't:
<this is not a real tag because it's not properly formatted
and doesn't have proper closing>''';

      final htmlService = HtmlService();
      final filename = htmlService.ensureHtmlExtension('notes', textContent);

      expect(filename, 'notes.txt');
    });
  });
}