import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/collectors/browser_loader.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

class FakeServerFetcher implements ServerFetcher {
  final calls = <Uri>[];
  final userAgents = <String>[];
  final robotsCalls = <Uri>[];
  final pending = <Completer<ServerSnapshot>>[];

  @override
  Future<ServerSnapshot> fetch(Uri url,
      {required String userAgent, int maxBytes = 10 << 20}) {
    calls.add(url);
    userAgents.add(userAgent);
    final c = Completer<ServerSnapshot>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<RobotsInfo> fetchRobots(Uri origin,
      {required String userAgent}) async {
    robotsCalls.add(origin);
    return RobotsInfo(
      robotsStatus: const Present(404, source: DataSource.server),
      robotsText: const Unavailable(UnavailableReason.notReportedByServer),
      disallowCount: const Unavailable(UnavailableReason.notReportedByServer),
      allowCount: const Unavailable(UnavailableReason.notReportedByServer),
      sitemaps: const Unavailable(UnavailableReason.notReportedByServer),
      sitemapStatus: const Present(404, source: DataSource.server),
    );
  }
}

class FakeBrowserLoader implements BrowserLoader {
  final calls = <Uri>[];
  @override
  void loadUrl(Uri url) => calls.add(url);
}

Present<T> _p<T>(T v) => Present(v, source: DataSource.server);

HttpHop _hop(String url, int status, {Map<String, List<String>>? headers}) =>
    HttpHop(
      url: Uri.parse(url),
      statusCode: status,
      reasonPhrase: status == 200 ? 'OK' : 'Found',
      headers: headers ?? const {},
      setCookies: const [],
      remoteAddress: const Unavailable(UnavailableReason.notReportedByPlatform),
      certificate: const Unavailable(UnavailableReason.notApplicable),
    );

ServerSnapshot okSnapshot(String url, String body, {String? finalUrl}) {
  final hops = finalUrl == null
      ? [
          _hop(url, 200, headers: {
            'content-type': ['text/html']
          })
        ]
      : [
          _hop(url, 301, headers: {
            'location': [finalUrl]
          }),
          _hop(finalUrl, 200, headers: {
            'content-type': ['text/html']
          }),
        ];
  return ServerSnapshot(
    requestedUrl: Uri.parse(url),
    userAgent: kServerUserAgent,
    hops: hops,
    finalUrl: _p(hops.last.url),
    body: _p(ServerBody(
      decoded: DecodedText(
          text: body,
          charset: 'utf-8',
          charsetSource: CharsetSource.header,
          byteLength: body.length),
      transferLength: body.length,
      truncated: false,
      contentLength: const Unavailable(UnavailableReason.notReportedByServer),
    )),
    timingMs: _p(7),
    certificate: const Unavailable(UnavailableReason.notApplicable),
  );
}

ServerSnapshot failedSnapshot(String url, String message) => ServerSnapshot(
      requestedUrl: Uri.parse(url),
      userAgent: kServerUserAgent,
      hops: const [],
      finalUrl: Failed(message),
      body: Failed(message),
      timingMs: _p(3),
      certificate: const Unavailable(UnavailableReason.notApplicable),
    );

HtmlFile localFile(String name, String content, {String? path}) => HtmlFile(
    name: name,
    path: path ?? '/tmp/$name',
    content: content,
    lastModified: DateTime(2024),
    size: content.length);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late FakeBrowserLoader browser;
  late InspectionStore store;
  late HtmlService service;
  late List<String> extractedHtml;

  HtmlService make({bool browserFirst = true, Completer<void>? gate}) {
    final s = HtmlService(
      store: store,
      serverFetcher: fetcher,
      browserLoader: browser,
      metadataExtractor: (html, baseUrl, {headers}) async {
        extractedHtml.add(html);
        if (gate != null && extractedHtml.length == 1) await gate.future;
        return {'title': html};
      },
    );
    s.setAppSettings(AppSettings()..useBrowserByDefault = browserFirst);
    return s;
  }

  setUp(() {
    fetcher = FakeServerFetcher();
    browser = FakeBrowserLoader();
    store = InspectionStore();
    extractedHtml = [];
    service = make();
  });

  tearDown(() => service.dispose());

  group('browser-first loadUrl', () {
    test('fetches the server body once and also starts the browser (B1)',
        () async {
      await service.loadUrl('https://a.test/');

      expect(fetcher.calls, [Uri.parse('https://a.test/')]);
      expect(fetcher.userAgents.single, kServerUserAgent);
      expect(fetcher.robotsCalls, [Uri.parse('https://a.test')]);
      expect(browser.calls, [Uri.parse('https://a.test/')]);
      expect(service.serverSource, isNull);

      fetcher.pending.single
          .complete(okSnapshot('https://a.test/', '<html>S</html>'));
      await pumpEventQueue();

      expect(service.serverSource, '<html>S</html>');
      expect(service.probeResult!['statusCode'], 200);
    });

    test('server body fills an empty currentFile until the DOM replaces it',
        () async {
      await service.loadUrl('https://a.test/');
      fetcher.pending.single
          .complete(okSnapshot('https://a.test/', '<html>S</html>'));
      await pumpEventQueue();
      expect(service.currentFile!.content, '<html>S</html>');

      // The browser DOM (sync) replaces it; the server source stays.
      await service.loadFile(
          localFileUrl('https://a.test/', '<html>DOM</html>'),
          clearProbe: false);
      expect(service.currentFile!.content, '<html>DOM</html>');
      expect(service.serverSource, '<html>S</html>');
    });

    test('a failed server fetch does not fabricate anything', () async {
      await service.loadUrl('https://a.test/');
      fetcher.pending.single
          .complete(failedSnapshot('https://a.test/', 'network error: down'));
      await pumpEventQueue();

      expect(service.probeResult, isNull);
      expect(service.probeError, 'network error: down');
      expect(service.serverSource, isNull);
      expect(service.isProbing, isFalse);
    });

    test('redirect chain from the server shows up in probeResult', () async {
      await service.loadUrl('http://a.test/');
      fetcher.pending.single.complete(
          okSnapshot('http://a.test/', 'x', finalUrl: 'https://a.test/'));
      await pumpEventQueue();

      final p = service.probeResult!;
      expect(p['isRedirect'], isTrue);
      expect((p['redirectChain'] as List).length, 1);
      expect(p['finalUrl'], 'https://a.test/');
    });
  });

  group('source-first loadUrl', () {
    setUp(() {
      service.dispose();
      service = make(browserFirst: false);
    });

    test('server body becomes the currentFile and survives loadFile (B2)',
        () async {
      final done = service.loadUrl('https://a.test/');
      await pumpEventQueue();
      expect(fetcher.calls.length, 1);
      expect(browser.calls, isEmpty);

      fetcher.pending.single
          .complete(okSnapshot('https://a.test/', '<html>S</html>'));
      await done;

      expect(service.currentFile!.content, '<html>S</html>');
      expect(service.currentFile!.isUrl, isTrue);
      expect(service.serverSource, '<html>S</html>');
      expect(service.isLoading, isFalse);
    });

    test('a failed fetch loads an error page and sets probeError', () async {
      final done = service.loadUrl('https://a.test/');
      await pumpEventQueue();
      fetcher.pending.single
          .complete(failedSnapshot('https://a.test/', 'timeout: slow'));
      await done;

      expect(service.currentFile!.isError, isTrue);
      expect(service.currentFile!.content, contains('timeout: slow'));
      expect(service.probeResult, isNull);
      expect(service.probeError, 'timeout: slow');
    });
  });

  group('generations', () {
    test('a late result for URL A leaves nothing behind after B started',
        () async {
      await service.loadUrl('https://a.test/');
      await service.loadUrl('https://b.test/');
      expect(fetcher.calls.length, 2);

      fetcher.pending[0]
          .complete(okSnapshot('https://a.test/', '<html>A</html>'));
      await pumpEventQueue();

      expect(service.serverSource, isNull);
      expect(service.probeResult, isNull);
      expect(service.currentFile?.content ?? '', isNot(contains('A')));

      fetcher.pending[1]
          .complete(okSnapshot('https://b.test/', '<html>B</html>'));
      await pumpEventQueue();
      expect(service.serverSource, '<html>B</html>');
      expect(service.probeResult!['url'], 'https://b.test/');
    });

    test('source-first: a late result for A never touches currentFile',
        () async {
      service.dispose();
      service = make(browserFirst: false);
      final a = service.loadUrl('https://a.test/');
      await pumpEventQueue();
      final b = service.loadUrl('https://b.test/');
      await pumpEventQueue();

      fetcher.pending[0]
          .complete(okSnapshot('https://a.test/', '<html>A</html>'));
      await pumpEventQueue();
      expect(service.currentFile?.content ?? '', isNot(contains('A')));

      fetcher.pending[1]
          .complete(okSnapshot('https://b.test/', '<html>B</html>'));
      await Future.wait([a, b]);
      expect(service.currentFile!.content, '<html>B</html>');
      expect(service.serverSource, '<html>B</html>');
    });
  });

  group('one fetch per navigation (B30)', () {
    test('deep link: loadFromUrl alone fetches once', () async {
      await service.loadFromUrl('https://a.test/x');
      expect(fetcher.calls.length, 1);
    });

    test('probeUrl for the page being loaded, or its final URL, reuses it',
        () async {
      await service.loadUrl('http://a.test/');
      unawaited(service.probeUrl('http://a.test/'));
      await pumpEventQueue();
      expect(fetcher.calls.length, 1);

      fetcher.pending.single.complete(
          okSnapshot('http://a.test/', 'x', finalUrl: 'https://a.test/'));
      await pumpEventQueue();
      await service.probeUrl('https://a.test/');
      expect(fetcher.calls.length, 1);

      // A browser URL while the fetch is still running belongs to it too.
      await service.loadUrl('http://c.test/');
      unawaited(service.probeUrl('https://www.c.test/'));
      await pumpEventQueue();
      expect(fetcher.calls.length, 2);
    });

    test('probeUrl for another page starts a new generation and fetch',
        () async {
      await service.loadUrl('https://a.test/');
      fetcher.pending.single.complete(okSnapshot('https://a.test/', 'a'));
      await pumpEventQueue();
      final gen = store.current.generation;
      final probe = service.probeUrl('https://other.test/');
      await pumpEventQueue();
      expect(fetcher.calls.length, 2);
      expect(store.current.generation, gen + 1);
      fetcher.pending[1].complete(okSnapshot('https://other.test/', 'o'));
      expect((await probe)['statusCode'], 200);
      expect(service.probeResult!['url'], 'https://other.test/');
    });
  });

  group('sameUrl (B17)', () {
    bool same(String a, String b) =>
        HtmlService.sameUrl(Uri.parse(a), Uri.parse(b));

    test('scheme and port matter; empty path equals "/"', () {
      expect(same('http://a.test/x', 'https://a.test/x'), isFalse);
      expect(same('https://a.test:8443/', 'https://a.test/'), isFalse);
      expect(same('https://a.test', 'https://a.test/'), isTrue);
      expect(same('https://A.test/x#f', 'https://a.test/x'), isTrue);
      expect(same('https://a.test/x?a=1', 'https://a.test/x'), isFalse);
    });
  });

  group('local files', () {
    test('have no probe result and no probe error (B3)', () async {
      await service.loadFile(localFile('t.html', '<p>x</p>'));
      expect(service.probeResult, isNull);
      expect(service.probeError, isNull);
      expect(service.isProbing, isFalse);
      expect(service.serverSource, isNull);
    });

    test('after a URL the previous browser data is gone', () async {
      await service.loadUrl('https://a.test/');
      service.seedBrowserDataForTest();
      expect(service.resourceTimelineData, isNotEmpty);
      expect(service.browserProbeResult, isNotNull);

      await service.loadFile(localFile('t.html', '<p>x</p>'));

      expect(service.resourceTimelineData, isEmpty);
      expect(service.browserProbeResult, isNull);
      expect(service.sovereigntyReport, isNull);
      expect(service.probeResult, isNull);
    });

    test('a URL page loaded without a fetch has no probe result (B3)',
        () async {
      await service.loadFile(localFileUrl('https://a.test/', '<p>x</p>'));
      expect(service.probeResult, isNull);
    });

    test('reloadCurrentFile re-reads through FileLoader (non-UTF-8 ok)',
        () async {
      final dir = await Directory.systemTemp.createTemp('reload');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/r.html')..writeAsStringSync('<p>old</p>');
      await service.loadFile(localFile('r.html', '<p>old</p>', path: f.path));

      // 0xE9 alone is invalid UTF-8; readAsString would throw.
      f.writeAsBytesSync([0x3c, 0x70, 0x3e, 0xE9, 0x3c, 0x2f, 0x70, 0x3e]);
      await service.reloadCurrentFile();

      // FileLoader decodes (malformed bytes become U+FFFD); readAsString threw.
      expect(service.currentFile!.content, '<p>\uFFFD</p>');
    });
  });

  group('metadata extraction', () {
    test('a slow extraction for an older generation is dropped', () async {
      final gate = Completer<void>();
      service.dispose();
      service = make(gate: gate);

      final a = service.loadFile(localFile('a.html', '<html>A</html>'));
      await Future.delayed(const Duration(milliseconds: 200));
      expect(extractedHtml, ['<html>A</html>']);

      // B arrives while A's extraction is still running: queued, not lost.
      await service.loadFile(localFile('b.html', '<html>B</html>'));
      gate.complete();
      await a;
      await Future.delayed(const Duration(milliseconds: 100));

      expect(extractedHtml, ['<html>A</html>', '<html>B</html>']);
      expect(service.pageMetadata!['title'], '<html>B</html>');
      expect(service.isExtractingMetadata, isFalse);
    });
  });
}

HtmlFile localFileUrl(String url, String content) => HtmlFile(
    name: 'index.html',
    path: url,
    content: content,
    lastModified: DateTime(2024),
    size: content.length,
    isUrl: true);
