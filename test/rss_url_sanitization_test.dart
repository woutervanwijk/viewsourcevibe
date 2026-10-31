import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/rss_template_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RSS URL sanitization (XSS via href/src)', () {
    test('javascript: item link is dropped from generated HTML', () async {
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>Feed</title>
          <link>https://example.com</link>
          <item>
            <title>Item</title>
            <link>javascript:alert(1)</link>
            <description>Desc</description>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'https://example.com');

      expect(html, isNot(contains('javascript:')));
      expect(html, contains('href="#"'));
    });

    test('quote-breakout in link is attribute-escaped', () async {
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>Feed</title>
          <link>https://example.com</link>
          <item>
            <title>Item</title>
            <link>https://example.com/" onmouseover="alert(1)</link>
            <description>Desc</description>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'https://example.com');

      expect(html, isNot(contains('" onmouseover="')));
    });

    test('data: image src is dropped', () async {
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>Feed</title>
          <link>https://example.com</link>
          <item>
            <title>Item</title>
            <link>https://example.com/1</link>
            <description>Desc</description>
            <enclosure url="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==" type="image/png" length="1"/>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'https://example.com');

      expect(html, isNot(contains('data:text/html')));
    });

    test('javascript: channel link is dropped from header', () async {
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>Feed</title>
          <link>javascript:alert(document.domain)</link>
          <item>
            <title>Item</title>
            <link>https://example.com/1</link>
            <description>Desc</description>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'https://example.com');

      expect(html, isNot(contains('javascript:')));
    });

    test('valid http/https links are preserved', () async {
      const xml = '''
      <rss version="2.0">
        <channel>
          <title>Feed</title>
          <link>https://example.com/feed</link>
          <item>
            <title>Item</title>
            <link>https://example.com/article/1</link>
            <description>Desc</description>
          </item>
        </channel>
      </rss>
      ''';

      final html =
          await RssTemplateService.convertRssToHtml(xml, 'https://example.com');

      expect(html, contains('href="https://example.com/feed"'));
      expect(html, contains('href="https://example.com/article/1"'));
    });
  });
}
