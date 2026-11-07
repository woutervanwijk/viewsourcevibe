import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/privacy_view.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';
import '../fixtures/inspection/trackers.dart';

void main() {
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p) async {
    service = makeService(seedStore(InspectionStore(), p));
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PrivacyView());
    await tester.pump();
  }

  testWidgets('(a) trackers equal the fixture, each with its sources',
      (tester) async {
    await show(tester, trackerPage());
    expect(find.textContaining('trackers follow you here'), findsOneWidget);
    expect(find.text('Meta Pixel'), findsOneWidget);
    // Evidence rows carry a source badge (browser / server).
    expect(find.text('browser'), findsWidgets);
    expect(find.text('server'), findsWidgets);
    expect(find.textContaining('Checked: server HTML and headers'),
        findsOneWidget);
  });

  testWidgets('(b) a page seen only by the server says what was not checked',
      (tester) async {
    final p = trackerPage().copyWith(
        browser: const Unavailable(
            UnavailableReason.blockedByPlatform, 'WebView not supported'));
    await show(tester, p);
    expect(find.textContaining('browser data not visible'), findsOneWidget);
    expect(find.text('No Trackers Detected'), findsNothing);
  });

  testWidgets('(c) local file: no tracker of a previous URL, wording',
      (tester) async {
    final store = seedStore(InspectionStore(), trackerPage());
    service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PrivacyView());
    await tester.pump();
    expect(find.text('Meta Pixel'), findsOneWidget);
    store.beginFile((localFile().target as FileTarget).file);
    await tester.pump();
    expect(find.text('Meta Pixel'), findsNothing);
    expect(find.text('No Trackers Detected'), findsOneWidget);
    expect(
        find.textContaining('browser requests not available for local files'),
        findsOneWidget);
  });

  testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
    await show(tester, trackerPage());
    final before = PrivacyView.builds;
    service.updateWebViewLoadingProgress(0.5);
    await tester.pump();
    service.updateWebViewLoadingProgress(0.9);
    await tester.pump();
    expect(PrivacyView.builds, before);
  });

  testWidgets('(e) scanning, failed and none found are distinct',
      (tester) async {
    final c = Completer<List<Map<String, dynamic>>>();
    service = HtmlService(
      store: seedStore(InspectionStore(), fullPage()),
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (h, b, {headers}) async => {},
      detectionScanner: (t) => c.future,
    );
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PrivacyView());
    await tester.pump();
    expect(find.text('Scanning…'), findsOneWidget);
    expect(find.text('No Trackers Detected'), findsNothing);
    c.completeError(StateError('scan broke'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.textContaining('scan broke'), findsOneWidget);
    expect(find.text('No Trackers Detected'), findsNothing);
  });

  testWidgets('a completed scan with no trackers says none found',
      (tester) async {
    await show(tester, fullPage());
    expect(find.text('No Trackers Detected'), findsOneWidget);
    expect(find.textContaining('Checked:'), findsOneWidget);
  });
}
