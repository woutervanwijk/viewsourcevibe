import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';

import '../derive/fixtures.dart'
    show inspection, serverSnap, browserSnap, cookie;
import '../fixtures/inspection/full_page.dart';
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
        service: service, child: const ProbeCookiesView());
    await tester.pump();
  }

  group('ProbeCookiesView', () {
    testWidgets('(a) full page: the cookie and its flags equal the fixture',
        (tester) async {
      await show(tester, fullPage());
      expect(find.text('sid'), findsOneWidget);
      expect(find.text('abc'), findsOneWidget);
      expect(find.text('Secure: yes · HttpOnly: yes · SameSite: Lax'),
          findsOneWidget);
      expect(find.textContaining('Domain: example.com'), findsOneWidget);
      expect(find.textContaining('Expires: unknown'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(find.text('1 total'), findsOneWidget);
    });

    testWidgets('(b) unknown flags are shown as unknown, never as No',
        (tester) async {
      await show(
          tester,
          inspection(
              server: serverSnap(),
              browser: browserSnap(cookies: [cookie('x')])));
      expect(
          find.text('Secure: unknown · HttpOnly: unknown · SameSite: unknown'),
          findsOneWidget);
      expect(find.textContaining('Secure: no'), findsNothing);
      expect(find.textContaining('not marked Secure'), findsNothing);
      expect(find.textContaining('unknown for 1 cookie'), findsOneWidget);
    });

    testWidgets('(b) a server Set-Cookie shows its source and real flags',
        (tester) async {
      await show(
          tester,
          inspection(
              server: serverSnap(setCookies: ['sid=1; Path=/; HttpOnly']),
              browser: browserSnap(cookies: const [])));
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Secure: no · HttpOnly: yes · SameSite: not set'),
          findsOneWidget);
    });

    testWidgets('(b) a missing source is said, not a silent "no cookies"',
        (tester) async {
      await show(tester, fullPage().copyWith(browser: const Pending()));
      expect(find.textContaining('Unknown: browser cookies'), findsOneWidget);
      expect(find.text('No cookies detected.'), findsNothing);
    });

    testWidgets('empty with every source present: an honest zero',
        (tester) async {
      await show(
          tester,
          inspection(
              server: serverSnap(), browser: browserSnap(cookies: const [])));
      expect(find.text('No cookies detected.'), findsOneWidget);
    });

    testWidgets('(c) local file', (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('local file'), findsOneWidget);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = ProbeCookiesView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      expect(ProbeCookiesView.builds, before);
    });

    testWidgets('(e) pending and failed are distinct', (tester) async {
      await show(
          tester,
          fullPage()
              .copyWith(server: const Pending(), browser: const Pending()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await show(
          tester,
          fullPage().copyWith(
              server: const Failed('network error: boom'),
              browser: const Pending()));
      expect(find.textContaining('network error: boom'), findsOneWidget);
    });
  });
}
