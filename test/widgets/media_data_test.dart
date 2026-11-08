import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/collectors/file_loader.dart';
import 'package:view_source_vibe/services/derive/media.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/media_view.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

const mediaUrl = 'https://media.example.com/';
const mediaDom = '<html><head><title>M</title></head><body>'
    '<img src="https://media.example.com/a.png" alt="First">'
    '<img src="https://media.example.com/a.png?v=2" alt="Dup">'
    '<video src="https://media.example.com/v.mp4"></video>'
    '</body></html>';

PageInspection mediaPage() => urlInspection(
      url: mediaUrl,
      serverResult: const Pending(),
      browserResult: browser(browserSnapshot(
        url: mediaUrl,
        dom: mediaDom,
        resources: [
          resource('https://media.example.com/a.png', 'img',
              transfer: browser(2048), decoded: browser(900000)),
          resource('https://media.example.com/v.mp4', 'video',
              transfer: browser(300000), decoded: browser(300000)),
          resource('https://media.example.com/f.woff2', 'css',
              transfer: browser(20000), decoded: browser(30000)),
        ],
      )),
    );

void main() {
  group('derive', () {
    test('normalizeMediaUrl ignores cache busters, fragments, default ports',
        () {
      expect(normalizeMediaUrl('https://a.test/x.png?v=3#top'),
          normalizeMediaUrl('https://a.test:443/x.png'));
      expect(normalizeMediaUrl('https://a.test/x.png?w=100'),
          isNot(normalizeMediaUrl('https://a.test/x.png')));
    });

    test('deduplicateMedia keeps the first of equal URLs, skips empty', () {
      final out = deduplicateMedia([
        {'src': 'https://a.test/x.png'},
        {'src': 'https://a.test/x.png?ts=9'},
        {'src': ''},
        {'src': 'data:image/png;base64,AA'},
        {'src': 'data:image/png;base64,AA'},
      ]);
      expect(out, hasLength(2));
    });

    test('sanitizeSvgData turns percentages into absolute numbers', () {
      final out = utf8.decode(sanitizeSvgData(Uint8List.fromList(utf8.encode(
          '<svg viewBox="0 0 100 50"><circle cx="50%" cy="50%" r="10%"/></svg>'))));
      expect(out, contains('cx="50.0"'));
      expect(out, contains('cy="25.0"'));
      expect(out, isNot(contains('%')));
    });

    test('imageSizeLabel: transfer only, estimate marked, unknown explained',
        () {
      expect(
          imageSizeLabel({'transfer': 2048, 'decoded': 900000},
              unknownReason: 'r'),
          '2 KB');
      expect(
          imageSizeLabel({'transfer': 2048, 'decoded': null, 'estimated': true},
              unknownReason: 'r'),
          '≈ 2 KB');
      expect(imageSizeLabel(null, unknownReason: 'not reported'),
          'size unknown (not reported)');
    });
  });

  group('MediaView', () {
    late HtmlService service;

    Future<void> show(WidgetTester tester, PageInspection p,
        {HtmlService Function(InspectionStore)? make, String? content}) async {
      final store = seedStore(InspectionStore(), p);
      service = (make ?? makeServiceWithMetadata)(store);
      addTearDown(service.dispose);
      await tester.runAsync(() => service.loadFile(htmlFileFor(p,
          content: content ?? (p.target is UrlTarget ? 'x' : ''))));
      await pumpWithProviders(tester,
          service: service, child: const MediaView());
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('(a) values equal the fixture, duplicates merged',
        (tester) async {
      await show(tester, mediaPage());
      expect(find.text('Images (1)'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Dup'), findsNothing);
      // The image size is the transfer size, not the decoded 879 KB.
      expect(find.text('2 KB'), findsOneWidget);
      expect(find.text('Videos (1)'), findsOneWidget);
      expect(find.text('Fonts (1)'), findsOneWidget);
      expect(find.textContaining('879'), findsNothing);
    });

    testWidgets('(b) iOS: an image without a size says why, never 0',
        (tester) async {
      await show(tester, iosPartialWithLinks());
      expect(find.text('5 KB'), findsOneWidget);
      expect(find.textContaining('size unknown (Not visible'), findsOneWidget);
      expect(find.textContaining('0 KB'), findsNothing);
    });

    testWidgets('(c) local file: relative image is not resolved or opened',
        (tester) async {
      final store = seedStore(InspectionStore(), mediaPage());
      service = makeServiceWithMetadata(store);
      addTearDown(service.dispose);
      await tester.runAsync(
          () => service.loadFile(htmlFileFor(mediaPage(), content: 'x')));
      await pumpWithProviders(tester,
          service: service, child: const MediaView());
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('First'), findsOneWidget);

      const html = '<html><body><img src="img/a.png" alt="Rel"></body></html>';
      final f = FileLoader.fromText(html,
          origin: FileOrigin.picker, name: 'l.html', path: '/tmp/l.html');
      await tester.runAsync(() => service.loadFile(HtmlFile(
          name: f.name,
          path: f.path,
          content: html,
          lastModified: DateTime(2024),
          size: html.length)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('First'), findsNothing);
      expect(find.text('Rel'), findsOneWidget);
      expect(
          find.textContaining(
              'relative link — cannot be resolved for a local file'),
          findsOneWidget);
      expect(find.textContaining('https://img'), findsNothing);
      await tester.tap(find.text('Rel'));
      await tester.pump();
      expect(service.currentFile?.path, f.path);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, mediaPage());
      final before = MediaView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      service.updateWebViewLoadingProgress(0.7);
      await tester.pump();
      expect(MediaView.builds, before);
    });

    testWidgets('(e) none found, reading and failed are distinct',
        (tester) async {
      await show(tester, localFile());
      expect(find.text('No Images, Videos or Fonts found'), findsOneWidget);

      await show(tester, mediaPage(),
          make: (s) => HtmlService(
                store: s,
                serverFetcher: SilentServerFetcher(),
                browserLoader: SilentBrowserLoader(),
                metadataExtractor: (h, b, {headers}) async =>
                    throw StateError('parser broke'),
              ));
      expect(find.textContaining('parser broke'), findsOneWidget);
      expect(find.text('No Images, Videos or Fonts found'), findsNothing);
    });

    testWidgets('pending metadata is reading, not "no media"', (tester) async {
      final store = seedStore(InspectionStore(), mediaPage());
      service = makeServiceWithMetadata(store);
      addTearDown(service.dispose);
      await pumpWithProviders(tester,
          service: service, child: const MediaView());
      await tester.pump();
      expect(find.text('Reading the page metadata…'), findsOneWidget);
      expect(find.text('No Images, Videos or Fonts found'), findsNothing);
    });

    testWidgets('items are keyed by URL, so a new page does not reuse state',
        (tester) async {
      await show(tester, mediaPage());
      expect(
          find.byKey(const ValueKey('font:https://media.example.com/f.woff2')),
          findsOneWidget);
    });
  });

  // keep the import used when a test above is skipped
  test('MediaModel.isEmpty', () {
    expect(
        const MediaModel(
            docSource: DataSource.file,
            images: [],
            inlineImages: [],
            videos: [],
            fonts: []).isEmpty,
        isTrue);
  });
}
