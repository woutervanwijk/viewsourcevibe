import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/derive/media.dart';
import 'package:view_source_vibe/services/derive/metadata_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/pump.dart';
import 'html_service_browser_sync_test.dart' show payload, obs;
import 'html_service_lifecycle_test.dart'
    show FakeServerFetcher, FakeBrowserLoader, okSnapshot;

MetadataModel modelOf(HtmlService s) =>
    (s.metadataState as Present<MetadataModel>).value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('selectSourceDocument re-extracts the metadata', () {
    final calls = <String>[];
    final gates = <String, Completer<void>>{};

    HtmlService make(InspectionStore store) => HtmlService(
          store: store,
          serverFetcher: SilentServerFetcher(),
          browserLoader: SilentBrowserLoader(),
          metadataExtractor: (html, base, {headers}) async {
            calls.add(html);
            final gate = gates[html];
            if (gate != null) await gate.future;
            final m = extractMetadataSync(html, base);
            if (gate != null) m['title'] = 'LATE ${m['title']}';
            return m;
          },
        );

    setUp(() {
      calls.clear();
      gates.clear();
    });

    test('switching the document changes the metadata and its docSource',
        () async {
      final p = fullPage();
      final service = make(seedStore(InspectionStore(), p));
      addTearDown(service.dispose);
      await service.loadFile(htmlFileFor(p, content: 'x'));
      expect(service.pageMetadata!['title'], 'Rendered');
      expect(modelOf(service).docSource, DataSource.browser);

      service.selectSourceDocument(DataSource.server);
      await pumpEventQueue();
      expect(service.pageMetadata!['title'], 'Server');
      expect(modelOf(service).docSource, DataSource.server);
      expect(modelOf(service).sourceLine, 'From: server HTML');
    });

    test('A -> B with A finishing late ends with B, never A', () async {
      final p = fullPage();
      final service = make(seedStore(InspectionStore(), p));
      addTearDown(service.dispose);
      await service.loadFile(htmlFileFor(p, content: 'x'));

      gates[fullPageServerHtml] = Completer<void>();
      service.selectSourceDocument(DataSource.server); // A, held
      await pumpEventQueue();
      service.selectSourceDocument(DataSource.browser); // B, queued
      await pumpEventQueue();
      gates[fullPageServerHtml]!.complete();
      await pumpEventQueue();

      expect(service.pageMetadata!['title'], 'Rendered');
      expect(modelOf(service).docSource, DataSource.browser);
      expect(service.isExtractingMetadata, isFalse);
      expect(calls.last, fullPageDomHtml);
    });

    test('a navigation during extraction drops the result', () async {
      final p = fullPage();
      final store = seedStore(InspectionStore(), p);
      final service = make(store);
      addTearDown(service.dispose);
      await service.loadFile(htmlFileFor(p, content: 'x'));

      gates[fullPageServerHtml] = Completer<void>();
      service.selectSourceDocument(DataSource.server);
      await pumpEventQueue();
      store.clear(); // new generation while the extraction runs
      gates[fullPageServerHtml]!.complete();
      await pumpEventQueue();

      expect(service.pageMetadata?['title'], isNot(startsWith('LATE')));
      // The late result was dropped; what stays is a rerun on what is
      // current now (the viewer's own file text, the store has no document).
      expect(calls.last, 'x');
    });
  });

  group('size updates change the state identity and the labels', () {
    const url = 'https://a.test/';
    const html = '<html><head><title>S</title>'
        '<script src="https://a.test/s.js"></script></head>'
        '<body><img src="https://a.test/p.png" alt="P"></body></html>';

    late FakeServerFetcher fetcher;
    late InspectionStore store;
    late String collected;
    Completer<int?>? lookupGate;

    HtmlService make() {
      final s = HtmlService(
        store: store,
        serverFetcher: fetcher,
        browserLoader: FakeBrowserLoader(),
        metadataExtractor: (h, b, {headers}) async =>
            extractMetadataSync(h, b, headers: headers),
        browserCollect: (u) async => collected,
        nativeCookies: (u) async => throw UnsupportedError('none'),
        browserPlatform: BrowserPlatform.macos,
        browserRefreshDelays: const [],
        spaSettleDelay: Duration.zero,
        sizeLookup: (u) => lookupGate?.future ?? Future.value(null),
      );
      s.setAppSettings(AppSettings()..useBrowserByDefault = true);
      return s;
    }

    String jsLabel(HtmlService s) {
      final m = modelOf(s);
      final item = (m.data['jsLinks'] as List)
          .cast<Map>()
          .firstWhere((e) => e['src'] == 'https://a.test/s.js');
      return linkSizeLabel(item['size'], unknownReason: m.sizeUnknownReason);
    }

    String imgLabel(HtmlService s) =>
        (s.mediaState as Present<MediaModel>).value.images.single.sizeLabel;

    Future<HtmlService> loaded() async {
      fetcher = FakeServerFetcher();
      store = InspectionStore();
      collected = payload(url: url, dom: html);
      final s = make();
      await s.loadUrl(url);
      fetcher.pending.last.complete(okSnapshot(url, html));
      await pumpEventQueue();
      await s.syncWebViewState(url);
      await pumpEventQueue();
      return s;
    }

    test('browser resources arriving later update both tabs', () async {
      final s = await loaded();
      addTearDown(s.dispose);
      expect(jsLabel(s), startsWith('size unknown'));
      expect(imgLabel(s), startsWith('size unknown'));
      final meta = s.metadataState;
      final media = s.mediaState;

      // No DOM this time: only the resources are applied to the metadata.
      collected = payload(url: url, domOk: false, observer: [
        {...obs('https://a.test/s.js', tx: 2048, dec: 8192)},
        {...obs('https://a.test/p.png', tx: 3072, dec: 3072), 'it': 'img'},
      ]);
      await s.syncWebViewState(url);
      await pumpEventQueue();

      expect(identical(s.metadataState, meta), isFalse);
      expect(identical(s.mediaState, media), isFalse);
      expect(jsLabel(s), '8 KB (↓ 2 KB)');
      expect(imgLabel(s), '3 KB');
    });

    test('an own size lookup updates both tabs, marked as an estimate',
        () async {
      lookupGate = Completer<int?>();
      addTearDown(() => lookupGate = null);
      final s = await loaded();
      addTearDown(s.dispose);
      expect(imgLabel(s), startsWith('size unknown'));
      final meta = s.metadataState;
      final media = s.mediaState;

      lookupGate!.complete(4096);
      await pumpEventQueue();

      expect(identical(s.metadataState, meta), isFalse);
      expect(identical(s.mediaState, media), isFalse);
      expect(imgLabel(s), '≈ 4 KB');
      expect(jsLabel(s), '≈ ↓ 4 KB');
    });
  });
}
