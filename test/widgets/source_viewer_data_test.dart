import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/source_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';
import 'package:view_source_vibe/widgets/source_viewer.dart';

import '../fixtures/inspection/bot_blocked.dart';
import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

String editorText(WidgetTester tester) =>
    (tester.widget<CodeEditor>(find.byType(CodeEditor)).controller
            as CodeLineEditingController)
        .text;

Iterable<String> allTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

void main() {
  late InspectionStore store;
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p,
      {bool loadLegacyFile = false}) async {
    store = seedStore(InspectionStore(), p);
    service = makeService(store);
    addTearDown(service.dispose);
    if (loadLegacyFile) {
      await tester.runAsync(() => service.loadFile(
          htmlFileFor(p, content: 'LEGACY-FILE-CONTENT'),
          clearProbe: false));
    }
    await pumpWithProviders(tester,
        service: service,
        child:
            SourceViewer(file: htmlFileFor(p, content: 'LEGACY-FILE-CONTENT')));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('full page: default is the rendered DOM, with a switch',
      (tester) async {
    await show(tester, fullPage());
    expect(editorText(tester), fullPageDomHtml);
    expect(find.text('Rendered DOM'), findsOneWidget);
    expect(find.text('Server HTML'), findsOneWidget);
    expect(find.textContaining('characters (serialized DOM)'), findsOneWidget);
    expect(find.textContaining('LEGACY-FILE-CONTENT'), findsNothing);
  });

  testWidgets('switching to Server HTML shows the server body via the store',
      (tester) async {
    await show(tester, fullPage());
    await tester.tap(find.text('Server HTML'));
    await tester.pump();
    expect(editorText(tester), fullPageServerHtml);
    expect(store.current.primaryDocumentPreference, DataSource.server);
    expect(find.text('${fullPageServerHtml.length} bytes'),
        findsNothing); // inside the "lines • size" label
    expect(find.textContaining('${fullPageServerHtml.length} bytes'),
        findsOneWidget);

    await tester.tap(find.text('Rendered DOM'));
    await tester.pump();
    expect(editorText(tester), fullPageDomHtml);
  });

  testWidgets('server body pending: spinner and a fetching message',
      (tester) async {
    final p = fullPage();
    await show(
        tester,
        PageInspection(
            generation: 1,
            target: p.target,
            server: const Pending(),
            browser: p.browser,
            file: p.file));
    await tester.tap(find.text('Server HTML'));
    await tester.pump();
    expect(find.text('Fetching server HTML…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CodeEditor), findsNothing);
  });

  testWidgets('server failed shows the error, unavailable the reason',
      (tester) async {
    final p = fullPage();
    await show(
        tester,
        PageInspection(
            generation: 1,
            target: p.target,
            server: const Failed('network error: connection refused'),
            browser: p.browser,
            file: p.file));
    await tester.tap(find.text('Server HTML'));
    await tester.pump();
    expect(find.text('network error: connection refused'), findsOneWidget);

    final q = PageInspection(
        generation: 1,
        target: p.target,
        server: const Unavailable(
            UnavailableReason.notApplicable, 'no request was made'),
        browser: p.browser,
        file: p.file);
    await tester.pumpWidget(const SizedBox());
    await show(tester, q);
    await tester.tap(find.text('Server HTML'));
    await tester.pump();
    expect(find.textContaining('Not applicable: no request was made'),
        findsOneWidget);
  });

  testWidgets('local file: no switch, file text, byte size (not characters)',
      (tester) async {
    await show(tester, localFile());
    expect(find.text('Rendered DOM'), findsNothing);
    expect(find.text('Server HTML'), findsNothing);
    expect(editorText(tester), localFileHtml);
    expect(find.textContaining('123 bytes'), findsOneWidget);
    expect(find.textContaining('characters'), findsNothing);
  });

  testWidgets('server size: bytes, plus transfer when it differs',
      (tester) async {
    final h = hop('https://gz.test/', 200, headers: {
      'content-type': ['text/html']
    });
    final p = urlInspection(
      url: 'https://gz.test/',
      serverResult: server(serverSnapshot(
          url: 'https://gz.test/',
          hops: [h],
          body: '<html>x</html>',
          decodedBody: decoded('<html>x</html>', byteLength: 5000),
          transferLength: 1200)),
      browserResult: const Pending(),
    );
    await show(tester, p);
    expect(find.textContaining('5.000 bytes'), findsOneWidget);
    expect(find.textContaining('transfer 1.200 bytes'), findsOneWidget);
  });

  testWidgets('ios partial: never a zero-byte size anywhere', (tester) async {
    await show(tester, iosPartial());
    final zero = RegExp(r'(^|[^0-9.])0 bytes');
    expect(allTexts(tester).where(zero.hasMatch), isEmpty);
    await tester.tap(find.text('Server HTML'));
    await tester.pump();
    expect(allTexts(tester).where(zero.hasMatch), isEmpty);
    expect(editorText(tester), iosServerHtml);
  });

  testWidgets('charset line for a Latin-1 server body', (tester) async {
    final h = hop('https://l1.test/', 200, headers: {
      'content-type': ['text/html; charset=iso-8859-1']
    });
    final p = urlInspection(
      url: 'https://l1.test/',
      serverResult: server(serverSnapshot(
          url: 'https://l1.test/',
          hops: [h],
          body: '<html>café</html>',
          decodedBody: decoded('<html>café</html>',
              charset: 'iso-8859-1', source: CharsetSource.header))),
      browserResult: const Pending(),
    );
    await show(tester, p);
    expect(find.text('charset iso-8859-1 (HTTP header)'), findsOneWidget);
  });

  testWidgets('unsupported charset is said, not hidden', (tester) async {
    final h = hop('https://x.test/', 200);
    final p = urlInspection(
      url: 'https://x.test/',
      serverResult: server(serverSnapshot(
          url: 'https://x.test/',
          hops: [h],
          body: '<html>x</html>',
          decodedBody: decoded('<html>x</html>',
              charset: 'windows-1252',
              source: CharsetSource.fallback,
              unsupported: true,
              declared: 'x-weird'))),
      browserResult: const Pending(),
    );
    await show(tester, p);
    expect(find.text('charset x-weird not supported — shown as windows-1252'),
        findsOneWidget);
  });

  testWidgets('TLS warning comes from the store', (tester) async {
    final h = hop('https://bad.test/', 200);
    PageInspection withTls(bool accepted) => urlInspection(
          url: 'https://bad.test/',
          serverResult: server(serverSnapshot(
              url: 'https://bad.test/',
              hops: [h],
              body: '<html>x</html>',
              acceptedInvalidCertificate: accepted)),
          browserResult: const Pending(),
        );
    await show(tester, withTls(true));
    expect(find.textContaining('TLS certificate validation failed'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await show(tester, withTls(false));
    expect(
        find.textContaining('TLS certificate validation failed'), findsNothing);
  });

  testWidgets('a refreshed DOM in the store shows up (R23)', (tester) async {
    await show(tester, fullPage());
    expect(editorText(tester), fullPageDomHtml);
    final b = (store.current.browser as Present<BrowserSnapshot>).value;
    store.applyBrowser(store.current.generation,
        browserSnapshot(url: b.url.toString(), dom: '<html>REFRESHED</html>'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(editorText(tester), '<html>REFRESHED</html>');
  });

  testWidgets('bot blocked: the DOM is the default, server shows the challenge',
      (tester) async {
    await show(tester, botBlocked());
    expect(editorText(tester), botDomHtml);
    await tester.tap(find.text('Server HTML'));
    await tester.pump();
    expect(editorText(tester), botChallengeHtml);
  });

  testWidgets('legacy file content is used only when the store has no document',
      (tester) async {
    final p = fullPage();
    await show(
        tester,
        PageInspection(
            generation: 1,
            target: p.target,
            server: const Unavailable(
                UnavailableReason.notApplicable, 'not fetched'),
            browser: const Pending(),
            file: p.file),
        loadLegacyFile: true);
    expect(editorText(tester), 'LEGACY-FILE-CONTENT');
  });

  testWidgets('fallback text: no switch, honest label', (tester) async {
    final p = fullPage();
    await show(
        tester,
        PageInspection(
            generation: 1,
            target: p.target,
            server: const Unavailable(
                UnavailableReason.notApplicable, 'not fetched'),
            browser: const Pending(),
            file: p.file),
        loadLegacyFile: true);
    expect(find.text('Rendered DOM'), findsNothing);
    expect(find.text('Server HTML'), findsNothing);
    expect(find.textContaining('loaded document'), findsOneWidget);
  });

  test('a file target without a file snapshot uses the legacy text', () {
    final p = localFile();
    final noSnapshot = PageInspection(
        generation: 1,
        target: p.target,
        server: p.server,
        browser: p.browser,
        file: const Failed('could not read'));
    final v = deriveSourceView(noSnapshot, fallbackText: 'LEGACY-FILE-CONTENT');
    expect(v.textOrNull, 'LEGACY-FILE-CONTENT');
    expect(v.canSwitch, isFalse);
    expect(v.sizeLabel, contains('loaded document'));
    // Without legacy text the failure is shown, not hidden.
    expect(deriveSourceView(noSnapshot).text, isA<Failed<String>>());
  });

  test('line count is part of the derived view', () {
    final v = deriveSourceView(localFile());
    expect(v.lineCount, 1);
    expect(deriveSourceView(fullPage()).lineCount, 1);
  });
}
