import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/network_quiet.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_browser_sync_test.dart' show payload;
import 'html_service_lifecycle_test.dart'
    show FakeServerFetcher, FakeBrowserLoader, okSnapshot;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late FakeBrowserLoader loader;
  late HtmlService service;

  const callback =
      'https://www.ad.nl/privacy-gate/accept-tcf2?redirectUri=%2F&authId=abc';

  setUp(() {
    fetcher = FakeServerFetcher();
    loader = FakeBrowserLoader();
    service = HtmlService(
      store: InspectionStore(),
      serverFetcher: fetcher,
      browserLoader: loader,
      metadataExtractor: (html, baseUrl, {headers}) async => {'title': html},
      browserCollect: (url) async => payload(url: url),
      nativeCookies: (url) async => throw UnsupportedError('no cookies'),
      browserPlatform: BrowserPlatform.macos,
      browserPoll: NetworkQuietPolicy.off,
      spaSettleDelay: Duration.zero,
    );
    service.setAppSettings(AppSettings()..useBrowserByDefault = true);
  });

  tearDown(() => service.dispose());

  test('a navigation the WebView started is neither reloaded nor fetched',
      () async {
    await service.loadUrl('https://www.ad.nl/');
    fetcher.pending.last.complete(okSnapshot('https://www.ad.nl/', '<html/>'));
    await pumpEventQueue();
    fetcher.calls.clear();
    loader.calls.clear();

    // Idle after the load settled: full deferred handling.
    await service.syncWebViewState('https://www.ad.nl/');
    await pumpEventQueue();
    fetcher.calls.clear();
    loader.calls.clear();

    service.beginBrowserNavigation(callback);
    await pumpEventQueue();

    expect(loader.calls, isEmpty);
    expect(fetcher.calls, isEmpty);
    final server = service.store.current.server;
    expect(server, isA<Pending<ServerSnapshot>>());
    expect((server as Pending).detail,
        'waiting for the browser to finish loading');
  });

  test('redirect hops of an in-flight load do not flip the URL or refetch',
      () async {
    await service.loadUrl('https://www.ad.nl/economie/');
    final gen = service.store.current.generation;
    fetcher.calls.clear();
    loader.calls.clear();

    // The server chain ad.nl -> consent -> myprivacy.dpgmedia.nl: each hop
    // reaches shouldOverrideUrlLoading while the load is in flight.
    service.beginBrowserNavigation(
        'https://www.ad.nl/privacy-gate/accept-tcf2?redirectUri=%2Feconomie');
    service.beginBrowserNavigation('https://myprivacy.dpgmedia.nl/economie/');
    await pumpEventQueue();

    // No new generation, no URL flip, no extra fetch or browser load.
    expect(service.store.current.generation, gen);
    expect(service.currentInputText, 'https://www.ad.nl/economie/');
    expect(loader.calls, isEmpty);
    expect(fetcher.calls, isEmpty);

    // The final URL is fetched exactly once, at the non-partial sync.
    await service.syncWebViewState('https://myprivacy.dpgmedia.nl/economie/');
    await pumpEventQueue();
    expect(fetcher.calls.map((u) => u.toString()),
        ['https://myprivacy.dpgmedia.nl/economie/']);
    expect(service.currentInputText, 'https://myprivacy.dpgmedia.nl/economie/');
  });

  test('a mid-load navigation the finished chain does not cover is synced once',
      () async {
    await service.loadUrl('https://www.ad.nl/');
    fetcher.pending.last.complete(okSnapshot('https://www.ad.nl/', '<html/>'));
    await pumpEventQueue();
    fetcher.calls.clear();

    // Click aborted the in-flight load; the noted URL is outside the chain.
    service.beginBrowserNavigation(callback);
    await pumpEventQueue();
    expect(fetcher.calls, isEmpty);

    await service.syncWebViewState(callback);
    await pumpEventQueue();
    expect(fetcher.calls.map((u) => u.toString()), [callback]);
    expect(service.store.current.target, isA<UrlTarget>());
    expect((service.store.current.target as UrlTarget).url.toString(),
        callback);
  });

  test('after the browser settled, only its final URL is fetched', () async {
    service.beginBrowserNavigation(callback);
    // The server redirect to / is a navigation of its own.
    service.beginBrowserNavigation('https://www.ad.nl/');
    await service.syncWebViewState('https://www.ad.nl/');
    await pumpEventQueue();

    expect(fetcher.calls.map((u) => u.toString()), ['https://www.ad.nl/']);
    expect(loader.calls, isEmpty);
  });

  test('a redirect the app was not told about is fetched at its final URL',
      () async {
    service.beginBrowserNavigation(callback);
    await service.syncWebViewState('https://www.ad.nl/');
    await pumpEventQueue();

    expect(fetcher.calls.map((u) => u.toString()), ['https://www.ad.nl/']);
  });

  test('a user-typed URL is fetched immediately and loaded in the browser',
      () async {
    await service.loadUrl('https://www.ad.nl/');
    expect(fetcher.calls.map((u) => u.toString()), ['https://www.ad.nl/']);
    expect(loader.calls.map((u) => u.toString()), ['https://www.ad.nl/']);
  });

  test('a deferred fetch of a navigation that moved on never starts', () async {
    service.beginBrowserNavigation('https://a.test/one');
    await service.loadUrl('https://b.test/');
    fetcher.pending.last.complete(okSnapshot('https://b.test/', '<html/>'));
    await service.syncWebViewState('https://b.test/');
    await pumpEventQueue();

    expect(fetcher.calls.map((u) => u.toString()), ['https://b.test/']);
  });

  test('a partial sync does not start the deferred fetch', () async {
    service.beginBrowserNavigation('https://a.test/one');
    await service.syncWebViewState('https://a.test/one', isPartial: true);
    await pumpEventQueue();
    expect(fetcher.calls, isEmpty);

    await service.syncWebViewState('https://a.test/one');
    await pumpEventQueue();
    expect(fetcher.calls.map((u) => u.toString()), ['https://a.test/one']);
  });

  test('the same document as the current navigation is nothing new', () async {
    await service.loadUrl('https://a.test/');
    final gen = service.store.current.generation;
    service.beginBrowserNavigation('https://a.test/');
    expect(service.store.current.generation, gen);
  });

  test('source-first mode defers the same way and adopts the server body',
      () async {
    service.setAppSettings(AppSettings()..useBrowserByDefault = false);
    service.beginBrowserNavigation(callback);
    await pumpEventQueue();
    expect(fetcher.calls, isEmpty);
    expect(loader.calls, isEmpty);

    await service.syncWebViewState('https://www.ad.nl/');
    await pumpEventQueue();
    expect(fetcher.calls.map((u) => u.toString()), ['https://www.ad.nl/']);
    expect(loader.calls, isEmpty);
  });
}
