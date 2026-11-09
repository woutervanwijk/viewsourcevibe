import 'dart:typed_data';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/collectors/fresh_load_measurer.dart';
import 'package:view_source_vibe/services/derive/network_quiet.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_browser_sync_test.dart' show payload, obs;
import 'html_service_estimates_test.dart' show blockedEntry;
import 'html_service_lifecycle_test.dart'
    show FakeServerFetcher, FakeBrowserLoader, okSnapshot;

class FakeMeasurer implements FreshLoadMeasurer {
  final Future<FreshLoadRaw> Function(Uri url) answer;
  final calls = <Uri>[];
  NetworkQuietPolicy? policy;
  FakeMeasurer(this.answer);
  @override
  Future<FreshLoadRaw> measure(Uri url, NetworkQuietPolicy policy) {
    calls.add(url);
    this.policy = policy;
    return answer(url);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late InspectionStore store;
  late HtmlService service;

  HtmlService make(FreshLoadMeasurer? measurer,
      {Future<int?> Function(String url)? lookup,
      Future<Uint8List?> Function()? screenshot}) {
    final s = HtmlService(
      store: store,
      serverFetcher: fetcher,
      browserLoader: FakeBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
      browserCollect: (url) async => payload(
          url: url, observer: [obs('https://a.test/app.js', tx: 1000)]),
      nativeCookies: (u) async => [],
      browserPlatform: BrowserPlatform.ios,
      browserPoll: NetworkQuietPolicy.off,
      spaSettleDelay: Duration.zero,
      sizeLookup: lookup ?? (u) async => 40000,
      freshLoadMeasurer: measurer,
      browserScreenshot: screenshot ?? () async => null,
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
  }

  test('not measured until asked; then the fresh load with its lookups',
      () async {
    final m = FakeMeasurer((url) async => FreshLoadRaw(
        payload(url: '$url', observer: [
          obs('https://a.test/app.js', tx: 1000),
          obs('https://a.test/late.js', tx: 9000),
          blockedEntry('https://ads.test/ad.jpg', 'img'),
        ]),
        screenshot: Uint8List.fromList([1, 2, 3])));
    service = make(m);
    await load('https://a.test/');
    expect(store.current.freshLoad, isA<Unavailable<BrowserSnapshot>>());
    expect(m.calls, isEmpty, reason: 'a fresh load costs data: only on ask');

    await service.measureFreshLoad();
    await pumpEventQueue();

    expect(m.calls.single.toString(), 'https://a.test/');
    expect(m.policy, NetworkQuietPolicy.fresh);
    final page = (service.pageSize as Present<PageSizeModel>).value;
    final fresh = (page.fresh as Present<PageSizeModel>).value;
    // 1000 + 9000 measured + 40000 own lookup (+ the server document).
    expect(fresh.weight.estimatedTransfer, 40000);
    expect(fresh.weight.measuredTransfer, greaterThanOrEqualTo(10000));
    expect(page.lighthouseNote, startsWith('Verdict (fresh load)'));
    // The live load is untouched.
    expect(page.weight.breakdown['scripts']!.transfer, 1000);
    // Its screenshot comes along; the live one is separate.
    expect((page.freshScreenshot as Present<Uint8List>).value, [1, 2, 3]);
    // 1 KB live vs ~50 KB fresh: the difference is explained.
    expect(page.differenceNote, contains('cookie or consent wall'));
  });

  test('the live browser screenshot is taken once the page loaded',
      () async {
    service = make(const NoFreshLoad(),
        screenshot: () async => Uint8List.fromList([9]));
    await load('https://a.test/');
    await pumpEventQueue();
    expect((store.current.liveScreenshot as Present<Uint8List>).value, [9]);
  });

  test('no screenshot is said, never an empty image', () async {
    service = make(const NoFreshLoad(), screenshot: () async => null);
    await load('https://a.test/');
    await pumpEventQueue();
    expect(store.current.liveScreenshot, isA<Unavailable<Uint8List>>());
  });

  test('pending while it runs; a failure is shown, not a size', () async {
    final gate = Completer<FreshLoadRaw>();
    service = make(FakeMeasurer((_) => gate.future));
    await load('https://a.test/');
    final run = service.measureFreshLoad();
    await pumpEventQueue();
    expect(store.current.freshLoad, isA<Pending<BrowserSnapshot>>());
    gate.completeError(StateError('offline'));
    await run;
    final f = store.current.freshLoad;
    expect(f, isA<Failed<BrowserSnapshot>>());
    expect((f as Failed).error, contains('offline'));
  });

  test('a navigation during the measurement drops its result', () async {
    final gate = Completer<FreshLoadRaw>();
    service = make(FakeMeasurer((_) => gate.future));
    await load('https://a.test/');
    final run = service.measureFreshLoad();
    await pumpEventQueue();
    await load('https://b.test/');
    gate.complete(FreshLoadRaw(payload(
        url: 'https://a.test/', observer: [obs('https://a.test/x.js')])));
    await run;
    expect(store.current.freshLoad, isA<Unavailable<BrowserSnapshot>>());
  });

  test('no off-screen browser on this platform: said so', () async {
    service = make(const NoFreshLoad());
    await load('https://a.test/');
    await service.measureFreshLoad();
    final f = store.current.freshLoad;
    expect(f, isA<Unavailable<BrowserSnapshot>>());
    expect((f as Unavailable).reason, UnavailableReason.unsupportedPlatform);
  });
}
