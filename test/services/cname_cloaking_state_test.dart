import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/cname_cloaking_service.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  late InspectionStore store;
  late HtmlService service;
  late List<String> looked;
  var hang = false;
  var finderThrows = false;

  final page = fullPage().copyWith(
    browser: browser(browserSnapshot(
      url: 'https://www.example.com/',
      dom: fullPageDomHtml,
      resources: [
        resource('https://metrics.example.com/s.js', 'script'),
        resource('https://static.example.com/a.css', 'css'),
      ],
    )),
  );

  setUp(() {
    store = InspectionStore();
    looked = [];
    service = HtmlService(
      store: store,
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
      cloakingFinder: (hosts, {required pageHost, required lookup}) {
        if (finderThrows) throw StateError('boom');
        return findCloakedTrackers(hosts, pageHost: pageHost, lookup: lookup);
      },
      cnameLookup: (h) async {
        looked.add(h);
        if (hang) return Completer<List<String>?>().future;
        return h.startsWith('metrics') ? ['x.sc.omtrdc.net'] : const [];
      },
    );
  });
  tearDown(() => service.dispose());

  test('no lookup while no view watches', () async {
    seedStore(store, page);
    await pumpEventQueue();
    expect(looked, isEmpty);
    expect(service.cnameCloaking, isA<Pending<CloakingResult>>());
  });

  test('watched and settled: one lookup run, a Present result', () async {
    seedStore(store, page);
    service.watchCloaking(true);
    await pumpEventQueue();
    final state = service.cnameCloaking as Present<CloakingResult>;
    expect(state.value.aliases.single.host, 'metrics.example.com');
    expect(looked.toSet(), {'metrics.example.com', 'static.example.com'});
    final n = looked.length;
    store.applyRobots(store.current.generation, const Pending());
    await pumpEventQueue();
    expect(looked.length, n);
  });

  test('a result for a page we navigated away from is dropped', () async {
    seedStore(store, page);
    service.watchCloaking(true);
    seedStore(store, page); // new generation before the lookups answer
    await pumpEventQueue();
    final state = service.cnameCloaking as Present<CloakingResult>;
    expect(state.value.aliases, hasLength(1));
  });

  test('the next page does not show the previous page result', () async {
    seedStore(store, page);
    service.watchCloaking(true);
    await pumpEventQueue();
    expect(service.cnameCloaking, isA<Present<CloakingResult>>());
    hang = true;
    seedStore(store, page);
    await pumpEventQueue();
    expect(service.cnameCloaking, isA<Pending<CloakingResult>>());
  });

  test('a check that throws is Failed, not Pending forever', () async {
    finderThrows = true;
    seedStore(store, page);
    service.watchCloaking(true);
    await pumpEventQueue();
    expect(service.cnameCloaking, isA<Failed<CloakingResult>>());
  });

  test('no in-app browser result: says so instead of checking forever',
      () async {
    seedStore(store, page.copyWith(browser: const Failed('no webview')));
    service.watchCloaking(true);
    await pumpEventQueue();
    final state = service.cnameCloaking as Unavailable<CloakingResult>;
    expect(state.detail, 'Needs the in-app browser');
    expect(looked, isEmpty);
  });

  test('a page that is not http(s) has no hostnames to check', () async {
    seedStore(
        store,
        page.copyWith(
            browser: browser(browserSnapshot(
                url: 'about:blank', dom: fullPageDomHtml, resources: []))));
    service.watchCloaking(true);
    await pumpEventQueue();
    final state = service.cnameCloaking as Unavailable<CloakingResult>;
    expect(state.reason, UnavailableReason.notApplicable);
  });
}
