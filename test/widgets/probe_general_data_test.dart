import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';

import '../fixtures/inspection/bot_blocked.dart';
import '../fixtures/inspection/builders.dart';
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
        service: service, child: const ProbeGeneralView());
    await tester.pump();
  }

  void noPlaceholders() {
    for (final bad in ['N/A', 'null', 'No cache policy']) {
      expect(find.textContaining(bad), findsNothing, reason: bad);
    }
  }

  group('ProbeGeneralView', () {
    testWidgets('(a) full page: values equal the fixture', (tester) async {
      await show(tester, fullPage());
      expect(find.textContaining('200 OK'), findsWidgets);
      expect(find.text('301 Moved'), findsOneWidget);
      expect(find.text('https://example.com/'), findsWidgets);
      expect(find.textContaining('93.184.216.34'), findsOneWidget);
      expect(find.textContaining('42 ms (measured by the app'), findsOneWidget);
      expect(find.textContaining('ViewSourceVibe/'), findsOneWidget);
      expect(find.text('robots 200'), findsOneWidget);
      expect(find.text('1 disallow'), findsOneWidget);
      expect(find.text('2 requests'), findsOneWidget);
      noPlaceholders();
    });

    testWidgets('(a) the browser card shows no HTTP status', (tester) async {
      await show(tester, botBlocked());
      expect(find.text('HTTP Status'), findsNothing);
      expect(find.textContaining('403 Forbidden'), findsWidgets);
    });

    testWidgets('(b) iOS: totals are a lower bound', (tester) async {
      await show(tester, iosPartial());
      expect(find.textContaining('≥ '), findsWidgets);
      noPlaceholders();
    });

    testWidgets('(b) bot blocked: the divergence is listed', (tester) async {
      await show(tester, botBlocked());
      expect(find.textContaining("server returned 403 to the app's request"),
          findsOneWidget);
    });

    testWidgets('(b) a www-only redirect is summarized as a minor note',
        (tester) async {
      // Server ended on www., the browser on the bare host.
      final p = urlInspection(
        url: 'https://example.com/',
        serverResult: server(serverSnapshot(
            url: 'https://example.com/',
            hops: [
              hop('https://www.example.com/', 200,
                  headers: {'content-type': ['text/html']})
            ],
            body: '<html/>')),
        browserResult: browser(
            browserSnapshot(url: 'https://example.com/', dom: '<html/>')),
      );
      await show(tester, p);
      expect(find.textContaining('1 minor difference'), findsOneWidget);
      expect(find.textContaining('www.example.com'), findsWidgets);
    });

    testWidgets('(c) local file: says there is nothing to probe',
        (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('local file'), findsOneWidget);
      expect(find.text('Curl Probe (Server-Side)'), findsNothing);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = ProbeGeneralView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      service.updateWebViewLoadingProgress(0.8);
      await tester.pump();
      expect(ProbeGeneralView.builds, before);
    });

    testWidgets('(e) pending server says fetching; failed shows the error',
        (tester) async {
      await show(tester, fullPage().copyWith(server: const Pending()));
      expect(find.textContaining('Fetching'), findsWidgets);
      await show(tester,
          fullPage().copyWith(server: const Failed('network error: boom')));
      expect(find.textContaining('network error: boom'), findsWidgets);
      expect(find.textContaining('Fetching'), findsNothing);
    });

    testWidgets('robots counts that are unknown never show as 0',
        (tester) async {
      final base = fullPage();
      await show(
          tester,
          base.copyWith(
              robots: const Failed('timeout: robots.txt did not answer')));
      expect(find.textContaining('timeout: robots.txt did not answer'),
          findsOneWidget);
      expect(find.textContaining('0 disallow'), findsNothing);
      expect(find.textContaining('0 allow'), findsNothing);
    });

    testWidgets('browser pending: spinner and text, no zero counts',
        (tester) async {
      await show(tester, fullPage().copyWith(browser: const Pending()));
      expect(find.textContaining('Waiting for the browser'), findsWidgets);
      expect(find.textContaining('0 requests'), findsNothing);
      noPlaceholders();
    });

    testWidgets('storage that was not collected is not shown as empty',
        (tester) async {
      await show(tester, fullPage());
      expect(find.textContaining('0 keys'), findsNothing);
      expect(find.textContaining('Not applicable'), findsWidgets);
    });

    testWidgets('a redirect Location can be loaded from the chain',
        (tester) async {
      await show(tester, fullPage());
      expect(find.byIcon(Icons.alt_route), findsWidgets);
    });
  });
}
