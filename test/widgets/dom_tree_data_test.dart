import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/dom_tree.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/dom_tree_view.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

DomTree html(String s) => deriveDomTree(s, DomTreeKind.html);

void main() {
  group('deriveDomTree (B25)', () {
    test('a lowercase doctype is HTML', () {
      final t = html('<!doctype html><html><body><p>x</p></body></html>');
      expect(t.usedXmlParser, isFalse);
      expect(t.roots.single.label, 'html');
    });

    test('a comment, BOM and whitespace before the doctype are skipped', () {
      final t = html(
          '﻿  \n<!-- saved from url -->\n<!DocType HTML><html><body>x</body></html>');
      expect(t.usedXmlParser, isFalse);
      expect(t.roots.single.label, 'html');
    });

    test('an uppercase <HTML> root is HTML', () {
      expect(html('<HTML><BODY>x</BODY></HTML>').usedXmlParser, isFalse);
    });

    test('an HTML fragment is not sent to the XML parser', () {
      final t = html('<div><p>unclosed <b>bold</div>');
      expect(t.usedXmlParser, isFalse);
      expect(t.roots, isNotEmpty);
    });

    test('feeds and xml declarations use the XML parser', () {
      final rss = html('<?xml version="1.0"?><rss><channel><title>t</title>'
          '</channel></rss>');
      expect(rss.usedXmlParser, isTrue);
      expect(rss.roots.single.label, 'rss');
      expect(html('<rss version="2.0"><channel/></rss>').usedXmlParser, isTrue);
      expect(deriveDomTree('<svg><g/></svg>', DomTreeKind.svg).usedXmlParser,
          isTrue);
    });

    test('malformed XML gives an approximate tree and a note', () {
      final t = deriveDomTree('<a><b></a', DomTreeKind.xml);
      expect(t.note, contains('malformed'));
      expect(t.roots.single.label, 'corrupt-xml');
    });

    test('empty text is an empty tree', () {
      expect(html('').roots, isEmpty);
    });
  });

  group('DomTreeView', () {
    late InspectionStore store;
    late HtmlService service;

    Future<void> show(WidgetTester tester, PageInspection p) async {
      store = seedStore(InspectionStore(), p);
      service = makeService(store);
      addTearDown(service.dispose);
      await pumpWithProviders(tester,
          service: service, child: const DomTreeView());
      await tester.pump();
    }

    testWidgets('shows which document it represents and the tree',
        (tester) async {
      await show(tester, fullPage());
      expect(find.text('Source: rendered DOM'), findsOneWidget);
      expect(find.text('<html'), findsOneWidget);
      expect(find.textContaining('id="app"'), findsOneWidget);

      service.selectSourceDocument(DataSource.server);
      await tester.pump();
      expect(find.text('Source: server HTML'), findsOneWidget);
      expect(find.textContaining('SERVER-BODY'), findsOneWidget);
      expect(find.textContaining('id="app"'), findsNothing);
    });

    testWidgets('a local file says "file"', (tester) async {
      await show(tester, localFile());
      expect(find.text('Source: file'), findsOneWidget);
      expect(find.textContaining('LOCAL-FILE-TEXT'), findsOneWidget);
    });

    testWidgets('built once per document, not per rebuild', (tester) async {
      await show(tester, fullPage());
      expect(service.domTreeBuilds, 1);
      service.updateWebViewLoadingProgress(0.5);
      await tester.pump();
      service.updateWebViewLoadingProgress(0.9);
      await tester.pump();
      expect(service.domTreeBuilds, 1);

      service.selectSourceDocument(DataSource.server);
      await tester.pump();
      expect(service.domTreeBuilds, 2);
    });

    testWidgets('server HTML still pending: a message, no stale tree',
        (tester) async {
      final p = fullPage();
      await show(
          tester,
          PageInspection(
              generation: 1,
              target: p.target,
              server: const Pending(),
              browser: p.browser,
              file: p.file,
              primaryDocumentPreference: DataSource.server));
      expect(find.text('Fetching server HTML…'), findsOneWidget);
      expect(find.textContaining('id="app"'), findsNothing);
    });
  });
}
