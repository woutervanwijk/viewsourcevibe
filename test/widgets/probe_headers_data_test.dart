import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

PageInspection withHeaders(Map<String, List<String>> h) => urlInspection(
      url: 'https://a.test/',
      serverResult: server(serverSnapshot(
          url: 'https://a.test/',
          hops: [hop('https://a.test/', 200, headers: h)],
          body: 'x')),
      browserResult: const Pending(),
    );

void main() {
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    service = makeService(seedStore(InspectionStore(), p));
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const ProbeHeadersView());
    await tester.pump();
  }

  group('ProbeHeadersView', () {
    testWidgets('(a) full page: insights and headers equal the fixture',
        (tester) async {
      await show(tester, fullPage());
      expect(find.text('Header Intelligence'), findsOneWidget);
      expect(find.text('No cache policy'), findsOneWidget);
      expect(find.text('Origin-ish'), findsOneWidget);
      expect(find.text('server'), findsWidgets);
      expect(find.text('nginx'), findsWidgets);
      expect(find.text('Final response · 200 OK'), findsOneWidget);
      expect(find.text('Redirect 1 · 301 Moved'), findsOneWidget);
    });

    testWidgets('(a) a repeated header shows each value on its own line',
        (tester) async {
      await show(
          tester,
          withHeaders({
            'vary': ['Accept', 'Accept-Encoding']
          }));
      expect(find.text('Accept\nAccept-Encoding'), findsOneWidget);
      expect(find.text('Vary: 2'), findsOneWidget);
    });

    testWidgets('(b) pending server: unknown, never "No cache policy"',
        (tester) async {
      await show(tester, fullPage().copyWith(server: const Pending()));
      expect(find.text('Cache: unknown'), findsOneWidget);
      expect(find.text('No cache policy'), findsNothing);
      expect(find.text('No compression'), findsNothing);
      expect(find.text('No CORS'), findsNothing);
      expect(find.textContaining('Fetching'), findsWidgets);
      expect(find.text('All Response Headers'), findsNothing);
    });

    testWidgets('(b) failed server: unknown plus the error', (tester) async {
      await show(tester,
          fullPage().copyWith(server: const Failed('network error: boom')));
      expect(find.text('Cache: unknown'), findsOneWidget);
      expect(find.textContaining('network error: boom'), findsOneWidget);
      expect(find.text('No cache policy'), findsNothing);
    });

    testWidgets('(c) local file: nothing to show', (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('local file'), findsOneWidget);
      expect(find.text('Header Intelligence'), findsNothing);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = ProbeHeadersView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      expect(ProbeHeadersView.builds, before);
    });

    testWidgets('no placeholder strings', (tester) async {
      await show(tester, fullPage().copyWith(server: const Pending()));
      for (final bad in ['N/A', 'null']) {
        expect(find.textContaining(bad), findsNothing);
      }
    });
  });
}
