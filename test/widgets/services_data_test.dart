import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/services_view.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';
import '../fixtures/inspection/trackers.dart';

void main() {
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p,
      {HtmlService Function(InspectionStore)? make}) async {
    final store = seedStore(InspectionStore(), p);
    service = (make ?? makeServiceWithMetadata)(store);
    addTearDown(service.dispose);
    await tester.runAsync(() => service.loadFile(htmlFileFor(p, content: 'x')));
    await pumpWithProviders(tester,
        service: service, child: const ServicesView());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('(a) trackers and services equal the fixture, with sources',
      (tester) async {
    await show(tester, trackerPage());
    expect(find.text('Tracker Radar'), findsOneWidget);
    expect(find.text('Meta Pixel'), findsWidgets);
    expect(find.textContaining('Google Analytics'), findsWidgets);
    // Each finding says which sources saw it.
    expect(find.textContaining('seen in'), findsWidgets);
    expect(find.textContaining('Checked: server HTML and headers'),
        findsOneWidget);
    expect(find.textContaining('No Services Detected'), findsNothing);
  });

  testWidgets('(b) iOS: external resources with unknown sizes say so',
      (tester) async {
    await show(tester, iosPartialWithLinks());
    expect(find.textContaining('size unknown (Not visible'), findsWidgets);
    expect(find.textContaining('0 KB'), findsNothing);
  });

  testWidgets('(c) local file: names the sources that were not available',
      (tester) async {
    await show(tester, localFile());
    expect(find.text('No Services Detected'), findsOneWidget);
    expect(find.textContaining('Checked: file source'), findsOneWidget);
    expect(
        find.textContaining('browser requests not available for local files'),
        findsOneWidget);
  });

  testWidgets('(c) a file after a URL shows nothing of the URL page',
      (tester) async {
    final store = seedStore(InspectionStore(), trackerPage());
    service = makeServiceWithMetadata(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const ServicesView());
    await tester.pump();
    expect(find.text('Meta Pixel'), findsWidgets);
    final lf = localFile();
    store.beginFile((lf.target as FileTarget).file);
    await tester.pump();
    expect(find.text('Meta Pixel'), findsNothing);
    expect(find.textContaining('Checked: file source'), findsOneWidget);
  });

  testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
    await show(tester, trackerPage());
    final before = ServicesView.builds;
    service.updateWebViewLoadingProgress(0.3);
    await tester.pump();
    service.updateWebViewLoadingProgress(0.8);
    await tester.pump();
    expect(ServicesView.builds, before);
  });

  testWidgets('(e) scanning, failed and none found read differently',
      (tester) async {
    final c = Completer<List<Map<String, dynamic>>>();
    final store = seedStore(InspectionStore(), fullPage());
    service = HtmlService(
      store: store,
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (h, b, {headers}) async => {},
      detectionScanner: (t) => c.future,
    );
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const ServicesView());
    await tester.pump();
    expect(find.text('Scanning…'), findsOneWidget);
    expect(find.text('No Services Detected'), findsNothing);
    c.completeError(StateError('scan broke'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.textContaining('scan broke'), findsOneWidget);
    expect(find.text('No Services Detected'), findsNothing);
    expect(find.text('Scanning…'), findsNothing);
  });

  testWidgets('nothing readable is not "no services"', (tester) async {
    final p = fullPage().copyWith(
        server: const Failed('timeout'), browser: const Failed('crashed'));
    final store = seedStore(InspectionStore(), p);
    service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const ServicesView());
    await tester.pump();
    expect(find.text('No Services Detected'), findsNothing);
    expect(find.textContaining('Nothing could be checked'), findsOneWidget);
    expect(find.textContaining('timeout'), findsOneWidget);
  });
}
