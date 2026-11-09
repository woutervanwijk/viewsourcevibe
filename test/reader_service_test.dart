import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/collectors/readability_js.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/reader_service.dart';

HtmlService _service() => HtmlService();

HtmlFile _htmlUrlFile({String path = 'https://example.com/article'}) =>
    HtmlFile(
      name: 'article.html',
      path: path,
      content:
          '<html><head><title>T</title></head><body><article><p>Hello</p></article></body></html>',
      lastModified: DateTime(2024),
      size: 100,
      isUrl: true,
    );

const _articleJson = {
  'title': 'A <b>Great</b> Article',
  'byline': 'Jane Doe',
  'excerpt': 'An excerpt',
  'content': '<p>Body <img src="img/a.png"></p>',
  'length': 5000,
  'siteName': 'Example',
  'publishedTime': '2024-01-01',
  'dir': '',
  'lang': 'en',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderService.applyResult', () {
    test('a valid article JSON becomes ready with parsed fields', () {
      final service = _service();
      final reader = ReaderService(service);
      addTearDown(service.dispose);

      final article = reader.applyResult(jsonEncode(_articleJson));

      expect(reader.status, ReaderStatus.ready);
      expect(article, isNotNull);
      expect(article!.title, 'A <b>Great</b> Article');
      expect(article.byline, 'Jane Doe');
      expect(article.siteName, 'Example');
      expect(article.length, 5000);
      expect(article.readingTimeMinutes, 5); // 5000 chars / 5 / 200 wpm
    });

    test('"null", null and empty results mean no article', () {
      final service = _service();
      final reader = ReaderService(service);
      addTearDown(service.dispose);

      reader.applyResult('null');
      expect(reader.status, ReaderStatus.noArticle);
      expect(reader.article, isNull);

      reader.applyResult(null);
      expect(reader.status, ReaderStatus.noArticle);

      reader.applyResult('');
      expect(reader.status, ReaderStatus.noArticle);
    });

    test('a JSON error object and invalid JSON become errors', () {
      final service = _service();
      final reader = ReaderService(service);
      addTearDown(service.dispose);

      reader.applyResult('{"error": "boom"}');
      expect(reader.status, ReaderStatus.error);
      expect(reader.errorMessage, 'boom');

      reader.applyResult('not json at all');
      expect(reader.status, ReaderStatus.error);
      expect(reader.errorMessage, isNotNull);
    });

    test('an already-decoded map and a quoted JSON string also parse', () {
      final service = _service();
      final reader = ReaderService(service);
      addTearDown(service.dispose);

      reader.applyResult(_articleJson);
      expect(reader.status, ReaderStatus.ready);
      expect(reader.article?.title, 'A <b>Great</b> Article');

      // Some platforms wrap a returned JS string in quotes.
      reader.applyResult(jsonEncode(jsonEncode(_articleJson)));
      expect(reader.status, ReaderStatus.ready);
      expect(reader.article?.siteName, 'Example');
    });
  });

  group('readability eval script', () {
    test('parses a clone of the document, never the live page', () {
      // Readability mutates the document it is given; running it on the
      // live document removed parts of pages in the Browser tab.
      expect(vsvReadabilityParseJs, contains('document.cloneNode(true)'));
      expect(vsvReadabilityParseJs, isNot(contains('new Readability(document)')));
      expect(vsvReadabilityEvalJs, contains(readabilityJs));
    });
  });

  group('wrapInReaderTemplate', () {
    final article = ReaderArticle.fromJson(_articleJson);

    test('wraps the article content with a base href and escaped title',
        () {
      final html = wrapInReaderTemplate(article,
          dark: false, baseUrl: 'https://example.com/article');

      expect(html, contains('<base href="https://example.com/article">'));
      expect(html, contains('<p>Body <img src="img/a.png"></p>'));
      // The title is text, not markup.
      expect(html, contains('A &lt;b&gt;Great&lt;/b&gt; Article'));
      expect(html, isNot(contains('<b>Great</b>')));
      // Light theme colors.
      expect(html, contains('#ffffff'));
    });

    test('dark mode uses dark colors and no base tag without a URL', () {
      final html =
          wrapInReaderTemplate(article, dark: true, baseUrl: null);
      expect(html, contains('#1e1e1e'));
      expect(html, isNot(contains('<base')));
    });

    test('shows byline, site and reading time in the header', () {
      final html = wrapInReaderTemplate(article, dark: false, baseUrl: null);
      expect(html, contains('Jane Doe · Example · 5 min read'));
    });
  });

  group('ReaderService extraction and staleness', () {
    test('without a live WebView the service switches to inView mode',
        () async {
      final service = _service();
      final reader = ReaderService(service);
      service.setReaderService(reader);
      addTearDown(service.dispose);

      await service.loadFile(_htmlUrlFile());
      expect(service.isHtml, isTrue);

      await reader.extract();
      expect(reader.status, ReaderStatus.inView);
      expect(reader.isStale, isFalse);
    });

    test('selecting the Reader tab triggers a lazy extraction', () async {
      final service = _service();
      final reader = ReaderService(service);
      service.setReaderService(reader);
      addTearDown(service.dispose);

      await service.loadFile(_htmlUrlFile());
      service.setActiveTabIndex(service.readerTabIndex);
      await Future<void>(() {});

      expect(reader.status, ReaderStatus.inView);
      expect(service.activeTabIndex, service.readerTabIndex);
    });

    test('a new page load marks the article stale', () async {
      final service = _service();
      final reader = ReaderService(service);
      service.setReaderService(reader);
      addTearDown(service.dispose);

      await service.loadFile(_htmlUrlFile());
      await reader.extract();
      expect(reader.isStale, isFalse);

      await service.loadFile(
          _htmlUrlFile(path: 'https://example.com/other'));
      expect(reader.isStale, isTrue);
      expect(reader.status, ReaderStatus.idle);
      expect(reader.article, isNull);
    });

    test('extractIfStale does not re-extract a fresh article', () async {
      final service = _service();
      final reader = ReaderService(service);
      service.setReaderService(reader);
      addTearDown(service.dispose);

      await service.loadFile(_htmlUrlFile());
      await reader.extract();
      expect(reader.status, ReaderStatus.inView);

      await reader.extractIfStale();
      // Still inView from the first extraction, not extracting again.
      expect(reader.status, ReaderStatus.inView);
    });
  });

  group('tab indices with a Reader tab', () {
    test('browser-first layout: Reader sits before DOM Tree and Source',
        () async {
      final service = _service();
      service.setAppSettings(AppSettings()..useBrowserByDefault = true);
      addTearDown(service.dispose);

      await service.loadFile(_htmlUrlFile());

      expect(service.browserTabIndex, 0);
      // Metadata(5) + Sovereignty(1) come before Reader.
      expect(service.readerTabIndex, 7);
      expect(service.sourceTabIndex, 9);
    });

    test('browser-last layout: counts include Reader before Source', () async {
      final service = _service();
      service.setAppSettings(AppSettings()..useBrowserByDefault = false);
      addTearDown(service.dispose);

      await service.loadFile(_htmlUrlFile());

      // Metadata(5) + Sovereignty(1) + Reader + DOM Tree + Source(1) +
      // server tabs(6) + Browser.
      expect(service.readerTabIndex, 6);
      expect(service.sourceTabIndex, 8);
      expect(service.browserTabIndex, 14);
    });

    test('non-HTML files have no Reader tab offset', () async {
      final service = _service();
      service.setAppSettings(AppSettings()..useBrowserByDefault = false);
      addTearDown(service.dispose);

      await service.loadFile(HtmlFile(
        name: 'data.json',
        path: '/tmp/data.json',
        content: '{"a": 1}',
        lastModified: DateTime(2024),
        size: 8,
      ));

      expect(service.isHtml, isFalse);
      // No metadata tabs, no Reader, no DOM Tree: Source first.
      expect(service.sourceTabIndex, 0);
    });
  });
}
