import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/collectors/file_loader.dart';
import 'package:view_source_vibe/services/derive/metadata_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';
import 'package:view_source_vibe/widgets/metadata_view.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

Future<Map<String, dynamic>> _realExtractor(String html, String base,
        {Map<String, String>? headers}) async =>
    extractMetadataSync(html, base, headers: headers);

HtmlService serviceFor(InspectionStore store, [MetadataExtractor? extractor]) =>
    HtmlService(
      store: store,
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: extractor ?? _realExtractor,
    );

const relativeHtml = '<html><head><title>Local</title></head><body>'
    '<img src="img/a.png"><script src="app.js"></script></body></html>';

FileSnapshot relativeFile() => FileLoader.fromText(relativeHtml,
    origin: FileOrigin.picker, name: 'local.html', path: '/tmp/local.html');

void main() {
  group('derive', () {
    test('deriveDocumentChecks counts what the old widget parsed', () {
      final c = deriveDocumentChecks('<html><body><h1>a</h1><h2>b</h2>'
          '<img src="a.png"><img src="b.png" alt="x"><nav></nav>'
          '<input id="n"><label for="n">N</label><input></body>'
          '<meta name="robots" content="noindex"></html>');
      expect(c.h1Count, 1);
      expect(c.headingCount, 2);
      expect(c.imageCount, 2);
      expect(c.imagesMissingAlt, 1);
      expect(c.landmarkCount, 1);
      expect(c.controlCount, 2);
      expect(c.unlabeledControls, 1);
      expect(c.robotsMeta, 'noindex');
      expect(deriveDocumentChecks('<p>x</p>').robotsMeta, isNull);
    });

    test('linkSizeLabel: known, estimated, unknown with a reason, never 0', () {
      expect(
          linkSizeLabel({'transfer': 2048, 'decoded': 4096},
              unknownReason: 'r'),
          '4 KB (↓ 2 KB)');
      expect(
          linkSizeLabel({'transfer': 2048, 'decoded': null, 'estimated': true},
              unknownReason: 'r'),
          '≈ ↓ 2 KB');
      expect(linkSizeLabel(null, unknownReason: 'not reported'),
          'size unknown (not reported)');
      expect(
          linkSizeLabel({
            'transfer': null,
            'decoded': null,
            'unknownReason': 'Not visible'
          }, unknownReason: 'x'),
          'size unknown (Not visible)');
    });
  });

  group('MetadataView', () {
    late HtmlService service;

    Future<void> show(WidgetTester tester, PageInspection p,
        {String? content, MetadataExtractor? extractor}) async {
      final store = seedStore(InspectionStore(), p);
      service = serviceFor(store, extractor);
      addTearDown(service.dispose);
      await tester.runAsync(() => service.loadFile(htmlFileFor(p,
          content: content ?? (p.target is UrlTarget ? 'x' : ''))));
      await pumpWithProviders(tester,
          service: service, child: const MetadataView());
      await tester.pump();
    }

    testWidgets('(a) full page: values and the analysed document',
        (tester) async {
      await show(tester, fullPage());
      expect(find.text('Rendered'), findsWidgets);
      expect(find.text('From: rendered DOM'), findsOneWidget);
      expect(find.textContaining('H1: 0 found'), findsOneWidget);
      expect(find.textContaining('This page has no <title>'), findsNothing);
    });

    testWidgets('(b) iOS: unknown sizes are said, not 0 KB', (tester) async {
      await show(tester, iosPartialWithLinks());
      expect(find.textContaining('size unknown (Not visible'), findsWidgets);
      expect(find.textContaining('↓ 2 KB'), findsOneWidget);
      expect(find.textContaining('0 KB'), findsNothing);
      expect(find.textContaining('0 B'), findsNothing);
    });

    testWidgets('(c) local file: findings, relative links, no old URL data',
        (tester) async {
      final store = seedStore(InspectionStore(), fullPage());
      service = serviceFor(store);
      addTearDown(service.dispose);
      await tester.runAsync(
          () => service.loadFile(htmlFileFor(fullPage(), content: 'x')));
      await pumpWithProviders(tester,
          service: service, child: const MetadataView());
      await tester.pump();
      expect(find.text('Rendered'), findsWidgets);

      final f = relativeFile();
      await tester.runAsync(() => service.loadFile(HtmlFile(
          name: f.name,
          path: f.path,
          content: relativeHtml,
          lastModified: DateTime(2024),
          size: relativeHtml.length)));
      await tester.pump();
      expect(find.text('Rendered'), findsNothing);
      expect(find.text('From: file'), findsOneWidget);
      expect(find.text('Local'), findsWidgets);
      expect(
          find.textContaining(
              'relative link — cannot be resolved for a local file'),
          findsWidgets);
      expect(find.textContaining('https://img'), findsNothing);
      await tester.tap(find.text('app.js'));
      await tester.pump();
      expect(service.currentFile?.path, f.path);
    });

    testWidgets('a page without <title> is a finding, not "No Title"',
        (tester) async {
      await show(tester, localFile());
      expect(find.textContaining('This page has no <title>'), findsWidgets);
      expect(find.textContaining('This page has no meta description'),
          findsWidgets);
      expect(find.text('No Title'), findsNothing);
      expect(find.text('No description available.'), findsNothing);
    });

    testWidgets('an empty <title> is an empty title, not a missing one',
        (tester) async {
      final p = fullPage();
      await show(tester, p, extractor: (h, b, {headers}) async {
        final m = extractMetadataSync(h, b);
        m['title'] = '';
        return m;
      });
      expect(
          find.textContaining('This page has an empty <title>'), findsWidgets);
      expect(find.textContaining('This page has no <title>'), findsNothing);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = MetadataView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      service.updateWebViewLoadingProgress(0.9);
      await tester.pump();
      expect(MetadataView.builds, before);
    });

    testWidgets('(e) pending and failed read differently', (tester) async {
      final p = fullPage();
      final pending = Completer<Map<String, dynamic>>();
      final store = seedStore(InspectionStore(), p);
      service = serviceFor(store, (h, b, {headers}) => pending.future);
      addTearDown(service.dispose);
      await tester.pump(const Duration(milliseconds: 300));
      final loading = service.loadFile(htmlFileFor(p, content: 'x'));
      await pumpWithProviders(tester,
          service: service, child: const MetadataView());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Reading the page metadata…'), findsOneWidget);
      pending.complete(extractMetadataSync('<html></html>', ''));
      await tester.runAsync(() => loading);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('(e) a failed extraction says so', (tester) async {
      final p = fullPage();
      await show(tester, p, extractor: (h, b, {headers}) async {
        throw StateError('parser broke');
      });
      expect(find.textContaining('Metadata could not be extracted'),
          findsOneWidget);
      expect(find.textContaining('parser broke'), findsOneWidget);
      expect(find.text('Reading the page metadata…'), findsNothing);
      expect(find.text('This page has no <title>'), findsNothing);
    });
  });
}
