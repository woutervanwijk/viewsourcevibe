import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';
import 'package:view_source_vibe/widgets/sovereignty_view.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

SovereigntyReport report({
  List<HostInfo>? hosts,
  List<SovereigntyCheck> checks = const [],
}) =>
    SovereigntyReport(
      home: 'EU',
      mainHost: 'example.com',
      hosts: hosts ?? [HostInfo('example.com')..requests = 1],
      cdn: null,
      nameServers: const [],
      mailServers: const [],
      tlsIssuer: null,
      tlsProvider: null,
      checks: checks,
    );

void main() {
  late HtmlService service;
  late Future<SovereigntyReport> Function() behaviour;
  var calls = 0;

  Future<void> show(WidgetTester tester, PageInspection p,
      {Future<SovereigntyReport> Function()? analyzer}) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    calls = 0;
    behaviour = analyzer ?? () async => report();
    service = HtmlService(
      store: seedStore(InspectionStore(), p),
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
      sovereigntyAnalyzer: ({
        required pageUrl,
        required inspection,
        metadata,
        detections = const [],
        html,
        home = 'EU',
      }) {
        calls++;
        return behaviour();
      },
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<HtmlService>.value(value: service),
        ChangeNotifierProvider<AppSettings>.value(value: AppSettings()),
      ],
      child: const MaterialApp(home: Scaffold(body: SovereigntyView())),
    ));
    await tester.pump();
    await tester.pump();
  }

  group('SovereigntyView', () {
    testWidgets('(a) the analysis runs once, started by the service',
        (tester) async {
      await show(tester, fullPage());
      expect(calls, 1);
      expect(find.text('Hosts (1)'), findsOneWidget);
      expect(find.textContaining('Legal home of example.com'), findsOneWidget);
      // Rebuilds do not start another analysis.
      service.updateWebViewLoadingProgress(0.5);
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('(b) nothing verifiable: no score, not "0 / 100 Poor"',
        (tester) async {
      await show(tester, fullPage(),
          analyzer: () async => report(checks: const [
                SovereigntyCheck(
                    Pillar.security, 'c', CheckStatus.unknown, 'unknown'),
              ]));
      expect(find.text('No score: nothing could be verified'), findsOneWidget);
      expect(find.textContaining('/ 100'), findsNothing);
      expect(find.text('Poor'), findsNothing);
      expect(find.text('not verifiable'), findsWidgets);
      expect(find.text('n/a'), findsNothing);
    });

    testWidgets('(b) unknown hosts are unknown, not "all stay"',
        (tester) async {
      await show(tester, fullPage());
      expect(find.textContaining('All requests stay'), findsNothing);
      expect(find.textContaining('could not be determined'), findsOneWidget);
      expect(find.textContaining('size unknown'), findsOneWidget);
    });

    testWidgets('(b) a verified report shows its score', (tester) async {
      await show(tester, fullPage(),
          analyzer: () async => report(checks: const [
                SovereigntyCheck(Pillar.residency, 'a', CheckStatus.pass, ''),
              ]));
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('(b) the derived jurisdiction carries its warning',
        (tester) async {
      final base = fullPage();
      final s = (base.server as Present<ServerSnapshot>).value;
      final withCert = ServerSnapshot(
        requestedUrl: s.requestedUrl,
        userAgent: s.userAgent,
        hops: s.hops,
        finalUrl: s.finalUrl,
        body: s.body,
        timingMs: s.timingMs,
        certificate: server(<String, dynamic>{
          'subjectParsed': {'Country': 'US', 'Organization': 'Cloudflare, Inc.'}
        }),
      );
      await show(tester, base.copyWith(server: server(withCert)));
      expect(find.textContaining('derived, not confirmed'), findsOneWidget);
      expect(find.textContaining('may be the CDN, not the site owner'),
          findsOneWidget);
    });

    testWidgets('(c) local file: says there is no host', (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('local file'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('(c) nothing loaded', (tester) async {
      await show(tester, const PageInspection.empty());
      expect(find.text('Load a URL to analyze where it is hosted.'),
          findsOneWidget);
    });

    testWidgets('(e) pending: waiting text, no analysis yet', (tester) async {
      await show(tester, fullPage().copyWith(server: const Pending()));
      expect(find.textContaining('Waiting for the page'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('(e) failed: the error, not "Load a URL"', (tester) async {
      await show(tester, fullPage(),
          analyzer: () async => throw Exception('RIPEstat down'));
      expect(find.text('The sovereignty analysis failed'), findsOneWidget);
      expect(find.textContaining('RIPEstat down'), findsOneWidget);
      expect(find.textContaining('Load a URL'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = SovereigntyView.builds;
      service.updateWebViewLoadingProgress(0.7);
      await tester.pump();
      expect(SovereigntyView.builds, before);
    });
  });
}
