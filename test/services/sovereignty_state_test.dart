import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

SovereigntyReport reportFor(String home) => SovereigntyReport(
    home: home,
    mainHost: 'example.com',
    hosts: const [],
    cdn: null,
    nameServers: const [],
    mailServers: const [],
    tlsIssuer: null,
    tlsProvider: null,
    checks: const []);

void main() {
  late InspectionStore store;
  late HtmlService service;
  late List<String> calls; // page URLs the analyzer was asked about
  late Future<SovereigntyReport> Function(String home) behaviour;

  HtmlService make() => HtmlService(
        store: store,
        serverFetcher: SilentServerFetcher(),
        browserLoader: SilentBrowserLoader(),
        metadataExtractor: (html, baseUrl, {headers}) async => {},
        sovereigntyAnalyzer: ({
          required pageUrl,
          required probeResult,
          required resources,
          metadata,
          detections = const [],
          html,
          home = 'EU',
        }) {
          calls.add(pageUrl);
          return behaviour(home);
        },
      );

  setUp(() {
    store = InspectionStore();
    calls = [];
    behaviour = (home) async => reportFor(home);
    service = make();
  });
  tearDown(() => service.dispose());

  group('sovereigntyState', () {
    test('nothing loaded / a local file: unavailable with a message', () {
      expect((service.sovereigntyState as Unavailable).detail,
          'Load a URL to analyze where it is hosted.');
      seedStore(store, localFile());
      expect((service.sovereigntyState as Unavailable).detail,
          contains('local file'));
    });

    test('a URL without a result yet is pending, not "load a URL"', () {
      seedStore(store, fullPage());
      expect(service.sovereigntyState, isA<Pending<SovereigntyReport>>());
    });
  });

  group('the service starts the analysis itself', () {
    test('never when no tab watches', () async {
      seedStore(store, fullPage());
      await pumpEventQueue();
      expect(calls, isEmpty);
    });

    test('once watched and the page is loaded: one run, a Present state',
        () async {
      seedStore(store, fullPage());
      service.watchSovereignty(true);
      await pumpEventQueue();
      expect(calls, ['https://example.com/']);
      expect(service.sovereigntyState, isA<Present<SovereigntyReport>>());
      // More notifications do not start another run.
      store.applyRobots(store.current.generation, const Pending());
      await pumpEventQueue();
      expect(calls, hasLength(1));
    });

    test('waits for the server answer; starts when it arrives', () async {
      final p = fullPage();
      seedStore(store, p.copyWith(server: const Pending()));
      service.watchSovereignty(true);
      await pumpEventQueue();
      expect(calls, isEmpty);
      store.applyServer(store.current.generation, p.server);
      await pumpEventQueue();
      expect(calls, hasLength(1));
    });

    test('a failing analysis is a Failed state, shown once, not looped',
        () async {
      behaviour = (home) async => throw Exception('RIPEstat down');
      seedStore(store, fullPage());
      service.watchSovereignty(true);
      await pumpEventQueue();
      final state = service.sovereigntyState;
      expect(state, isA<Failed<SovereigntyReport>>());
      expect((state as Failed).error, contains('RIPEstat down'));
      await pumpEventQueue();
      expect(calls, hasLength(1));
      // An explicit re-run tries again.
      behaviour = (home) async => reportFor(home);
      await service.analyzeSovereignty();
      expect(calls, hasLength(2));
      expect(service.sovereigntyState, isA<Present<SovereigntyReport>>());
    });

    test('a new page is analysed again, the old report does not show',
        () async {
      seedStore(store, fullPage());
      service.watchSovereignty(true);
      await pumpEventQueue();
      expect(service.sovereigntyState, isA<Present<SovereigntyReport>>());
      store.beginUrl(Uri.parse('https://other.test/'));
      expect(service.sovereigntyState, isA<Pending<SovereigntyReport>>());
      store.applyServer(
          store.current.generation,
          server(serverSnapshot(
              url: 'https://other.test/',
              hops: [hop('https://other.test/', 200)],
              body: 'x')));
      await pumpEventQueue();
      expect(calls, ['https://example.com/', 'https://other.test/']);
    });

    test('a changed legal home re-runs the analysis', () async {
      final settings = AppSettings();
      service.setAppSettings(settings);
      seedStore(store, fullPage());
      service.watchSovereignty(true);
      await pumpEventQueue();
      expect(calls, hasLength(1));
      final before = service.siteJurisdiction.jurisdiction;
      final other = before == 'US' ? 'EU' : 'US';
      service.setSiteJurisdiction(other);
      await pumpEventQueue();
      expect(calls, hasLength(2));
      expect(service.sovereigntyReport!.home, other);
    });

    test('stops when the last watcher leaves', () async {
      service.watchSovereignty(true);
      service.watchSovereignty(false);
      seedStore(store, fullPage());
      await pumpEventQueue();
      expect(calls, isEmpty);
    });
  });

  group('site jurisdiction', () {
    test('the host comes from the store, not from a legacy file', () {
      seedStore(store, fullPage());
      expect(service.sovereigntyDomain, 'example.com');
      expect(Uri.parse('https://example.com/').host, 'example.com');
    });
  });
}
