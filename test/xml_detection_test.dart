import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Content detection is strict: XML needs a declaration or a known XML root
  // (rss, feed, svg); other markup is judged by the server's Content-Type.
  group('XML content detection', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    Future<String?> detect(String name, String content) async {
      await htmlService.loadFile(HtmlFile(
        name: name,
        path: 'https://example.com/$name',
        content: content,
        lastModified: DateTime.now(),
        size: content.length,
        isUrl: true,
      ));
      return htmlService.selectedContentType;
    }

    test('XML declaration', () async {
      expect(
        await detect('test', '''<?xml version="1.0" encoding="UTF-8"?>
<root>
  <element>Value</element>
</root>'''),
        'xml',
      );
    });

    test('RSS feed', () async {
      expect(
        await detect('feed', '''<rss version="2.0">
  <channel>
    <title>Test Feed</title>
  </channel>
</rss>'''),
        'xml',
      );
      expect(htmlService.currentFile?.name, 'RSS Page.xml');
    });

    test('SVG', () async {
      expect(
        await detect('image', '''<svg width="100" height="100">
  <circle cx="50" cy="50" r="40" fill="red" />
</svg>'''),
        'xml',
      );
    });

    test('HTML is not XML', () async {
      expect(
        await detect('page', '''<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body><p>Hello</p></body>
</html>'''),
        'html',
      );
    });

    test('generic markup without declaration is not guessed as XML', () async {
      expect(await detect('config', '<config>settings</config>'), 'plaintext');
    });

    test('plain text', () async {
      expect(
        await detect(
            'text', 'This is plain text content without any XML tags.'),
        'plaintext',
      );
    });

    test('extensionless names get a neutral filename', () async {
      await detect('', '<root><item>test</item></root>');
      expect(htmlService.currentFile?.name, 'index.html');
    });

    test('existing extension is kept', () async {
      await detect('file.xml', '<root>data</root>');
      expect(htmlService.currentFile?.name, 'file.xml');
    });
  });

  group('tryParseAsXml', () {
    final htmlService = HtmlService();

    test('valid XML', () async {
      expect(await htmlService.tryParseAsXml('''<?xml version="1.0"?>
<catalog>
  <book id="1">
    <title>Test Book</title>
  </book>
</catalog>'''), isTrue);
    });

    test('plain text', () async {
      expect(
          await htmlService.tryParseAsXml('This is not XML content'), isFalse);
    });

    test('HTML that is not well-formed XML', () async {
      expect(
        await htmlService
            .tryParseAsXml('<html><body>Line<br>break</body></html>'),
        isFalse,
      );
    });

    test('SOAP message', () async {
      expect(
        await htmlService.tryParseAsXml(
            '''<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    <GetPrice><Item>Apples</Item></GetPrice>
  </soap:Body>
</soap:Envelope>'''),
        isTrue,
      );
    });

    test('WSDL', () async {
      expect(
        await htmlService.tryParseAsXml('''<definitions name="HelloService"
  xmlns="http://schemas.xmlsoap.org/wsdl/">
  <message name="SayHelloRequest"/>
</definitions>'''),
        isTrue,
      );
    });
  });
}
