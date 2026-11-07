import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/request_timeline_view.dart';

import '../derive/fixtures.dart' show browserSnap, inspection, res, b;
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    service = makeService(seedStore(InspectionStore(), p));
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const RequestTimelineView());
    await tester.pump();
  }

  void noPlaceholders() {
    for (final bad in ['N/A', 'null', 'Status N/A', 'Size N/A']) {
      expect(find.textContaining(bad), findsNothing, reason: bad);
    }
  }

  group('RequestTimelineView', () {
    testWidgets('(a) full page: values equal the fixture', (tester) async {
      await show(tester, fullPage());
      expect(find.text('App request: 200 OK'), findsOneWidget);
      expect(find.text('2 resources'), findsOneWidget);
      expect(find.text('app.js'), findsWidgets);
      expect(find.text('10ms / 20ms'), findsWidgets);
      expect(find.text('12 KB (↓ 4 KB)'), findsWidgets);
      expect(find.text('Redirect Chain'), findsOneWidget);
      expect(find.text('301 Moved'), findsOneWidget);
      noPlaceholders();
    });

    testWidgets('(b) iOS: lower-bound total and unknown sizes', (tester) async {
      await show(tester, iosPartial());
      expect(find.textContaining('≥ '), findsWidgets);
      expect(find.textContaining('size unknown'), findsWidgets);
      expect(find.text('0 KB'), findsNothing);
      expect(find.textContaining(RegExp(r'(^| )0 KB')), findsNothing);
      noPlaceholders();
    });

    testWidgets('(b) a request without timing is listed without a bar',
        (tester) async {
      await show(
          tester,
          inspection(
              browser: browserSnap(resources: [
            res('https://a.test/a.js', tx: b(10), dec: b(20)),
          ])));
      expect(find.text('a.js'), findsOneWidget);
      expect(find.textContaining('timing unknown'), findsOneWidget);
      expect(find.textContaining('has no timing'), findsOneWidget);
      expect(find.textContaining('0ms'), findsNothing);
    });

    testWidgets('(b) a browser with no requests says so, only then',
        (tester) async {
      await show(tester, inspection(browser: browserSnap(resources: const [])));
      expect(find.text('The browser reported no requests for this page.'),
          findsOneWidget);
      expect(find.text('0 resources'), findsOneWidget);
    });

    testWidgets('(c) local file: says it is not available', (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('local file'), findsOneWidget);
      expect(find.text('Resource Timeline'), findsNothing);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = RequestTimelineView.builds;
      service.updateWebViewLoadingProgress(0.5);
      await tester.pump();
      expect(RequestTimelineView.builds, before);
    });

    testWidgets('(e) pending and failed browser are distinct', (tester) async {
      await show(tester, fullPage().copyWith(browser: const Pending()));
      expect(find.textContaining('Waiting for the browser'), findsOneWidget);
      expect(find.text('Redirect Chain'), findsOneWidget);
      expect(find.textContaining('0 resources'), findsNothing);
      await show(
          tester, fullPage().copyWith(browser: const Failed('payload broke')));
      expect(find.textContaining('payload broke'), findsWidgets);
      expect(find.textContaining('Waiting for the browser'), findsNothing);
    });

    testWidgets('server pending: the status is unknown, not N/A',
        (tester) async {
      await show(tester, fullPage().copyWith(server: const Pending()));
      expect(find.textContaining('App request: unknown'), findsOneWidget);
      noPlaceholders();
    });
  });
}
