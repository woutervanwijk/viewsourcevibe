import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

PageInspection page(
  Map<String, List<String>> headers, {
  String url = 'https://a.test/',
  Observed<Map<String, dynamic>>? certificate,
  bool invalidCert = false,
}) {
  final cert = certificate ??
      const Unavailable<Map<String, dynamic>>(UnavailableReason.notApplicable);
  final h = HttpHop(
    url: Uri.parse(url),
    statusCode: 200,
    reasonPhrase: 'OK',
    headers: headers,
    setCookies: const [],
    remoteAddress: server('1.2.3.4'),
    certificate: cert,
  );
  return urlInspection(
    url: url,
    serverResult: server(ServerSnapshot(
      requestedUrl: Uri.parse(url),
      userAgent: kServerUserAgent,
      hops: [h],
      finalUrl: server(Uri.parse(url)),
      body: serverSnapshot(url: url, hops: [h], body: 'x').body,
      timingMs: server(5),
      certificate: cert,
      acceptedInvalidCertificate: invalidCert,
    )),
    browserResult: const Pending(),
  );
}

void main() {
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    service = makeService(seedStore(InspectionStore(), p));
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const ProbeSecurityView());
    await tester.pump();
  }

  final goodHeaders = {
    'strict-transport-security': ['max-age=31536000'],
    'content-security-policy': ["default-src 'self'; frame-ancestors 'none'"],
    'x-content-type-options': ['nosniff'],
    'referrer-policy': ['no-referrer'],
    'permissions-policy': ['camera=()'],
  };

  group('ProbeSecurityView', () {
    testWidgets('(a) full page: the audit equals the response', (tester) async {
      await show(tester, fullPage());
      expect(find.text('Security Headers Score'), findsOneWidget);
      expect(find.text('0 of 6 controls present'), findsOneWidget);
      expect(find.text('Missing Header'), findsNWidgets(6));
    });

    testWidgets('(a) a good response scores fully', (tester) async {
      await show(tester, page(goodHeaders));
      expect(find.text('6 of 6 controls present'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      // Frames pass through CSP frame-ancestors; X-Frame-Options itself is
      // still reported as not sent.
      expect(find.text('Missing Header'), findsOneWidget);
      expect(find.textContaining('max-age'), findsOneWidget);
    });

    testWidgets('(b) pending server: no score, no verdicts', (tester) async {
      await show(tester, fullPage().copyWith(server: const Pending()));
      expect(find.text('Security Headers Score'), findsOneWidget);
      expect(find.textContaining('controls present'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.text('Missing Header'), findsNothing);
      expect(find.textContaining('No Content-Security-Policy'), findsNothing);
      expect(find.textContaining('Fetching'), findsWidgets);
    });

    testWidgets('(b) failed server: the error, no score', (tester) async {
      await show(tester,
          fullPage().copyWith(server: const Failed('network error: boom')));
      expect(find.textContaining('network error: boom'), findsWidgets);
      expect(find.textContaining('controls present'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('(b) csp: missing header is a finding, with no score',
        (tester) async {
      await show(tester, fullPage());
      expect(find.text('No Content-Security-Policy header found.'),
          findsOneWidget);
    });

    testWidgets('(b) http page: no certificate, says why', (tester) async {
      await show(tester, page({}, url: 'http://a.test/'));
      expect(find.textContaining('loaded over HTTP'), findsOneWidget);
      expect(find.text('No certificate information available'), findsNothing);
    });

    testWidgets('(b) certificate fields of the final hop', (tester) async {
      await show(
          tester,
          page({},
              certificate: server({
                'subjectParsed': {
                  'Common Name': 'a.test',
                  'Organization': 'A Inc'
                },
                'issuerParsed': {'Organization': 'CA Corp'},
                'startValidity': '2020-01-01T00:00:00.000Z',
                'endValidity': '2021-01-01T00:00:00.000Z',
                'pem': 'PEM',
              })));
      expect(find.text('A Inc'), findsOneWidget);
      expect(find.text('CA Corp'), findsOneWidget);
      expect(find.textContaining('Expired'), findsOneWidget);
      expect(find.text('CN matches host'), findsOneWidget);
      expect(find.text('Copy PEM Certificate'), findsOneWidget);
    });

    testWidgets('(b) accepted invalid certificate shows the warning',
        (tester) async {
      await show(tester, page({}, invalidCert: true));
      expect(find.text('TLS Certificate Warning'), findsOneWidget);
    });

    testWidgets('(c) local file: nothing to show', (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('local file'), findsOneWidget);
      expect(find.text('Security Headers Score'), findsNothing);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = ProbeSecurityView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      expect(ProbeSecurityView.builds, before);
    });
  });
}
