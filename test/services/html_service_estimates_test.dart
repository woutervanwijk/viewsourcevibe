import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_browser_sync_test.dart' show payload;
import 'html_service_lifecycle_test.dart'
    show FakeServerFetcher, FakeBrowserLoader, okSnapshot;

/// A cross-origin resource the browser could not size (tx/enc/dec 0).
Map<String, Object?> blockedEntry(String url, String type) => {
      'n': url,
      'it': type,
      'st': 1.0,
      'du': 2.0,
      'tx': 0,
      'enc': 0,
      'dec': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late InspectionStore store;
  late HtmlService service;

  HtmlService make(
    List<Map<String, Object?>> observer,
    Future<int?> Function(String url) lookup, {
    Map<String, Object?> Function()? metadata,
  }) {
    final s = HtmlService(
      store: store,
      serverFetcher: fetcher,
      browserLoader: FakeBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async =>
          metadata?.call() ?? {},
      browserCollect: (url) async => payload(url: url, observer: observer),
      nativeCookies: (u) async => [],
      browserPlatform: BrowserPlatform.ios,
      browserRefreshDelays: const [],
      spaSettleDelay: Duration.zero,
      sizeLookup: lookup,
    );
    s.setAppSettings(AppSettings()..useBrowserByDefault = true);
    return s;
  }

  setUp(() {
    fetcher = FakeServerFetcher();
    store = InspectionStore();
  });

  tearDown(() => service.dispose());

  Future<void> load(String url) async {
    await service.loadUrl(url);
    fetcher.pending.last.complete(okSnapshot(url, '<html>S</html>'));
    await pumpEventQueue();
    await service.syncWebViewState(url);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('only allowed types are looked up; results land in the store', () async {
    final looked = <String>[];
    service = make([
      blockedEntry('https://cdn.test/a.js', 'script'),
      blockedEntry('https://cdn.test/b.css', 'link'),
      blockedEntry('https://cdn.test/c.woff2', 'css'),
      blockedEntry('https://cdn.test/d.png', 'img'),
      blockedEntry('https://cdn.test/e.mp4', 'video'),
      blockedEntry('https://cdn.test/api', 'fetch'),
      blockedEntry('https://cdn.test/api2', 'xmlhttprequest'),
      blockedEntry('https://cdn.test/t', 'beacon'),
      blockedEntry('https://cdn.test/f', 'iframe'),
      blockedEntry('https://cdn.test/o', 'other'),
    ], (url) async {
      looked.add(url);
      return 2048;
    });
    await load('https://a.test/');

    expect(looked..sort(), [
      'https://cdn.test/a.js',
      'https://cdn.test/b.css',
      'https://cdn.test/c.woff2',
      'https://cdn.test/d.png',
      'https://cdn.test/e.mp4',
    ]);
    final est = store.current.resourceEstimates;
    expect(est.keys.toSet(), looked.toSet());
    final one = est['https://cdn.test/a.js'] as Present<int>;
    expect(one.value, 2048);
    expect(one.source, DataSource.server);
    expect(one.provenance, Provenance.estimated);
  });

  test('at most 5 at a time, at most 80 per page', () async {
    var running = 0, peak = 0, calls = 0;
    service = make([
      for (var i = 0; i < 100; i++)
        blockedEntry('https://cdn.test/$i.js', 'script'),
    ], (url) async {
      calls++;
      running++;
      if (running > peak) peak = running;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      running--;
      return 100;
    });
    await service.loadUrl('https://a.test/');
    fetcher.pending.last
        .complete(okSnapshot('https://a.test/', '<html>S</html>'));
    await pumpEventQueue();
    await service.syncWebViewState('https://a.test/');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(peak, 5);
    expect(calls, 80);
    expect(store.current.resourceEstimates, hasLength(80));
  });

  test('a failing or empty lookup is recorded as not Present', () async {
    service = make([
      blockedEntry('https://cdn.test/a.js', 'script'),
      blockedEntry('https://cdn.test/b.js', 'script'),
    ], (url) async {
      if (url.endsWith('a.js')) throw StateError('offline');
      return null;
    });
    await load('https://a.test/');
    final est = store.current.resourceEstimates;
    expect(est['https://cdn.test/a.js'], isA<Failed<int>>());
    expect(est['https://cdn.test/b.js'], isA<Unavailable<int>>());
    final m = (service.pageSize as Present<PageSizeModel>).value;
    expect(m.weight.estimatedTransfer, isNull);
    expect(m.weight.missingCount, 2);
  });

  test('results that arrive after a new navigation are dropped', () async {
    final gate = Completer<int?>();
    service = make([blockedEntry('https://cdn.test/a.js', 'script')],
        (url) => gate.future);
    await service.loadUrl('https://a.test/');
    fetcher.pending.last
        .complete(okSnapshot('https://a.test/', '<html>S</html>'));
    await pumpEventQueue();
    await service.syncWebViewState('https://a.test/');
    await pumpEventQueue();

    await service.loadUrl('https://b.test/');
    gate.complete(555);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(store.current.resourceEstimates, isEmpty);
  });

  test('one lookup per URL, shared with the metadata items', () async {
    final looked = <String>[];
    service = make(
      [blockedEntry('https://cdn.test/a.js', 'script')],
      (url) async {
        looked.add(url);
        return 777;
      },
      metadata: () => {
        'jsLinks': ['https://cdn.test/a.js'],
      },
    );
    await load('https://a.test/');

    expect(looked, ['https://cdn.test/a.js']);
    expect(store.current.resourceEstimates['https://cdn.test/a.js'],
        isA<Present<int>>());
    final js = (service.pageMetadata!['jsLinks'] as List).single as Map;
    expect(js['size']['transfer'], 777);
    expect(js['size']['estimated'], true);
  });

  test('the Page Size view model changes when estimates arrive', () async {
    final gate = Completer<int?>();
    service = make([blockedEntry('https://cdn.test/a.js', 'script')],
        (url) => gate.future);
    await service.loadUrl('https://a.test/');
    fetcher.pending.last
        .complete(okSnapshot('https://a.test/', '<html>S</html>'));
    await pumpEventQueue();
    await service.syncWebViewState('https://a.test/');
    await pumpEventQueue();

    final before = service.pageSize;
    expect(identical(service.pageSize, before), isTrue);
    expect((before as Present<PageSizeModel>).value.estimatedCount, 0);

    gate.complete(4096);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final after = service.pageSize;
    expect(identical(after, before), isFalse);
    final m = (after as Present<PageSizeModel>).value;
    expect(m.estimatedCount, 1);
    expect(m.rows.single.sizeLabel, '≈ 4 KB');
  });
}
