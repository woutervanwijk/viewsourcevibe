import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/network_quiet.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/collectors/browser_loader.dart';
import 'package:view_source_vibe/services/derive/cookies.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_lifecycle_test.dart'
    show
        FakeServerFetcher,
        FakeBrowserLoader,
        okSnapshot,
        localFile,
        presentServer;

/// A collector payload in the schema of `__vsv_collect()`.
String payload({
  String url = 'https://a.test/',
  String dom = '<html>DOM</html>',
  List<Map<String, Object?>> observer = const [],
  String cookies = '',
  bool domOk = true,
}) =>
    jsonEncode({
      'v': 1,
      'url': url,
      'contentType': 'text/html',
      'timing': {'ok': true, 'now': 2000.0, 'timeOrigin': 1.0},
      'dom': domOk
          ? {'ok': true, 'value': dom, 'iframes': 0, 'shadowRoots': 0}
          : {'ok': false, 'error': 'boom'},
      'resources': {
        'ok': true,
        'bootstrap': true,
        'dropped': 0,
        'observer': observer,
        'patch': [],
      },
      'navigation': {
        'ok': true,
        'responseStart': 30.0,
        'domInteractive': 100.0,
        'domContentLoaded': 110.0,
        'loadEnd': 0,
        'protocol': 'h2'
      },
      'storage': {
        'local': {
          'ok': true,
          'count': 1,
          'items': [
            {'k': 'theme', 'v': 'dark'}
          ],
          'truncated': false
        },
        'session': {'ok': false, 'error': 'SecurityError: denied'},
      },
      'cookies': {'ok': true, 'raw': cookies},
    });

Map<String, Object?> obs(String url,
        {double? st = 5.0, double? du = 20.0, int tx = 100, int dec = 400}) =>
    {
      'n': url,
      'it': 'script',
      'st': st,
      'du': du,
      'tx': tx,
      'enc': tx,
      'dec': dec,
    };

/// One later pass after [ms] milliseconds.
NetworkQuietPolicy once(int ms) => NetworkQuietPolicy(
    interval: Duration(milliseconds: ms),
    quiet: const Duration(hours: 1),
    max: Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late FakeBrowserLoader loader;
  late InspectionStore store;
  late HtmlService service;
  late List<String> collectCalls;
  late Future<Object?> Function(String url) collect;
  late Future<List<Map>> Function(String url) native;

  HtmlService make({NetworkQuietPolicy? poll}) {
    final s = HtmlService(
      store: store,
      serverFetcher: fetcher,
      browserLoader: loader,
      metadataExtractor: (html, baseUrl, {headers}) async => {'title': html},
      browserCollect: (url) {
        collectCalls.add(url);
        return collect(url);
      },
      nativeCookies: (url) => native(url),
      browserPlatform: BrowserPlatform.macos,
      browserPoll: poll ?? NetworkQuietPolicy.off,
      spaSettleDelay: Duration.zero,
    );
    s.setAppSettings(AppSettings()..useBrowserByDefault = true);
    return s;
  }

  setUp(() {
    fetcher = FakeServerFetcher();
    loader = FakeBrowserLoader();
    store = InspectionStore();
    collectCalls = [];
    collect = (url) async => payload(url: url);
    native = (url) async => throw UnsupportedError('no native cookies');
    service = make();
  });

  tearDown(() => service.dispose());

  Future<void> loadAndAnswer(String url,
      {String body = '<html>S</html>'}) async {
    await service.loadUrl(url);
    fetcher.pending.last.complete(okSnapshot(url, body));
    await pumpEventQueue();
  }

  BrowserSnapshot browserOf(HtmlService s) =>
      (s.store.current.browser as Present<BrowserSnapshot>).value;

  group('syncWebViewState through the collector', () {
    test('the payload reaches the store; DOM becomes the file content',
        () async {
      collect = (url) async => payload(
          url: url,
          dom: '<html>é DOM</html>',
          observer: [obs('https://a.test/a.js')],
          cookies: 'a=1');
      await loadAndAnswer('https://a.test/');

      await service.syncWebViewState('https://a.test/');

      expect(collectCalls, ['https://a.test/']);
      final b = browserOf(service);
      expect((b.renderedDom as Present<RenderedDom>).value.text,
          '<html>é DOM</html>');
      expect(service.currentFile!.content, '<html>é DOM</html>');
      // Bytes of the serialized DOM, not characters and not the server size.
      expect(
          service.currentFile!.size, utf8.encode('<html>é DOM</html>').length);
      expect(service.serverSource, '<html>S</html>');
      final t = service.resourceTimelineData;
      expect(t.single['name'], 'https://a.test/a.js');
      expect(t.single['transfer'], 100);
      expect(
          ((store.current.browser as Present<BrowserSnapshot>).value.resources
                  as Present<List<ResourceEntry>>)
              .value,
          hasLength(1));
    });

    test('a failed storage section does not drop the rest (B22)', () async {
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      final b = browserOf(service);
      final storage = (b.storage as Present<BrowserStorage>).value;
      expect(storage.local, isA<Present<StorageArea>>());
      expect(storage.session, isA<Failed<StorageArea>>());
      expect(b.renderedDom, isA<Present<RenderedDom>>());
    });

    test('a collect that completes after a new navigation is dropped (B5)',
        () async {
      final late = Completer<Object?>();
      collect = (url) => url == 'https://a.test/'
          ? late.future
          : Future.value(payload(url: url, dom: '<html>B-DOM</html>'));
      await loadAndAnswer('https://a.test/');
      final syncA = service.syncWebViewState('https://a.test/');
      await pumpEventQueue();

      await loadAndAnswer('https://b.test/', body: '<html>B</html>');
      late.complete(payload(url: 'https://a.test/', dom: '<html>A-DOM</html>'));
      await syncA;

      final target = store.current.target as UrlTarget;
      expect(target.url, Uri.parse('https://b.test/'));
      expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
      expect(service.currentFile?.content ?? '', isNot(contains('A-DOM')));
      expect(service.resourceTimelineData, isEmpty);
    });

    test('a throwing collect marks the browser Failed, server data intact',
        () async {
      collect = (url) async => throw StateError('webview gone');
      await loadAndAnswer('https://a.test/');

      await service.syncWebViewState('https://a.test/');

      final browserState = store.current.browser;
      expect(browserState, isA<Failed<BrowserSnapshot>>());
      expect((browserState as Failed).error, contains('webview gone'));
      expect(presentServer(service)!.hops.last.statusCode, 200);
      expect(service.serverSource, '<html>S</html>');
      expect(service.currentFile!.content, '<html>S</html>');
      expect(service.resourceTimelineData, isEmpty);
      expect(store.current.browser, isNot(isA<Present<BrowserSnapshot>>()));
    });

    test('a non-String result is Unavailable and does not blank the page',
        () async {
      collect = (url) async => <String, Object?>{'not': 'a string'};
      await loadAndAnswer('https://a.test/');

      await service.syncWebViewState('https://a.test/');

      expect(store.current.browser, isA<Unavailable<BrowserSnapshot>>());
      expect(service.currentFile!.content, '<html>S</html>');
    });

    test('a file target ignores the sync entirely (scan bug 16)', () async {
      await service.loadFile(localFile('t.html', '<p>local</p>'));
      collectCalls.clear();

      await service.syncWebViewState('https://a.test/');

      expect(collectCalls, isEmpty);
      expect(service.currentFile!.isUrl, isFalse);
      expect(service.currentFile!.content, '<p>local</p>');
      expect(store.current.target, isA<FileTarget>());
      expect(store.current.browser, isA<Unavailable<BrowserSnapshot>>());
    });

    test('native cookies carry real flags into the probe map (B20)', () async {
      native = (url) async => [
            {
              'name': 'sid',
              'value': 'x',
              'domain': 'a.test',
              'path': '/',
              'isSecure': true,
              'isHttpOnly': true,
              'expiresDate': null,
            }
          ];
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');

      final sid =
          deriveCookies(store.current).firstWhere((c) => c.name == 'sid');
      expect(sid.httpOnly, true);
      expect(sid.secure, true);
    });

    test('without native cookies the JS cookies are used, flags unknown',
        () async {
      collect = (url) async => payload(url: url, cookies: 'jsc=1');
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');

      final c = deriveCookies(store.current).firstWhere((c) => c.name == 'jsc');
      expect(c.httpOnly, isNull); // unknown, not false
    });

    test('the raw payload of the last sync is kept per generation', () async {
      final raw = payload(url: 'https://a.test/');
      collect = (url) async => raw;
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(service.browserDebugPayload, raw);

      await service.loadUrl('https://b.test/');
      expect(service.browserDebugPayload, isNull);
    });

    test('an unparsable payload is still kept for debugging', () async {
      collect = (url) async => '{not json';
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(service.browserDebugPayload, '{not json');
      expect(store.current.browser, isA<Failed<BrowserSnapshot>>());
    });
  });

  group('refreshes', () {
    test(
        'a refresh merges: startTime/duration of the first sync survive '
        '(B12)', () async {
      service.dispose();
      service = make(poll: once(20));
      var n = 0;
      collect = (url) async {
        n++;
        return n == 1
            ? payload(url: url, observer: [
                obs('https://a.test/a.js', st: 5.0, du: 20.0, tx: 100, dec: 400)
              ])
            // The page cleared its timings: the fresh entry has no start.
            : payload(url: url, observer: [
                obs('https://a.test/a.js',
                    st: null, du: null, tx: 100, dec: 400),
                obs('https://a.test/late.js', st: 9000.0, du: 10.0),
              ]);
      };
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(service.resourceTimelineData, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 120));
      await pumpEventQueue();

      expect(collectCalls, hasLength(2));
      final t = {for (final r in service.resourceTimelineData) r['name']: r};
      expect(t.keys,
          containsAll(['https://a.test/a.js', 'https://a.test/late.js']));
      expect(t['https://a.test/a.js']!['startTime'], 5.0);
      expect(t['https://a.test/a.js']!['duration'], 20.0);
    });

    test('a refresh whose collect completes after navigation is dropped',
        () async {
      service.dispose();
      service = make(poll: once(20));
      final slow = Completer<Object?>();
      var n = 0;
      collect = (url) {
        n++;
        return n == 1 ? Future.value(payload(url: url)) : slow.future;
      };
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(collectCalls, hasLength(2)); // refresh is in flight

      await loadAndAnswer('https://b.test/');
      slow.complete(payload(
          url: 'https://a.test/', observer: [obs('https://a.test/old.js')]));
      await pumpEventQueue();

      expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
      expect(service.resourceTimelineData, isEmpty);
    });

    test('polls until nothing new arrives, then marks the load settled',
        () async {
      service.dispose();
      service = make(
          poll: const NetworkQuietPolicy(
              interval: Duration(milliseconds: 10),
              quiet: Duration(milliseconds: 25),
              max: Duration(seconds: 5)));
      var n = 0;
      collect = (url) async {
        n++;
        // Resources keep arriving for the first three collects.
        return payload(url: url, observer: [
          for (var i = 0; i < (n < 3 ? n : 3); i++) obs('https://a.test/$i.js')
        ]);
      };
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(store.current.browserSettled, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();

      expect(store.current.browserSettled, isTrue);
      final calls = collectCalls.length;
      expect(calls, greaterThanOrEqualTo(4));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(collectCalls, hasLength(calls), reason: 'polling stopped');
    });

    test('without polling the load is settled at once', () async {
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(store.current.browserSettled, isTrue);
    });

    test('pending refreshes are cancelled by a navigation', () async {
      service.dispose();
      service = make(poll: once(50));
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(collectCalls, hasLength(1));

      await service.loadUrl('https://b.test/');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(collectCalls, hasLength(1));
    });

    test('pending refreshes are cancelled by dispose', () async {
      service.dispose();
      service = make(poll: once(50));
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(collectCalls, hasLength(1));
      // tearDown disposes again; a second dispose must not throw.
      service = make();
    });

    test('a partial sync schedules no refreshes', () async {
      service.dispose();
      service = make(poll: once(20));
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/', isPartial: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(collectCalls, hasLength(1));
    });
  });

  group('SPA navigation (B21)', () {
    test('a different path is a new generation, a server fetch and a sync',
        () async {
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/'); // full load done
      final genBefore = store.current.generation;
      collectCalls.clear();

      await service.handleBrowserUrlChange('https://a.test/other/route');
      await pumpEventQueue();

      expect(store.current.generation, greaterThan(genBefore));
      expect((store.current.target as UrlTarget).url,
          Uri.parse('https://a.test/other/route'));
      expect(fetcher.calls.last, Uri.parse('https://a.test/other/route'));
      expect(fetcher.calls, hasLength(2));
      expect(collectCalls, ['https://a.test/other/route']);
    });

    test(
        'F1: a route change whose collect fails never shows the previous '
        "route's text; the server body of the new route is adopted", () async {
      collect = (url) async {
        if (url.endsWith('/b')) throw Exception('boom');
        return payload(url: url, dom: '<html>A-DOM</html>');
      };
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(service.currentFile!.content, contains('A-DOM'));

      await service.handleBrowserUrlChange('https://a.test/b');
      await pumpEventQueue();

      // Route B has neither DOM nor server body yet.
      expect(service.currentFile?.content ?? '', isNot(contains('A-DOM')));

      fetcher.pending.last
          .complete(okSnapshot('https://a.test/b', '<html>B-BODY</html>'));
      // Loading the file resets the editor (real short delays): wait for the
      // service to announce the file instead of guessing a duration.
      final shown = Completer<void>();
      void onChange() {
        if (service.currentFile != null && !shown.isCompleted) shown.complete();
      }

      service.addListener(onChange);
      await shown.future.timeout(const Duration(seconds: 5));
      service.removeListener(onChange);
      expect(service.currentFile!.content, contains('B-BODY'));
      expect(service.currentFile!.content, isNot(contains('A-DOM')));
    });

    test('same document (scheme/www/trailing slash differ): nothing happens',
        () async {
      await loadAndAnswer('https://a.test/page');
      final gen = store.current.generation;
      collectCalls.clear();

      await service.handleBrowserUrlChange('http://a.test/page');
      await service.handleBrowserUrlChange('https://www.a.test/page/');

      expect(store.current.generation, gen);
      expect(fetcher.calls, hasLength(1));
      expect(collectCalls, isEmpty);
    });

    test('a hash-only change is the same document', () async {
      await loadAndAnswer('https://a.test/page');
      final gen = store.current.generation;
      await service.handleBrowserUrlChange('https://a.test/page#section');
      expect(store.current.generation, gen);
      expect(fetcher.calls, hasLength(1));
    });

    test('ignored for a file target and for non-http URLs', () async {
      await service.loadFile(localFile('t.html', '<p>x</p>'));
      final gen = store.current.generation;
      await service.handleBrowserUrlChange('https://a.test/x');
      expect(store.current.generation, gen);

      await loadAndAnswer('https://a.test/');
      final gen2 = store.current.generation;
      await service.handleBrowserUrlChange('about:blank');
      await service.handleBrowserUrlChange('data:text/html,hi');
      expect(store.current.generation, gen2);
    });
  });

  group('fix round 1', () {
    test('M1: an estimated lookup leaves decoded unknown', () async {
      service.dispose();
      service = HtmlService(
        store: store,
        serverFetcher: fetcher,
        browserLoader: loader,
        metadataExtractor: (html, baseUrl, {headers}) async => {
          'jsLinks': ['https://cdn.test/unknown.js'],
        },
        browserCollect: (url) async => payload(url: url, observer: [
          {
            'n': 'https://cdn.test/unknown.js',
            'it': 'script',
            'st': 1.0,
            'du': 2.0,
            'tx': 0,
            'enc': 0,
            'dec': 0
          }
        ]),
        nativeCookies: (u) async => [],
        browserPlatform: BrowserPlatform.macos,
        browserPoll: NetworkQuietPolicy.off,
        spaSettleDelay: Duration.zero,
        sizeLookup: (url) async => 777,
      );
      service.setAppSettings(AppSettings()..useBrowserByDefault = true);
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final js = (service.pageMetadata!['jsLinks'] as List).single as Map;
      expect(js['size']['transfer'], 777);
      expect(js['size']['decoded'], isNull);
      expect(js['size']['estimated'], true);
    });

    test('M2: a URL outside the server chain gets a browser sync', () async {
      await service.loadUrl('https://a.test/');
      // The browser reports another document while the fetch is pending.
      // (Not covered: the note is rechecked when the chain arrives.)
      service.debugNoteBrowserUrl(Uri.parse('https://elsewhere.test/x'));
      collectCalls.clear();
      fetcher.pending.last
          .complete(okSnapshot('https://a.test/', '<html>S</html>'));
      await pumpEventQueue();
      expect(fetcher.calls.last, Uri.parse('https://elsewhere.test/x'));
      expect(collectCalls, ['https://elsewhere.test/x']);
    });

    test('M4: no SPA handling while a full load is in progress', () async {
      await service.loadUrl('https://a.test/'); // sets isWebViewLoading
      expect(service.isWebViewLoading, isTrue);
      final gen = store.current.generation;
      await service.handleBrowserUrlChange('https://a.test/other');
      expect(store.current.generation, gen);
      expect(collectCalls, isEmpty);
    });
  });

  group('platform mapping', () {
    test('defaultTargetPlatform maps to BrowserPlatform', () {
      expect(browserPlatformFor(TargetPlatform.iOS), BrowserPlatform.ios);
      expect(browserPlatformFor(TargetPlatform.macOS), BrowserPlatform.macos);
      expect(
          browserPlatformFor(TargetPlatform.android), BrowserPlatform.android);
      expect(
          browserPlatformFor(TargetPlatform.windows), BrowserPlatform.windows);
      expect(browserPlatformFor(TargetPlatform.linux), BrowserPlatform.linux);
      expect(
          browserPlatformFor(TargetPlatform.fuchsia), BrowserPlatform.unknown);
    });
  });

  group('legacy getters follow the store', () {
    test('a new navigation empties them; a local file too', () async {
      collect = (url) async =>
          payload(url: url, observer: [obs('https://a.test/a.js')]);
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      expect(service.resourceTimelineData, isNotEmpty);
      expect(store.current.browser, isA<Present<BrowserSnapshot>>());

      await service.loadUrl('https://b.test/');
      expect(service.resourceTimelineData, isEmpty);
      expect(store.current.browser, isNot(isA<Present<BrowserSnapshot>>()));
    });

    test('metadata sizes tolerate unknown (null) resource sizes', () async {
      service.dispose();
      service = HtmlService(
        store: store,
        serverFetcher: fetcher,
        browserLoader: loader,
        metadataExtractor: (html, baseUrl, {headers}) async => {
          'jsLinks': ['https://cdn.test/x.js'],
        },
        browserCollect: (url) async => payload(url: url, observer: [
          // transfer/decoded 0 cross-origin = blocked by the platform
          {
            'n': 'https://cdn.test/x.js',
            'it': 'script',
            'st': 1.0,
            'du': 2.0,
            'tx': 0,
            'enc': 0,
            'dec': 0
          }
        ]),
        nativeCookies: (u) async => [],
        browserPlatform: BrowserPlatform.macos,
        browserPoll: NetworkQuietPolicy.off,
        spaSettleDelay: Duration.zero,
        sizeLookup: (url) async => null,
      );
      service.setAppSettings(AppSettings()..useBrowserByDefault = true);
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      await pumpEventQueue();
      expect(service.pageMetadata, isNotNull);
      final js = service.pageMetadata!['jsLinks'] as List;
      final size = (js.single as Map)['size'] as Map?;
      expect(size?['decoded'], isNull);
      expect(size?['transfer'], isNull);
    });

    test(
        'estimated size lookups: only for unknown sizes, marked, and never '
        'over a Present value (B11)', () async {
      final looked = <String>[];
      service.dispose();
      service = HtmlService(
        store: store,
        serverFetcher: fetcher,
        browserLoader: loader,
        metadataExtractor: (html, baseUrl, {headers}) async => {
          'jsLinks': [
            'https://a.test/known.js',
            'https://cdn.test/unknown.js',
          ],
        },
        browserCollect: (url) async => payload(url: url, observer: [
          obs('https://a.test/known.js', tx: 10, dec: 20),
          {
            'n': 'https://cdn.test/unknown.js',
            'it': 'script',
            'st': 1.0,
            'du': 2.0,
            'tx': 0,
            'enc': 0,
            'dec': 0
          }
        ]),
        nativeCookies: (u) async => [],
        browserPlatform: BrowserPlatform.macos,
        browserPoll: NetworkQuietPolicy.off,
        spaSettleDelay: Duration.zero,
        sizeLookup: (url) async {
          looked.add(url);
          return 777;
        },
      );
      service.setAppSettings(AppSettings()..useBrowserByDefault = true);
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(looked, ['https://cdn.test/unknown.js']);
      final js = (service.pageMetadata!['jsLinks'] as List).cast<Map>();
      final known = js.firstWhere(
          (i) => (i['src'] ?? i['href']) == 'https://a.test/known.js');
      expect(known['size']['decoded'], 20);
      expect(known['size'].containsKey('estimated'), isFalse);
      final unknown = js.firstWhere(
          (i) => (i['src'] ?? i['href']) == 'https://cdn.test/unknown.js');
      expect(unknown['size']['transfer'], 777);
      expect(unknown['size']['estimated'], true);
    });

    test('a size lookup that finishes after navigation writes nothing',
        () async {
      final gate = Completer<int?>();
      service.dispose();
      service = HtmlService(
        store: store,
        serverFetcher: fetcher,
        browserLoader: loader,
        metadataExtractor: (html, baseUrl, {headers}) async => {
          'jsLinks': ['https://cdn.test/unknown.js'],
        },
        browserCollect: (url) async => payload(url: url),
        nativeCookies: (u) async => [],
        browserPlatform: BrowserPlatform.macos,
        browserPoll: NetworkQuietPolicy.off,
        spaSettleDelay: Duration.zero,
        sizeLookup: (url) => gate.future,
      );
      service.setAppSettings(AppSettings()..useBrowserByDefault = true);
      await loadAndAnswer('https://a.test/');
      await service.syncWebViewState('https://a.test/');
      await pumpEventQueue();
      final metadataA = service.pageMetadata;
      expect(metadataA, isNotNull);

      await service.loadUrl('https://b.test/');
      gate.complete(555);
      await pumpEventQueue();

      // The old metadata object was not written to after the navigation.
      final js = (metadataA!['jsLinks'] as List).single;
      expect(js is Map ? js['size'] : null, isNull);
    });
  });
}
