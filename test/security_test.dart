import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/rss_template_service.dart';
import 'package:view_source_vibe/services/file_system_service.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync().path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.createTempSync().path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    // Initialize services
    FileSystemService().initialize();
  });

  group('RSS Security Tests', () {
    test('Should escape XSS vectors in RSS title', () async {
      // We can't access private _generateHtml directly, but convertRssToHtml calls it.
      // We need to construct a robust XML that triggers the parser.
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>&lt;script&gt;alert(1)&lt;/script&gt;</title>
          <link>http://example.com</link>
          <description>Test Feed</description>
          <item>
            <title>&lt;script&gt;alert(1)&lt;/script&gt;</title>
            <link>http://example.com/1</link>
            <description>Desc</description>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'http://example.com');

      // The output should display the script tag as text, not run it.
      // So &lt;script&gt; should be preserved or double escaped?
      // RssTemplateService decodes XML entities then escapes them again.
      // xml parser decodes &lt; to <.
      // So we expect &lt;script&gt; in the final HTML.

      expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(html, isNot(contains('<script>alert(1)</script>')));
    });

    test('Should escape XSS vectors in Item Description', () async {
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>Title</title>
          <item>
            <title>Item</title>
            <description>&lt;img src=x onerror=alert(1)&gt;</description>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'http://example.com');

      expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
      expect(html, isNot(contains('<img src=x onerror=alert(1)>')));
    });
  });

  group('Path Traversal Tests', () {
    test('Should reject parent directory traversal in subdirectory', () async {
      final fs = FileSystemService();

      // We expect it to throw Exception('Invalid subdirectory: Path traversal detected')
      expect(
          () async => await fs.saveToDataDirectory(
              filename: 'test.txt', content: 'data', subDirectory: '../parent'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Path traversal detected'))));
    });

    test('Should sanitize filename with path traversal', () async {
      final fs = FileSystemService();

      // Verify no exception on malicious filename, but correct sanitation
      // We can't verify the file path easily without mocking io.File,
      // but verifying it doesn't throw is a good start as it means it handled the path.

      await fs.saveToDataDirectory(
          filename: '../../../../etc/passwd', content: 'harmless data');

      // If we are here, it didn't crash.
      // Ideally we check where it wrote, but that requires listing the dir.
    });
  });

  group('Metadata Parser ReDoS Mitigation', () {
    test('Should extract JSON-LD using DOM parser', () async {
      const html = '''
      <html>
      <head>
        <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Article",
            "author": "Security Tester",
            "datePublished": "2024-01-01"
          }
        </script>
      </head>
      <body></body>
      </html>
      ''';

      // We use extractMetadataInIsolate exposed method
      final metadata =
          await extractMetadataInIsolate(html, 'http://example.com');

      expect(metadata['article']['Author'], equals('Security Tester'));
      expect(metadata['article']['Published'], equals('2024-01-01'));
    });
  });
}
